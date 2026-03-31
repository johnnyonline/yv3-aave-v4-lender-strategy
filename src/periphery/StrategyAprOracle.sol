// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {IHub} from "../interfaces/IHub.sol";
import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";

contract StrategyAprOracle is AprOracleBase {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice RAY constant
    uint256 private constant _RAY = 1e27;

    /// @notice WAD constant
    uint256 private constant _WAD = 1e18;

    /// @notice Max basis points
    uint256 private constant _MAX_BPS = 10_000;

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor() AprOracleBase("Aave V4 Lender APR Oracle", msg.sender) {}

    // ===============================================================
    // View functions
    // ===============================================================

    /// @inheritdoc AprOracleBase
    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256) {
        IStrategyInterface _s = IStrategyInterface(_strategy);
        IHub _hub = IHub(_s.HUB());
        uint16 _assetId = _s.ASSET_ID();

        // Per-second borrow rate in RAY
        uint256 _drawnRate = _hub.getAssetDrawnRate(_assetId);

        // Total supplied and total borrowed
        uint256 _totalAdded = _hub.getAddedAssets(_assetId);
        uint256 _totalOwed = _hub.getAssetTotalOwed(_assetId);

        // Adjust total supplied for the delta
        if (_delta > 0) {
            _totalAdded += uint256(_delta);
        } else if (_delta < 0) {
            uint256 _decrease = uint256(-_delta);
            _totalAdded = _totalAdded > _decrease ? _totalAdded - _decrease : 0;
        }

        if (_totalAdded == 0) return 0;

        // Utilization = totalOwed / totalAdded
        // Supply rate = drawn rate * utilization * (1 - liquidityFee)
        IHub.AssetConfig memory _config = _hub.getAssetConfig(_assetId);
        uint256 _netFactor = _MAX_BPS - uint256(_config.liquidityFee);

        // supplyRate (RAY) = drawnRate * totalOwed / totalAdded * netFactor / MAX_BPS
        uint256 _supplyRate = (_drawnRate * _totalOwed * _netFactor) / (_totalAdded * _MAX_BPS);

        // Convert from RAY to WAD
        return _supplyRate / (_RAY / _WAD);
    }

}

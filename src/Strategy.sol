// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AuctionSwapper} from "@periphery/swappers/AuctionSwapper.sol";
import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IHub} from "./interfaces/IHub.sol";
import {ISpoke} from "./interfaces/ISpoke.sol";
import {IMerklDistributor} from "./interfaces/IMerklDistributor.sol";

contract AaveV4LenderStrategy is AuctionSwapper, BaseHealthCheck {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice The Aave V4 Spoke contract used for supply/withdraw operations
    ISpoke public immutable SPOKE;

    /// @notice The Aave V4 Hub contract that manages liquidity and share accounting
    IHub public immutable HUB;

    /// @notice The reserve identifier on the Spoke for this strategy's asset
    uint256 public immutable RESERVE_ID;

    /// @notice The asset identifier on the Hub
    uint16 public immutable ASSET_ID;

    /// @notice The number of decimals of the underlying asset
    uint256 private immutable _DECIMALS;

    /// @notice The Merkl Distributor contract for claiming rewards
    IMerklDistributor private constant _MERKL_DISTRIBUTOR =
        IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @notice Initializes the strategy
    /// @param _asset The underlying asset to lend
    /// @param _name The name of the strategy
    /// @param _spoke The Aave V4 Spoke contract address
    /// @param _reserveId The reserve ID for `_asset` on the Spoke
    constructor(
        address _asset,
        string memory _name,
        address _spoke,
        uint256 _reserveId
    ) BaseHealthCheck(_asset, _name) {
        SPOKE = ISpoke(_spoke);
        RESERVE_ID = _reserveId;

        ISpoke.Reserve memory _reserve = SPOKE.getReserve(RESERVE_ID);
        require(_reserve.underlying == _asset, "!asset");

        HUB = _reserve.hub;
        ASSET_ID = _reserve.assetId;
        _DECIMALS = asset.decimals();

        asset.forceApprove(_spoke, type(uint256).max);
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Returns the amount of assets currently supplied
    /// @return The supplied balance including accrued interest
    function balanceOfSupplied() public view returns (uint256) {
        return SPOKE.getUserSuppliedAssets(RESERVE_ID, address(this));
    }

    /// @notice Returns the amount of idle assets held by the strategy
    /// @return The idle asset balance
    function balanceOfAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @inheritdoc BaseStrategy
    function availableDepositLimit(
        address /*_owner*/
    ) public view override returns (uint256) {
        ISpoke.ReserveConfig memory _reserveConfig = SPOKE.getReserveConfig(RESERVE_ID);
        if (_reserveConfig.paused || _reserveConfig.frozen) return 0;

        IHub.SpokeConfig memory _spokeConfig = HUB.getSpokeConfig(ASSET_ID, address(SPOKE));

        // MAX_ALLOWED_SPOKE_CAP means no cap
        if (_spokeConfig.addCap >= HUB.MAX_ALLOWED_SPOKE_CAP()) return type(uint256).max;

        // addCap is in whole assets, scale to decimals
        uint256 _supplyCap = uint256(_spokeConfig.addCap) * (10 ** _DECIMALS);
        uint256 _currentSupply = HUB.getSpokeAddedAssets(ASSET_ID, address(SPOKE));

        if (_currentSupply >= _supplyCap) return 0;

        return _supplyCap - _currentSupply;
    }

    /// @inheritdoc BaseStrategy
    function availableWithdrawLimit(
        address /*_owner*/
    ) public view override returns (uint256) {
        ISpoke.ReserveConfig memory _reserveConfig = SPOKE.getReserveConfig(RESERVE_ID);
        if (_reserveConfig.paused) return 0;

        return balanceOfAsset() + Math.min(balanceOfSupplied(), HUB.getAssetLiquidity(ASSET_ID));
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Claims rewards from the Merkl distributor
    /// @param _users Recipients of tokens
    /// @param _tokens ERC20 tokens being claimed
    /// @param _amounts Amounts of tokens that will be sent to the corresponding users
    /// @param _proofs Array of Merkle proofs verifying the claims
    function claimMerklRewards(
        address[] calldata _users,
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        bytes32[][] calldata _proofs
    ) external onlyManagement {
        _MERKL_DISTRIBUTOR.claim(_users, _tokens, _amounts, _proofs);
    }

    /// @notice Set the auction contract to use for selling rewards
    /// @param _auction The auction contract address
    function setAuction(
        address _auction
    ) external onlyManagement {
        _setAuction(_auction);
    }

    /// @notice Enable or disable auction usage for reward selling
    /// @param _useAuction Whether to use auctions
    function setUseAuction(
        bool _useAuction
    ) external onlyManagement {
        _setUseAuction(_useAuction);
    }

    /// @notice Set the minimum token amount required to kick an auction
    /// @param _minAmountToSell Minimum token amount
    function setMinAmountToSell(
        uint256 _minAmountToSell
    ) external onlyManagement {
        _setMinAmountToSell(_minAmountToSell);
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _deployFunds(
        uint256 _amount
    ) internal override {
        SPOKE.supply(RESERVE_ID, _amount, address(this));
    }

    /// @inheritdoc BaseStrategy
    function _freeFunds(
        uint256 _amount
    ) internal override {
        SPOKE.withdraw(RESERVE_ID, _amount, address(this));
    }

    /// @inheritdoc BaseStrategy
    function _emergencyWithdraw(
        uint256 _amount
    ) internal override {
        _freeFunds(_amount);
    }

    /// @inheritdoc BaseStrategy
    function _harvestAndReport() internal view override returns (uint256) {
        return balanceOfSupplied() + balanceOfAsset();
    }

}

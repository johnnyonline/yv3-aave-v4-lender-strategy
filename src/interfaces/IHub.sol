// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IHub {

    struct SpokeConfig {
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
    }

    function getAssetLiquidity(
        uint256 assetId
    ) external view returns (uint256);
    function getSpokeAddedAssets(
        uint256 assetId,
        address spoke
    ) external view returns (uint256);
    function getSpokeConfig(
        uint256 assetId,
        address spoke
    ) external view returns (SpokeConfig memory);
    function MAX_ALLOWED_SPOKE_CAP() external view returns (uint40);
    function getAddedAssets(
        uint256 assetId
    ) external view returns (uint256);
    function getAssetTotalOwed(
        uint256 assetId
    ) external view returns (uint256);
    function getAssetDrawnRate(
        uint256 assetId
    ) external view returns (uint256);

    struct AssetConfig {
        address feeReceiver;
        uint16 liquidityFee;
        address irStrategy;
        address reinvestmentController;
    }

    function getAssetConfig(
        uint256 assetId
    ) external view returns (AssetConfig memory);

}

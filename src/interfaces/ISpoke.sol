// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IHub} from "./IHub.sol";

interface ISpoke {

    struct Reserve {
        address underlying;
        IHub hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        uint8 flags;
        uint32 dynamicConfigKey;
    }

    struct ReserveConfig {
        uint24 collateralRisk;
        bool paused;
        bool frozen;
        bool borrowable;
        bool receiveSharesEnabled;
    }

    function supply(
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);
    function withdraw(
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);
    function getUserSuppliedAssets(
        uint256 reserveId,
        address user
    ) external view returns (uint256);
    function getReserve(
        uint256 reserveId
    ) external view returns (Reserve memory);
    function getReserveConfig(
        uint256 reserveId
    ) external view returns (ReserveConfig memory);
    function getReserveCount() external view returns (uint256);
    function getReserveSuppliedAssets(
        uint256 reserveId
    ) external view returns (uint256);

}

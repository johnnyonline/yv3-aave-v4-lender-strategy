// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {

    function SPOKE() external view returns (address);
    function HUB() external view returns (address);
    function RESERVE_ID() external view returns (uint256);
    function ASSET_ID() external view returns (uint16);
    function balanceOfSupplied() external view returns (uint256);
    function balanceOfAsset() external view returns (uint256);

    function claimMerklRewards(
        address[] calldata _users,
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        bytes32[][] calldata _proofs
    ) external;

    function setAuction(
        address _auction
    ) external;
    function setUseAuction(
        bool _useAuction
    ) external;
    function setMinAmountToSell(
        uint256 _minAmountToSell
    ) external;

}

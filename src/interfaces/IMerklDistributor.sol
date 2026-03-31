// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IMerklDistributor {

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

}

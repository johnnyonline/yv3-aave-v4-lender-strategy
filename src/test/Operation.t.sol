// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract OperationTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertTrue(strategy.SPOKE() != address(0));
        assertTrue(strategy.HUB() != address(0));
    }

    function test_operation(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(10 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest - skip enough time for meaningful accrual
        skip(30 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Should have earned real Aave interest
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport_withFees(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Set protocol fee to 0 and perf fee to 10%
        setFees(0, 1_000);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(30 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        // Get the expected fee
        uint256 expectedShares = (profit * 1_000) / MAX_BPS;

        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");

        vm.prank(performanceFeeRecipient);
        strategy.redeem(expectedShares, performanceFeeRecipient, performanceFeeRecipient);

        checkStrategyTotals(strategy, 0, 0, 0);

        assertGe(asset.balanceOf(performanceFeeRecipient), expectedShares, "!perf fee out");
    }

    function test_tendTrigger(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(1 days);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger,) = strategy.tendTrigger();
        assertTrue(!trigger);
    }

    function test_availableDepositLimit(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Should have a non-zero deposit limit
        uint256 depositLimit = strategy.availableDepositLimit(user);
        assertGt(depositLimit, 0, "!depositLimit");

        // After deposit, limit should decrease
        mintAndDepositIntoStrategy(strategy, user, _amount);
        uint256 depositLimitAfter = strategy.availableDepositLimit(user);
        assertLe(depositLimitAfter, depositLimit, "!depositLimit decreased");
    }

    function test_availableWithdrawLimit(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Before deposit, withdraw limit should be 0
        assertEq(strategy.availableWithdrawLimit(user), 0, "!zero before deposit");

        // After deposit, withdraw limit should reflect supplied amount
        mintAndDepositIntoStrategy(strategy, user, _amount);
        uint256 withdrawLimit = strategy.availableWithdrawLimit(user);
        assertGt(withdrawLimit, 0, "!withdrawLimit");
        assertGe(withdrawLimit, _amount - 1, "!withdrawLimit >= amount");
    }

    function test_setAuction() public {
        // Non-management cannot set auction
        vm.expectRevert("!management");
        vm.prank(user);
        strategy.setAuction(address(0));

        // Management can set auction to zero
        vm.prank(management);
        strategy.setAuction(address(0));
    }

    function test_setUseAuction() public {
        // Non-management cannot toggle
        vm.expectRevert("!management");
        vm.prank(user);
        strategy.setUseAuction(true);

        // Management can toggle
        vm.prank(management);
        strategy.setUseAuction(true);
    }

    function test_setMinAmountToSell() public {
        // Non-management cannot set
        vm.expectRevert("!management");
        vm.prank(user);
        strategy.setMinAmountToSell(1e6);

        // Management can set
        vm.prank(management);
        strategy.setMinAmountToSell(1e6);
    }

    function test_claimMerklRewards_onlyManagement() public {
        address[] memory users = new address[](0);
        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        bytes32[][] memory proofs = new bytes32[][](0);

        // Non-management cannot claim
        vm.expectRevert("!management");
        vm.prank(user);
        strategy.claimMerklRewards(users, tokens, amounts, proofs);
    }

}

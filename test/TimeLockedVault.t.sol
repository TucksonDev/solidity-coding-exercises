// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {TimeLockedVault} from "../src/TimeLockedVault.sol";

contract TimeLockedVaultTest is Test {
    TimeLockedVault public vault;
    uint256 public withdrawalDelayBlocks = 100;
    address public owner = makeAddr("owner");

    // Events
    event Deposit(address indexed depositor, uint256 indexed amount);
    event WithdrawRequested(address indexed depositor, uint256 indexed amount);
    event Withdraw(address indexed depositor, uint256 indexed amount);

    function setUp() public {
        // Deploy vault
        vm.prank(owner);
        vault = new TimeLockedVault(withdrawalDelayBlocks);
    }

    function test_Deployment() public view {
        address _owner = vault.owner();
        uint256 _withdrawalDelayBlocks = vault.withdrawalDelayBlocks();

        assertEq(owner, _owner);
        assertEq(withdrawalDelayBlocks, _withdrawalDelayBlocks);
    }

    function testFuzz_Deposit(uint256 amount) public {
        address alice = makeAddr("alice");
        vm.deal(alice, amount);

        // Initial balance
        uint256 initialBalance = vault.balances(alice);

        // Deposit
        vm.prank(alice);
        if (amount == 0) {
            vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        } else {
            vm.expectEmit(true, true, false, false, address(vault));
            emit Deposit(alice, amount);
        }
        vault.deposit{value: amount}();

        // Balance check
        uint256 finalBalance = vault.balances(alice);

        assertEq(finalBalance, initialBalance + amount);
    }

    function test_Withdraw() public {
        // We don't want fuzz testing for the withdrawal flow
        uint256 depositAmount = 1_000_000;
        uint256 _withdrawalDelayBlocks = vault.withdrawalDelayBlocks();

        address alice = makeAddr("alice");
        vm.deal(alice, depositAmount);

        // Deposit
        vm.prank(alice);
        vault.deposit{value: depositAmount}();

        // Initial balance check
        uint256 initialVaultBalance = vault.balances(alice);
        uint256 initialBalance = address(alice).balance;

        // Try to withdraw amount without request
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("RequestNotExists()"));
        vault.withdraw(depositAmount);

        // Try to request withdrawal of higher amount
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance()"));
        vault.requestWithdrawal(depositAmount * 2);

        // Request withdrawal for half the amount
        uint256 withdrawRequestAmount = depositAmount / 2;
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(vault));
        emit WithdrawRequested(alice, withdrawRequestAmount);
        vault.requestWithdrawal(withdrawRequestAmount);

        // Get requested withdrawal
        (uint256 blockNumber, uint256 amount) = vault.withdrawalRequests(alice);
        assertEq(blockNumber, block.number + _withdrawalDelayBlocks);
        assertEq(amount, withdrawRequestAmount);

        // Try to withdraw before allowed
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("WithdrawalNotReady()"));
        vault.withdraw(withdrawRequestAmount);

        // Pass some time
        vm.roll(block.number + _withdrawalDelayBlocks);

        // Try to withdraw more than allowed
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughAmountRequested()"));
        vault.withdraw(withdrawRequestAmount + 1);

        // Withdraw less amount than requested
        uint256 withdrawAmount = withdrawRequestAmount - 1_000;
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(vault));
        emit Withdraw(alice, withdrawAmount);
        vault.withdraw(withdrawAmount);

        // Final balance check
        uint256 finalVaultBalance = vault.balances(alice);
        uint256 finalBalance = address(alice).balance;
        assertEq(finalVaultBalance, initialVaultBalance - withdrawAmount);
        assertEq(finalBalance, initialBalance + withdrawAmount);

        // Check withdraw request doesn't exist
        (uint256 newBlockNumber, uint256 newAmount) = vault.withdrawalRequests(alice);
        assertEq(newBlockNumber, 0);
        assertEq(newAmount, 0);
    }
}
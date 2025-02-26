// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DrippingStakeVault.sol";
import "../src/helpers/MockERC20.sol";

contract DrippingStakeVaultTest is Test {
    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");

    MockERC20 token;
    DrippingStakeVault vault;

    // Constants
    uint16 constant initialDrippingRate = 100;
    uint256 constant initialTokenSupply = 1_000_000_000_000_000_000_000;

    function setUp() public {
        // Deploy MockERC20
        vm.prank(deployer);
        token = new MockERC20("RewardToken", "RWT");

        // Deploy vault
        vm.prank(deployer);
        vault = new DrippingStakeVault(address(token), initialDrippingRate);

        // Mint tokens to vault
        vm.prank(deployer);
        token.mintTo(address(vault), initialTokenSupply);
    }

    function test_Deployment() public view {
        address rewardToken = address(vault.rewardToken());
        uint16 drippingRate = vault.drippingRate();
        address owner = vault.owner();

        assertEq(rewardToken, address(token));
        assertEq(drippingRate, initialDrippingRate);
        assertEq(owner, deployer);

        // Checking vault balance of token
        uint256 balance = token.balances(address(vault));
        assertEq(balance, initialTokenSupply);
    }

    function testFuzz_Deposit(uint256 amountToDeposit) public {
        vm.prank(alice);
        vm.deal(alice, amountToDeposit);

        uint256 initialBalance = address(vault).balance;
        
        if (amountToDeposit == 0) {
            vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        } else {
            vm.expectEmit(true, true, false, false, address(vault));
            emit DrippingStakeVault.Deposit(alice, amountToDeposit, initialDrippingRate);
        }
        vault.deposit{value: amountToDeposit}();

        // Check balances
        (
            uint256 depositAmount,
            uint256 depositStartingBlock,
            uint16 depositDrippingRate
        ) = vault.getDepositData(alice);

        assertEq(depositAmount, amountToDeposit);
        if (amountToDeposit > 0) {
            assertEq(depositStartingBlock, block.number);
            assertEq(depositDrippingRate, initialDrippingRate);
        } else {
            assertEq(depositStartingBlock, 0);
            assertEq(depositDrippingRate, 0);
        }

        uint256 finalBalance = address(vault).balance;
        assertEq(finalBalance, initialBalance + amountToDeposit);
    }

    function testFuzz_Withdrawal(uint256 amountToDeposit) public {
        uint256 amountToWithdraw = 0.01 ether;
        vm.assume(amountToDeposit > amountToWithdraw);

        // Test withdraw without deposited funds
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance()"));
        vault.withdraw(amountToWithdraw);

        // Deposit funds
        vm.prank(alice);
        vm.deal(alice, amountToDeposit);
        vault.deposit{value: amountToDeposit}();

        // Test withdraw
        uint256 initialBalance = address(alice).balance;
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(vault));
        emit DrippingStakeVault.Withdraw(alice, amountToWithdraw);
        vault.withdraw(amountToWithdraw);

        // Check values
        uint256 finalBalance = address(alice).balance;
        assertEq(finalBalance, initialBalance + amountToWithdraw);

        (uint256 depositAmount,,) = vault.getDepositData(alice);
        assertEq(depositAmount, amountToDeposit - amountToWithdraw);
    }

    function testFuzz_ClaimRewards(uint256 amountToDeposit) public {
        // Minimum deposit
        vm.assume(amountToDeposit > 0);
        vm.assume(amountToDeposit < 100 ether);

        // Deposit funds
        vm.prank(alice);
        vm.deal(alice, amountToDeposit);
        vault.deposit{value: amountToDeposit}();

        // Let some time pass
        uint256 startingBlock = block.number;
        vm.roll(block.number + 100);

        // Test claim reward
        uint256 initialBalance = token.balances(alice);

        (uint256 depositAmount,,uint16 depositDrippingRate) = vault.getDepositData(alice);
        uint256 timeElapsed = block.number - startingBlock;
        uint256 pendingRewards = depositAmount * timeElapsed * depositDrippingRate / 10000;

        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(vault));
        emit DrippingStakeVault.RewardClaimed(alice, pendingRewards);
        vault.claimRewards();

        // Check values
        uint256 finalBalance = token.balances(alice);
        assertEq(finalBalance, initialBalance + pendingRewards);

        (uint256 finalDepositAmount,uint256 finalStartingBlock,) = vault.getDepositData(alice);
        assertEq(finalDepositAmount, amountToDeposit);
        assertEq(finalStartingBlock, block.number);
    }
}
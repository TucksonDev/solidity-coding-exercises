// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RewardingVault} from "../src/RewardingVault.sol";
import {MockERC20} from "../src/helpers/MockERC20.sol";

contract RewardingVaultTest is Test {
    RewardingVault public vault;
    MockERC20 public erc20;
    uint8 public initialFee = 1;
    address public ownerAddr = makeAddr("owner");

    // Events
    event Deposit(address indexed account, uint256 indexed amount, uint256 indexed fee);
    event RewardClaimed(address indexed account, uint256 indexed rewardTierId);
    event Withdraw(address indexed account, uint256 indexed amount);
    event FeeWithdraw(uint256 indexed amount);

    function setUp() public {
        // Deploy MockERC20
        vm.prank(ownerAddr);
        erc20 = new MockERC20("RewardToken", "RWT");

        // Deploy vault
        vm.prank(ownerAddr);
        vault = new RewardingVault(initialFee, address(erc20));

        // Change ownership of MockERC20
        vm.prank(ownerAddr);
        erc20.transferOwnership(address(vault));

        // Create new rewards
        vm.prank(ownerAddr);
        vault.addRewardTier(1000, 1);
        vm.prank(ownerAddr);
        vault.addRewardTier(5000, 10);
    }

    function test_Deployment() public view {
        address owner = vault.owner();
        (uint256 rewardTier0Threshold, uint256 rewardTier0Ratio) = vault.rewardTiers(0);
        (uint256 rewardTier1Threshold, uint256 rewardTier1Ratio) = vault.rewardTiers(1);

        console.log("Owner is ", owner);
        console.log("Reward tier 0 threshold is ", rewardTier0Threshold);
        console.log("Reward tier 0 ratio is ", rewardTier0Ratio);
        console.log("Reward tier 1 threshold is ", rewardTier1Threshold);
        console.log("Reward tier 1 ratio is ", rewardTier1Ratio);

        assertEq(ownerAddr, owner);
        assertEq(rewardTier0Threshold, 1000);
        assertEq(rewardTier0Ratio, 1);
        assertEq(rewardTier1Threshold, 5000);
        assertEq(rewardTier1Ratio, 10);
    }

    function testFuzz_Deposit(uint256 amountToDeposit) public {
        address alice = makeAddr("alice");
        vm.deal(alice, amountToDeposit);

        // Calculated fees
        uint8 feeRatio = vault.feeRatio();
        uint256 fees = amountToDeposit * feeRatio / 100;
        uint256 depositedAmount = amountToDeposit - fees;

        // Deposit and check for event
        vm.prank(alice);
        if (amountToDeposit == 0) {
            vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        } else {
            vm.expectEmit(true, true, true, false, address(vault));
            emit Deposit(alice, depositedAmount, fees);
        }
        vault.deposit{value: amountToDeposit}();

        // Check balance
        uint256 aliceBalance = vault.balances(alice);
        assertEq(aliceBalance, depositedAmount);

        // Check fees
        uint256 accruedFees = vault.accruedFees();
        assertEq(accruedFees, fees);
    }

    function test_Claim() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 10000);

        // Deposit (should not be enough because of fees)
        vm.prank(alice);
        vault.deposit{value: 1000}();

        // Expect the following to revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("ThresholdNotReached()"));
        vault.claimReward(0);

        // Deposit some more
        vm.prank(alice);
        vault.deposit{value: 500}();

        // Next one should work
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(vault));
        emit RewardClaimed(alice, 0);
        vault.claimReward(0);

        // Check token balance
        uint256 aliceBalance = vault.balances(alice);
        (, uint256 rewardRatio) = vault.rewardTiers(0);
        uint256 rewardAmount = (aliceBalance * rewardRatio) / 100;

        uint256 aliceTokenBalance = erc20.balances(alice);
        assertEq(aliceTokenBalance, rewardAmount);

        // Check that reward has been claimed
        bool rewardWasClaimed = vault.isClaimed(alice, 0);
        assertTrue(rewardWasClaimed);

        // Expect another claim to fail
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("RewardAlreadyClaimed()"));
        vault.claimReward(0);
    }

    function testFuzz_Withdraw(uint256 amountToDeposit) public {
        // Check for amount boundaries
        if (amountToDeposit == 0) {
            amountToDeposit += 1;
        }
        if (amountToDeposit == UINT256_MAX) {
            amountToDeposit -= 1;
        }

        address alice = makeAddr("alice");
        vm.deal(alice, amountToDeposit);

        // Deposit
        vm.prank(alice);
        vault.deposit{value: amountToDeposit}();

        // Initial balances
        uint256 initialAliceVaultBalance = vault.balances(alice);
        uint256 initialAliceBalance = address(alice).balance;

        // Try to withdraw double the amount
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance()"));
        vault.withdraw(amountToDeposit + 1);

        // Withdraw
        uint256 amountToWithdraw = initialAliceVaultBalance / 2;
        vm.prank(alice);
        if (amountToWithdraw == 0) {
            vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        } else {
            vm.expectEmit(true, true, false, false, address(vault));
            emit Withdraw(alice, amountToWithdraw);
        }
        vault.withdraw(amountToWithdraw);

        // Final balances
        uint256 aliceFinalVaultBalance = vault.balances(alice);
        uint256 finalAliceBalance = address(alice).balance;

        assertEq(aliceFinalVaultBalance, initialAliceVaultBalance - amountToWithdraw);
        assertEq(finalAliceBalance, initialAliceBalance + amountToWithdraw);
    }

    function testFuzz_WithdrawFees() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 1000000);

        // Deposit
        vm.prank(alice);
        vault.deposit{value: 1000000}();

        // Check fees and balance
        uint256 initialAccruedFees = vault.accruedFees();
        uint256 initialOwnerBalance = address(ownerAddr).balance;

        // Withdraw fees revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotOwner()"));
        vault.withdrawFees();

        // Withdraw fees from owner
        vm.prank(ownerAddr);
        vault.withdrawFees();

        // Check final fees and balance
        uint256 finalAccruedFees = vault.accruedFees();
        uint256 finalOwnerBalance = address(ownerAddr).balance;

        assertEq(finalAccruedFees, 0);
        assertEq(finalOwnerBalance, initialOwnerBalance + initialAccruedFees);
    }
}

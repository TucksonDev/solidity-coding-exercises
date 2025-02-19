// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleEscrow} from "../src/SimpleEscrow.sol";

contract SimpleEscrowTest is Test {
    SimpleEscrow public simpleEscrow;
    address public depositorAddr = makeAddr("depositor");
    address public arbiterAddr = makeAddr("arbiter");
    address public beneficiaryAddr = makeAddr("beneficiary");

    // Events
    event Approved(uint256 amount);

    function setUp() public {
        vm.prank(depositorAddr);
        simpleEscrow = new SimpleEscrow(arbiterAddr, beneficiaryAddr);
    }

    function test_Deployment() public view {
        address depositor = simpleEscrow.depositor();
        address arbiter = simpleEscrow.arbiter();
        address beneficiary = simpleEscrow.beneficiary();

        console.log("Depositor is ", depositor);
        console.log("Arbiter is ", arbiter);
        console.log("Beneficiary is ", beneficiary);

        assertEq(depositorAddr, depositor);
        assertEq(arbiterAddr, arbiter);
        assertEq(beneficiaryAddr, beneficiary);
    }

    function testFuzz_Deposit(uint256 amountToSend) public {
        uint256 initialBalance = address(simpleEscrow).balance;
        console.log("Initial balance: ", initialBalance);

        // Deposit funds
        vm.prank(depositorAddr);
        vm.deal(depositorAddr, amountToSend);
        (bool success,) = address(simpleEscrow).call{value: amountToSend}("");
        assertTrue(success);

        // Check final balance
        uint256 finalBalance = address(simpleEscrow).balance;
        console.log("Final balance: ", finalBalance);

        assertEq(finalBalance, initialBalance + amountToSend);
    }

    function testFuzz_Approve(uint256 amountToSend) public {
        // Deposit funds
        vm.prank(depositorAddr);
        vm.deal(depositorAddr, amountToSend);
        (bool success1,) = address(simpleEscrow).call{value: amountToSend}("");
        assertTrue(success1);

        // Checking starting balances
        uint256 escrowBalance = address(simpleEscrow).balance;
        uint256 beneficiaryBalance = address(beneficiaryAddr).balance;
        console.log("Escrow balance: ", escrowBalance);
        console.log("Beneficiary balance: ", beneficiaryBalance);

        // Approving from an account different than the arbiter (depositor)
        vm.expectRevert(abi.encodeWithSignature("NonArbiter()"));
        simpleEscrow.approve();

        // Approving from the arbiter
        vm.prank(arbiterAddr);
        vm.expectEmit(true, false, false, false, address(simpleEscrow));
        emit Approved(escrowBalance);
        simpleEscrow.approve();

        // Checking final balances
        uint256 escrowFinalBalance = address(simpleEscrow).balance;
        uint256 beneficiaryFinalBalance = address(beneficiaryAddr).balance;
        console.log("Escrow final balance: ", escrowFinalBalance);
        console.log("Beneficiary final balance: ", beneficiaryFinalBalance);
        assertEq(escrowFinalBalance, 0);
        assertEq(beneficiaryFinalBalance, beneficiaryBalance + escrowBalance);
    }
}

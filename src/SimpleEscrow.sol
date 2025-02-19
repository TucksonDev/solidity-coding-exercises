// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleEscrow {
    // In this case we'll try to restrict the contract to receive funds only from the depositor.
    // However, one must take into account that:
    //  - the contract can receive funds by selfdestructing another contract
    //  - if the depositor is an smart contract, there's a way to send funds from any account
    address public depositor;
    address public arbiter;
    address public beneficiary;

    // Events
    event Approved(uint256 amount);

    // Errors
    error ActorIsZeroAddress();
    error NonDepositor();
    error NonArbiter();
    error TransferError();

    // Modifiers
    modifier onlyArbiter() {
        if (msg.sender != arbiter) {
            revert NonArbiter();
        }
        _;
    }

    constructor(address _arbiter, address _beneficiary) payable {
        if (_arbiter == address(0) || _beneficiary == address(0)) {
            revert ActorIsZeroAddress();
        }
        depositor = msg.sender;
        arbiter = _arbiter;
        beneficiary = _beneficiary;
    }

    receive() external payable {
        if (msg.sender != depositor) {
            revert NonDepositor();
        }
    }

    // This function is now simple enough so it doesn't need reentrancy protection.
    // However, if in the future we want to add a more complex logic, we should consider
    // using the check-effects-interactions pattern, or a reentrancy guard.
    function approve() external onlyArbiter {
        uint256 amountToSend = address(this).balance;
        // We use call for the case where the beneficiary is a contract that will perform an additional
        // logic when receiving funds. If the beneficiary is guaranteed to be an EOA (without code), we could also use
        // "transfer" so it reverts if the funds were not received.
        (bool success,) = payable(beneficiary).call{value: amountToSend}("");
        if (!success) {
            revert TransferError();
        }
        emit Approved(amountToSend);
    }
}

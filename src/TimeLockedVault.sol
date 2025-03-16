// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TimeLockedVault {
    struct WithdrawalRequest {
        uint256 blockNumber; // 0 if no request created
        uint256 amount;
    }

    // Mapping from address to ETH balance
    mapping(address => uint256) public balances;

    // Mapping from address to block when the last withdrawal request was made
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    // Withdrawal delay (0 is allowed)
    uint256 public withdrawalDelayBlocks;

    // Owner
    address public owner;

    // Events
    event Deposit(address indexed depositor, uint256 indexed amount);
    event WithdrawRequested(address indexed depositor, uint256 indexed amount);
    event Withdraw(address indexed depositor, uint256 indexed amount);

    // Errors
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error RequestNotExists();
    error RequestExists();
    error WithdrawalNotReady();
    error NotEnoughAmountRequested();
    error NotEnoughBalance();
    error ErrorSendingEth();

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(uint256 _withdrawalDelayBlocks) {
        // Note: we allow for 0 delay blocks
        withdrawalDelayBlocks = _withdrawalDelayBlocks;
        owner = msg.sender;
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function setWithdrawalDelayBlocks(uint256 _withdrawalDelayBlocks) external onlyOwner {
        withdrawalDelayBlocks = _withdrawalDelayBlocks;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) {
            revert ZeroAddress();
        }
        owner = _newOwner;
    }

    //////////////////////////////
    // Deposits and withdrawals //
    //////////////////////////////
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function requestWithdrawal(uint256 amount) external {
        if (withdrawalRequests[msg.sender].blockNumber != 0) {
            revert RequestExists();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (balances[msg.sender] < amount) {
            revert NotEnoughBalance();
        }

        withdrawalRequests[msg.sender] = WithdrawalRequest(block.number + withdrawalDelayBlocks, amount);

        emit WithdrawRequested(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        // Check
        if (withdrawalRequests[msg.sender].blockNumber == 0) {
            revert RequestNotExists();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (withdrawalRequests[msg.sender].blockNumber > block.number) {
            revert WithdrawalNotReady();
        }
        if (withdrawalRequests[msg.sender].amount < amount) {
            revert NotEnoughAmountRequested();
        }
        if (balances[msg.sender] < amount) {
            revert NotEnoughBalance();
        }

        // Effects
        // Note: setting the amount to 0 is not needed, but it's a security measure
        withdrawalRequests[msg.sender].blockNumber = 0;
        withdrawalRequests[msg.sender].amount = 0;
        balances[msg.sender] -= amount;

        // Interactions
        // Note: we use call here to allow for contracts using the vault perform
        // additional logic when receiving the funds (without having a low gas limit)
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert ErrorSendingEth();
        }

        emit Withdraw(msg.sender, amount);
    }
}

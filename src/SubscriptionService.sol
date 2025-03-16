// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SubscriptionService {
    // Subscription fee
    uint256 public subscriptionFee;

    // Subscription duration (in seconds)
    uint256 public subscriptionDurationSeconds;

    // Owner
    address public owner;

    // Subscriptions (mapping user => expiryTime)
    mapping(address => uint256) public subscriptionExpiryTime;

    // Errors
    error NotOwner();
    error ZeroAmount();
    error ZeroTime();
    error ActiveSubscription();
    error InactiveSubscription();
    error NotExactValue();
    error TransferFailed();

    // Events
    event Subscription(address indexed subscriber);
    event Renewal(address indexed subscriber);
    event OwnerWithdraw(address indexed owner, uint256 amount);

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    // Constructor
    constructor(uint256 _subscriptionFee, uint256 _subscriptionDurationSeconds) {
        if (_subscriptionFee == 0) {
            revert ZeroAmount();
        }
        if (_subscriptionDurationSeconds == 0) {
            revert ZeroTime();
        }
        subscriptionFee = _subscriptionFee;
        subscriptionDurationSeconds = _subscriptionDurationSeconds;
        owner = msg.sender;
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function setSubscriptionFee(uint256 newSubscriptionFee) external onlyOwner {
        if (newSubscriptionFee == 0) {
            revert ZeroAmount();
        }
        subscriptionFee = newSubscriptionFee;
    }

    function setSubscriptionDurationSeconds(uint256 newSubscriptionDurationSeconds) external onlyOwner {
        if (newSubscriptionDurationSeconds == 0) {
            revert ZeroTime();
        }
        subscriptionDurationSeconds = newSubscriptionDurationSeconds;
    }

    function withdrawFunds() external onlyOwner {
        if (address(this).balance == 0) {
            revert ZeroAmount();
        }

        uint256 amountToWithdraw = address(this).balance;

        // Using "call" here and checking for success so the owner can perform
        // additional logic if it's a contract
        // There's no reentrancy risk since we're sending directly the balance of the contract
        // and no state variable tracks that
        (bool success,) = payable(owner).call{value: amountToWithdraw}("");
        if (!success) {
            revert TransferFailed();
        }

        emit OwnerWithdraw(owner, amountToWithdraw);
    }

    ////////////////
    // Main logic //
    ////////////////
    function subscribe() external payable {
        if (block.timestamp < subscriptionExpiryTime[msg.sender]) {
            // User has an active subscription
            revert ActiveSubscription();
        }
        if (msg.value != subscriptionFee) {
            // User must provide exact value
            revert NotExactValue();
        }

        subscriptionExpiryTime[msg.sender] = block.timestamp + subscriptionDurationSeconds;

        emit Subscription(msg.sender);
    }

    function renew() external payable {
        if ((subscriptionExpiryTime[msg.sender] == 0) || (subscriptionExpiryTime[msg.sender] < block.timestamp)) {
            // User never had a subscription (== 0) or it expired (< block.timestamp)
            revert InactiveSubscription();
        }

        if (msg.value != (subscriptionFee / 2)) {
            // Renewal fee is half the price
            revert NotExactValue();
        }

        subscriptionExpiryTime[msg.sender] = block.timestamp + subscriptionDurationSeconds;

        emit Renewal(msg.sender);
    }

    /////////////
    // Getters //
    /////////////
    function hasActiveSubscription(address subscriber) external view returns (bool) {
        return subscriptionExpiryTime[subscriber] >= block.timestamp;
    }
}

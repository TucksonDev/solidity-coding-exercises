// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DrippingStakeVault {
    // Structs
    struct UserDeposit {
        uint256 amount;
        uint256 startingBlock;
        // Dripping rate can change at any given time,
        // so each deposit gets the configured drippingRate at the time
        // of the deposit
        uint16 drippingRate;
    }

    // Reward token
    IERC20 public immutable rewardToken;

    // User deposits
    mapping(address => UserDeposit) public deposits;

    // User extra claimable rewards
    mapping(address => uint256) public extraClaimableRewards;

    // Dripping rate per block: 0 (0.00%) - 10000 (100.00%)
    uint16 public drippingRate;

    // Owner
    address public owner;

    // Events
    event Deposit(address indexed depositor, uint256 indexed amount, uint16 drippingRate);
    event RewardClaimed(address indexed depositor, uint256 rewardAmount);
    event Withdraw(address indexed depositor, uint256 amount);

    // Errors
    error ZeroAddress();
    error NotOwner();
    error ZeroAmount();
    error NoDeposit();
    error NoRewardToSend();
    error TokensNotSent();
    error NotEnoughBalance();

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(address _rewardToken, uint16 _drippingRate) {
        if (_rewardToken == address(0)) {
            revert ZeroAddress();
        }
        // Upper bound drippingRate (no need to revert)
        if (_drippingRate > 10000) {
            _drippingRate = 10000;
        }

        rewardToken = IERC20(_rewardToken);
        drippingRate = _drippingRate;
        owner = msg.sender;
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    /// @dev we allow setting ownership to the zero address, so the drippingRate is not modifiable anymore
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setDrippingRate(uint16 newDrippingRate) external onlyOwner {
        // Upper bound drippingRate (no need to revert)
        if (newDrippingRate > 10000) {
            newDrippingRate = 10000;
        }
        drippingRate = newDrippingRate;
    }

    ////////////////
    // Main flows //
    ////////////////
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        uint256 currentDeposit = 0;
        uint256 amount = msg.value;

        // Update pending rewards
        if (deposits[msg.sender].amount > 0) {
            uint256 timeElapsed = block.number - deposits[msg.sender].startingBlock;
            uint256 pendingReward =
                (deposits[msg.sender].amount * timeElapsed * deposits[msg.sender].drippingRate) / 10000;
            extraClaimableRewards[msg.sender] += pendingReward;
            currentDeposit = deposits[msg.sender].amount;
        }

        // Update deposit
        deposits[msg.sender] = UserDeposit(currentDeposit + amount, block.number, drippingRate);

        // Emit event
        emit Deposit(msg.sender, amount, drippingRate);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (deposits[msg.sender].amount < amount) {
            revert NotEnoughBalance();
        }

        // Update pending rewards
        if (deposits[msg.sender].amount > 0) {
            uint256 timeElapsed = block.number - deposits[msg.sender].startingBlock;
            uint256 pendingRewards =
                (deposits[msg.sender].amount * timeElapsed * deposits[msg.sender].drippingRate) / 10000;
            extraClaimableRewards[msg.sender] += pendingRewards;
        }

        // Update user balance (doing it now prevents reentrancy attacks)
        // Note: we already checked above for potential underflows, so this saves a bit of gas
        unchecked {
            deposits[msg.sender].amount -= amount;
            deposits[msg.sender].startingBlock = block.number;
        }

        // Transfer ETH
        // Note: we use call here to allow for contracts using this contract and performing some logic
        // when receiving funds
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TokensNotSent();
        }

        emit Withdraw(msg.sender, amount);
    }

    function claimRewards() external {
        if (deposits[msg.sender].amount == 0) {
            revert NoDeposit();
        }

        // Rewards to send
        uint256 timeElapsed = block.number - deposits[msg.sender].startingBlock;
        uint256 pendingReward = (deposits[msg.sender].amount * timeElapsed * deposits[msg.sender].drippingRate) / 10000;
        uint256 totalRewards = pendingReward + extraClaimableRewards[msg.sender];

        if (totalRewards == 0) {
            revert NoRewardToSend();
        }

        // Effects (to prevent reentrancy attacks)
        deposits[msg.sender].startingBlock = block.number;
        extraClaimableRewards[msg.sender] = 0;

        // Note: this will revert if the token doesn't return a value in the transfer function
        bool success = rewardToken.transfer(msg.sender, totalRewards);
        if (!success) {
            revert TokensNotSent();
        }

        emit RewardClaimed(msg.sender, totalRewards);
    }

    /////////////
    // Getters //
    /////////////
    function getDepositData(address depositor)
        external
        view
        returns (uint256 depositAmount, uint256 depositStartingBlock, uint16 depositDrippingRate)
    {
        depositAmount = deposits[depositor].amount;
        depositStartingBlock = deposits[depositor].startingBlock;
        depositDrippingRate = deposits[depositor].drippingRate;
    }
}

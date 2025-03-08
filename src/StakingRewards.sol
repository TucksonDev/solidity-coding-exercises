// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingRewards {
    struct UserDeposit {
        uint256 amount;
        uint16 rewardRate;
        uint256 startedAtTimestamp;
    }

    // Token
    IERC20 public token;

    // Owner (packed together with rewardRate)
    address public owner;

    // Reward rate (10.00% APY)
    uint16 public rewardRate = 1000;

    // Constant helpers for reward rate calculation
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint16 constant MAX_REWARD_RATE = 5000;

    // Mapping address to current deposit
    mapping(address => UserDeposit) public deposits;
    // Mapping address to total unclaimed rewards
    mapping(address => uint256) public pendingRewards;

    // Errors
    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error RewardRateOverMax();
    error NotEnoughBalance();
    error NotEnoughAllowance();
    error ContractNotEnoughBalance();
    error TransferFailed();
    error NoRewardsToClaim();

    // Events
    event Deposit(address indexed depositor, uint256 indexed amount);
    event Withdraw(address indexed depositor, uint256 indexed amount);
    event RewardsClaimed(address indexed depositor, uint256 indexed amount);

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor (
        address _token,
        uint16 _rewardRate
    ) {
        if (_token == address(0)) {
            revert ZeroAddress();
        }
        if (_rewardRate == 0) {
            revert ZeroAmount();
        }
        if (_rewardRate > MAX_REWARD_RATE) {
            revert RewardRateOverMax();
        }
        token = IERC20(_token);
        rewardRate = _rewardRate;
        owner = msg.sender;

        // Making a test call to verify that the contract is likely an ERC-20 contract
        token.balanceOf(address(0));
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setRewardRate(uint16 newRewardRate) external onlyOwner {
        if (newRewardRate == 0) {
            revert ZeroAmount();
        }
        if (newRewardRate > MAX_REWARD_RATE) {
            revert RewardRateOverMax();
        }
        rewardRate = newRewardRate;
    }

    //////////////////////////////
    // Deposit / withdraw logic //
    //////////////////////////////
    function stake(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (token.balanceOf(msg.sender) < amount) {
            revert NotEnoughBalance();
        }
        // Extra check to verify that this contract has enough allowance
        if (token.allowance(msg.sender, address(this)) < amount) {
            revert NotEnoughAllowance();
        }

        // If the user already had a deposit, update their pending rewards
        updatePendingRewards(msg.sender);

        // Update deposits mapping
        deposits[msg.sender].amount += amount;
        deposits[msg.sender].rewardRate = rewardRate;
        deposits[msg.sender].startedAtTimestamp = block.timestamp;

        // Transfer tokens
        // NOTE: we expect the token follows the ERC-20 standard that returns a boolean
        // on transfer
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }

        // Emit event
        emit Deposit(msg.sender, amount);
    }

    function getReward() public {
        // First update pending rewards
        updatePendingRewards(msg.sender);

        // Check if there's anything to claim
        if (pendingRewards[msg.sender] == 0) {
            revert NoRewardsToClaim();
        }

        // Update pending rewards (prevents reentrancy attacks)
        uint256 reward = pendingRewards[msg.sender];
        pendingRewards[msg.sender] = 0;

        // Checks contract balance
        if (token.balanceOf(address(this)) < reward) {
            revert ContractNotEnoughBalance();
        }

        // Send tokens
        bool success = token.transfer(msg.sender, reward);
        if (!success) {
            revert TransferFailed();
        }

        // Event
        emit RewardsClaimed(msg.sender, reward);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (deposits[msg.sender].amount < amount) {
            revert NotEnoughBalance();
        }

        // First get the current and pending rewards
        getReward();

        // Then update the state variables
        deposits[msg.sender].amount -= amount;
        if (deposits[msg.sender].amount == 0) {
            // Reset UserDeposit
            deposits[msg.sender].rewardRate = 0;
            deposits[msg.sender].startedAtTimestamp = 0;
        }

        // Checks contract balance
        if (token.balanceOf(address(this)) < amount) {
            revert ContractNotEnoughBalance();
        }

        // Send tokens
        bool success = token.transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }

        // Event
        emit Withdraw(msg.sender, amount);
    }

    ///////////////////
    // Other actions //
    ///////////////////
    /// @dev This function allows an admin to fund the contract with ERC-20 tokens
    function fundContract(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (token.balanceOf(msg.sender) < amount) {
            revert NotEnoughBalance();
        }
        // Extra check to verify that this contract has enough allowance
        if (token.allowance(msg.sender, address(this)) < amount) {
            revert NotEnoughAllowance();
        }

        // Transfer tokens
        // NOTE: we expect the token follows the ERC-20 standard that returns a boolean
        // on transfer
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    function updatePendingRewards(address depositor) internal {
        if (deposits[depositor].amount == 0) {
            return;
        }
        // Edge case, but checking to avoid extra calculations
        if (deposits[depositor].startedAtTimestamp == block.timestamp) {
            return;
        }

        uint256 secondsPassed = block.timestamp - deposits[depositor].startedAtTimestamp;
        uint256 rewardsAccrued = (
            deposits[depositor].amount *
            secondsPassed *
            rewardRatePerSecond(deposits[depositor].rewardRate)
        ) / 1e18;

        pendingRewards[depositor] += rewardsAccrued;
        deposits[depositor].startedAtTimestamp = block.timestamp;
    }

    function rewardRatePerSecond(uint16 _rewardRate) private pure returns (uint256) {
        uint256 scaledRewardRate = (_rewardRate * 1e18) / 10000;
        return scaledRewardRate / SECONDS_PER_YEAR;
    }
}

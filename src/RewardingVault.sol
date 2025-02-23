// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// We assume rewards will be paid in an ERC-20 token
// through a `mintTo()` function that can only be called
// by this contract
interface IERC20 {
    function mintTo(address to, uint256 amount) external;
}

contract RewardingVault {
    // Structs
    struct Reward {
        uint256 threshold;  // Amount of ETH deposited to be able to claim this reward
        uint256 ratio;      // Reward ratio in basis points (multiplied by 100)
    }

    // An ERC-20 token to pay rewards in
    address public rewardToken;

    // Mapping from rewardTierId to Reward
    mapping (uint256 => Reward) public rewardTiers;
    uint256 public rewardCount;
    
    // Mapping from account to balance
    mapping (address => uint256) public balances;

    // Mapping from account to rewardTierId to claimed
    mapping (address => mapping (uint256 => bool) ) claimedRewards;

    // Fees accrued
    uint256 public accruedFees;

    // Amount of fees claimable by the owner (multiplied by 100)
    uint8 public feeRatio;

    // Owner
    address public owner;

    // Events
    event Deposit(address indexed account, uint256 indexed amount, uint256 indexed fee);
    event RewardClaimed(address indexed account, uint256 indexed rewardTierId);
    event Withdraw(address indexed account, uint256 indexed amount);
    event FeeWithdraw(uint256 indexed amount);

    // Errors
    error FeeRatioTooHigh();
    error NotOwner();
    error NotAccruedFees();
    error FeeWithdrawalError();
    error WithdrawalError();
    error RewardNotExist();
    error ZeroAmount();
    error ZeroThreshold();
    error ZeroRatio();
    error ZeroAddress();
    error NotEnoughBalance();
    error RewardAlreadyClaimed();
    error ThresholdNotReached();

    // Modifiers
    modifier onlyOwner {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(uint8 _feeRatio, address _rewardToken) {
        if (_feeRatio > 100) {
            revert FeeRatioTooHigh();
        }
        if (_rewardToken == address(0)) {
            revert ZeroAddress();
        }
        feeRatio = _feeRatio;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    //////////////////////////
    // Admin only functions //
    //////////////////////////
    function addRewardTier(uint256 threshold, uint256 ratio) external onlyOwner {
        if (threshold == 0) {
            revert ZeroThreshold();
        }
        if (ratio == 0) {
            revert ZeroRatio();
        }
        rewardTiers[rewardCount] = Reward(
            threshold,
            ratio
        );
        rewardCount++;
    }

    function modifyRewardTier(uint256 rewardTierId, uint256 threshold, uint256 ratio) external onlyOwner {
        if (rewardTierId >= rewardCount) {
            revert RewardNotExist();
        }
        if (threshold == 0) {
            revert ZeroThreshold();
        }
        if (ratio == 0) {
            revert ZeroRatio();
        }
        rewardTiers[rewardTierId] = Reward(
            threshold,
            ratio
        );
    }

    function setFeeRatio(uint8 _feeRatio) external onlyOwner {
        if (_feeRatio > 100) {
            revert FeeRatioTooHigh();
        }
        feeRatio = _feeRatio;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function withdrawFees() external onlyOwner {
        if (accruedFees == 0) {
            revert NotAccruedFees();
        }

        uint256 amountToSend = accruedFees;
        accruedFees = 0;

        // We use "call" here so if the owner is a contract we can perform some additional logic
        // when receiving funds, without having a low gas limit available.
        // Reentrancy should be handled by the effects above this call
        (bool success,) = payable(owner).call{value: amountToSend}("");
        if (!success) {
            revert FeeWithdrawalError();
        }

        emit FeeWithdraw(amountToSend);
    }

    ////////////////////////
    // Mutating functions //
    ////////////////////////

    // Note: Users should be aware that this function retains some fee
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        // Accruing fees
        uint256 fees = msg.value * feeRatio / 100;
        accruedFees += fees;

        // Deposited amount
        uint256 depositedAmount = msg.value - fees;
        balances[msg.sender] += depositedAmount;

        // Emitting event
        emit Deposit(msg.sender, depositedAmount, fees);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (amount > balances[msg.sender]) {
            revert NotEnoughBalance();
        }

        balances[msg.sender] -= amount;

        // We use "call" here so if the receiver is a contract we can perform some additional logic
        // when receiving funds, without having a low gas limit available.
        // Reentrancy should be handled by the effects above this call
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert WithdrawalError();
        }

        emit Withdraw(msg.sender, amount);
    }

    function claimReward(uint256 rewardTierId) external {
        // Must be a valid rewardTierId
        if (rewardTierId >= rewardCount) {
            revert RewardNotExist();
        }
        // Must not have claimed that reward
        if (claimedRewards[msg.sender][rewardTierId]) {
            revert RewardAlreadyClaimed();
        }
        // Must have passed the threshold to claim that reward
        if (balances[msg.sender] < rewardTiers[rewardTierId].threshold) {
            revert ThresholdNotReached();
        }

        // Marking this reward as claimed
        claimedRewards[msg.sender][rewardTierId] = true;

        // Calculating reward amount
        uint256 rewardAmount = (balances[msg.sender] * rewardTiers[rewardTierId].ratio) / 100;

        // Here, we assume rewards are paid by an ERC-20 token, that has a mintTo function that's only
        // callable by this contract
        IERC20(rewardToken).mintTo(msg.sender, rewardAmount);

        emit RewardClaimed(msg.sender, rewardTierId);
    }

    function isClaimed(address depositor, uint256 rewardTierId) external view returns (bool) {
        return claimedRewards[depositor][rewardTierId];
    }
}
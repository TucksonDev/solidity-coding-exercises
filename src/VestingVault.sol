// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VestingVault {
    using SafeERC20 for IERC20;

    // cliffPeriodInSeconds and vestDurationAfterCliffInSeconds are packed together in the same slots
    // (max amount of seconds used must be below 2^128-1)
    struct Vest {
        uint256 amount; // Tokens vested
        uint256 claimedAmount;
        uint256 startTimestamp; // Start timestamp
        uint128 cliffPeriodInSeconds; // Seconds of cliff period
        uint128 vestDurationAfterCliffInSeconds; // Vest duration in seconds (linear vesting)
    }

    // Constants
    uint128 constant MINIMUM_VEST_DURATION = 1 days;

    // Owner
    address public owner;

    // Vested token
    IERC20 public token;

    // Beneficiaries
    mapping(address => Vest) public beneficiaries;

    // Errors
    error NotOwner();
    error ZeroAddress();
    error NoCode();
    error ZeroAmount();
    error VestTooLow();
    error AlreadyExists();
    error NoBeneficiary();
    error TooSoon();
    error CliffPeriod();
    error AmountTooHigh();

    // Events
    event BeneficiaryAdded(
        address indexed beneficiary,
        uint256 amount,
        uint128 cliffPeriodInSeconds,
        uint128 vestDurationAfterCliffInSeconds
    );
    event TokensWithdrawn(address indexed beneficiary, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(address _token) {
        if (_token == address(0)) {
            revert ZeroAddress();
        }
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_token)
        }
        if (codeSize == 0) {
            revert NoCode();
        }

        token = IERC20(_token);
        owner = msg.sender;
    }

    function registerBeneficiary(
        address beneficiary,
        uint256 amount,
        uint128 cliffPeriodInSeconds,
        uint128 vestDurationAfterCliffInSeconds
    ) external onlyOwner {
        if (beneficiary == address(0)) {
            revert ZeroAddress();
        }
        if (beneficiaries[beneficiary].startTimestamp > 0) {
            revert AlreadyExists();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        // We allow for 0 cliffPeriodInSeconds, but non-zero vestDurationAfterCliffInSeconds
        if (vestDurationAfterCliffInSeconds < MINIMUM_VEST_DURATION) {
            revert VestTooLow();
        }

        // Saving the beneficiary information
        beneficiaries[beneficiary] =
            Vest(amount, 0, block.timestamp, cliffPeriodInSeconds, vestDurationAfterCliffInSeconds);

        // We send the tokens to the contract
        // (we use safeTransferFrom so the call reverts if this fails)
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit BeneficiaryAdded(beneficiary, amount, cliffPeriodInSeconds, vestDurationAfterCliffInSeconds);
    }

    function withdrawTokens(uint256 amount) external {
        // All checks are performed in the view function
        // We avoid duplicating checks here for saving gas
        uint256 withdrawableTokens = withdrawableTokensPerBeneficiary(msg.sender);
        if (amount > withdrawableTokens) {
            revert AmountTooHigh();
        }

        // Updating the state
        beneficiaries[msg.sender].claimedAmount += amount;

        // Sending the tokens
        // (using "safeTransfer" so it reverts if it fails)
        token.safeTransfer(msg.sender, amount);

        emit TokensWithdrawn(msg.sender, amount);
    }

    function withdrawableTokensPerBeneficiary(address beneficiary) public view returns (uint256) {
        if (beneficiaries[beneficiary].startTimestamp == 0) {
            revert NoBeneficiary();
        }
        if (beneficiaries[beneficiary].startTimestamp > block.timestamp) {
            // This shouldn't be possible, but adding the extra check
            revert TooSoon();
        }

        Vest memory vestingInformation = beneficiaries[beneficiary];

        if (block.timestamp < vestingInformation.startTimestamp + vestingInformation.cliffPeriodInSeconds) {
            revert CliffPeriod();
        }
        uint256 timeElapsed =
            block.timestamp - (vestingInformation.startTimestamp + vestingInformation.cliffPeriodInSeconds);

        uint256 vestingRatePerMilliSecond =
            (vestingInformation.amount * 1000 / vestingInformation.vestDurationAfterCliffInSeconds);
        uint256 unlockedTokens = timeElapsed * vestingRatePerMilliSecond / 1000;

        if (vestingInformation.claimedAmount > unlockedTokens) {
            // It should never be higher, but adding this extra check just in case
            return 0;
        }

        return unlockedTokens - vestingInformation.claimedAmount;
    }
}

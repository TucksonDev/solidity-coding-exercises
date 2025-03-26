# Solidity coding exercises

This repo contains a few exercises done to improve my solidity-coding skills.

## Exercises

Following are the list of exercises done. For each exercise, there's the description obtained from the AI used (namely ChatGPT or Gemini) and links to the relevant code.

### Simple Escrow

You’ll build a “Simple Escrow” contract that demonstrates basic ownership logic, payment handling, and event emission. Specifically:

1. Participants
    - An arbiter (the entity who can release funds),
    - A depositor (funds are deposited by this party),
    - A beneficiary (the one who will receive the funds).

2. Contract Flow
    - The depositor deploys the contract with a predefined arbiter and beneficiary.
    - The depositor then sends ETH into this escrow contract.
    - When certain off-chain conditions are met (in real use cases), the arbiter can call a function (e.g., approve()) to release the funds to the beneficiary.
    - Include a fallback or receive function to allow additional funds to be sent (if needed).

3. Ownership Requirements
    - Only the arbiter can approve the release of funds.
    - The arbiter should not be able to take the funds for themselves; it should strictly go to the beneficiary.

4. Events
    - Emit an event (e.g., Approved(uint amount)) whenever funds are successfully released to the beneficiary.

5. Testing
    - In your test folder, write unit tests to verify:
    - Deployment: Contract sets the correct arbiter and beneficiary.
    - Deposit: Ether can be deposited to the contract (the contract balance should increase accordingly).
    - Approve: Only the arbiter can call approve() and release the funds to the beneficiary.
    - Unauthorized Approval: Ensure that if anyone other than the arbiter calls approve(), it reverts.
    - Event: Validate that the Approved event is emitted with the correct amount.

**Code**

- Contract: [./src/SimpleEscrow.sol](./src/SimpleEscrow.sol)
- Test file: [./test/SimpleEscrow.t.sol](./test/SimpleEscrow.t.sol)

### Rewarding Vault

You will create a smart contract that manages two main operations:

- Payments: Users can deposit ETH into the contract.
- Rewards: Users can claim rewards based on predefined “tiers.”

1. Core Features:
    - Tiered Access Control:
        - Only an “admin” should be able to define or modify reward tiers (for instance, silver, gold, platinum), each with a specific reward ratio or value.
        - Tiers must be stored in a mapping or another suitable data structure.
    - Deposit Function:
        - A function to deposit ETH into the contract that tracks deposits on a per-user basis.
        - Emit an event when a deposit is made.
    - Claim Function:
        - Users can claim rewards if they have reached the deposit thresholds for a specific tier.
        - Rewards can only be claimed once per deposit threshold, preventing double-claiming the same reward.
        - Emit an event upon successful reward claim.
    - Withdrawal Function:
        - The contract owner (admin) can withdraw certain fees from the contract, but only within a certain limit (e.g., a small percentage of the total contract balance).
    - Security:
        - Demonstrate usage of OpenZeppelin’s ReentrancyGuard (or a custom re-entrancy guard pattern) to protect deposit/claim functions.
        - Properly handle ownership (e.g., using OpenZeppelin’s Ownable or your own custom approach).

2. Testing Requirements:
    - Ensure you write at least 4 or 5 test cases covering deposit, claim, and withdrawal scenarios.
    - Show how you handle error conditions (e.g., insufficient balance, unauthorized actions, or claiming a reward before meeting the threshold).
    - Test for re-entrancy attacks if you’ve implemented your own guard.

**Code**

- Contract: [./src/RewardingVault.sol](./src/RewardingVault.sol)
- Test file: [./test/RewardingVault.t.sol](./test/RewardingVault.t.sol)

### Time locked vault

Implement and test a “Vault with Time-Locked Withdrawals and Access Control”. The vault will allow depositors to store Ether, and all withdrawals from the vault must be requested in advance, respecting a configurable “withdrawal delay.” Additionally, the contract must enforce role-based access control for configuring certain parameters (like the withdrawal delay).

1. Requirements

    - Deposits
        - Anyone can deposit Ether into the vault.
        - Keep track of each depositor’s balance.

    - Withdrawal Requests
        - Before withdrawing, a user must submit a withdrawal request.
        - Store a timestamp indicating when the user’s withdrawal request will become valid.
        - Only one request can be active per user at a time.

    - Time-Locked Withdrawals
        - Users can only withdraw their Ether after their withdrawal request matures (i.e., after the withdrawalDelay time).
        - If a user’s request is valid, they can withdraw up to the amount they have requested (or their full balance if you prefer).
        - Once withdrawn, the withdrawal request resets (the user needs to make a new request for another withdrawal).

    - Access Control
        - Introduce a role (e.g., ADMIN) that is allowed to change the withdrawalDelay.
        - At contract deployment, the contract deployer is the default ADMIN.
        - Other addresses can be granted or revoked the ADMIN role by existing admins.
        - Use a simple approach for role management (it doesn’t have to be a full library like OpenZeppelin AccessControl—feel free to build minimal custom logic).

    - Testing
        - Write a comprehensive test suite in Foundry.
        - Unit Tests: Check deposit logic, withdrawal request logic, and actual withdrawal.

    - Security Considerations
        - Ensure no reentrancy vulnerabilities.
        - Validate that role checks are enforced.

**Code**

- Contract: [./src/TimeLockedVault.sol](./src/TimeLockedVault.sol)
- Test file: [./test/TimeLockedVault.t.sol](./test/TimeLockedVault.t.sol)

### ERC-20 token with extra functionality

You will be tasked with developing a simplified version of an ERC-20 token contract with some added functionality.

Specifically:

- Token Basics: The contract should implement the basic ERC-20 interface (e.g., transfer, balanceOf, approve, allowance).
- Minting:  The contract should allow a designated "minter" address to mint new tokens.
- Burning: The contract should allow token holders to burn their own tokens.
- Pausable: The contract should have a "pausable" feature, controlled by the minter, that can temporarily halt all token transfers.
- Security:  The contract must be written with security best practices in mind to prevent common vulnerabilities.

**Code**

- Contract: [./src/ERC20Extra.sol](./src/ERC20Extra.sol)

### Staking Contract with Reward Dripping

You need to implement an ETH staking contract where:
- Users can deposit ETH and start accumulating rewards over time.
- The contract rewards users with an ERC20 token at a fixed rate per second, proportional to their stake.
- Users can withdraw rewards anytime without unstaking.
- Users can unstake their ETH at any moment, but accumulated rewards remain claimable.

Requirements:
- Staking ETH: Users deposit ETH into the contract.
- Reward Calculation: Rewards should accrue based on staking time and amount.
- Claiming Rewards: Users can withdraw their rewards without unstaking.
- Unstaking ETH: Users can withdraw their initial stake, stopping further reward accumulation.
- ERC20 Reward Token: Implement an ERC20 token to distribute as rewards.

**Code**

- Contract: [./src/DrippingStakeVault.sol](./src/DrippingStakeVault.sol)
- Test file: [./test/DrippingStakeVault.t.sol](./test/DrippingStakeVault.t.sol)

### Staking rewards

Objective: Design, implement, and test a "Staking Rewards" smart contract system on Ethereum. The system should allow users to stake an ERC20 token, earn rewards in the same token over time, and withdraw their stake and rewards.

Requirements:
- Contract Structure:
    - Create a StakingRewards contract that integrates with an existing ERC20 token (e.g., use OpenZeppelin’s ERC20 for simplicity).
    - Users can stake tokens by calling a stake(uint256 amount) function.
    - Users earn rewards based on the time their tokens are staked and a predefined reward rate (e.g., 10% APY, simplified for this exercise).
    - Users can withdraw their stake and rewards with a withdraw() function.
    - Include a getReward() function to claim rewards without withdrawing the stake.

- Security Features:
    - Protect against reentrancy attacks.
    - Ensure only the token owner can stake their tokens (leverage ERC20 allowances).
    - Prevent reward calculation manipulation (e.g., flash loan exploits).

- Testing:
    - Write at least 3 test cases in Foundry:
        - Test successful staking and reward calculation.
        - Test withdrawal of stake and rewards.
        - Test a failure case (e.g., withdrawing more than staked).
    - Use Foundry’s vm.warp to simulate time passing for reward accrual.

- Assumptions:
    - For simplicity, assume the reward pool is pre-funded (e.g., the contract starts with enough ERC20 tokens to pay rewards).
    - Use a simple linear reward formula: reward = stakedAmount * rewardRate * timeStaked, where rewardRate is a fixed value you define (e.g., 10% per year, adjusted for block timestamps).

**Code**

- Contract: [./src/StakingRewards.sol](./src/StakingRewards.sol)

### Subscription service

Implement a “Subscription Service” smart contract with these rules and constraints:

- Subscription Model
    - Users can “subscribe” by paying a certain fee, which grants them access to the service for a period (e.g., 30 days).
    - The subscription fee and subscription duration should be configurable by the contract owner.

- Renewals & Expiration
    - A user can renew their subscription before it expires.
    - If a subscription expires, they must pay the fee again to reactivate it.

- Access Control & Ownership
    - Use a suitable ownership pattern (e.g., Ownable or a custom approach) to restrict certain functionality to the contract owner (for example, changing the subscription fee or duration).

- Robust Payable Handling
    - Carefully handle incoming payments to avoid re-entrancy vulnerabilities.
    - Any leftover funds beyond the subscription fee should revert or be handled gracefully (depending on your design decision).

- Data Structures & Mapping
    - Efficiently track user subscription status and expiry timestamps.

- Withdrawals
    - The contract owner should be able to withdraw accumulated subscription fees.

- Error Handling & Edge Cases
    - Consider what happens if a user sends too little ether, tries to renew an already-active subscription, etc.

**Code**

- Contract: [./src/SubscriptionService.sol](./src/SubscriptionService.sol)

### MultisigWallet

Objective: Implement a simplified multi-signature (multi-sig) wallet in Solidity.

- Key Requirements:
    - The wallet must support multiple owners (e.g., an array of owner addresses).
    - There should be a threshold (say requiredConfirmations) indicating how many owner confirmations are needed before a transaction can be executed.
    - Owners can propose a transaction (e.g., transfer Ether to some recipient, or call an external contract with specific data).
    - Other owners can confirm the proposed transaction.
    - Once the required number of owners have confirmed, the transaction becomes executable.
    - No additional functionality (such as revoking confirmations) is strictly required, but it’s a plus if included.

- Minimal Contract Interface:
    - You should define functions that allow:
        - constructor: Accept the list of owners and the required number of confirmations.
        - submitTransaction: Allows an owner to propose a new transaction.
        - confirmTransaction: Allows an owner to confirm a transaction.
        - executeTransaction: Once enough confirmations are gathered, executes the transaction.

- Security Considerations:
    - Ensure only valid owners can call these methods.
    - Check that the transaction hasn’t already been executed.
    - If you want to handle Ether, consider the fallback or receive function, or rely on external funding.

**Code**

- Contract: [./src/MultisigWallet.sol](./src/MultisigWallet.sol)

### UpgradeableMultisig

You will implement a simple multi-signature (multi-sig) wallet contract that is upgradeable. Specifically:

Core multi-sig functionality:

- The contract will have multiple owners, each with an address stored on-chain.
- Any owner can propose a transaction to call an external contract (or a simple ETH transfer) from the multi-sig wallet.
- The transaction must gather a certain threshold of approvals (e.g., >50% of owners) to be executable.
- Once the threshold is met, anyone can trigger the execution of the transaction.

Upgradeable pattern:

- Implement a basic upgradeable mechanism (e.g., a Proxy + Implementation logic).
- You do not need a separate script or contract for the proxy if you prefer to demonstrate a minimal inline approach. But there must be a clear separation between:
- Proxy (which holds the storage)
- Logic/Implementation contract (which contains the functions)

Requirements:

- Demonstrate how owners are set initially.
- Show how the threshold is determined (e.g., constructor param or function).
- Outline how proposals are submitted, approved, and executed.
- Implement at least one basic security measure (e.g., a check to prevent re-entrancy or to ensure only owners can approve).
- You do not have to create tests or scripts; just implement the core contract logic.

Nice-to-have features (not strictly required, but you can include if you have time):

- An event for each step in the multi-sig (submission, approval, execution).
- A function that allows an owner to remove themselves or add a new owner (with some form of threshold vote).

**Code**

- Contract: [./src/UpgradeableMultisig.sol](./src/UpgradeableMultisig.sol)

### VestingVault

Your task is to create a smart contract named VestingVault.sol that securely handles token vesting schedules for multiple beneficiaries. You will be evaluated on correctness, efficiency, security considerations, and readability.

Requirements:

- Contract Name: VestingVault

Functionality:
- The contract is deployed by an owner who can register multiple beneficiaries, each with their own vesting schedule.
- Each beneficiary has a unique vesting schedule consisting of:
    - Total amount of ERC20 tokens allocated.
    - Start time (UNIX timestamp).
    - Cliff period (in seconds, from start time).
    - Vesting duration (after the cliff, linear vesting until the entire allocation is released).
- Beneficiaries can withdraw only their vested tokens at any point after the cliff period. Tokens - should accumulate linearly over time after the cliff.

Conditions:
- The owner can register beneficiaries only once per beneficiary address.
- Beneficiaries cannot withdraw more than their vested tokens.
- The smart contract should not rely on external price feeds or oracle services.

Security considerations:
- Protect against common vulnerabilities like re-entrancy and integer overflows/underflows.
- Ensure access control and state updates follow Solidity best practices.

**Code**

- Contract: [./src/VestingVault.sol](./src/VestingVault.sol)

## ArbitratedEscrow

You are tasked to create a decentralized escrow contract in Solidity that securely manages funds between two parties—a buyer and a seller—facilitating trustless transactions. To handle disputes transparently, the contract involves a third-party arbitrator that can intervene to settle conflicts.

Your Contract Should Include:

- Roles & Permissions:
    - A buyer, seller, and arbitrator.
    - Only the buyer can deposit funds.
    - Only the arbitrator can intervene in disputes.

- Escrow Flow:
    - Buyer deposits the payment, initiating escrow.
    - Seller can withdraw the funds only after the buyer explicitly confirms delivery of the goods/services.
    - Buyer can initiate a dispute which freezes the escrow.

- Dispute Management (Arbitration):
    - When a dispute is raised, funds are locked until the arbitrator makes a decision.
    - The arbitrator can resolve in favor of either the buyer or seller, triggering a fund transfer accordingly.
    - Clearly defined outcomes for arbitrator’s intervention.

- Security Considerations:
    - Ensure proper handling of edge-cases, such as repeated function calls, reentrancy protection, and strict access control.

- Additional Rules:
    - Use Solidity ^0.8.20 or later.
    - Clearly document your logic using NatSpec style documentation.

**Code**

- Contract: [./src/ArbitratedEscrow.sol](./src/ArbitratedEscrow.sol)

## TimelockedMultisigWallet

Implement a multi-signature wallet with a built-in timelock mechanism.

Requirements:

- Multi-Signature
    - There should be a list of owners, each with an address stored in the contract’s state.
    - A minimum number of owners (quorum) must approve a transaction before it can be queued for execution.

- Timelock
    - After enough owners have approved a transaction, the transaction is queued.
    - There must be a configurable time delay (e.g., set in the constructor) that elapses before the transaction can be executed.

- Queueing and Execution
    - Each transaction to be executed must be “queued” by the contract, which includes storing relevant data:
        - target address, function call data, value, and the earliest execution time.
    - Only after the timelock delay has passed can an approved transaction be executed.
    - Transactions expire if not executed within a certain grace period (another parameter).

- Extra Considerations
    - Think about preventing replay attacks (e.g., re-using transaction data).
    - Handle edge cases like removing an owner, changing the quorum, or changing the timelock delay (if time allows).
    - Provide functions to add or remove owners (optional if time is tight, but good to demonstrate advanced knowledge).

**Code**

- Contract: [./src/TimelockedMultisigWallet.sol](./src/TimelockedMultisigWallet.sol)

## Other contracts

### BlockFiller

Contract that tries to fill an entire block with a gas limit of 32,000,000

**Code**

- Contract: [./src/BlockFiller.sol](./src/BlockFiller.sol)

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


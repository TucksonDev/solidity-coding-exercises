// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TimelockedMultisigWallet {
    struct Transaction {
        // Transaction information
        address to;
        uint256 value;
        bytes data;
        // Approvals
        mapping(address => bool) approvals;
        uint256 approvalCount;
        // Status (packed in the same slot)
        uint64 queuedAt;
        uint64 expiresAt;
        bool executed;
    }

    // Owners
    mapping(address => bool) public owners;
    uint256 public ownerCount;
    uint256 public approvalThreshold;

    // Transactions (nonce => transaction)
    mapping(uint256 => Transaction) public transactions;
    uint256 public nonce;

    // Timing (we could set a minimum of delays here)
    uint64 public executionDelaySeconds;
    uint64 public expirationDelaySeconds;

    // Errors
    error NoOwners();
    error ZeroAddress();
    error ZeroThreshold();
    error ZeroExecutionDelay();
    error ZeroExpirationDelay();
    error NotMultisig();
    error AlreadyOwner();
    error NotOwner();
    error NotEnoughOwners();
    error InvalidNonce();
    error AlreadyExpired();
    error AlreadyExecuted();
    error AlreadyApproved();
    error ThresholdNotReached();
    error NotEnoughValue();
    error CallFailed();
    error Timelocked();

    // Event
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed ownerToRemove);
    event ApprovalThresholdSet(uint256 indexed newThreshold);
    event ExecutionDelaySet(uint256 indexed newExecutionDelaySeconds);
    event ExpirationDelaySet(uint256 indexed newExpirationDelaySeconds);
    event TransactionProposed(uint256 indexed nonce, address indexed to, uint256 value, bytes data);
    event TransactionApproved(uint256 indexed nonce, address indexed owner);
    event TranscationExecuted(uint256 indexed nonce);

    // Modifiers
    modifier onlyMultisig() {
        if (msg.sender != address(this)) {
            revert NotMultisig();
        }
        _;
    }

    modifier onlyOwner() {
        if (!owners[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    constructor(
        address[] memory _owners,
        uint256 _approvalThreshold,
        uint64 _executionDelaySeconds,
        uint64 _expirationDelaySeconds
    ) {
        if (_owners.length == 0) {
            revert NoOwners();
        }
        if (_approvalThreshold == 0) {
            revert ZeroThreshold();
        }
        if (_executionDelaySeconds == 0) {
            revert ZeroExecutionDelay();
        }
        if (_expirationDelaySeconds == 0) {
            revert ZeroExpirationDelay();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) {
                revert ZeroAddress();
            }

            if (!owners[_owners[i]]) {
                owners[_owners[i]] = true;
                ownerCount++;

                // Emitting one event per owner added
                // It is more common in real-world scenarios
                emit OwnerAdded(_owners[i]);
            }
        }

        if (ownerCount < _approvalThreshold) {
            revert NotEnoughOwners();
        }

        approvalThreshold = _approvalThreshold;
        emit ApprovalThresholdSet(approvalThreshold);

        executionDelaySeconds = _executionDelaySeconds;
        emit ExecutionDelaySet(executionDelaySeconds);

        expirationDelaySeconds = _expirationDelaySeconds;
        emit ExpirationDelaySet(expirationDelaySeconds);
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function addOwner(address newOwner) external onlyMultisig {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }
        if (owners[newOwner]) {
            revert AlreadyOwner();
        }

        owners[newOwner] = true;
        ownerCount++;

        emit OwnerAdded(newOwner);
    }

    function removeOwner(address ownerToRemove) external onlyMultisig {
        if (ownerToRemove == address(0)) {
            revert ZeroAddress();
        }
        if (!owners[ownerToRemove]) {
            revert NotOwner();
        }

        owners[ownerToRemove] = false;
        ownerCount--;

        if (ownerCount < approvalThreshold) {
            revert NotEnoughOwners();
        }

        emit OwnerRemoved(ownerToRemove);
    }

    function setApprovalThreshold(uint256 newApprovalThreshold) external onlyMultisig {
        if (newApprovalThreshold == 0) {
            revert ZeroThreshold();
        }
        if (ownerCount < newApprovalThreshold) {
            revert NotEnoughOwners();
        }

        approvalThreshold = newApprovalThreshold;

        emit ApprovalThresholdSet(newApprovalThreshold);
    }

    function setExecutionDelay(uint64 newExecutionDelaySeconds) external onlyMultisig {
        if (newExecutionDelaySeconds == 0) {
            revert ZeroExecutionDelay();
        }

        executionDelaySeconds = newExecutionDelaySeconds;

        emit ExecutionDelaySet(newExecutionDelaySeconds);
    }

    function setExpirationDelaySeconds(uint64 newExpirationDelaySeconds) external onlyMultisig {
        if (newExpirationDelaySeconds == 0) {
            revert ZeroExpirationDelay();
        }

        expirationDelaySeconds = newExpirationDelaySeconds;

        emit ExpirationDelaySet(newExpirationDelaySeconds);
    }

    ///////////////////////
    // Transaction logic //
    ///////////////////////
    function proposeTransaction(address to, uint256 value, bytes memory data, bool approve) external onlyOwner {
        // We could add some logic here depending on the allowed transactions
        // (like verify whether the destination is a contract or not based on the data included, ...)
        // But for simplicity, we'll allow any arbitrary calls except calling the zero address (so we also can check if the nonce exists or not that way)
        if (to == address(0)) {
            revert ZeroAddress();
        }

        uint256 currentNonce = nonce;
        nonce++;

        Transaction storage transaction = transactions[currentNonce];
        transaction.to = to;
        transaction.value = value;
        transaction.data = data;

        // The sender also approves this transaction
        if (approve) {
            transaction.approvals[msg.sender] = true;
            transaction.approvalCount++;

            emit TransactionApproved(currentNonce, msg.sender);
        }

        emit TransactionProposed(currentNonce, to, value, data);
    }

    function approveTransaction(uint256 _nonce) external onlyOwner {
        if (transactions[_nonce].to == address(0)) {
            revert InvalidNonce();
        }

        Transaction storage transaction = transactions[_nonce];

        if ((transaction.expiresAt > 0) && (transaction.expiresAt < uint64(block.timestamp))) {
            revert AlreadyExpired();
        }
        if (transaction.executed) {
            revert AlreadyExecuted();
        }
        if (transaction.approvals[msg.sender]) {
            revert AlreadyApproved();
        }

        transaction.approvals[msg.sender] = true;
        transaction.approvalCount++;

        // Setting timings if we reach the threshold
        if ((transaction.approvalCount >= approvalThreshold) && (transaction.queuedAt == 0)) {
            transaction.queuedAt = uint64(block.timestamp);
            transaction.expiresAt = uint64(block.timestamp) + expirationDelaySeconds;
        }

        emit TransactionApproved(_nonce, msg.sender);
    }

    function executeTransaction(uint256 _nonce) external onlyOwner returns (bytes memory) {
        if (transactions[_nonce].to == address(0)) {
            revert InvalidNonce();
        }

        Transaction storage transaction = transactions[_nonce];

        if (transaction.expiresAt < uint64(block.timestamp)) {
            revert AlreadyExpired();
        }
        if (transaction.queuedAt + executionDelaySeconds > uint64(block.timestamp)) {
            revert Timelocked();
        }
        if (transaction.executed) {
            revert AlreadyExecuted();
        }
        if (transaction.approvalCount < approvalThreshold) {
            revert ThresholdNotReached();
        }
        if (transaction.value > address(this).balance) {
            revert NotEnoughValue();
        }

        // Storing the executed flag
        transaction.executed = true;

        (bool success, bytes memory returnedData) =
            payable(transaction.to).call{value: transaction.value}(transaction.data);
        if (!success) {
            revert CallFailed();
        }

        emit TranscationExecuted(_nonce);

        return returnedData;
    }

    // Only owners can send funds to this wallet
    receive() external payable {
        if (!owners[msg.sender]) {
            revert NotOwner();
        }
    }
}

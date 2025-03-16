// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    // Structs
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 blockAdded;
        address[] confirmed;
        bool executed;
    }

    // Owners
    // Maximum amount = type(uint8).max
    mapping(address => bool) public owners;
    uint8 public ownersCount;

    // Confirmation threshold (expected less than 256 owners)
    uint8 public confirmationThreshold;

    // Transactions (nonce => Transaction)
    mapping(uint256 => Transaction) public transactions;
    uint256 public nonce;

    // Errors
    error IsOwner();
    error NotOwner();
    error NotMultisig();
    error TooManyOwners();
    error ConfirmationThresholdTooHigh();
    error ZeroAddress();
    error ZeroThreshold();
    error WrongTransaction();
    error AlreadyExecuted();
    error AlreadyConfirmed();
    error NotEnoughConfirmations();
    error NotEnoughValue();
    error CallFailed();

    // Events
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event ConfirmationThresholdSet(uint8 newConfirmationThreshold);
    event NewTransaction(uint256 indexed currentNonce, address to, uint256 value);
    event TransactionConfirmed(uint256 indexed nonce, address confirmedBy);
    event TransactionExecuted(uint256 indexed nonce);

    // Modifiers
    modifier onlyMultisig() {
        // Transactions only sent from this multisig to this multisig
        if (msg.sender != address(this)) {
            revert NotMultisig();
        }
        _;
    }

    modifier onlyOwner() {
        // We are assuming there won't be a lot of owners. If many owners are expected,
        // it'd be better to use a mapping(address => bool) instead
        if (!isOwner(msg.sender)) {
            revert NotOwner();
        }
        _;
    }

    constructor(address[] memory _owners, uint8 _confirmationThreshold) {
        // We enforce a state where transactions can be signed right at the beginning
        // (i.e., we could remove this check, but it would mean more owners might have to
        // be added before the wallet is usable)
        if (_confirmationThreshold > _owners.length) {
            revert ConfirmationThresholdTooHigh();
        }

        // Check amount of owners
        if (_owners.length > type(uint8).max) {
            revert TooManyOwners();
        }

        // Check every address
        for (uint8 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) {
                revert ZeroAddress();
            }
            owners[_owners[i]] = true;
        }
        ownersCount = uint8(_owners.length);

        // Check confirmation threshold
        if (_confirmationThreshold == 0) {
            revert ZeroThreshold();
        }

        confirmationThreshold = _confirmationThreshold;
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function addOwner(address newOwner) external onlyMultisig {
        if (isOwner(newOwner)) {
            revert IsOwner();
        }

        if (ownersCount + 1 > type(uint8).max) {
            revert TooManyOwners();
        }

        owners[newOwner] = true;
        ownersCount++;

        emit OwnerAdded(newOwner);
    }

    function removeOwner(address ownerToRemove) external onlyMultisig {
        if (!isOwner(ownerToRemove)) {
            revert NotOwner();
        }

        if (ownersCount - 1 < confirmationThreshold) {
            revert ConfirmationThresholdTooHigh();
        }

        owners[ownerToRemove] = false;
        ownersCount--;

        emit OwnerRemoved(ownerToRemove);
    }

    function setConfirmationThreshold(uint8 newConfirmationThreshold) external onlyMultisig {
        if (newConfirmationThreshold == 0) {
            revert ZeroThreshold();
        }
        if (newConfirmationThreshold > ownersCount) {
            revert ConfirmationThresholdTooHigh();
        }

        confirmationThreshold = newConfirmationThreshold;

        emit ConfirmationThresholdSet(newConfirmationThreshold);
    }

    ////////////////
    // Main logic //
    ////////////////
    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner {
        uint256 currentNonce = nonce;
        nonce++;
        transactions[currentNonce] = Transaction(to, value, data, block.number, new address[](0), false);

        emit NewTransaction(currentNonce, to, value);
    }

    function confirmTransaction(uint256 _nonce) external onlyOwner {
        if (transactions[_nonce].blockAdded == 0) {
            revert WrongTransaction();
        }

        if (transactions[_nonce].executed == true) {
            revert AlreadyExecuted();
        }

        for (uint8 i = 0; i < transactions[_nonce].confirmed.length; i++) {
            if (transactions[_nonce].confirmed[i] == msg.sender) {
                revert AlreadyConfirmed();
            }
        }

        transactions[_nonce].confirmed.push(msg.sender);
        emit TransactionConfirmed(_nonce, msg.sender);
    }

    // Once confirmed by enough owners, anyone could execute the transaction
    // but let's add an additional check here so only an owner can execute it
    function executeTransaction(uint256 _nonce) external payable onlyOwner {
        if (transactions[_nonce].blockAdded == 0) {
            revert WrongTransaction();
        }

        if (transactions[_nonce].executed == true) {
            revert AlreadyExecuted();
        }

        if (transactions[_nonce].confirmed.length < confirmationThreshold) {
            revert NotEnoughConfirmations();
        }

        if (msg.value != transactions[_nonce].value) {
            revert NotEnoughValue();
        }

        // Execution
        (bool success,) = transactions[_nonce].to.call{value: transactions[_nonce].value}(transactions[_nonce].data);
        if (!success) {
            revert CallFailed();
        }
        transactions[_nonce].executed = true;

        emit TransactionExecuted(_nonce);
    }

    function isOwner(address owner) public view returns (bool) {
        return owners[owner];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigSimpleProxy {
    // We use the first slots to store the admin and the implementation
    // We could use something like EIP-1967, but for simplicity, we'll do it
    // this way in this exercise
    address public admin;
    address public implementation;

    // Errors
    error NotAdmin();
    error ZeroAddress();
    error NoCode();
    error CallFailed();
    error NoData();

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }
        admin = newAdmin;
    }

    // To simplify the proxy, we require the implementation to be set here (even the first one)
    // and to have an initialize function
    // We also don't allow a "setImplementation" to exist in the implementation contract
    // I'm aware this is a bit limiting, but I'm doing it this way for simplicity
    function setImplementation(
        address newImplementation,
        address[] memory multisigOwners,
        uint256 multisigConfirmationThreshold
    ) external onlyAdmin {
        if (newImplementation == address(0)) {
            revert ZeroAddress();
        }
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(newImplementation)
        }
        if (codeSize == 0) {
            revert NoCode();
        }

        implementation = newImplementation;
        (bool success,) = implementation.delegatecall(
            abi.encodeWithSignature("initialize(address[], uint256)", multisigOwners, multisigConfirmationThreshold)
        );
        if (!success) {
            revert CallFailed();
        }
    }

    fallback() external payable {
        (bool success,) = implementation.delegatecall(msg.data);
        if (!success) {
            revert CallFailed();
        }
    }

    // We need to hold funds to execute multisig transactions
    receive() external payable {}
}

contract Multisig {
    // Unused storage slots
    // (Needed since the proxy uses these slots to store the admin and implementation)
    address private reservedForAdmin;
    address private reservedForImplementation;

    // Structs
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        mapping(address => bool) ownerConfirmations;
        uint256 confirmations;
        bool executed;
    }

    // Initialization
    bool public initialized;

    // Owners
    // We use a mapping for its simplicity on adding/removing owners
    mapping(address => bool) public owners;
    uint256 public ownerCount;

    // Confirmation threshold
    // (Minimum number of owners needed for confirmation)
    uint256 public confirmationThreshold;

    // Transactions
    // Mapping nonce => transaction data
    mapping(uint256 => Transaction) public transactions;
    uint256 public currentNonce;

    // Errors
    error AlreadyInitialized();
    error ZeroAddress();
    error NotMultisig();
    error NotOwner();
    error ConfirmationThresholdTooHigh();
    error AlreadyExecuted();
    error AlreadyConfirmed();
    error NotEnoughConfirmations();
    error NotEnoughValue();
    error CallFailed();

    // Events
    event NewOwnersAdded(uint256 ownerCount);
    event OwnerRemoved(address indexed removedOwner);
    event ConfirmationThresholdSet(uint256 confirmationThreshold);
    event TransactionProposed(
        uint256 indexed nonce, address indexed owner, address indexed to, uint256 value, bytes data
    );
    event TransactionConfirmed(uint256 indexed nonce, address indexed owner);
    event TransactionExecuted(uint256 indexed nonce);

    // Modifier
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

    function initialize(address[] memory _owners, uint256 _confirmationThreshold) external {
        if (initialized) {
            revert AlreadyInitialized();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) {
                revert ZeroAddress();
            }
            if (!owners[_owners[i]]) {
                owners[_owners[i]] = true;
                ownerCount++;
            }
        }

        // We check the threshold here, in case we had duplicates in the owners array
        if (_confirmationThreshold > ownerCount) {
            revert ConfirmationThresholdTooHigh();
        }
        confirmationThreshold = _confirmationThreshold;

        emit NewOwnersAdded(ownerCount);
        emit ConfirmationThresholdSet(confirmationThreshold);
    }

    /////////////////////
    // Admin functions //
    /////////////////////
    function setConfirmationThreshold(uint256 newConfirmationThreshold) external onlyMultisig {
        if (newConfirmationThreshold > ownerCount) {
            revert ConfirmationThresholdTooHigh();
        }
        confirmationThreshold = newConfirmationThreshold;

        emit ConfirmationThresholdSet(newConfirmationThreshold);
    }

    function addOwners(address[] memory newOwners) external onlyMultisig {
        uint256 currentOwners = ownerCount;
        for (uint256 i = 0; i < newOwners.length; i++) {
            if (newOwners[i] == address(0)) {
                revert ZeroAddress();
            }
            if (!owners[newOwners[i]]) {
                owners[newOwners[i]] = true;
                ownerCount++;
            }
        }

        emit NewOwnersAdded(ownerCount - currentOwners);
    }

    function removeOwner(address ownerToRemove) external onlyMultisig {
        if (ownerToRemove == address(0)) {
            revert ZeroAddress();
        }
        if (!owners[ownerToRemove]) {
            revert NotOwner();
        }
        if (confirmationThreshold > (ownerCount - 1)) {
            revert ConfirmationThresholdTooHigh();
        }

        owners[ownerToRemove] = false;
        ownerCount--;

        emit OwnerRemoved(ownerToRemove);
    }

    function resign() external onlyOwner {
        if (confirmationThreshold > (ownerCount - 1)) {
            revert ConfirmationThresholdTooHigh();
        }

        owners[msg.sender] = false;
        ownerCount--;

        emit OwnerRemoved(msg.sender);
    }

    ////////////////
    // Main logic //
    ////////////////

    // Propose function
    // There are multiple things we could filter here:
    //  - address 0
    //  - No value and/or no data
    //  - How many transactions has the owner proposed
    // But we'll leave it open for simplicity
    function propose(address _to, uint256 _value, bytes memory _data) external onlyOwner {
        Transaction storage transaction = transactions[currentNonce];
        transaction.to = _to;
        transaction.value = _value;
        transaction.data = _data;

        currentNonce++;

        emit TransactionProposed(currentNonce - 1, msg.sender, _to, _value, _data);
    }

    // Confirm function
    function confirm(uint256 nonce) external onlyOwner {
        if (transactions[nonce].executed) {
            revert AlreadyExecuted();
        }
        if (transactions[nonce].ownerConfirmations[msg.sender]) {
            revert AlreadyConfirmed();
        }

        transactions[nonce].ownerConfirmations[msg.sender] = true;
        transactions[nonce].confirmations++;

        emit TransactionConfirmed(nonce, msg.sender);
    }

    // Execute function
    // We could open for anyone to execute a transcation (since it's already been confirmed),
    // but we limit it to owners in case they want to have control on when to execute the transaction
    // Transactions are paid with funds on the contract and funds sent through this function
    function execute(uint256 nonce) external payable onlyOwner returns (bytes memory) {
        if (transactions[nonce].executed) {
            revert AlreadyExecuted();
        }
        if (transactions[nonce].confirmations < confirmationThreshold) {
            revert NotEnoughConfirmations();
        }
        if (transactions[nonce].value > address(this).balance) {
            revert NotEnoughValue();
        }

        transactions[nonce].executed = true;

        // We try to execute
        (bool success, bytes memory returnedData) =
            address(transactions[nonce].to).call{value: transactions[nonce].value}(transactions[nonce].data);
        if (!success) {
            revert CallFailed();
        }

        emit TransactionExecuted(nonce);

        return returnedData;
    }
}

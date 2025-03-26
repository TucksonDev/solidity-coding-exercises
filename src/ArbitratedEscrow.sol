// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ArbitratedEscrow {
    // Arbitrator is placed next to the isDisputed boolean so they are packed together
    // (both arbitrator and isDisputed are read in the same function)
    address public arbitrator;
    bool public isDisputed;

    address public buyer;
    bool public isFinished;

    // Seller is placed last so this variable is packed with operationConfirmed
    // (both seller and operationConfirmed are read in the same function)
    address public seller;
    bool public receptionConfirmed;

    uint256 public purchasePrice;

    // Errors
    error ZeroAddress();
    error JointRoles();
    error NotBuyer();
    error NotSeller();
    error NotArbitrator();
    error ZeroAmount();
    error ReceptionAlreadyConfirmed();
    error ReceptionNotConfirmed();
    error SendEthFailed();
    error IsDisputed();
    error NotDisputed();
    error OperationFinished();

    // Events
    event Deposit(uint256 amount);
    event PriceSet(uint256 purchasePrice);
    event ReceptionConfirmed();
    event Withdraw(uint256 amount);
    event DisputeRaised();
    event DisputeResolved(bool buyerWasFavored);

    // Modifiers
    modifier onlyBuyer() {
        if (msg.sender != buyer) {
            revert NotBuyer();
        }
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) {
            revert NotSeller();
        }
        _;
    }

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) {
            revert NotArbitrator();
        }
        _;
    }

    modifier ifNotDisputed() {
        if (isDisputed) {
            revert IsDisputed();
        }
        _;
    }

    constructor(address _buyer, address _seller, address _arbitrator, uint256 _purchasePrice) {
        if (_buyer == address(0) || _seller == address(0) || _arbitrator == address(0)) {
            revert ZeroAddress();
        }
        if (_buyer == _seller || _buyer == _arbitrator || _seller == _arbitrator) {
            revert JointRoles();
        }
        if (_purchasePrice == 0) {
            revert ZeroAmount();
        }

        buyer = _buyer;
        seller = _seller;
        arbitrator = _arbitrator;
        purchasePrice = _purchasePrice;

        emit PriceSet(purchasePrice);
    }

    // Seller can modify the price if needed (even if disputed)
    function setPurchasePrice(uint256 newPrice) external onlySeller {
        if (newPrice == 0) {
            revert ZeroAmount();
        }
        purchasePrice = newPrice;
        emit PriceSet(purchasePrice);
    }

    // Buyer confirms when it has received the purchased good (even if disputed)
    function confirmReception() external onlyBuyer {
        if (receptionConfirmed) {
            revert ReceptionAlreadyConfirmed();
        }
        receptionConfirmed = true;
        emit ReceptionConfirmed();
    }

    function withdrawFunds() external onlySeller ifNotDisputed {
        if (!receptionConfirmed) {
            revert ReceptionNotConfirmed();
        }
        uint256 escrowedFunds = getEscrowedFunds();
        isFinished = true;

        (bool success,) = payable(seller).call{value: escrowedFunds}("");
        if (!success) {
            revert SendEthFailed();
        }

        emit Withdraw(escrowedFunds);
    }

    function initiateDispute() external onlyBuyer ifNotDisputed {
        isDisputed = true;
        emit DisputeRaised();
    }

    function solveDispute(bool favorBuyer) external onlyArbitrator {
        if (!isDisputed) {
            revert NotDisputed();
        }

        address recipient = favorBuyer ? buyer : seller;

        uint256 escrowedFunds = getEscrowedFunds();
        isDisputed = false;
        isFinished = true;

        (bool success,) = payable(recipient).call{value: escrowedFunds}("");
        if (!success) {
            revert SendEthFailed();
        }

        emit DisputeResolved(favorBuyer);
    }

    // Funds can only deposited by the buyer
    // Note: funds can also be sent to this contract via self-destructing another
    // contract and sending its funds here
    receive() external payable {
        if (isFinished) {
            revert OperationFinished();
        }
        if (msg.sender != buyer) {
            revert NotBuyer();
        }
        if (msg.value == 0) {
            revert ZeroAmount();
        }
        emit Deposit(msg.value);
    }

    // We consider all balance of this contract to be the escrowed funds
    // Payments can be deposited via the "receive" method (by the buyer) or by
    // self-destructing another contract and sending its funds to this one
    function getEscrowedFunds() public view returns (uint256) {
        return address(this).balance;
    }
}

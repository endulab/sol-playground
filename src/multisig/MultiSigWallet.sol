// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * This smart contract implements a Multi-Signature Wallet where multiple owners
 * are required to approve transactions before they can be executed.
 */
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) isOwner;

    uint public immutable requiredApprovalsNumber;

    struct Transaction {
        bool executed;
        address to;
        uint256 value;
    }

    Transaction[] public transactions;

    mapping(uint256 => mapping(address => bool)) approvals;

    event TransactionSubmitted(uint256 indexed transactionId, address indexed to, uint256 amount);
    event TransactionApproved(uint256 indexed transactionId);
    event TransactionExecuted(uint256 indexed transactionId);

    error MultiSigWallet_NotEnoughOwners();
    error MultiSigWallet_RequiredApprovalsNumberIncorrect();
    error MultiSigWallet_OwnerAddressInvalid();
    error MultiSigWallet_ReceiverAddressInvalid();
    error MultiSigWallet_TransactionValueTooLow();
    error MultiSigWallet_TransactionIdIncorrect();
    error MultiSigWallet_TransactionAlreadyExecuted();
    error MultiSigWallet_TransactionAlreadyApprovedByTheAddress();
    error MultiSigWallet_TransactionNotFullyApproved();
    error MultiSigWallet_TransferFailed();
    error MultiSigWallet_NotTheOwner();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert MultiSigWallet_NotTheOwner();
        }
        _;
    }

    constructor(address[] memory _owners, uint _requiredApprovalsNumber) {
        if (_owners.length < 2) {
            revert MultiSigWallet_NotEnoughOwners();
        }
        if (_requiredApprovalsNumber <= 0 || _requiredApprovalsNumber > _owners.length) {
            revert MultiSigWallet_RequiredApprovalsNumberIncorrect();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) {
                revert MultiSigWallet_OwnerAddressInvalid();
            }
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }

        requiredApprovalsNumber = _requiredApprovalsNumber;
    }

    /**
     * Submits a new transaction with the address _to and amount from msg.value.
     * Returns id of the added transaction.
     * Only sub-owner of the contract can execute this function.
     */
    function submitTransaction(address _to) public payable onlyOwner returns (uint256) {
        if (_to == address(0)) {
            revert MultiSigWallet_ReceiverAddressInvalid();
        }
        if (msg.value <= 0) {
            revert MultiSigWallet_TransactionValueTooLow();
        }
        uint256 newId = transactions.length;
        transactions.push(Transaction({to: _to, value: msg.value, executed: false}));
        emit TransactionSubmitted(newId, _to, msg.value);
        return newId;
    }

    /**
     * Approves a transaction with id _transactionId.
     * Only sub-owner of the contract can execute this function.
     */
    function approveTransaction(uint256 _transactionId) public onlyOwner {
        if (_transactionId >= transactions.length) {
            revert MultiSigWallet_TransactionIdIncorrect();
        }
        if (transactions[_transactionId].executed) {
            revert MultiSigWallet_TransactionAlreadyExecuted();
        }
        if (approvals[_transactionId][msg.sender]) {
            revert MultiSigWallet_TransactionAlreadyApprovedByTheAddress();
        }
        approvals[_transactionId][msg.sender] = true;
        emit TransactionApproved(_transactionId);
    }

    /**
     * Executes a transaction with id _transactionId.
     * The transaction's value is transferred from contract to the transaction's address.
     * Only sub-owner of the contract can execute this function.
     */
    function executeTransaction(uint256 _transactionId) public onlyOwner {
        if (_transactionId >= transactions.length) {
            revert MultiSigWallet_TransactionIdIncorrect();
        }
        if (transactions[_transactionId].executed) {
            revert MultiSigWallet_TransactionAlreadyExecuted();
        }
        if (!isTransactionFullyApproved(_transactionId)) {
            revert MultiSigWallet_TransactionNotFullyApproved();
        }

        (bool result, ) = transactions[_transactionId].to.call{value: transactions[_transactionId].value }("");
        if (!result) {
            revert MultiSigWallet_TransferFailed();
        }
        transactions[_transactionId].executed = true;
        emit TransactionExecuted(_transactionId);
    }

    /**
     * Returns true if transaction with id _transactionId
     * is approved by required number of owners. Otherwise returns false.
     */
    function isTransactionFullyApproved(uint256 _transactionId) public view returns (bool) {
        uint numberOfApprovals;
        for (uint i = 0; i < owners.length; i++) {
            if (approvals[_transactionId][owners[i]]) {
                numberOfApprovals++;
            }
        }
        return numberOfApprovals >= requiredApprovalsNumber;
    }
}

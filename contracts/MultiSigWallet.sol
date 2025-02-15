// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoardFundManager {

    error Unauthorized();
    error InvalidBoardSize();
    error InvalidTokenAddress();
    error DuplicateBoardMember();
    error TransactionNotFound();
    error TransactionAlreadyExecuted();
    error TransactionAlreadyApproved();
    error ApprovalRequired();
    error TransferFailed();

    event FundsDeposited(address indexed depositor, uint amount, uint newBalance);
    event TransactionSubmitted(address indexed initiator, uint indexed txID, address indexed target, uint amount, bytes payload);
    event TransactionConfirmed(address indexed approver, uint indexed txID);
    event ConfirmationRevoked(address indexed approver, uint indexed txID);
    event TransactionExecuted(address indexed executor, uint indexed txID);
    event FundsTransferred(address indexed target, uint amount);
    event TransactionApproval(address indexed approver, uint indexed txID, uint totalApprovals);

    IERC20 public token;
    address[] public boardMembers;
    mapping(address => bool) public isBoardMember;
    uint public requiredApprovals;

    struct PendingTransaction {
        address target;
        uint amount;
        bytes payload;
        bool hasBeenExecuted;
        uint approvalCount;
    }

    mapping(uint => mapping(address => bool)) public hasConfirmed;
    PendingTransaction[] public pendingTransactions;

    modifier onlyBoardMember() {
        if (!isBoardMember[msg.sender]) revert Unauthorized();
        _;
    }

    modifier transactionExists(uint _txID) {
        if (_txID >= pendingTransactions.length) revert TransactionNotFound();
        _;
    }

    modifier notYetExecuted(uint _txID) {
        if (pendingTransactions[_txID].hasBeenExecuted) revert TransactionAlreadyExecuted();
        _;
    }

    modifier notYetConfirmed(uint _txID) {
        if (hasConfirmed[_txID][msg.sender]) revert TransactionAlreadyApproved();
        _;
    }

    constructor(address[] memory _members, address _token) {
        if (_members.length != 20) revert InvalidBoardSize();
        if (_token == address(0)) revert InvalidTokenAddress();

        token = IERC20(_token);
        requiredApprovals = 20;

        for (uint i = 0; i < _members.length; i++) {
            address member = _members[i];
            if (member == address(0)) revert InvalidTokenAddress();
            if (isBoardMember[member]) revert DuplicateBoardMember();

            isBoardMember[member] = true;
            boardMembers.push(member);
        }
    }

    //this function is used to deposit funds into the contract
    function depositFunds(uint _amount) public onlyBoardMember {
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert TransferFailed();
        emit FundsDeposited(msg.sender, _amount, token.balanceOf(address(this)));
    }

    function addTransaction(address _target, uint _amount, bytes memory _payload) public onlyBoardMember {
        uint txID = pendingTransactions.length;
        pendingTransactions.push(PendingTransaction({
            target: _target,
            amount: _amount,
            payload: _payload,
            hasBeenExecuted: false,
            approvalCount: 0
        }));
        emit TransactionSubmitted(msg.sender, txID, _target, _amount, _payload);
    }

    function approveTransaction(uint _txID) 
        public onlyBoardMember transactionExists(_txID) notYetExecuted(_txID) notYetConfirmed(_txID) 
    {
        PendingTransaction storage pendingTx = pendingTransactions[_txID];

        pendingTx.approvalCount += 1;
        hasConfirmed[_txID][msg.sender] = true;

        emit TransactionApproval(msg.sender, _txID, pendingTx.approvalCount);
    }

    //this function is used to withdraw funds from the contract
    function runTransaction(uint _txID) public onlyBoardMember transactionExists(_txID) notYetExecuted(_txID) {
        PendingTransaction storage pendingTx = pendingTransactions[_txID];

        require(pendingTx.approvalCount == requiredApprovals, "Not enough approvals");

        pendingTx.hasBeenExecuted = true;

        emit TransactionExecuted(msg.sender, _txID); // Log before sending

        bool success = token.transfer(pendingTx.target, pendingTx.amount);
        require(success, "ERC20 Transfer failed");

        emit FundsTransferred(pendingTx.target, pendingTx.amount);
    }


    function retractApproval(uint _txID) public onlyBoardMember transactionExists(_txID) notYetExecuted(_txID) {
        PendingTransaction storage pendingTx = pendingTransactions[_txID];
        if (!hasConfirmed[_txID][msg.sender]) revert TransactionAlreadyApproved();
        pendingTx.approvalCount -= 1;
        hasConfirmed[_txID][msg.sender] = false;
        emit ConfirmationRevoked(msg.sender, _txID);
    }

    function listBoardMembers() public view returns (address[] memory) {
        return boardMembers;
    }

    //this function is used to count the number of pending transactions
    function countTransactions() public view returns (uint) {
        return pendingTransactions.length;
    }

    //this function is used to fetch a transaction
    function fetchTransaction(uint _txID) public view returns (address target, uint amount, bytes memory payload, bool hasBeenExecuted, uint approvalCount) {
        if (_txID >= pendingTransactions.length) revert TransactionNotFound();
        PendingTransaction storage pendingTx = pendingTransactions[_txID];
        return (pendingTx.target, pendingTx.amount, pendingTx.payload, pendingTx.hasBeenExecuted, pendingTx.approvalCount);
    }
}

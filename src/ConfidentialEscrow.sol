// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EncryptedVault} from "./EncryptedVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {euint256, ebool, e} from "@inco/lightning/src/Lib.sol";

contract ConfidentialEscrow {
    using e for *;

    error ConfidentionEscrow__TitleOfConditionsCanNotBeSame();

    // ========== STORAGE ==========
    IERC20 private immutable token;
    EncryptedVault private immutable vault;
    address private immutable buyer;
    address private immutable seller;
    address private immutable i_governor;
    uint256 private immutable totalAmount;
    address private immutable tokenAddress;
    uint256 private immutable i_deadLine;
    uint256 private immutable i_initialtionTime;
    euint256 private key;
    bool private deposited;
    bool private refund;

    mapping(bytes32 => bool) private isCondition;
    mapping(bytes32 => Condition) private conditions;

    struct Condition {
        string title;
        string description;
        bool approvedByBuyer;
        bool approvedBySeller;
        uint256 advancePayment;
        bool lock;
    }

    enum Status {
        IN_PROGRESS,
        FUNDS_LOCKED,
        COMPLETE
    }

    Status private contractStatus;

    // ========== CUSTOM ERRORS ==========
    error NotBuyer();
    error NotSeller();
    error InvalidStatus();
    error InsufficientBalance();
    error ApprovalFailed();
    error NotAllowed();

    // ========== EVENTS ==========
    event ContractCompleted();
    event DepositCompleted(address indexed buyer, uint256 amount);
    event AmountLocked(address indexed buyer, uint256 amount);

    // ========== MODIFIERS ==========
    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller();
        _;
    }

    /**
     *
     * @dev Only the governor can call this function
     */
    modifier onlyGovernor() {
        if (msg.sender != i_governor) revert NotSeller();
        _;
    }

    modifier inProgress() {
        if (contractStatus != Status.IN_PROGRESS) revert InvalidStatus();
        _;
    }

    // ========== CONSTRUCTOR ==========
    constructor(
        address _seller,
        address _buyer,
        uint256 _amount,
        address _tokenAddress,
        address _governor,
        Conditons[] memory _conditions,
        uint256 _deadLine
    ) payable {
        buyer = _buyer;
        seller = _seller;
        totalAmount = _amount;
        tokenAddress = _tokenAddress;
        contractStatus = Status.IN_PROGRESS;
        i_governor = _governor; // address of the timeLock contract of the governor contract
        i_deadLine = _deadLine;

        for (uint256 i = 0; i < _conditions.length; i++) {
            bytes32 conditionHash = keccak256(abi.encodePacked(_conditions[i].title));
            if (isCondition[conditionHash]) revert ConfidentionEscrow__TitleOfConditionsCanNotBeSame();
            isCondition[conditionHash] = true;
            conditions[conditionHash] = _conditions[i];
        }

        i_initialtionTime = block.timestamp;

        token = IERC20(_tokenAddress);
    }

    // ========== CORE FUNCTIONS ==========

    function deposit() external onlyBuyer inProgress {
        if (deposited) revert ApprovalFailed();

        token.transferFrom(msg.sender, address(this), totalAmount);
        if (token.balanceOf(address(this)) < totalAmount) revert InsufficientBalance();
        deposited = true;
        emit DepositCompleted(msg.sender, totalAmount);
    }

    function advancePayment() private {}

    function lock() external onlyBuyer inProgress {
        if (token.balanceOf(msg.sender) < totalAmount) revert InsufficientBalance();

        EncryptedVault _vault = new EncryptedVault(_tokenAddress, _buyer, _seller, _governor);
        vault = _vault;

        euint256 generatedKey = _getRandomKey();
        key = generatedKey;

        if (!token.approve(address(vault), totalAmount)) revert ApprovalFailed();

        generatedKey.allow(address(vault));
        vault.deposit(totalAmount, generatedKey);

        emit AmountLocked(msg.sender, totalAmount);
    }

    function approveKey() external onlyBuyer inProgress {
        key.allow(seller);
        if (!e.isAllowed(seller, key)) revert NotAllowed();
    }

    // function releaseFunds() external onlySeller inProgress {
    //     vault.releaseFunds();
    // }

    function approveCondition(bytes32 _conditionKey) external inProgress {
        if (msg.sender == buyer) {
            conditions[_conditionKey].approvedByBuyer = true;
        } else if (msg.sender == seller) {
            conditions[_conditionKey].approvedBySeller = true;
        } else {
            revert NotAllowed();
        }

        if (conditions[_conditionKey].approvedByBuyer && conditions[_conditionKey].approvedBySeller) {
            if (conditions[_conditionKey].advancePayment > 0) {
                token.transfer(seller, conditions[_conditionKey].advancePayment);
                totalAmount -= conditions[_conditionKey].advancePayment;

                if (condition[_conditionKey].lock) {
                    lock();
                }
            }
        }
    }

    function refund() external onlySeller inProgress {
        refund = true;
    }

    function ariseDispute() external inProgress {
        if (msg.sender != buyer || msg.sender != seller) revert NotAllowed();
        if (block.timestamp > i_deadLine + i_initialtionTime) {
            if(contractStatus == Status.IN_PROGRESS) {
                token.transfer(buyer, totalAmount);
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            } else {
                // propose a vote to the governor contract
            }
        }
    }

    function completeContract() external inProgress {
        if (contractStatus == Status.COMPLETE) revert InvalidStatus();

        if (msg.sender == seller) {
            for (uint256 i = 0; i < conditions.length; i++) {
                if (!conditions[i].approvedByBuyer || !conditions[i].approvedBySeller) revert ApprovalFailed();
            }

            vault.releaseFunds();

            contractStatus = Status.COMPLETE;
            emit ContractCompleted();
        } else if (msg.sender == buyer) {
            if (!refund) revert ApprovalFailed();
            if (contractStatus == status.IN_PROGRESS) {
                token.transfer(buyer, totalAmount);
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            } else {
                key.allow(buyer);
                vault.releaseFunds();
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            }
        }
    }

    // ========== INTERNAL UTILITIES ==========

    function _getRandomKey() internal returns (euint256) {
        return e.rand();
    }

    // ========== VIEW ==========

    function getContractInfo()
        external
        view
        returns (address _buyer, address _seller, uint256 _totalAmount, Status _status)
    {
        return (buyer, seller, totalAmount, contractStatus);
    }

    function getVault() external view returns (address) {
        return address(vault);
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function getGovernor() external view returns (address) {
        return i_governor;
    }

    function getConditionKey(string memory _title) external view returns (bytes32) {
        return keccak256(abi.encodePacked(_title));
    }

    function getCondition(bytes32 _conditionKey) external view returns (Condition memory condition) {
        return conditions[_conditionKey];
    }

    function getConditionStatus(bytes32 _conditionKey)
        external
        view
        returns (bool approvedByBuyer, bool approvedBySeller)
    {
        Condition memory condition = conditions[_conditionKey];
        return (condition.approvedByBuyer, condition.approvedBySeller);
    }
}

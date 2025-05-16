// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface TimeLock {
    function owner() external view returns (address);
    function resolveDispute(address escrowContract, address recipient, uint256 amount, bool isBuyerWinner) external;
}

interface GovernorContract {
    function proposeDispute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address escrowContract
    ) external returns (uint256);
}

contract ConfidentialEscrow {
    error ConfidentionEscrow__TitleOfConditionsCanNotBeSame();
    error ConfidentialEscrow__OnlyOneLockConditionAllowed();
    error ConfidentialEscrow__NoAdvancePaymentAfterLock();

    // ========== STORAGE ==========
    IERC20 private immutable token;
    address private immutable buyer;
    address private immutable seller;
    address private immutable i_governor;
    uint256 private totalAmount;
    address private immutable tokenAddress;
    uint256 private immutable i_deadLine;
    uint256 private immutable i_initialtionTime;
    bool private deposited;
    bool private refund;

    mapping(bytes32 => bool) private isCondition;
    mapping(bytes32 => Condition) private conditions;
    bytes32[] private conditionKeys;

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
    event DisputeRaised(address indexed buyer, address indexed seller, uint256 amount, address governorContract);

    enum RLockStatus {
        LOCKED,
        UNLOCKED
    }

    RLockStatus private rLockStatus = RLockStatus.UNLOCKED;

    // ========== MODIFIERS ==========
    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier rLock() {
        if (rLockStatus == RLockStatus.LOCKED) {
            revert NotAllowed();
        }
        rLockStatus = RLockStatus.LOCKED;
        _;
        rLockStatus = RLockStatus.UNLOCKED;
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

    modifier notCompleted() {
        if (contractStatus == Status.COMPLETE) revert InvalidStatus();
        _;
    }

    modifier notLocked() {
        if (contractStatus == Status.FUNDS_LOCKED) revert InvalidStatus();
        _;
    }

    // ========== CONSTRUCTOR ==========
    constructor(
        address _seller,
        address _buyer,
        uint256 _amount,
        address _tokenAddress,
        address _governor,
        Condition[] memory _conditions,
        uint256 _deadLine
    ) {
        buyer = _buyer;
        seller = _seller;
        totalAmount = _amount;
        tokenAddress = _tokenAddress;
        contractStatus = Status.IN_PROGRESS;
        i_governor = _governor; // address of the timeLock contract of the governor contract
        i_deadLine = _deadLine;

        bool lockCalled;
        for (uint256 i = 0; i < _conditions.length; i++) {
            bytes32 conditionHash = keccak256(abi.encodePacked(_conditions[i].title));
            if (isCondition[conditionHash]) revert ConfidentionEscrow__TitleOfConditionsCanNotBeSame();
            isCondition[conditionHash] = true;
            conditions[conditionHash] = _conditions[i];
            conditionKeys.push(conditionHash);
            if (lockCalled) {
                if (_conditions[i].advancePayment > 0) revert ConfidentialEscrow__NoAdvancePaymentAfterLock();
            }
            if (_conditions[i].lock) {
                if (lockCalled) revert ConfidentialEscrow__OnlyOneLockConditionAllowed();
                lockCalled = true;
            }
        }

        i_initialtionTime = block.timestamp;

        token = IERC20(_tokenAddress);
    }

    // ========== CORE FUNCTIONS ==========

    function deposit() external rLock onlyBuyer notCompleted {
        if (deposited) revert ApprovalFailed();

        token.transferFrom(msg.sender, address(this), totalAmount);
        if (token.balanceOf(address(this)) < totalAmount) revert InsufficientBalance();
        deposited = true;
        emit DepositCompleted(msg.sender, totalAmount);
    }

    function lock() private rLock notCompleted notLocked {
        contractStatus = Status.FUNDS_LOCKED;

        emit AmountLocked(msg.sender, totalAmount);
    }

    function approveCondition(bytes32 _conditionKey) external rLock notCompleted {
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
            }
            if (conditions[_conditionKey].lock) {
                lock();
            }
        }
    }

    function approveRefund() external rLock onlySeller notCompleted {
        refund = true;
    }

    function ariseDispute() external rLock notCompleted {
        if (msg.sender != buyer && msg.sender != seller) revert NotAllowed();

        if (block.timestamp > i_deadLine + i_initialtionTime) {
            if (contractStatus == Status.IN_PROGRESS) {
                token.transfer(buyer, totalAmount);
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            } else {
                // propose a vote to the governor contract
                _ariseDispute();
                contractStatus = Status.COMPLETE;
            }
        }
    }

    function _ariseDispute() private {
    TimeLock timeLock = TimeLock(i_governor);
    address governorAddress = timeLock.owner();
    GovernorContract governor = GovernorContract(governorAddress);

    // Create proposal description
    string memory description = string(
        abi.encodePacked(
            "Dispute for contract between ",
            addressToString(buyer),
            " and ",
            addressToString(seller),
            " for amount ",
            uintToString(totalAmount),
            ". Vote FOR to give funds to buyer. Vote AGAINST to give funds to seller."
        )
    );

    // Approve the timelock to transfer tokens from this contract
    token.approve(address(timeLock), totalAmount);

    // Prepare the calldata for resolving the dispute
    bytes memory proposalCalldata = abi.encodeWithSignature(
        "resolveDispute(address,address,uint256,bool)",
        address(this),
        buyer,
        totalAmount,
        true
    );

    // Create arrays for the proposal parameters
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    
    targets[0] = address(timeLock);
    values[0] = 0;
    calldatas[0] = proposalCalldata;
    
    // Use the proposeDispute function that registers the escrow -> proposal mapping
    uint256 proposalId = governor.proposeDispute(
        targets, 
        values, 
        calldatas, 
        description,
        address(this)  // Pass the escrow contract address
    );
    
    // Emit event about the dispute being raised
    emit DisputeRaised(buyer, seller, totalAmount, address(governor));
}

    function completeContract() external rLock notCompleted {
        if (msg.sender == seller) {
            for (uint256 i = 0; i < conditionKeys.length; i++) {
                if (!conditions[conditionKeys[i]].approvedByBuyer || !conditions[conditionKeys[i]].approvedBySeller) {
                    revert ApprovalFailed();
                }
            }

            token.transfer(seller, totalAmount);

            contractStatus = Status.COMPLETE;
            emit ContractCompleted();
        } else if (msg.sender == buyer) {
            if (refund) {
                token.transfer(buyer, totalAmount);
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            } else if(block.timestamp > i_deadLine + i_initialtionTime) {
                if(contractStatus == Status.FUNDS_LOCKED) revert NotAllowed();
                token.transfer(buyer, totalAmount);
                contractStatus = Status.COMPLETE;
                emit ContractCompleted();
            } else {
                revert ApprovalFailed();
            }
        } else {
            revert NotAllowed();
        }
    }

    // ========== INTERNAL UTILITIES ==========

    // function _getRandomKey() internal returns (euint256) {
    //     return e.rand();
    // }

    // ========== VIEW ==========

    function getContractInfo()
        external
        view
        returns (address _buyer, address _seller, uint256 _totalAmount, Status _status, bytes32[] memory _conditionKeys)
    {
        return (buyer, seller, totalAmount, contractStatus, conditionKeys);
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function getGovernor() external view returns (address) {
        return i_governor;
    }

    function getConditionKey(string memory _title) external pure returns (bytes32) {
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

    // Helper function to convert address to string
    function addressToString(address _addr) private pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    // Helper function to convert uint to string
    function uintToString(uint256 _i) private pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }

    /**
     * @notice Returns the seller address
     * @return The address of the seller
     */
    function getSellerAddress() external view returns (address) {
        return seller;
    }

    /**
     * @notice Returns the buyer address
     * @return The address of the buyer
     */
    function getBuyerAddress() external view returns (address) {
        return buyer;
    }
}

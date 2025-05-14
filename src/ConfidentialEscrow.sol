// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EncryptedVault} from "./EncryptedVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {euint256, ebool, e} from "@inco/lightning/src/Lib.sol";

contract ConfidentialEscrow {
    using e for *;

    // ========== STORAGE ==========
    IERC20 public immutable token;
    EncryptedVault public immutable vault;
    address public immutable buyer;
    address public immutable seller;
    uint256 public immutable totalAmount;
    address public immutable tokenAddress;
    euint256 private key;

    enum Status { IN_PROGRESS, COMPLETE }
    Status public contractStatus;

    // ========== CUSTOM ERRORS ==========
    error NotBuyer();
    error NotSeller();
    error InvalidStatus();
    error InsufficientBalance();
    error ApprovalFailed();
    error NotAllowed();

    // ========== EVENTS ==========
    event ContractCompleted();

    // ========== MODIFIERS ==========
    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller();
        _;
    }

    modifier inProgress() {
        if (contractStatus != Status.IN_PROGRESS) revert InvalidStatus();
        _;
    }

    // ========== CONSTRUCTOR ==========
    constructor(address _seller, address _buyer, uint256 _amount, address _tokenAddress) payable {
        buyer = _buyer;
        seller = _seller;
        totalAmount = _amount;
        tokenAddress = _tokenAddress;
        contractStatus = Status.IN_PROGRESS;

        EncryptedVault _vault = new EncryptedVault(_tokenAddress, _buyer, _seller);
        vault = _vault;
        token = IERC20(_tokenAddress);
    }

    // ========== CORE FUNCTIONS ==========

    function deposit() external onlyBuyer inProgress {
        if (token.balanceOf(msg.sender) < totalAmount) revert InsufficientBalance();

        euint256 generatedKey = _getRandomKey();
        key = generatedKey;

        if (!token.approve(address(vault), totalAmount)) revert ApprovalFailed();

        generatedKey.allow(address(vault));
        vault.deposit(totalAmount, generatedKey);
    }

    function approveKey() external onlyBuyer inProgress {
        key.allow(seller);
        if (!e.isAllowed(seller, key)) revert NotAllowed();
    }

    function releaseFunds() external onlySeller inProgress {
        vault.releaseFunds();
    }

    // ========== INTERNAL UTILITIES ==========

    function _getRandomKey() internal returns (euint256) {
        return e.rand();
    }

    // ========== VIEW ==========

    function getContractInfo() external view returns (
        address _buyer,
        address _seller,
        uint256 _totalAmount,
        Status _status
    ) {
        return (buyer, seller, totalAmount, contractStatus);
    }

    function getVault() external view returns (address) {
        return address(vault);
    }
}

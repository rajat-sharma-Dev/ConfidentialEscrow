// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {euint256, ebool, e} from "@inco/lightning/src/Lib.sol";

contract Vault {
    using e for *;

    // ========== STATE VARIABLES ==========

    address public immutable buyer;
    address public immutable seller;
    IERC20 public immutable token;

    mapping(address => uint256) public lockedFunds;
    euint256 private key;

    enum SafeStatus { LOCKED, OPEN }
    SafeStatus public status;

    // ========== CUSTOM ERRORS ==========

    error NotBuyer();
    error NotSeller();
    error ZeroAmount();
    error InvalidSeller();
    error NotAllowed();
    error TransferFailed();
    error NoFunds();
    error VaultLocked();

    // ========== MODIFIERS ==========

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NotBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller();
        _;
    }

    // ========== CONSTRUCTOR ==========

    constructor(address _tokenAddress, address _buyer, address _seller) {
        if (_seller == address(0)) revert InvalidSeller();
        buyer = _buyer;
        seller = _seller;
        token = IERC20(_tokenAddress);
    }

    // ========== MAIN FUNCTIONS ==========

    function deposit(uint256 amount, euint256 _key) external onlyBuyer {
        if (amount == 0) revert ZeroAmount();
        if (!e.isAllowed(address(this), _key)) revert NotAllowed();
        if (!token.transferFrom(buyer, address(this), amount)) revert TransferFailed();

        key = _key;
        lockedFunds[seller] += amount;
        status = SafeStatus.LOCKED;
    }

    function releaseFunds() external {
        if (lockedFunds[seller] == 0) revert NoFunds();
        if (!e.isAllowed(msg.sender, key)) revert NotAllowed();
        status = SafeStatus.OPEN;

        _release();
    }

    function _release() internal onlySeller {
        if (status != SafeStatus.OPEN) revert VaultLocked();

        uint256 amount = lockedFunds[seller];
        if (amount == 0) revert NoFunds();

        lockedFunds[seller] = 0; // Prevent re-entrancy
        if (!token.transfer(seller, amount)) revert TransferFailed();
    }

    // ========== VIEW ==========

    function getLockedFunds() external view returns (uint256) {
        return lockedFunds[seller];
    }
}

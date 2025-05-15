// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {euint256, ebool, e} from "@inco/lightning/src/Lib.sol";

contract EncryptedVault {
    using e for *;

    // ========== STATE VARIABLES ==========

    address private immutable buyer;
    address private immutable seller;
    IERC20 private immutable token;
    address private immutable i_governor;

    uint256 private lockedFunds;
    euint256 private key;

    enum SafeStatus { LOCKED, OPEN }
    SafeStatus private status;
    


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
    modifier onlyGovernor() {
        if (msg.sender != i_governor) revert NotSeller();
        _;
    }

    // ========== CONSTRUCTOR ==========

    constructor(address _tokenAddress, address _buyer, address _seller, address _governor) {
        if (_seller == address(0)) revert InvalidSeller();
        buyer = _buyer;
        seller = _seller;
        token = IERC20(_tokenAddress);
        i_governor = _governor;
    }

    // ========== MAIN FUNCTIONS ==========

    function deposit(uint256 amount, euint256 _key) external onlyBuyer {
        if (amount == 0) revert ZeroAmount();
        if (!e.isAllowed(address(this), _key)) revert NotAllowed();
        if (!token.transferFrom(buyer, address(this), amount)) revert TransferFailed();

        key = _key;
        lockedFunds += amount;
        status = SafeStatus.LOCKED;
    }

    function releaseFunds() external {
        if (lockedFunds == 0) revert NoFunds();
        if (!e.isAllowed(msg.sender, key)) revert NotAllowed();
        status = SafeStatus.OPEN;

        _release();
    }

    function _release() internal onlySeller {
        if (status != SafeStatus.OPEN) revert VaultLocked();

        uint256 amount = lockedFunds;
        if (amount == 0) revert NoFunds();

        lockedFunds = 0; // Prevent re-entrancy
        if (!token.transfer(seller, amount)) revert TransferFailed();
    }

    // ========== VIEW ==========

    function getLockedFunds() external view returns (uint256) {
        return lockedFunds;
    }

    function getBuyer() external view returns (address) {
        return buyer;
    }
    function getSeller() external view returns (address) {
        return seller;
    }
    function getToken() external view returns (address) {
        return address(token);
    }


}

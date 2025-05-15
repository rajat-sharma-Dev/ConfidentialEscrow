// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EncryptedVault} from "./EncryptedVault.sol";
import {ConfidentialEscrow} from "./ConfidentialEscrow.sol";
import {euint256, ebool, e} from "@inco/lightning/src/Lib.sol";

interface IVault {
    function deposit(uint256 amount, euint256 _key) external;
    function releaseFunds() external;
    function getLockedFunds() external view returns (uint256);
}

contract Factory {

    address private immutable tokenAddress;
    address private buyer;
    address private immutable i_governor;
    address private seller;
    uint256 private totalAmount;
    EncryptedVault private vault;
    ConfidentialEscrow private escrow;
    address[] private escrowAddresses;
    address[] private vaultAddresses;
    bool private Deposited;

    mapping(address => address) private vaults;

    constructor (address _tokenAddress, address _buyer, address _seller, uint256 _amount, address _governor){
        tokenAddress = _tokenAddress;
        buyer = _buyer;
        seller = _seller;
        totalAmount = _amount;
        i_governor = _governor;

    }

    function createContract() external {

        escrow = new ConfidentialEscrow(seller, buyer, totalAmount, tokenAddress, i_governor);
        vault = EncryptedVault(escrow.getVault());

    }

    function deposit() external {
        require(address(escrow) != address(0), "Escrow not created");
        require(address(vault) != address(0), "Vault not created");
        escrow.deposit();
        Deposited = true;



    }

    function approve() external {
        require(address(escrow) != address(0), "Escrow not created");
        require(address(vault) != address(0), "Vault not created");
        Deposited = true;
        escrow.approveKey();
    }

    function release() external {
        require(address(escrow) != address(0), "Escrow not created");
        require(address(vault) != address(0), "Vault not created");
        require(Deposited == true, "Funds not deposited");
        escrow.releaseFunds();
    } 

    

}
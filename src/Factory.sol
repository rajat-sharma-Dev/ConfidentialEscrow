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

    address public immutable tokenAddress;
    address public buyer;
    address public seller;
    uint256 public totalAmount;
    EncryptedVault public vault;
    ConfidentialEscrow public escrow;
    address[] public escrowAddresses;
    address[] public vaultAddresses;
    bool public Deposited;

    mapping(address => address) public vaults;

    constructor (address _tokenAddress, address _buyer, address _seller, uint256 amount){
        tokenAddress = _tokenAddress;
        buyer = _buyer;
        seller = _seller;
        totalAmount = amount;


    }

    function createContract() external {

        escrow = new ConfidentialEscrow(seller, buyer, totalAmount, tokenAddress);
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
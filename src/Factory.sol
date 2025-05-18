// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ConfidentialEscrow} from "./ConfidentialEscrow.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Factory is Ownable {
    error NotBuyer();

    ConfidentialEscrow private escrow;
    address[] private escrowAddresses;
    mapping(address buyers => address[] escrowAddresses) private escrowAddressesOfBuyer;
    mapping(address sellers => address[] escrowAddresses) private escrowAddressesOfSeller;

    mapping(address => address) private vaults;

    constructor(address _owner) Ownable(_owner) {}

    function createContract(
        address _seller,
        address _buyer,
        uint256 _amount,
        address _tokenAddress,
        address _governor,
        ConfidentialEscrow.Condition[] memory _conditions,
        uint256 _deadline
    ) external {
        if (msg.sender != _buyer) revert NotBuyer();
        escrow = new ConfidentialEscrow(_seller, _buyer, _amount, _tokenAddress, _governor, _conditions, _deadline);
        escrowAddresses.push(address(escrow));
        escrowAddressesOfBuyer[_buyer].push(address(escrow));
        escrowAddressesOfSeller[_seller].push(address(escrow));
    }

    function getEscrowAddresses() external view returns (address[] memory) {
        return escrowAddresses;
    }

    function getEscrowAddressOfBuyer(address _buyer) external view returns (address[] memory) {
        return escrowAddressesOfBuyer[_buyer];
    }

    function getEscrowAddressesOfSeller(address _seller) external view returns (address[] memory) {
        return escrowAddressesOfSeller[_seller];
    }
}

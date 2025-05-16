// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ConfidentialEscrow {
    function getSellerAddress() external view returns (address);
    function getBuyerAddress() external view returns (address);
    function getToken() external view returns (address);
    function getContractInfo()
        external
        view
        returns (address buyer, address seller, uint256 amount, address tokenAddress);
}

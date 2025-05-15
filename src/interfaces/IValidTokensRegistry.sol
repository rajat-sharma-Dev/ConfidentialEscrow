// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IValidTokensRegistry
 * @author Yug Agarwal
 * @dev Interface for registry of valid tokens that can be staked in the StakingPool
 */
interface IValidTokensRegistry {
    /**
     * @dev Error thrown when a zero address is provided
     */
    error ValidTokensRegistry__ZeroAddress();

    /**
     * @dev Adds a token to the valid tokens registry
     * @param token The address of the token
     * @param priceFeed The address of the price feed for the token
     * @param decimals The number of decimals for the price feed
     */
    function addValidToken(address token, address priceFeed, uint8 decimals) external;

    /**
     * @dev Removes a token from the valid tokens registry
     * @param token The address of the token to remove
     */
    function removeValidToken(address token) external;

    /**
     * @dev Checks if a token is valid
     * @param token The address of the token to check
     * @return True if the token is valid, false otherwise
     */
    function isValidToken(address token) external view returns (bool);

    /**
     * @dev Gets the price feed address and decimals for a token
     * @param token The address of the token
     * @return priceFeedAddress The address of the price feed
     * @return decimals The number of decimals for the price feed
     */
    function getPriceFeedAddress(address token) external view returns (address priceFeedAddress, uint8 decimals);

    /**
     * @dev Gets the list of valid tokens
     * @return An array of valid token addresses
     */
    function getValidTokensList() external view returns (address[] memory);
}

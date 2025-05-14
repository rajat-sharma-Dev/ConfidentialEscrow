// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VerdictorToken} from "./VerdictorToken.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IValidTokensRegistry} from "../../interfaces/IValidTokensRegistry.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from
    "../../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title StakingPool
 * @author Yug Agarwal
 * @dev Users can stake their USDC tokens in this contract to receive Verdictor tokens.
 *
 *                          .            .                                   .#
 *                        +#####+---+###+#############+-                  -+###.
 *                        +###+++####+##-+++++##+++##++####+-.         -+###+++
 *                        +#########.-#+--+####++###- -########+---+++#####+++
 *                        +#######+#+++--+####+-..-+-.###+++########+-++###++.
 *                       +######.     +#-#####+-.-------+############+++####-
 *                      +####++...     ########-++-        +##########++++++.
 *                     -#######-+.    .########+++          -++######+++-
 *                     #++########--+-+####++++-- . ..    .-#++--+##+####.
 *                    -+++++++++#####---###---.----###+-+########..-+#++##-
 *                    ++###+++++#####-..---.. .+##++++#++#++-+--.   .-++++#
 *                   .###+.  .+#+-+###+ ..    +##+##+#++----...---.  .-+--+.
 *                   ###+---------+####+   -####+-.......    ...--++.  .---.
 *                  -#++++-----#######+-  .-+###+.... .....      .-+##-.  .
 *                  ##+++###++######++-.   .--+---++---........  ...---.  .
 *                 -####+-+#++###++-.        .--.--...-----.......--..... .
 *                 +######+++###+--..---.....  ...---------------.. .. .  .
 *                .-#########+#+++--++--------......----++--.--.  .--+---.
 *                 -+++########++--++++----------------------.--+++--+++--
 *            .######-.-++++###+----------------------..---++--++-+++---..
 *            -##########-------+-----------------------+-++-++----..----+----+#####++--..
 *            -#############+..  ..--..----------.....-+++++++++++++++++##################+.
 *            --+++++#########+-   . ....  ....... -+++++++++++++++++++############-.----+##-
 *            -----....-+#######+-             .. -+++++++++++++++++++++##+######+.       +++.
 *            --------.....---+#####+--......----.+++++++++++++++++++++##+-+++##+.        -++-
 *            -------...   .--++++++---.....-----.+++++++++++++++++++++++. -+++##-        .---
 *            #################+--.....-------.  .+++++++++++++++++++++-       -+-.       .---
 *            +#########++++-.. .......-+--..--++-++++++++++++++++++++-         .-... ....----
 *            -#####++---..   .--       -+++-.  ..+++++++++++++++++++--        .-+-......-+---
 *            +####+---...    -+#-   .  --++++-. .+++++++++++++++++++---        --        -+--
 *            ++++++++++--....-++.--++--.--+++++-.+++++++++++++++++++---. .......         ----
 *           .--++#########++-.--.+++++--++++###+-++++++++++++++++++++----   .-++-        ----
 *            .-+#############+-.++#+-+-++#######-++++++++++++++++++++----   -++++-      ..---
 *           .---+############+.+###++--++#####++-+++++++++++++++++++++-------++++-........-+-
 *            --+-+##########-+######+++++-++++++-++++++++++++++++++++++-----.----.......---+-
 *           .--+---#######..+#######+++++++--+++-+++++++++++++++++++++++-----------------+++-
 *           .++--..-+##-.-########+++++---++ .+-.+++++++++++++++++++++++++++++++++++---+++++-
 *           -+++. ..-..-+#########++-++--..--....+++++++++++++++++++++++++++++++++++++++++++-
 *           -++-......-+++############++++----- .+++++++++++++++++++++++++++++++++++++++++++-
 *           +##-.....---+#######+####+####+--++-.+++++++++++++++++++++++++++++++++++++++++++-
 *          .#+++-...-++######++-+-----..----++##-+++++++++++++++++++++++++++++++++++++++++++-
 *          .+++--------+##----+------+-..----+++-+++++++++++++++++++++++++++++++++++++++++++-
 *           ----.-----+++-+-...------++-----...--+++++++++++++++++++++++++++++++++++++++++++-
 *          .-..-.--.----..--.... ....++--.  ....-+++++++++++++++++++++++++++++++++++++++++++-
 *           -----------.---..--..   ..+.  . ... .+++++++++++++++++++++++++++++++++++++++++++-
 *         .+#+#+---####+-.    .....--...   .    .+++++++++++++++++++++++++++++++++++++++++++-
 *         -+++++#++++++++.    ..-...--.. ..     .+++++++++++++++++++++++++++++++++++++++++++-
 *         ++++++-------++--   . ....--.. . . .. .+++++++++++++++++++++++++-+----------...
 *         -++++--++++.------......-- ...  ..  . .---------------...
 *         -++-+####+++---..-.........
 *           .....
 */
contract StakingPool is Ownable {
    error StakingPool__InvalidAmount();
    error StakingPool__InvalidToken();
    error StakingPool__InvalidAddress();

    event Staked(address indexed user, address indexed token, uint256 amount, uint256 verdictorAmount);
    event Unstaked(address indexed user, address indexed token, uint256 amount, uint256 verdictorAmount);
    event Sliced(address indexed recipient, address indexed token, uint256 amount);

    VerdictorToken private immutable i_verdictorToken;
    IValidTokensRegistry private immutable i_validTokensRegistry;
    mapping(address => uint256) private tokenBalances;
    uint256 private usdCounter;
    uint256 private lastRebaseTimestamp;

    /**
     * 
     * @param token address of the token that needs its validitity checked
     */
    modifier ValidToken(address token) {
        if (!i_validTokensRegistry.isValidToken(token)) {
            revert StakingPool__InvalidToken();
        }
        _;
    }

    /**
     * 
     * @param validTokensRegistry address of the ValidTokensRegistry contract
     * @dev The constructor initializes the StakingPool contract with the address of the ValidTokensRegistry contract.
     */
    constructor(address validTokensRegistry) Ownable(msg.sender) {
        if (validTokensRegistry == address(0)) {
            revert StakingPool__InvalidAddress();
        }
        i_verdictorToken = new VerdictorToken();
        i_validTokensRegistry = IValidTokensRegistry(validTokensRegistry);
    }

    /**
     * @notice Calculates the total USD value of all tokens in the contract.
     * @return totalValue The total USD value of all tokens in the contract.
     * @dev This function iterates through all valid tokens and calculates their USD value using Chainlink price feeds.
     */
    function calculateTotalUsdValue() public view returns (uint256) {
        uint256 totalValue = 0;
        // You'll need to iterate through all valid tokens and calculate their USD value
        address[] memory validTokens = i_validTokensRegistry.getValidTokensList();

        for (uint256 i = 0; i < validTokens.length; i++) {
            address token = validTokens[i];
            uint256 tokenAmount = tokenBalances[token];
            if (tokenAmount > 0) {
                (address priceFeedAddress, uint8 decimals) = i_validTokensRegistry.getPriceFeedAddress(token);

                if (priceFeedAddress == address(1)) {
                    // USDC is treated as $1
                    totalValue += tokenAmount * 10 ** 12; // Convert to 18 decimals
                } else {
                    // Use Chainlink price feed
                    AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
                    (, int256 price,,,) = priceFeed.latestRoundData();

                    totalValue += (
                        tokenAmount * 10 ** (18 - IERC20(token).decimals()) * (uint256(price) * 10 ** (18 - decimals))
                    ) / 1e18;
                }
            }
        }

        return totalValue;
    }

    /**
     * @notice Stakes a given amount of tokens in the pool.
     * @param amount Amount of tokens to stake
     * @param token Address of the token to stake
     * @dev This function transfers the specified amount of tokens from the user to the contract and mints Verdictor tokens.
     */
    function stake(uint256 amount, address token) external ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;

        (address priceFeedAddress, uint8 decimals) = i_validTokensRegistry.getPriceFeedAddress(token);
        uint256 verdictorAmount;

        if (priceFeedAddress == address(1)) {
            // token is USDC
            verdictorAmount = getUsdToVerdictorTokens(amount * 10e12); // Convert to 18 decimals
        } else {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
            (, int256 price,,,) = priceFeed.latestRoundData();
            verdictorAmount = getUsdToVerdictorTokens(
                ((amount * 10 ** (18 - IERC20(token).decimals()) * (uint256(price) * 10 ** (18 - decimals))) / 1e18)
            );
        }

        i_verdictorToken.mint(msg.sender, verdictorAmount);

        emit Staked(msg.sender, token, amount, verdictorAmount);
    }

    /**
     * @notice Unstakes a given amount of tokens from the pool.
     * @param amount Amount of tokens to unstake
     * @param token Address of the token to unstake
     * @dev This function burns the specified amount of Verdictor tokens and transfers the corresponding amount of tokens to the user.
     */
    function unstake(uint256 amount, address token) external ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }

        // Check if there's enough of the token to unstake
        if (tokenBalances[token] < amount) {
            revert StakingPool__InvalidAmount();
        }

        // Calculate how many Verdictor tokens need to be burned based on USD value
        (address priceFeedAddress, uint8 decimals) = i_validTokensRegistry.getPriceFeedAddress(token);
        uint256 verdictorAmount;

        if (priceFeedAddress == address(1)) {
            // token is USDC
            verdictorAmount = getUsdToVerdictorTokens(amount * 10 ** 12); // Convert to 18 decimals
        } else {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
            (, int256 price,,,) = priceFeed.latestRoundData();
            verdictorAmount = getUsdToVerdictorTokens(
                (amount * 10 ** (18 - IERC20(token).decimals()) * (uint256(price) * 10 ** (18 - decimals))) / 1e18
            );
        }

        // Transfer Verdictor tokens from user to this contract and burn them
        i_verdictorToken.transferFrom(msg.sender, address(this), verdictorAmount);
        i_verdictorToken.burn(verdictorAmount);

        // Update token balances
        tokenBalances[token] -= amount;

        // Transfer requested tokens to user
        IERC20(token).transfer(msg.sender, amount);

        emit Unstaked(msg.sender, token, amount, verdictorAmount);
    }

    /**
     * @notice Slices a given amount of tokens from the pool.
     * @param amount Amount of tokens to slice
     * @param token Token to be sliced
     * @param recipient Address of the recipient
     * @dev This function transfers the specified amount of tokens from the pool to the recipient.
     */
    function slice(uint256 amount, address token, address recipient) external onlyOwner ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        if (recipient == address(0)) {
            revert StakingPool__InvalidAddress();
        }

        // Transfer tokens from recipient to this contract
        IERC20(token).transferFrom(address(this), recipient, amount);

        // Update token balances
        tokenBalances[token] += amount;

        emit Sliced(recipient, token, amount);
    }

    /**
     * 
     * @param amount Amount of usd to conver to verdictor tokens in 18 decimals
     * @return Amount of verdictor tokens in 18 decimals
     * @dev This function will convert the given amount of USD to Verdictor tokens based on the current USD to Verdictor token exchange rate.
     * @dev The exchange rate is determined by the total USD value of all tokens in the contract and the total supply of Verdictor tokens.
     */
    function getUsdToVerdictorTokens(uint256 amount) public view returns (uint256) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }

        uint256 totalUsdValue = calculateTotalUsdValue();
        uint256 totalVerdictorTokens = i_verdictorToken.totalSupply();

        if (totalVerdictorTokens == 0) {
            return amount; // If no Verdictor tokens exist, return the amount as is
        }

        // Calculate the amount of Verdictor tokens equivalent to the given USD amount
        return (amount * totalVerdictorTokens) / totalUsdValue;
    }
}

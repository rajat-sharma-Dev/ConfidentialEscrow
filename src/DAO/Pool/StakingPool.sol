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
    uint256 private toalUsdValueInPool;
    uint256 private lastRebaseTimestamp;
    uint256 private constant REBASE_INTERVAL = 6 hours;

    modifier ValidToken(address token) {
        if (!i_validTokensRegistry.isValidToken(token)) {
            revert StakingPool__InvalidToken();
        }
        _;
    }

    constructor(address validTokensRegistry) Ownable(msg.sender) {
        if (validTokensRegistry == address(0)) {
            revert StakingPool__InvalidAddress();
        }
        i_verdictorToken = new VerdictorToken();
        i_validTokensRegistry = IValidTokensRegistry(validTokensRegistry);
    }

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
     * @notice Trigger a rebase if the rebase interval has passed
     * @dev Updates the token supply to match the USD value in the pool
     */
    function checkAndRebase() public {
        if (block.timestamp >= lastRebaseTimestamp + REBASE_INTERVAL) {
            // Calculate the target supply based on total USD value
            uint256 totalUsdValue = calculateTotalUsdValue();

            // Set target supply equal to USD value (1 VDT = $1)
            i_verdictorToken.rebase(totalUsdValue);

            lastRebaseTimestamp = block.timestamp;
        }
    }

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
            verdictorAmount = amount * 10e12; // Convert to 18 decimals
        } else {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
            (, int256 price,,,) = priceFeed.latestRoundData();
            verdictorAmount =
                ((amount * 10 ** (18 - IERC20(token).decimals()) * (uint256(price) * 10 ** (18 - decimals))) / 1e18);
        }

        i_verdictorToken.mint(msg.sender, verdictorAmount);
        checkAndRebase();

        emit Staked(msg.sender, token, amount, verdictorAmount);
    }

    function unstake(uint256 amount, address token) external ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }

        // Check if there's enough of the token to unstake
        if (tokenBalances[token] < amount) {
            revert StakingPool__InvalidAmount();
        }
        
        // Check if rebase is needed BEFORE unstaking
        checkAndRebase();

        // Calculate how many Verdictor tokens need to be burned based on USD value
        (address priceFeedAddress, uint8 decimals) = i_validTokensRegistry.getPriceFeedAddress(token);
        uint256 verdictorAmount;

        if (priceFeedAddress == address(1)) {
            // token is USDC
            verdictorAmount = amount * 10 ** 12; // Convert to 18 decimals
        } else {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
            (, int256 price,,,) = priceFeed.latestRoundData();
            verdictorAmount =
                (amount * 10 ** (18 - IERC20(token).decimals()) * (uint256(price) * 10 ** (18 - decimals))) / 1e18;
        }

        // Transfer Verdictor tokens from user to this contract and burn them
        i_verdictorToken.transferFrom(msg.sender, address(this), verdictorAmount);
        i_verdictorToken.burn(verdictorAmount);

        // Update token balances
        tokenBalances[token] -= amount;

        // Transfer requested tokens to user
        IERC20(token).transfer(msg.sender, amount);

        // Check if rebase is needed
        checkAndRebase();

        emit Unstaked(msg.sender, token, amount, verdictorAmount);
    }

    function slice(uint256 amount, address token, address recipient) external onlyOwner ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        if (recipient == address(0)) {
            revert StakingPool__InvalidAddress();
        }

        // Transfer tokens from recipient to this contract
        IERC20(token).transferFrom(recipient, address(this), amount);

        // Update token balances
        tokenBalances[token] += amount;

        // Check if rebase is needed
        checkAndRebase();

        emit Sliced(recipient, token, amount);
    }
}

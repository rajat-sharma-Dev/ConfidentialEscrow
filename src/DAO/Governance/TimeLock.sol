// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TimelockController} from "../../../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {StakingPool} from "../Pool/StakingPool.sol";
import {ValidTokensRegistry} from "../Pool/ValidTokensRegistry.sol";
import {Factory} from "../../Factory.sol";
import {Rewards} from "../Pool/Rewards.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {GovernorContract} from "./GovernorContract.sol";
import {IGovernor} from "../../../lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";
import {ConfidentialEscrow} from "../../ConfidentialEscrow.sol";

// Interface for the Rewards contract
interface IRewards {
    function addRewards(IERC20 token, uint256 amount, address[] memory recipients) external;
}

/**
 * @title TimeLock
 * @author Yug Agarwal
 * @dev Timelock contract for the DAO. This is the main contract that owns the Pool and Escrow Contracts
 * @notice This contract is used to delay the execution of proposals
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
contract TimeLock is TimelockController {
    error TimeLock__AlreadySet();

    address private immutable i_stakingPool;
    address private immutable i_validTokensRegistry;
    address private immutable i_factory;
    address private immutable i_rewards;
    address private s_governorAddress; // Storage for governor address

    event DisputeResolved(
        address indexed escrowContract, address indexed recipient, uint256 amount, bool isBuyerWinner
    );

    event FailedDisputeExecutedImmediately(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event DisputeProposalRegistered(address indexed escrowContract, uint256 indexed proposalId);

    /**
     * @notice Returns the address of the governor contract
     * @return The address of the governor contract
     */
    function owner() external view returns (address) {
        return s_governorAddress;
    }

    /**
     * @notice Sets the governor address
     * @param governorAddress The address of the governor contract
     */
    function setGovernor(address governorAddress) external {
        // Only admin can set the governor
        if (s_governorAddress != address(0)) {
            revert TimeLock__AlreadySet();
        }
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "TimeLock: caller is not admin");
        s_governorAddress = governorAddress;
    }

    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address verdictorToken)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {
        i_validTokensRegistry = address(new ValidTokensRegistry(address(this)));
        i_stakingPool = address(new StakingPool(i_validTokensRegistry, verdictorToken, address(this)));
        i_factory = address(new Factory(address(this)));
        i_rewards = address(new Rewards(address(this)));
    }

    /**
     * @notice Registers a dispute proposal for an escrow contract
     * @param escrowContract The address of the escrow contract in dispute
     * @param proposalId The ID of the created proposal
     */
    function registerDisputeProposal(address escrowContract, uint256 proposalId) external {
        // Only the governor can register dispute proposals
        require(msg.sender == s_governorAddress, "TimeLock: caller is not governor");

        // Optionally emit an event for tracking
        emit DisputeProposalRegistered(escrowContract, proposalId);
    }

    function getStakingPool() external view returns (address) {
        return i_stakingPool;
    }

    function getValidTokensRegistry() external view returns (address) {
        return i_validTokensRegistry;
    }

    function getFactory() external view returns (address) {
        return i_factory;
    }

    /**
     * @notice Resolves a dispute between buyer and seller in an escrow contract
     * @param escrowContract The address of the escrow contract
     * @param recipient The address that should receive the funds (buyer or seller)
     * @param amount The amount to distribute
     * @param isBuyerWinner True if buyer wins, false if seller wins
     */
    function resolveDispute(address escrowContract, address recipient, uint256 amount, bool isBuyerWinner) external {
        // Only this contract (through governance) can call this function
        require(msg.sender == address(this), "TimeLock: caller must be timelock");

        // Get the latest proposal ID
        uint256 proposalId = ConfidentialEscrow(escrowContract).getProposalId();

        // Execute the resolution
        _executeDisputeResolution(escrowContract, recipient, amount, isBuyerWinner, proposalId);
    }

    /**
     * @notice Resolves a dispute immediately for failed proposals
     * @param proposalId The ID of the failed proposal
     * @param escrowContract The address of the escrow contract involved in the dispute
     */
    function executeFailedDisputeImmediately(uint256 proposalId, address escrowContract) external {
        // Get the governor contract
        GovernorContract governor = GovernorContract(payable(s_governorAddress));

        // Verify proposal is defeated
        require(governor.state(proposalId) == IGovernor.ProposalState.Defeated, "TimeLock: proposal not defeated");

        // Verify this escrow contract has the given proposal ID
        require(
            ConfidentialEscrow(escrowContract).getProposalId() == proposalId, "TimeLock: invalid escrow for proposal"
        );

        // Get the contract parties
        address buyer;
        address seller;
        (buyer, seller,,,) = ConfidentialEscrow(escrowContract).getContractInfo();

        // Get the amount in escrow
        (,, uint256 amount,,) = ConfidentialEscrow(escrowContract).getContractInfo();

        // Execute the resolution directly with seller as winner
        _executeDisputeResolution(
            escrowContract,
            seller, // seller is recipient for failed proposals
            amount,
            false, // seller wins means isBuyerWinner is false
            proposalId
        );

        emit FailedDisputeExecutedImmediately(proposalId, seller, amount);
    }

    /**
     * @dev Internal function to execute dispute resolution
     */
    function _executeDisputeResolution(
        address escrowContract,
        address recipient,
        uint256 amount,
        bool isBuyerWinner,
        uint256 proposalId
    ) internal {
        // Get token from escrow contract
        IERC20 token = IERC20(ConfidentialEscrow(escrowContract).getToken());

        // Calculate reward portions
        uint256 voterReward = (amount * 20) / 100; // 20% for voters
        uint256 recipientAmount = amount - voterReward; // 80% for winner

        // Get winning voters based on outcome
        address[] memory winningVoters;
        GovernorContract governor = GovernorContract(payable(s_governorAddress));

        if (isBuyerWinner) {
            winningVoters = governor.getForVoters(proposalId);
        } else {
            winningVoters = governor.getAgainstVoters(proposalId);
        }

        // Transfer main amount to winner
        token.transferFrom(escrowContract, recipient, recipientAmount);

        // Handle voter rewards
        if (winningVoters.length > 0) {
            token.transferFrom(escrowContract, address(this), voterReward);
            token.approve(address(i_rewards), voterReward);
            IRewards(i_rewards).addRewards(token, voterReward, winningVoters);
        } else {
            // If no winning voters, give everything to the winner
            token.transferFrom(escrowContract, recipient, voterReward);
        }

        // Emit event
        emit DisputeResolved(escrowContract, recipient, amount, isBuyerWinner);
    }
}

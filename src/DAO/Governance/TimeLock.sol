// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TimelockController} from "../../../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {StakingPool} from "../Pool/StakingPool.sol";
import {ValidTokensRegistry} from "../Pool/ValidTokensRegistry.sol";
import {Factory} from "../../Factory.sol";
import {Rewards} from "../Pool/Rewards.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {GovernorContract} from "./GovernorContract.sol";

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
    address private immutable i_stakingPool;
    address private immutable i_validTokensRegistry;
    address private immutable i_factory;
    address private immutable i_rewards;

    event DisputeResolved(
        address indexed escrowContract, address indexed recipient, uint256 amount, bool isBuyerWinner
    );

    event FailedDisputeExecutedImmediately(
        uint256 indexed proposalId,
        address indexed recipient,
        uint256 amount
    );

    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address verdictorToken)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {
        i_validTokensRegistry = address(new ValidTokensRegistry(address(this)));
        i_stakingPool = address(new StakingPool(i_validTokensRegistry, verdictorToken, address(this)));
        i_factory = address(new Factory(address(this)));
        i_rewards = address(new Rewards(address(this)));
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
        uint256 proposalId = getLatestProposalId();
        
        // Execute the resolution
        _executeDisputeResolution(escrowContract, recipient, amount, isBuyerWinner, proposalId);
    }

    /**
     * @notice Resolves a dispute immediately for failed proposals
     * @param proposalId The ID of the failed proposal
     */
    function executeFailedDisputeImmediately(uint256 proposalId) external {
        // Get the governor contract
        GovernorContract governor = GovernorContract(owner());
        
        // Verify proposal is defeated
        require(governor.state(proposalId) == IGovernor.ProposalState.Defeated, 
            "TimeLock: proposal not defeated");
        
        // Get proposal details
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) = 
            governor.getProposalDetails(proposalId);
        
        // Verify this is a dispute resolution
        bytes4 selector = bytes4(calldatas[0][0:4]);
        require(selector == this.resolveDispute.selector, "TimeLock: not a dispute resolution");
        
        // Extract dispute parameters
        (address escrowContract, address recipient, uint256 amount, bool isBuyerWinner) = 
            abi.decode(calldatas[0][4:], (address, address, uint256, bool));
        
        // If the proposal failed, the seller wins (flip the winner flag)
        address seller;
        address buyer;
        (buyer, seller, , ) = ConfidentialEscrow(escrowContract).getContractInfo();
        
        // Execute the resolution directly with seller as winner
        _executeDisputeResolution(
            escrowContract,
            seller,  // seller is recipient for failed proposals
            amount,
            false,   // seller wins means isBuyerWinner is false
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
        uint256 voterReward = (amount * 20) / 100;  // 20% for voters
        uint256 recipientAmount = amount - voterReward;  // 80% for winner
        
        // Get winning voters based on outcome
        address[] memory winningVoters;
        GovernorContract governor = GovernorContract(owner());
        
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
            i_rewards.addRewards(token, voterReward, winningVoters);
        } else {
            // If no winning voters, give everything to the winner
            token.transferFrom(escrowContract, recipient, voterReward);
        }
        
        // Emit event
        emit DisputeResolved(escrowContract, recipient, amount, isBuyerWinner);
    }

    function getLatestProposalId() internal view returns (uint256) {
        GovernorContract governor = GovernorContract(owner());
        // This assumes you have a way to get the latest proposal ID
        // You might need to add a counter to your governor contract
        return governor.getLatestProposalId();
    }
}

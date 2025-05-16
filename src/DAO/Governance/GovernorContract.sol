// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Governor} from "../../../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from
    "../../../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from
    "../../../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl} from
    "../../../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "../../../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from
    "../../../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "../../../lib/openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "../../../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {TimeLock} from "./TimeLock.sol";
import {GovernorVoteTracker} from "./GovernorVoteTracker.sol";
import {ConfidentialEscrow} from "../../ConfidentialEscrow.sol";
import {IERC20} from "../../interfaces/IERC20.sol";

/**
 * @title GovernorContract
 * @author Yug Agarwal
 * @dev This contract implements a governance system for the DAO.
 * It allows token holders to propose and vote on changes to the protocol.
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
contract GovernorContract is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    GovernorVoteTracker
{
    constructor(IVotes _token, TimeLock _timelock, uint32 _votinDelay, uint32 _votingPeriod, uint256 _quorumPercentage)
        Governor("GovernorContract")
        GovernorSettings(_votinDelay, _votingPeriod, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {} // voter delay- 3 days(129600), voting period- 3 days, proposal threshold - 1 VDT

    // The following functions are overrides required by Solidity.

    /**
     * @notice Creates a dispute proposal and registers it with the timelock
     * @param targets The contract addresses to call
     * @param values The ETH values to send
     * @param calldatas The calldata to send
     * @param description The proposal description
     * @param escrowContract The address of the escrow contract in dispute
     * @return The ID of the created proposal
     */
    function proposeDispute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address escrowContract
    ) public virtual returns (uint256) {
        // Create the proposal
        uint256 proposalId = propose(targets, values, calldatas, description);

        // Register the dispute in the timelock
        TimeLock timeLock = TimeLock(payable(timelock()));
        timeLock.registerDisputeProposal(escrowContract, proposalId);

        return proposalId;
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    /**
     * @notice Override to resolve conflict between base contracts
     */
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        override(Governor, GovernorVoteTracker)
        returns (uint256)
    {
        // Call both parent implementations
        Governor._castVote(proposalId, account, support, reason, params);
        return GovernorVoteTracker._castVote(proposalId, account, support, reason, params);
    }

    /**
     * @notice Executes the seller win case when a dispute proposal fails
     * @param proposalId The ID of the failed proposal
     * @dev This function can be called by anyone once a proposal is defeated
     */
    function executeFailedDisputeProposal(uint256 proposalId) external {
        // Check proposal is in defeated state
        require(state(proposalId) == ProposalState.Defeated, "Governor: proposal not defeated");

        // Get proposal details
        ProposalDetails memory details = _proposalDetails[proposalId];

        // Get the timelock controller
        TimeLock timeLock = TimeLock(payable(timelock()));

        // Extract the escrow contract address from the calldata
        // The calldata format is: "resolveDispute(address,address,uint256,bool)"
        // We need to extract the first parameter which is the escrow address
        address escrowContract;
        if (details.targets.length > 0 && details.calldatas.length > 0) {
            // Skip function selector (4 bytes) and extract the escrow address (32 bytes)
            bytes memory callData = details.calldatas[0];
            require(callData.length >= 36, "Governor: invalid calldata");

            // Extract the escrow contract address from calldata
            assembly {
                escrowContract := mload(add(add(callData, 0x20), 4))
            }
        }

        require(escrowContract != address(0), "Governor: no escrow contract found");

        // Execute the failed dispute resolution through timelock
        timeLock.executeFailedDisputeImmediately(proposalId, escrowContract);

        emit DisputeResolutionScheduled(
            proposalId,
            ConfidentialEscrow(escrowContract).getSellerAddress(), // Seller is the recipient
            ConfidentialEscrow(escrowContract).getToken() == address(0)
                ? address(escrowContract).balance
                : IERC20(ConfidentialEscrow(escrowContract).getToken()).balanceOf(escrowContract),
            keccak256(abi.encodePacked("failed_dispute", proposalId))
        );
    }

    event DisputeResolutionScheduled(
        uint256 indexed proposalId, address indexed recipient, uint256 amount, bytes32 indexed operationId
    );

    // Store proposal details separately
    struct ProposalDetails {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    // Mapping to store proposal details
    mapping(uint256 => ProposalDetails) private _proposalDetails;

    /**
     * @notice Override propose to store details
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        uint256 proposalId = super.propose(targets, values, calldatas, description);

        // Store the proposal details for later retrieval
        _storeProposalDetails(proposalId, targets, values, calldatas, description);

        return proposalId;
    }

    /**
     * @dev Store proposal details
     */
    function _storeProposalDetails(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal {
        // Create copies of array parameters
        address[] memory targetsCopy = new address[](targets.length);
        uint256[] memory valuesCopy = new uint256[](values.length);
        bytes[] memory calldatasCopy = new bytes[](calldatas.length);

        for (uint256 i = 0; i < targets.length; i++) {
            targetsCopy[i] = targets[i];
            valuesCopy[i] = values[i];
            calldatasCopy[i] = calldatas[i];
        }

        // Store the details
        _proposalDetails[proposalId] = ProposalDetails({
            targets: targetsCopy,
            values: valuesCopy,
            calldatas: calldatasCopy,
            description: description
        });
    }
}

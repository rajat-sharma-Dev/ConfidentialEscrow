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
     * @notice Executes the seller win case when a dispute proposal fails
     * @param proposalId The ID of the failed proposal
     * @dev This function can be called by anyone once a proposal is defeated
     */
    function executeFailedDisputeProposal(uint256 proposalId) external {
        // Check proposal is in defeated state
        require(state(proposalId) == ProposalState.Defeated, "Governor: proposal not defeated");
        
        // Get the proposal targets, values and calldata
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = getProposalDetails(proposalId);
        
        // Verify this is a dispute proposal by checking function signature
        bytes4 selector = bytes4(calldatas[0][0:4]);
        require(selector == bytes4(keccak256("resolveDispute(address,address,uint256,bool)")), 
            "Governor: not a dispute proposal");
        
        // Decode the original calldata to get parameters
        (address escrowContract, address buyer, uint256 amount, bool _) = 
            abi.decode(calldatas[0][4:], (address, address, uint256, bool));
        
        // Get seller address from escrow
        address seller;
        try ConfidentialEscrow(escrowContract).getSellerAddress() returns (address _seller) {
            seller = _seller;
        } catch {
            // Alternative way if the function doesn't exist
            (, seller, , ) = ConfidentialEscrow(escrowContract).getContractInfo();
        }
        
        // Create calldata for seller win case (flip the winner flag to false)
        bytes memory sellerCalldata = abi.encodeWithSignature(
            "resolveDispute(address,address,uint256,bool)",
            escrowContract,
            seller,    // recipient is now the seller
            amount,
            false      // false means seller gets the funds
        );
        
        // Schedule execution through timelock with zero delay for immediate execution
        TimeLock timeLock = TimeLock(payable(targets[0]));
        
        // Get and use the minimum delay
        uint256 delay = timeLock.getMinDelay();
        
        // Schedule the operation
        bytes32 operationId = timeLock.schedule(
            targets[0],
            values[0],
            sellerCalldata,
            bytes32(0),  // predecessor: none
            bytes32(0),  // salt: use a unique value in production
            delay
        );
        
        // Emit event for tracking
        emit DisputeResolutionScheduled(proposalId, seller, amount, operationId);
    }

    event DisputeResolutionScheduled(
        uint256 indexed proposalId, 
        address indexed recipient, 
        uint256 amount, 
        bytes32 indexed operationId
    );

    /**
     * @notice Get proposal details
     * @param proposalId The ID of the proposal
     */
    function getProposalDetails(uint256 proposalId) public view returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) {
        ProposalCore memory proposal = _proposals[proposalId];
        return (
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            proposal.description
        );
    }
}

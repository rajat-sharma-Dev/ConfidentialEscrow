// // SPDX-License-Identifier: MIT
// pragma solidity  ^0.8.20;

// import {Script, console} from "../lib/forge-std/src/Script.sol";
// import {IGovernor} from "../lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";

// contract Propose is Script {
//     // Constants - you can modify these as needed
//     uint256 public constant NEW_STORE_VALUE = 77;
//     string public constant FUNC = "store";
//     string public constant PROPOSAL_DESCRIPTION = "Proposal #1: Store 77 in the Box";
//     uint256 public constant VOTING_DELAY = 1; // blocks

//     function run()
//         external
//         returns (uint256 proposalId)
//     {
//         address governorAddress = vm.envOr("GOVERNOR_ADDRESS", address(0));
//         address boxAddress = vm.envOr("BOX_ADDRESS", address(0));
//         uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
//         // Ensure we have the required addresses
//         if (governorAddress == address(0)) revert("GOVERNOR_ADDRESS not set");
//         if (boxAddress == address(0)) revert("BOX_ADDRESS not set");
        
//         vm.startBroadcast(deployerPrivateKey);
        
//         // Encode the function call
//         bytes memory encodedFunctionCall = abi.encodeWithSignature(FUNC, NEW_STORE_VALUE);
        
//         console.log("Proposing %s on %s with value %s", FUNC, boxAddress, NEW_STORE_VALUE);
//         console.log("Proposal Description: %s", PROPOSAL_DESCRIPTION);
        
//         // Create the proposal
//         IGovernor governor = IGovernor(governorAddress);
//         proposalId = governor.propose(
//             [boxAddress],
//             [0],
//             [encodedFunctionCall],
//             PROPOSAL_DESCRIPTION
//         );
        
//         vm.stopBroadcast();
        
//         console.log("Proposed with proposal ID: %s", proposalId);
        
//         // For local development chains, we can simulate moving blocks
//         if (block.chainid == 31337) {
//             vm.roll(block.number + VOTING_DELAY + 1);
            
//             IGovernor.ProposalState proposalState = governor.state(proposalId);
//             uint256 proposalSnapshot = governor.proposalSnapshot(proposalId);
//             uint256 proposalDeadline = governor.proposalDeadline(proposalId);
            
//             console.log("Current Proposal State: %s", uint256(proposalState));
//             console.log("Current Proposal Snapshot: %s", proposalSnapshot);
//             console.log("Current Proposal Deadline: %s", proposalDeadline);
//         }
        
//         // Store the proposal ID in a file
//         _storeProposalId(proposalId);
        
//         return proposalId;
//     }
    
//     function _storeProposalId(uint256 proposalId) internal {
//         string memory chainId = vm.toString(block.chainid);
//         string memory proposalsFile = "proposals.json";
        
//         // Setup JSON structure
//         string memory jsonData;
//         if (vm.exists(proposalsFile)) {
//             jsonData = vm.readFile(proposalsFile);
//             // Simple approach - this would need more complex parsing for production
//             if (bytes(jsonData).length == 0) {
//                 jsonData = "{}";
//             }
//         } else {
//             jsonData = "{}";
//         }
        
//         // Add proposal ID to chain data (simplified approach)
//         vm.writeJson(
//             vm.toString(proposalId), 
//             proposalsFile, 
//             string.concat(".", chainId, "[-1]")
//         );
        
//         console.log("Proposal ID stored in proposals.json for chain %s", chainId);
//     }
// }

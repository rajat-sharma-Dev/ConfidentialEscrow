// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {IGovernor} from "../lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";

contract Propose is Script {
    // Constants - you can modify these as needed
    uint256 public constant NEW_STORE_VALUE = 77;
    string public constant FUNC = "store";
    string public constant PROPOSAL_DESCRIPTION = "Proposal #1: Store 77 in the Box";
    uint256 public constant VOTING_DELAY = 1; // blocks

    function run()
        external
        returns (uint256 proposalId)
    {
        address governorAddress = vm.envOr("GOVERNOR_ADDRESS", address(0));
        address conflictedContract = vm.envOr("CONFLICTED_CONTRACT", address(0));
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
        // Ensure we have the required addresses
        if (governorAddress == address(0)) revert("GOVERNOR_ADDRESS not set");
        if (conflictedContract == address(0)) revert("CONFLICTED_CONTRACT not set");

        vm.startBroadcast(deployerPrivateKey);
        
        // Encode the function call
        bytes memory encodedFunctionCall = abi.encodeWithSignature(FUNC, NEW_STORE_VALUE);

        console.log("Proposing %s on %s with value %s", FUNC, conflictedContract, NEW_STORE_VALUE);
        console.log("Proposal Description: %s", PROPOSAL_DESCRIPTION);
        
        // Create the proposal
        IGovernor governor = IGovernor(governorAddress);
        address[] memory targets = new address[](1);
        targets[0] = conflictedContract;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = encodedFunctionCall;
        proposalId = governor.propose(
            targets,
            values,
            calldatas,
            PROPOSAL_DESCRIPTION
        );
        
        vm.stopBroadcast();
        
        console.log("Proposed with proposal ID: %s", proposalId);
        
        // For local development chains, we can simulate moving blocks
        if (block.chainid == 31337) {
            vm.roll(block.number + VOTING_DELAY + 1);
            
            IGovernor.ProposalState proposalState = governor.state(proposalId);
            uint256 proposalSnapshot = governor.proposalSnapshot(proposalId);
            uint256 proposalDeadline = governor.proposalDeadline(proposalId);
            
            console.log("Current Proposal State: %s", uint256(proposalState));
            console.log("Current Proposal Snapshot: %s", proposalSnapshot);
            console.log("Current Proposal Deadline: %s", proposalDeadline);
        }
        
        // Store the proposal ID in a file
        _storeProposalId(proposalId);
        
        return proposalId;
    }
    
    function _storeProposalId(uint256 proposalId) internal {
        string memory chainId = vm.toString(block.chainid);
        string memory proposalsFile = "proposals.json";
        
        // Setup JSON structure
        string memory jsonData;
        if (vm.exists(proposalsFile)) {
            jsonData = vm.readFile(proposalsFile);
            // Simple approach - this would need more complex parsing for production
            if (bytes(jsonData).length == 0) {
                jsonData = "{}";
            }
        } else {
            jsonData = "{}";
        }
        
        // Add proposal ID to chain data (simplified approach)
        vm.writeJson(
            vm.toString(proposalId), 
            proposalsFile, 
            string.concat(".", chainId, "[-1]")
        );
        
        console.log("Proposal ID stored in proposals.json for chain %s", chainId);
    }
}

contract QueueAndExecute is Script {
    // Reuse the constants from Propose contract
    uint256 public constant NEW_STORE_VALUE = Propose.NEW_STORE_VALUE;
    string public constant FUNC = Propose.FUNC;
    string public constant PROPOSAL_DESCRIPTION = Propose.PROPOSAL_DESCRIPTION;
    uint256 public constant MIN_DELAY = 3600; // 1 hour timelock delay

    function run() external {
        address governorAddress = vm.envOr("GOVERNOR_ADDRESS", address(0));
        address boxAddress = vm.envOr("CONFLICTED_CONTRACT", address(0));
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
        // Ensure we have the required addresses
        if (governorAddress == address(0)) revert("GOVERNOR_ADDRESS not set");
        if (boxAddress == address(0)) revert("CONFLICTED_CONTRACT not set");

        // Get the proposal ID
        uint256 proposalId = _getProposalId();
        if (proposalId == 0) revert("No proposal ID found");

        // Encode the function call
        bytes memory encodedFunctionCall = abi.encodeWithSignature(FUNC, NEW_STORE_VALUE);
        
        // Calculate description hash
        bytes32 descriptionHash = keccak256(bytes(PROPOSAL_DESCRIPTION));
        
        IGovernor governor = IGovernor(governorAddress);
        
        // Check proposal state before queueing
        IGovernor.ProposalState proposalState = governor.state(proposalId);
        console.log("Current Proposal State: %s", uint256(proposalState));
        
        if (proposalState != IGovernor.ProposalState.Succeeded) {
            revert("Proposal not in Succeeded state");
        }

        vm.startBroadcast(deployerPrivateKey);
        
        // Queue transaction
        console.log("Queueing proposal...");
        address[] memory targets = new address[](1);
        targets[0] = boxAddress;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = encodedFunctionCall;
        
        governor.queue(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        // For local development chains, we can simulate moving time
        if (block.chainid == 31337) {
            // Advance time by MIN_DELAY + 1 seconds
            vm.warp(block.timestamp + MIN_DELAY + 1);
            // Advance by 1 block
            vm.roll(block.number + 1);
            
            proposalState = governor.state(proposalId);
            console.log("Proposal State after time manipulation: %s", uint256(proposalState));
        }
        
        // Execute proposal
        console.log("Executing proposal...");
        governor.execute(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        
        // Try to read the new value (if Box follows ERC20-like interface)
        // Note: This may need adjustment based on your actual Box contract
        try IBox(boxAddress).retrieve() returns (uint256 value) {
            console.log("Box value after execution: %s", value);
        } catch {
            console.log("Cannot retrieve Box value - check contract interface");
        }
        
        vm.stopBroadcast();
    }
    
    function _getProposalId() internal returns (uint256) {
        string memory chainId = vm.toString(block.chainid);
        string memory proposalsFile = "proposals.json";
        
        if (!vm.exists(proposalsFile)) {
            return 0;
        }
        
        string memory json = vm.readFile(proposalsFile);
        if (bytes(json).length == 0) {
            return 0;
        }
        
        // Simple approach to get the last proposal ID
        // This is a simplification - in production use a proper JSON parser
        bytes memory proposalIdBytes = vm.parseJson(
            json,
            string.concat(".", chainId, "[-1]")
        );
        
        if (proposalIdBytes.length == 0) {
            return 0;
        }
        
        return abi.decode(proposalIdBytes, (uint256));
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VerdictorToken} from "../src/DAO/Pool/VerdictorToken.sol";
import {TimeLock} from "../src/DAO/Governance/TimeLock.sol";
import {GovernorContract} from "../src/DAO/Governance/GovernorContract.sol";
import {IVotes} from "../lib/openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract DeployDAO is Script {
    // Error messages
    error DeployDAO__VerdictorTokenDeployementFailed();
    error DeployDAO__ChainIdNotSupported();
    error DeployDAO__TimeLockDeploymentFailed();
    error DeployDAO__GovernorDeployementFailed();

    VerdictorToken public verdictorToken;
    uint256 private deployerKey;
    TimeLock private timeLock;
    HelperConfig helperConfig;
    GovernorContract private governor;

    function run()
        external
        returns (
            /**
             * (Contract contract)
             */
            address verdictorTokenAddress,
            address timeLockAddress,
            address governorAddress
        )
    {
        helperConfig = new HelperConfig();
        deployerKey = helperConfig.getDeployerKey();
        if (deployerKey == 0) {
            revert DeployDAO__ChainIdNotSupported();
        }

        verdictorToken = deployVerdictorToken();
        if (address(verdictorToken) == address(0)) {
            revert DeployDAO__VerdictorTokenDeployementFailed();
        }
        delegate(verdictorToken, vm.addr(deployerKey));

        timeLock = deployTimeLock();

        governor = deployGovernor();

        setUpContracts();


        return (address(verdictorToken), address(timeLock), address(governor));
    }

    function deployVerdictorToken() internal returns (VerdictorToken) {
        vm.startBroadcast(deployerKey);
        VerdictorToken _verdictorToken = new VerdictorToken();
        vm.stopBroadcast();
        vm.label(address(_verdictorToken), "VerdictorToken");
        console.log("Deployer VerdictorToken to address: ", address(_verdictorToken));
        return _verdictorToken;
    }

    function delegate(VerdictorToken _verdictorToken, address _delegateAccount) internal {
        vm.startBroadcast(deployerKey);
        _verdictorToken.delegate(_delegateAccount);
        vm.roll(block.number + 2000); // wait for 20 blocks
        uint32 numCheckPoints = _verdictorToken.numCheckpoints(_delegateAccount);
        vm.stopBroadcast();
        console.log("Delegated to: ", _delegateAccount);
        console.log("Number of initial checkpoints: ", numCheckPoints);
    }

    function deployTimeLock() internal returns (TimeLock) {
        vm.startBroadcast(deployerKey);
        timeLock = new TimeLock(helperConfig.MIN_DELAY(), new address[](0), new address[](0));
        vm.stopBroadcast();
        console.log("TimeLock deployer at address: ", address(timeLock));
        if (address(timeLock) == address(0)) revert DeployDAO__TimeLockDeploymentFailed();
        vm.label(address(timeLock), "TimeLock");
        return timeLock;
    }

    function deployGovernor() internal returns (GovernorContract) {
        vm.startBroadcast(deployerKey);
        governor = new GovernorContract(
            IVotes(address(verdictorToken)),
            timeLock,
            helperConfig.VOTING_PERIOD(),
            helperConfig.VOTING_DELAY(),
            helperConfig.QUORUM_PERCENTAGE()
        );
        vm.stopBroadcast();
        if(address(governor) == address(0)) revert DeployDAO__GovernorDeployementFailed();
        console.log("Governor deployed at address: ", address(governor));
        vm.label(address(governor), "Governor");
        return governor;
    }

    function setUpContracts() internal {
        bytes32 proposalRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timeLock.CANCELLER_ROLE();
        vm.startBroadcast(deployerKey);
        timeLock.grantRole(proposalRole, address(governor));
        vm.roll(block.number + 2000);
        timeLock.grantRole(executorRole, address(0));
        vm.roll(block.number + 2000);
        timeLock.revokeRole(cancellerRole, vm.addr(deployerKey));
        vm.roll(block.number + 2000);
        vm.stopBroadcast();
    }


}

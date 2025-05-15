// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFactory is Script {
    // HelperConfig public helperConfig;
    error DeployFactory__ChainIdNotSupported();
    uint256 private deployerKey;

    function run()
        external
        returns (
            /**
             * (Contract contract)
             */
            HelperConfig helperConfig
        )
    {
        helperConfig = new HelperConfig();
        deployerKey = helperConfig.getDeployerKey();
        if (deployerKey == 0) {
            revert DeployFactory__ChainIdNotSupported();
        }


        vm.startBroadcast(deployerKey);
        // deploy your contract here...
        
        vm.stopBroadcast();
    }
}

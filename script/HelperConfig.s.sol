// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported();

    struct NetworkConfig {
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;
    uint256 public constant MIN_DELAY = 0; // 1 hour
    uint32 public constant VOTING_PERIOD = 129600; // 3 days
    uint32 public constant VOTING_DELAY = 129600; // 3 days
    uint256 public constant QUORUM_PERCENTAGE = 5; // 5%

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        } else if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaNetworkConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseNetworkConfig();
        } else {
            revert HelperConfig__ChainIdNotSupported();
        }
    }

    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory _anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.deployerKey == DEFAULT_ANVIL_PRIVATE_KEY) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        // deploy the mocks...
        vm.stopBroadcast();

        _anvilNetworkConfig = NetworkConfig({deployerKey: DEFAULT_ANVIL_PRIVATE_KEY});
    }

    function getBaseSepoliaNetworkConfig() internal view returns (NetworkConfig memory _sepoliaNetworkConfig) {
        _sepoliaNetworkConfig = NetworkConfig({deployerKey: vm.envUint("PRIVATE_KEY_SEPOLIA")});
    }

    function getBaseNetworkConfig() internal view returns (NetworkConfig memory _baseNetworkConfig) {
        _baseNetworkConfig = NetworkConfig({deployerKey: vm.envUint("PRIVATE_KEY")});
    }

    function getDeployerKey() external view returns (uint256) {
        return activeNetworkConfig.deployerKey;
    }
}

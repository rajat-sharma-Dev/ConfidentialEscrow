// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../interfaces/IERC20.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Rewards is Ownable {
    mapping(address => address[]) private _rewardTokens;
    mapping(address => mapping(address => uint256)) private _rewards;

    enum LockStatus {
        UNLOCKED,
        LOCKED
    }

    LockStatus private _lockStatus;

    modifier lock() {
        if(_lockStatus == LockStatus.LOCKED) revert("Locked");
        _lockStatus = LockStatus.LOCKED;
        _;
        _lockStatus = LockStatus.UNLOCKED;
    }

    constructor(address _owner) Ownable(_owner) {}

    function addRewards(address token, uint256 amount, address[] memory recipients) external lock {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 rewardPerRecipient = amount / recipients.length;
        for (uint256 i = 0; i < recipients.length; i++) {
            _rewards[token][recipients[i]] += rewardPerRecipient;
            _rewardTokens[recipients[i]].push(token);
        }
    }

    function claimRewards(address recipient) external lock {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < _rewardTokens[recipient].length; i++) {
            address token = _rewardTokens[recipient][i];
            uint256 reward = _rewards[token][recipient];
            if (reward > 0) {
                totalRewards += reward;
                _rewards[token][recipient] = 0;
                _rewardTokens[recipient][i] = _rewardTokens[recipient][_rewardTokens[recipient].length - 1];
                _rewardTokens[recipient].pop();
                IERC20(token).transfer(recipient, reward);
            }
        }
        require(totalRewards > 0, "No rewards to claim");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Governor, IGovernor} from "../../../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import {SafeCast} from "../../../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

/**
 * @title GovernorVoteTracker
 * @dev Extension of Governor that tracks votes cast for/against each proposal
 */
abstract contract GovernorVoteTracker is Governor {
    using SafeCast for uint256;

    // Track voters and their votes for each proposal
    struct VoterInfo {
        bool voted;
        uint8 support;
        uint256 weight;
    }

    // Map proposal ID => voter address => vote info
    mapping(uint256 => mapping(address => VoterInfo)) private _voterInfo;

    // Map proposal ID => arrays of for/against voters
    mapping(uint256 => address[]) private _forVoters;
    mapping(uint256 => address[]) private _againstVoters;

    // Total votes for/against each proposal
    mapping(uint256 => uint256) private _totalForVotes;
    mapping(uint256 => uint256) private _totalAgainstVotes;

    /**
     * @dev Cast a vote with a reason
     */
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        uint256 weight = super._castVote(proposalId, account, support, reason, params);

        // Track voter info
        _voterInfo[proposalId][account] = VoterInfo({voted: true, support: support, weight: weight});

        // Add voter to the appropriate list
        if (support == 0) {
            // Against
            _againstVoters[proposalId].push(account);
            _totalAgainstVotes[proposalId] += weight;
        } else if (support == 1) {
            // For
            _forVoters[proposalId].push(account);
            _totalForVotes[proposalId] += weight;
        }
    }

    /**
     * @dev Get list of voters who voted "for" a proposal
     */
    function getForVoters(uint256 proposalId) public view returns (address[] memory) {
        return _forVoters[proposalId];
    }

    /**
     * @dev Get list of voters who voted "against" a proposal
     */
    function getAgainstVoters(uint256 proposalId) public view returns (address[] memory) {
        return _againstVoters[proposalId];
    }

    /**
     * @dev Get voter info for a specific voter on a proposal
     */
    function getVoterInfo(uint256 proposalId, address voter)
        public
        view
        returns (bool voted, uint8 support, uint256 weight)
    {
        VoterInfo memory info = _voterInfo[proposalId][voter];
        return (info.voted, info.support, info.weight);
    }

    /**
     * @dev Get total "for" votes for a proposal
     */
    function getTotalForVotes(uint256 proposalId) public view returns (uint256) {
        return _totalForVotes[proposalId];
    }

    /**
     * @dev Get total "against" votes for a proposal
     */
    function getTotalAgainstVotes(uint256 proposalId) public view returns (uint256) {
        return _totalAgainstVotes[proposalId];
    }

    /**
     * @dev Get winning voters for a proposal
     */
    function getWinningVoters(uint256 proposalId) public view returns (address[] memory) {
        uint256 forVotes = _totalForVotes[proposalId];
        uint256 againstVotes = _totalAgainstVotes[proposalId];

        if (forVotes > againstVotes) {
            return _forVoters[proposalId];
        } else {
            return _againstVoters[proposalId];
        }
    }
}

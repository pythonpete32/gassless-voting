// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {Enum} from "../zodiac/core/Module.sol";

/// @notice The voting state
enum VoterState {
    Absent,
    Yea,
    Nay
}

/// @notice The vote struct
struct Vote {
    bool executed;
    uint64 startDate;
    uint64 snapshotBlock;
    uint64 supportRequiredPct;
    uint64 minAcceptQuorumPct;
    uint256 yea;
    uint256 nay;
    uint256 votingPower;
    address to;
    uint256 value;
    bytes data;
    Enum.Operation operation;
    mapping(address => VoterState) voters;
}

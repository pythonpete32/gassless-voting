// SPDX-License-Identitifer: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@gnosis.pm/safe-contracts/contracts/base/Module.sol";

contract GasslessVoting is ERC2771Context {
    /* ====================================================================== */
    /*                              ERRORS
    /* ====================================================================== */

    error SupportRequiredPctTooHigh();

    /* ====================================================================== */
    /*                              EVENTS
    /* ====================================================================== */

    event StartVote(
        uint256 indexed voteId,
        address indexed creator,
        string metadata
    );
    event CastVote(
        uint256 indexed voteId,
        address indexed voter,
        bool support,
        uint256 stake
    );
    event ExecuteVote(uint256 indexed voteId);
    event ChangeSupportRequired(uint64 supportRequiredPct);
    event ChangeMinQuorum(uint64 minAcceptQuorumPct);

    /* ====================================================================== */
    /*                              STORAGE
    /* ====================================================================== */

    enum VoterState {
        Absent,
        Yea,
        Nay
    }

    struct Vote {
        bool executed;
        uint64 startDate;
        uint64 snapshotBlock;
        uint64 supportRequiredPct;
        uint64 minAcceptQuorumPct;
        uint256 yea;
        uint256 nay;
        uint256 votingPower;
        bytes executionScript;
        mapping(address => VoterState) voters;
    }

    /// Voting Token
    ERC20Votes public token;

    // Voting Parameters
    uint64 public supportRequiredPct;
    uint64 public minAcceptQuorumPct;
    uint64 public voteTime;

    // Votes
    mapping(uint256 => Vote) internal votes;
    uint256 public votesLength;

    uint64 public constant PCT_BASE = 10**18; // 0% = 0; 1% = 10^16; 100% = 10^18
    bool public initialized;

    /* ====================================================================== */
    /*                              CONSTRUCTOR
    /* ====================================================================== */

    constructor(address _trustedForwarder) ERC2771Context(_trustedForwarder) {}

    function initialize(
        ERC20Votes _token,
        uint64 _supportRequiredPct,
        uint64 _minAcceptQuorumPct,
        uint64 _voteTime
    ) external {
        initialized = true;

        if (_minAcceptQuorumPct <= _supportRequiredPct)
            revert SupportRequiredPctTooHigh();
        if (_supportRequiredPct < PCT_BASE) revert SupportRequiredPctTooHigh();

        token = _token;
        supportRequiredPct = _supportRequiredPct;
        minAcceptQuorumPct = _minAcceptQuorumPct;
        voteTime = _voteTime;
    }

    /* ====================================================================== */
    /*                              VIEWS
    /* ====================================================================== */

    /* ====================================================================== */
    /*                              USER FUNCTIONS
    /* ====================================================================== */

    /* ====================================================================== */
    /*                              ADMIN FUNCTIONS
    /* ====================================================================== */

    /* ====================================================================== */
    /*                              INTERNAL UTILS
    /* ====================================================================== */
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./zodiac/core/Module.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-contracts/metatx/ERC2771Context.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract MetaVotingModule is Module, ERC2771Context, Ownable {
    /* ====================================================================== */
    /*                              ERRORS
    /* ====================================================================== */

    error SupportRequiredPctTooHigh();
    error QuorumRequiredPctTooHigh();
    error NoVotingPower();
    error CannotVote();
    error VoteDoesNotExist();
    error CannotExecute();

    /* ====================================================================== */
    /*                              EVENTS
    /* ====================================================================== */

    /// @notice Emitted when a vote is created
    /// @param voteId The id of the vote
    /// @param creator The creator of the vote
    /// @param metadata The metadata of the vote
    event StartVote(
        uint256 indexed voteId,
        address indexed creator,
        string metadata
    );

    /// @notice Emitted when a vote is casted
    /// @param voteId The id of the vote
    /// @param voter The voter
    /// @param supports The support of the vote: 0 == absent, 1 == yes, 2 == no
    event CastVote(
        uint256 indexed voteId,
        address indexed voter,
        bool support,
        uint256 stake
    );

    /// @notice Emitted when a vote is executed
    /// @param voteId The id of the vote
    event ExecuteVote(uint256 indexed voteId);

    /// @notice Emitted when a vote is cancelled
    /// @param voteId The id of the vote
    event ChangeSupportRequired(uint64 supportRequiredPct);

    /// @notice Emitted when the quorum required is changed
    /// @param quorumRequiredPct The new quorum required
    event ChangeMinQuorum(uint64 minAcceptQuorumPct);

    /* ====================================================================== */
    /*                              STORAGE
    /* ====================================================================== */

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

    /// @notice is the contract initialized
    bool public initialized;
    /// @notice The voting token
    ERC20Votes public token;

    /// @notice 100% expressed as a percentage of 10^18
    uint64 public constant PCT_BASE = 10**18;
    /// @notice The support required to pass a vote (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    uint64 public supportRequiredPct;
    /// @notice The minimum acceptance quorum for a vote to succeed (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    uint64 public minAcceptQuorumPct;
    /// @notice The duration of a vote in seconds
    uint64 public voteTime;

    /// @notice The total number of votes
    uint256 public votesLength;
    /// @notice Mocking a variable length array of all the votes created
    mapping(uint256 => Vote) internal votes;

    /// @notice The address of the MetaTransactionForwarder
    address public immutable metaTxForwarder =
        0x84a0856b038eaAd1cC7E297cF34A7e72685A8693;

    /* ====================================================================== */
    /*                              MODIFIERS
    /* ====================================================================== */

    modifier voteExists(uint256 _voteId) {
        if (_voteId < votesLength) revert VoteDoesNotExist();
        _;
    }

    /* ====================================================================== */
    /*                              CONSTRUCTOR
    /* ====================================================================== */

    constructor() ERC2771Context(metaTxForwarder) {}

    /// @notice Initializes the contract
    /// @param _token The address of the voting token
    /// @param _supportRequiredPct The support required to pass a vote (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @param _minAcceptQuorumPct The minimum acceptance quorum for a vote to succeed (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @param _voteTime The duration of a vote in seconds

    function initialize(
        ERC20Votes _token,
        uint64 _supportRequiredPct,
        uint64 _minAcceptQuorumPct,
        uint64 _voteTime
    ) external onlyOwner {
        initialized = true;

        if (_minAcceptQuorumPct > _supportRequiredPct)
            revert QuorumRequiredPctTooHigh();
        if (_supportRequiredPct > PCT_BASE) revert SupportRequiredPctTooHigh();
        token = _token;
        supportRequiredPct = _supportRequiredPct;
        minAcceptQuorumPct = _minAcceptQuorumPct;
        voteTime = _voteTime;
    }

    /* ====================================================================== */
    /*                              VIEWS
    /* ====================================================================== */

    function canVote(uint256 _voteId, address _voter)
        public
        view
        returns (bool)
    {
        Vote storage vote_ = votes[_voteId];
        return
            isVoteOpen(vote_) &&
            token.getPastVotes(_voter, vote_.snapshotBlock) > 0;
    }

    function isVoteOpen(Vote storage vote_) public view returns (bool) {
        return
            uint64(block.number) < vote_.startDate + voteTime &&
            !vote_.executed;
    }

    /// @dev function to check if a vote can be executed. It assumes the queried vote exists.
    /// @return True if the given vote can be executed, false otherwise
    function canExecute(uint256 _voteId) public view returns (bool) {
        Vote storage vote_ = votes[_voteId];

        if (vote_.executed) {
            return false;
        }

        // Voting is already decided
        if (
            _isValuePct(vote_.yea, vote_.votingPower, vote_.supportRequiredPct)
        ) {
            return true;
        }

        // Vote ended?
        if (_isVoteOpen(vote_)) {
            return false;
        }
        // Has enough support?
        uint256 totalVotes = vote_.yea + (vote_.nay);
        if (!_isValuePct(vote_.yea, totalVotes, vote_.supportRequiredPct)) {
            return false;
        }
        // Has min quorum?
        if (
            !_isValuePct(vote_.yea, vote_.votingPower, vote_.minAcceptQuorumPct)
        ) {
            return false;
        }

        return true;
    }

    /* ====================================================================== */
    /*                              USER FUNCTIONS
    /* ====================================================================== */

    /// @notice Create a new vote about "`_metadata`"
    /// @param _to Address of the contract to be called
    /// @param _value Amount of Ether to be sent
    /// @param _data Calldata to be sent
    /// @param _operation Operation type of module transaction: 0 == call, 1 == delegate call.
    /// @param _metadata Vote metadata, link to the lens post
    /// @return voteId Id for newly created vote
    function newVote(
        address _to,
        uint256 _value,
        bytes memory _data,
        Enum.Operation _operation,
        string memory _metadata
    ) external returns (uint256 voteId) {
        return _newVote(_to, _value, _data, _operation, _metadata, true, true);
    }

    /// @notice Vote `_supports ? 'yes' : 'no'` in vote #`_voteId`
    /// @dev Initialization check is implicitly provided by `voteExists()` as new votes can only be
    ///      created via `newVote(),` which requires initialization
    /// @param _voteId Id for vote
    /// @param _supports Whether voter supports the vote
    /// @param _executesIfDecided Whether the vote should execute its action if it becomes decided
    function vote(
        uint256 _voteId,
        bool _supports,
        bool _executesIfDecided
    ) external voteExists(_voteId) {
        if (!canVote(_voteId, msg.sender)) revert CannotVote();
        _vote(_voteId, _supports, msg.sender, _executesIfDecided);
    }

    /* ====================================================================== */
    /*                              INTERNAL FUNCTIONS
    /* ====================================================================== */

    /// @dev Internal function to create a new vote
    /// @param _to Address of the contract to be called
    /// @param _value Amount of Ether to be sent
    /// @param _data Calldata to be sent
    /// @param _operation Operation type of module transaction: 0 == call, 1 == delegate call.
    /// @param _metadata Vote metadata, link to the lens post
    /// @param _castVote Whether to also cast newly created vote
    /// @param _executesIfDecided Whether to also immediately execute newly created vote if decided
    /// @return voteId id for newly created vote
    function _newVote(
        address _to,
        uint256 _value,
        bytes memory _data,
        Enum.Operation _operation,
        string memory _metadata,
        bool _castVote,
        bool _executesIfDecided
    ) internal returns (uint256 voteId) {
        // find the current blocknumber
        uint64 snapshotBlock = uint64(block.number - 1); // avoid double voting in this very block

        uint256 votingPower = token.getPastVotes(_msgSender(), snapshotBlock);
        if (votingPower == 0) revert NoVotingPower();

        voteId = votesLength++;

        Vote storage vote_ = votes[voteId];
        vote_.startDate = uint64(block.number);
        vote_.snapshotBlock = snapshotBlock;
        vote_.supportRequiredPct = supportRequiredPct;
        vote_.minAcceptQuorumPct = minAcceptQuorumPct;
        vote_.votingPower = votingPower;
        vote_.to = _to;
        vote_.value = _value;
        vote_.data = _data;
        vote_.operation = _operation;

        emit StartVote(voteId, _msgSender(), _metadata);

        // TODO: implement Vote first
        if (_castVote && canVote(voteId, _msgSender())) {
            _vote(voteId, true, _msgSender(), _executesIfDecided);
        }
    }

    /// @dev Internal function to cast a vote. It assumes the queried vote exists.
    function _vote(
        uint256 _voteId,
        bool _supports,
        address _voter,
        bool _executesIfDecided
    ) internal {
        Vote storage vote_ = votes[_voteId];

        // This could re-enter, though we can assume the governance token is not malicious
        uint256 voterStake = token.getPastVotes(_voter, vote_.snapshotBlock);
        VoterState state = vote_.voters[_voter];

        // If voter had previously voted, decrease count
        if (state == VoterState.Yea) {
            vote_.yea = vote_.yea - (voterStake);
        } else if (state == VoterState.Nay) {
            vote_.nay = vote_.nay - (voterStake);
        }

        if (_supports) {
            vote_.yea = vote_.yea + (voterStake);
        } else {
            vote_.nay = vote_.nay + (voterStake);
        }

        vote_.voters[_voter] = _supports ? VoterState.Yea : VoterState.Nay;

        emit CastVote(_voteId, _voter, _supports, voterStake);

        // TODO: implement executeVote
        if (_executesIfDecided && canExecute(_voteId)) {
            // We've already checked if the vote can be executed with `_canExecute()`
            _unsafeExecuteVote(_voteId);
        }
    }

    /// @dev Internal function to execute a vote. It assumes the queried vote exists.
    function _executeVote(uint256 _voteId) internal {
        if (!canExecute(_voteId)) revert CannotExecute();
        _unsafeExecuteVote(_voteId);
    }

    /// @dev Unsafe version of _executeVote that assumes you have already checked if the vote can be executed and exists
    function _unsafeExecuteVote(uint256 _voteId) internal {
        Vote storage vote_ = votes[_voteId];

        vote_.executed = true;

        exec(vote_.to, vote_.value, vote_.data, vote_.operation);

        emit ExecuteVote(_voteId);
    }

    /// @dev Internal function to check if a voter can participate on a vote. It assumes the queried vote exists.
    /// @return True if the given voter can participate a certain vote, false otherwise
    function _canVote(uint256 _voteId, address _voter)
        internal
        view
        returns (bool)
    {
        Vote storage vote_ = votes[_voteId];
        return
            _isVoteOpen(vote_) &&
            token.getPastVotes(_voter, vote_.snapshotBlock) > 0;
    }

    /// @dev Internal function to check if a vote is still open
    /// @return True if the given vote is open, false otherwise

    function _isVoteOpen(Vote storage vote_) internal view returns (bool) {
        return
            uint64(block.number) < vote_.startDate + (voteTime) &&
            !vote_.executed;
    }

    /// @dev Calculates whether `_value` is more than a percentage `_pct` of `_total`
    function _isValuePct(
        uint256 _value,
        uint256 _total,
        uint256 _pct
    ) internal pure returns (bool) {
        if (_total == 0) {
            return false;
        }

        uint256 computedPct = (_value * (PCT_BASE)) / _total;
        return computedPct > _pct;
    }

    /* ====================================================================== */
    /*                              ADMIN FUNCTIONS
    /* ====================================================================== */

    /// @notice Change required support to `@formatPct(_supportRequiredPct)`%
    /// @param _supportRequiredPct New required support
    function changeSupportRequiredPct(uint64 _supportRequiredPct)
        external
        onlyOwner
    {
        if (minAcceptQuorumPct > _supportRequiredPct)
            revert MinAcceptQuorumPctTooHigh();
        if (_supportRequiredPct > PCT_BASE) revert SupportTooHigh();
        supportRequiredPct = _supportRequiredPct;

        emit ChangeSupportRequired(_supportRequiredPct);
    }

    /// @notice Change minimum acceptance quorum to `@formatPct(_minAcceptQuorumPct)`%
    /// @param _minAcceptQuorumPct New acceptance quorum
    function changeMinAcceptQuorumPct(uint64 _minAcceptQuorumPct)
        external
        onlyOwner
    {
        if (_minAcceptQuorumPct > supportRequiredPct)
            revert MinAcceptQuorumPctTooHigh();
        minAcceptQuorumPct = _minAcceptQuorumPct;

        emit ChangeMinQuorum(_minAcceptQuorumPct);
    }

    /* ====================================================================== */
    /*                              INTERNAL UTILS
    /* ====================================================================== */

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }
}

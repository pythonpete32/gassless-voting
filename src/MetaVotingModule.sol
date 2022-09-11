// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./lib/common.sol";
import "./zodiac/core/Module.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-contracts/metatx/ERC2771Context.sol";

contract MetaVotingModule is Module, ERC2771Context {
    /* ====================================================================== */
    /*                              STORAGE
    /* ====================================================================== */

    /// @notice is the contract initialized
    bool public initialized;
    /// @notice The voting token
    ERC20Votes public token;

    /// @notice 100% expressed as a percentage of 10^18
    uint64 public PCT_BASE;
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

    /// META TX
    /// @notice This is a map of user address and a nonce to prevent replay attacks
    mapping(address => uint256) public nonces;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            bytes(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            )
        );
    bytes32 internal constant META_TRANSACTION_TYPEHASH =
        keccak256(bytes("MetaTransaction(uint256 nonce,address from)"));
    bytes32 internal DOMAIN_SEPARATOR;

    /* ====================================================================== */
    /*                              ERRORS
    /* ====================================================================== */

    error SupportRequiredPctTooHigh();
    error QuorumRequiredPctTooHigh();
    error NoVotingPower();
    error CannotVote();
    error VoteDoesNotExist();
    error CannotExecute();
    error InvalidAddress();
    error InvalidSignature();

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
    /// @param support The support of the vote: 0 == absent, 1 == yes, 2 == no
    /// @param stake The voting power of the voter
    event CastVote(
        uint256 indexed voteId,
        address indexed voter,
        bool support,
        uint256 stake
    );

    /// @notice Emitted when a vote is executed
    /// @param voteId The id of the vote
    event ExecuteVote(uint256 indexed voteId);

    /// @notice Emitted when support required pct is changed
    /// @param supportRequiredPct the new support required pct
    event ChangeSupportRequired(uint64 supportRequiredPct);

    /// @notice Emitted when the quorum required is changed
    /// @param quorumRequiredPct The new quorum required
    event ChangeMinQuorum(uint64 quorumRequiredPct);

    event Initialized(
        ERC20Votes token,
        uint64 supportRequiredPct,
        uint64 minAcceptQuorumPct,
        uint64 voteTime
    );

    event TestLog(string message);
    event TestLog(string message, uint256 value);

    /* ====================================================================== */
    /*                              CONSTRUCTOR
    /* ====================================================================== */

    constructor() ERC2771Context(metaTxForwarder) {}

    /// @notice Initializes the contract
    /// @param _token The address of the voting token
    /// @param _supportRequiredPct The support required to pass a vote (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @param _minAcceptQuorumPct The minimum acceptance quorum for a vote to succeed (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @param _voteTime The duration of a vote in seconds
    /// @param _chainId The network id of the chain
    function initialize(
        ERC20Votes _token,
        uint64 _supportRequiredPct,
        uint64 _minAcceptQuorumPct,
        uint64 _voteTime,
        uint256 _chainId
    ) external initializer {
        __Ownable_init();
        initialized = true;
        PCT_BASE = 10**18;
        if (_minAcceptQuorumPct > _supportRequiredPct)
            revert QuorumRequiredPctTooHigh();
        if (_supportRequiredPct > PCT_BASE) revert SupportRequiredPctTooHigh();
        token = _token;
        supportRequiredPct = _supportRequiredPct;
        minAcceptQuorumPct = _minAcceptQuorumPct;
        voteTime = _voteTime;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Quote")),
                keccak256(bytes("1")),
                _chainId,
                address(this)
            )
        );
        emit Initialized(
            _token,
            _supportRequiredPct,
            _minAcceptQuorumPct,
            _voteTime
        );
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
    /// @param _v Signature v parameter
    /// @param _r Signature r parameter
    /// @param _s Signature s parameter
    /// @return voteId Id for newly created vote
    function newVote(
        address _to,
        uint256 _value,
        bytes memory _data,
        Enum.Operation _operation,
        string memory _metadata,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) external returns (uint256 voteId) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[_msgSender()],
            from: _msgSender()
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        META_TRANSACTION_TYPEHASH,
                        metaTx.nonce,
                        metaTx.from
                    )
                )
            )
        );
        if (_msgSender() == address(0)) revert InvalidAddress();
        if (_msgSender() != ecrecover(digest, _v, _r, _s))
            revert InvalidSignature();
        nonces[_msgSender()]++;

        return _newVote(_to, _value, _data, _operation, _metadata, true, true);
    }

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
    /// @param _v Signature v parameter
    /// @param _r Signature r parameter
    /// @param _s Signature s parameter
    function vote(
        uint256 _voteId,
        bool _supports,
        bool _executesIfDecided, // voteExists(_voteId)
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) external {
        if (!canVote(_voteId, msg.sender)) revert CannotVote();

        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[_msgSender()],
            from: _msgSender()
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        META_TRANSACTION_TYPEHASH,
                        metaTx.nonce,
                        metaTx.from
                    )
                )
            )
        );
        if (_msgSender() == address(0)) revert InvalidAddress();
        if (_msgSender() != ecrecover(digest, _v, _r, _s))
            revert InvalidSignature();
        nonces[_msgSender()]++;

        _vote(_voteId, _supports, msg.sender, _executesIfDecided);
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
        bool _executesIfDecided // voteExists(_voteId)
    ) external {
        if (!canVote(_voteId, msg.sender)) revert CannotVote();
        _vote(_voteId, _supports, msg.sender, _executesIfDecided);
    }

    /// @dev public function to execute a vote
    /// @param _voteId Id for vote
    /// @param _v Signature v parameter
    /// @param _r Signature r parameter
    /// @param _s Signature s parameter
    function executeVote(
        uint256 _voteId,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) public {
        if (_voteId > votesLength) revert VoteDoesNotExist();
        if (!canExecute(_voteId)) revert CannotExecute();

        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[_msgSender()],
            from: _msgSender()
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        META_TRANSACTION_TYPEHASH,
                        metaTx.nonce,
                        metaTx.from
                    )
                )
            )
        );
        if (_msgSender() == address(0)) revert InvalidAddress();
        if (_msgSender() != ecrecover(digest, _v, _r, _s))
            revert InvalidSignature();

        Vote storage vote_ = votes[_voteId];
        vote_.executed = true;

        exec(vote_.to, vote_.value, vote_.data, vote_.operation);

        emit ExecuteVote(_voteId);
    }

    /// @dev public function to execute a vote
    /// @param _voteId Id for vote
    function executeVote(uint256 _voteId) public {
        if (_voteId > votesLength) revert VoteDoesNotExist();
        if (!canExecute(_voteId)) revert CannotExecute();
        Vote storage vote_ = votes[_voteId];
        vote_.executed = true;

        exec(vote_.to, vote_.value, vote_.data, vote_.operation);

        emit ExecuteVote(_voteId);
    }

    /* ====================================================================== */
    /*                              VIEWS
    /* ====================================================================== */

    /// @notice Returns all the vote info of a given id (minus the call data if sucessfull)
    /// @param _voteId The id of the vote
    /// @return _executed Whether the vote has been executed or not
    /// @return _startDate The start date of the vote
    /// @return _snapshotBlock The block number of the snapshot
    /// @return _supportRequiredPct The support required to pass a vote (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @return _minAcceptQuorumPct The minimum acceptance quorum for a vote to succeed (expressed as a percentage of 10^18; eg. 10^16 = 1%, 10^18 = 100%)
    /// @return _yea The total voting power in favor of the vote
    /// @return _nay The total voting power against the vote
    /// @return _votingPower The total voting power
    function getVote(uint256 _voteId)
        external
        view
        returns (
            bool _executed,
            uint64 _startDate,
            uint64 _snapshotBlock,
            uint64 _supportRequiredPct,
            uint64 _minAcceptQuorumPct,
            uint256 _yea,
            uint256 _nay,
            uint256 _votingPower
        )
    {
        if (_voteId > votesLength) revert VoteDoesNotExist();
        Vote storage vote_ = votes[_voteId];
        _executed = vote_.executed;
        _startDate = vote_.startDate;
        _snapshotBlock = vote_.snapshotBlock;
        _supportRequiredPct = vote_.supportRequiredPct;
        _minAcceptQuorumPct = vote_.minAcceptQuorumPct;
        _yea = vote_.yea;
        _nay = vote_.nay;
        _votingPower = vote_.votingPower;
    }

    /**
     * @dev Return the state of a voter for a given vote by its ID
     * @param _voteId Vote identifier
     * @return VoterState of the requested voter for a certain vote
     */
    function getVoterState(uint256 _voteId, address _voter)
        public
        view
        returns (VoterState)
    {
        if (_voteId > votesLength) revert VoteDoesNotExist();
        return votes[_voteId].voters[_voter];
    }

    function canVote(uint256 _voteId, address _voter)
        public
        view
        returns (bool)
    {
        if (_voteId > votesLength) revert VoteDoesNotExist();
        Vote storage vote_ = votes[_voteId];
        return
            isVoteOpen(_voteId) &&
            token.getPastVotes(_voter, vote_.snapshotBlock) > 0;
    }

    /// @dev check if a vote is still open and not executed
    /// @return True if the given vote is open, false otherwise
    function isVoteOpen(uint256 voteId) public view returns (bool) {
        if (voteId > votesLength) revert VoteDoesNotExist();
        Vote storage vote_ = votes[voteId];
        return
            uint64(block.number) < vote_.startDate + voteTime &&
            !vote_.executed;
    }

    /// @dev function to check if a vote can be executed. It assumes the queried vote exists.
    /// @return True if the given vote can be executed, false otherwise
    function canExecute(uint256 _voteId) public view returns (bool) {
        if (_voteId > votesLength) revert VoteDoesNotExist();

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
        if (isVoteOpen(_voteId)) {
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

        // check if the creator has voting power
        uint256 votingPower = token.getPastVotes(_msgSender(), snapshotBlock);
        if (votingPower == 0) revert NoVotingPower();

        voteId = votesLength;
        votesLength++;

        Vote storage vote_ = votes[voteId];
        vote_.startDate = uint64(block.number);
        vote_.snapshotBlock = snapshotBlock;
        vote_.supportRequiredPct = supportRequiredPct;
        vote_.minAcceptQuorumPct = minAcceptQuorumPct;
        vote_.votingPower = token.getPastTotalSupply(snapshotBlock);
        vote_.to = _to;
        vote_.value = _value;
        vote_.data = _data;
        vote_.operation = _operation;

        emit StartVote(voteId, _msgSender(), _metadata);

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
            executeVote(_voteId);
        }
    }

    /// @dev Calculates whether `_value` is more than a percentage `_pct` of `_total`
    function _isValuePct(
        uint256 _value,
        uint256 _total,
        uint256 _pct
    ) internal view returns (bool) {
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
            revert QuorumRequiredPctTooHigh();
        if (_supportRequiredPct > PCT_BASE) revert QuorumRequiredPctTooHigh();
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
            revert QuorumRequiredPctTooHigh();
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

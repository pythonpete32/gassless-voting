// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {VotingToken} from "../src/mocks/VotingToken.sol";
import {MetaVotingModule} from "../src/MetaVotingModule.sol";
import {Operation} from "../src/lib/Operation.sol";

contract MetaVotingTestBase is Test {
    // users
    address DAO = vm.addr(0xDA0);
    address bob = vm.addr(0xB0B);
    address alice = vm.addr(0xA11CE);
    address carol = vm.addr(0xCA401);
    address[] users = [bob, alice, carol];

    // contracts
    VotingToken public votingToken;
    MetaVotingModule public votingModule;

    // constants
    uint256 constant THOUSAND_TOKENS = 1000 * 10**18;
    uint64 public FIFTY_PERCENT = 50 * 10**16;
    uint64 public FIVE_PERCENT = 5 * 10**16;
    uint64 public VOTE_LENGTH = (60 * 60 * 24 * 7); // 1 week

    // test vote
    address to_ = bob;
    uint256 value_ = 1;
    bytes data_ = "0x";
    string metadata_ = "test vote";
    Operation operation = 0;

    function setUp() public {
        votingToken = new VotingToken();
        votingToken.mint(users, THOUSAND_TOKENS);
        votingModule = new MetaVotingModule();
        votingModule.initialize(
            votingToken,
            FIFTY_PERCENT,
            FIVE_PERCENT,
            VOTE_LENGTH
        );
        votingModule.transferOwnership(DAO);
    }
}

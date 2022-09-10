// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {VotingToken} from "../src/mocks/VotingToken.sol";
import {MetaVotingModule} from "../src/MetaVotingModule.sol";

contract AgreementFrameworkTestBase is Test {
    // users
    address bob = vm.addr(0xB0B);
    address alice = vm.addr(0xA11CE);
    address carol = vm.addr(0xCA401);
    address DAO = vm.addr(0xDA0);

    // contracts
    VotingToken public votingToken;
    MetaVotingModule public votingModule;

    // constants
    uint256 constant THOUSAND_TOKENS = 1000 * 10**18;
    uint64 public FIFTY_PERCENT = 50 * 10**16;
    uint64 public FIVE_PERCENT = 5 * 10**16;
    uint64 public VOTE_LENGTH = (60 * 60 * 24 * 7); // 1 week

    function setUp() public {
        votingToken = new VotingToken();
        votingToken.mint([alice, bob, carol], THOUSAND_TOKENS);
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

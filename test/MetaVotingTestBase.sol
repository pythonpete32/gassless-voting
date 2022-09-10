// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {VotingToken} from "../src/mocks/VotingToken.sol";
import {MetaVotingModule} from "../src/MetaVotingModule.sol";

contract AgreementFrameworkTestBase is Test {
    VotingToken public votingToken;
    MetaVotingModule public metaVotingModule;

    // voting params
    uint256 public FIFTY_PERCENT = 50 * 10**16;
    uint256 public FIVE_PERCENT = 5 * 10**16;
    uint256 public VOTE_LENGTH = (60 * 60 * 24 * 7); // 1 week

    function setUp() public {
        votingToken = new VotingToken();
        metaVotingModule = new MetaVotingModule();
    }
}

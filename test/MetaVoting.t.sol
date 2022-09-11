// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./MetaVotingTestBase.sol";

contract MetaVotingTest is MetaVotingTestBase {
    function testVotingPower() public {
        // everyone should have 10000 voting power
        assertEq(
            votingToken.getPastVotes(bob, block.number - 1),
            THOUSAND_TOKENS
        );
        assertEq(
            votingToken.getPastVotes(alice, block.number - 1),
            THOUSAND_TOKENS
        );
        assertEq(
            votingToken.getPastVotes(carol, block.number - 1),
            THOUSAND_TOKENS
        );
    }

    function testTotalVotes() public {
        assertEq(votingToken.getPastTotalSupply(block.number - 1), 3000 ether);
    }

    function testNewVote() public {
        vm.startPrank(alice);
        votingModule.newVote(to_, value_, data_, operation, metadata_);
        vm.stopPrank();
        (
            bool executed,
            uint64 startDate,
            uint64 snapshotBlock,
            uint64 support,
            uint64 quorum,
            uint256 yay,
            uint256 nay,
            uint256 power
        ) = votingModule.getVote(0);
        assertEq(executed, false);
        assertEq(startDate, block.timestamp + 1); // should look at this
        assertEq(snapshotBlock, block.number - 1);
        assertEq(support, FIFTY_PERCENT);
        assertEq(quorum, FIVE_PERCENT);
        assertEq(yay, votingToken.getPastVotes(alice, snapshotBlock));
        assertEq(nay, 0);
        assertEq(power, votingToken.getPastTotalSupply(snapshotBlock));
        assertFalse(votingModule.canExecute(0));
    }

    function testInitialisation() public {
        assertEq(votingModule.supportRequiredPct(), FIFTY_PERCENT);
        assertEq(votingModule.minAcceptQuorumPct(), FIVE_PERCENT);
        assertEq(votingModule.voteTime(), VOTE_LENGTH);
    }

    function testFailsOnReinitialisation() public {
        vm.startPrank(alice);
        votingModule.initialize(
            votingToken,
            FIFTY_PERCENT,
            FIVE_PERCENT,
            VOTE_LENGTH,
            31337
        );
        vm.stopPrank();
    }

    function testChangeRequiredSupport() public {}

    function testFailsChangingSupportLowerThanQuorum() public {
        vm.startPrank(alice);
        votingModule.changeSupportRequiredPct(FIVE_PERCENT - 1);
        vm.stopPrank();
    }

    function testFailsChangingSupportTo100orMore() public {
        vm.startPrank(alice);
        votingModule.changeSupportRequiredPct(100 * 10**16);
        vm.stopPrank();
    }

    function testCanChangeQuorum() public {}

    function testFailsChaingingQuorumMoreThanSupport() public {
        vm.startPrank(alice);
        votingModule.changeMinAcceptQuorumPct(FIFTY_PERCENT + 1);
        vm.stopPrank();
    }
}

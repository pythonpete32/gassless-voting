// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./MetaVotingTestBase.sol";

contract MetaVotingTest is MetaVotingTestBase {
    function testVotingPower() public {
        // everyone should have 10000 voting power
        console.log("blocknumber: %s", block.number);
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
        (, , , uint64 support, , uint256 yay, , uint256 power) = votingModule
            .getVote(0);
        console.log("A) yay:      %s", yay);
        console.log("B) power:    %s  ", power); // this is the problem. for some reason power is just the ves votes of the first voter
        console.log("C) support:  %s", support);

        assertFalse(votingModule.canExecute(0));
    }
}

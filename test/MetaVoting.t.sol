// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./MetaVotingTestBase.sol";

contract MetaVotingTest is MetaVotingTestBase {
    function testNewVote() public {
        vm.startPrank(alice);
        votingModule.newVote(to_, value_, data_, operation, metadata_);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/zodiac/common/Enum.sol";
import {TestAvatar} from "../src/mocks/TestAvatar.sol";
import {VotingToken} from "../src/mocks/VotingToken.sol";
import {MetaVotingModule} from "../src/MetaVotingModule.sol";

contract MetaVotingTestBase is Test {
    // users
    // address DAO = makeAddr("DAO");
    address bob = makeAddr("BOB");
    address alice = makeAddr("ALICE");
    address carol = makeAddr("CAROL");

    address[] users = [bob, alice, carol];

    // contracts
    VotingToken public votingToken;
    MetaVotingModule public votingModule;
    TestAvatar public avatar;

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
    Enum.Operation operation = Enum.Operation.Call;

    function setUp() public {
        emit log_uint(block.number);
        setupToken();
        setupDao();
    }

    function setupDao() internal {
        // deploy avatar
        avatar = new TestAvatar();

        // deploy safe
        votingModule = new MetaVotingModule();
        votingModule.initialize(
            address(avatar),
            votingToken,
            FIFTY_PERCENT,
            FIVE_PERCENT,
            VOTE_LENGTH,
            1337 // chain id
        );

        // enable voting module
        avatar.enableModule(address(votingModule));
        assertTrue(avatar.isModuleEnabled(address(votingModule)));

        // give the avatar some funds
        vm.deal(address(avatar), 1000 ether);
    }

    function setupToken() internal {
        votingToken = new VotingToken();
        votingToken.mint(users, THOUSAND_TOKENS);
        vm.prank(alice);
        votingToken.delegate(alice);
        changePrank(bob);
        votingToken.delegate(bob);
        changePrank(carol);
        votingToken.delegate(carol);
        vm.stopPrank();
        vm.roll(2);
    }
}

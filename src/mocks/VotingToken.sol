// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

contract VotingToken is ERC20, ERC20Permit, ERC20Votes {
    error MintArrayLengthMismatch();

    constructor() ERC20("Voting Token", "MTK") ERC20Permit("Voting Token") {
        // _mint(msg.sender, 1000000000000000000000000);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mint(address[] memory to, uint256[] memory amount) external {
        if (to.length != amount.length) revert MintArrayLengthMismatch();
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], amount[i]);
        }
    }

    function mint(address[] memory to, uint256 amount) external {
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], amount);
        }
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {GnosisSafeL2} from "safe-contracts/GnosisSafeL2.sol"; //singleton
import {GnosisSafeProxyFactory} from "safe-contracts/proxies/GnosisSafeProxyFactory.sol"; //factory

contract Deploy is Script {
    GnosisSafeL2 singleton =
        GnosisSafeL2(payable(0x3E5c63644E683549055b9Be8653de26E0B4CD36E));
    GnosisSafeProxyFactory factory =
        GnosisSafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
    address public _depolyer = 0x0533F9d586ABd3334a0E90cA162602D6574F0493;
    address public ZERO = 0x0000000000000000000000000000000000000000;

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();
        vm.label(0x3E5c63644E683549055b9Be8653de26E0B4CD36E, "singleton");
        vm.label(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2, "factory");

        string
            memory setupSig = "setup(address[],uint256,address,bytes,address,address,uint256,address)";
        // get function call data from singleton
        bytes memory setupdata = abi.encodeWithSignature(
            setupSig,
            [_depolyer],
            1,
            ZERO,
            "0x",
            ZERO,
            ZERO,
            0,
            0
        );
        factory.createProxy(address(singleton), setupdata);

        vm.stopBroadcast();
    }
}

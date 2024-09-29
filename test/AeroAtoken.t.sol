// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test, console} from "../lib/forge-std/src/Test.sol";

abstract contract AeroATokenTest is Test {
    address public owner = makeAddr("owner");
    address public whale = makeAddr("whale");
    address public ant = makeAddr("ant");
    address public governance = makeAddr("governance");

    function setUp() public {
        // TODO: setup the fork network and the fork block
        // TODO: upgrade the atoken on base mainnet to the new AeroAToken
    }

    // TODO: add a fork test to check deposit
    // TODO: add a fork test to check withdrawal
    // TODO: add a fork test to check liquidations
    // TODO: add a fork test to check rewards
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test, console} from "../lib/forge-std/src/Test.sol";

abstract contract AeroATokenTest is Test {
    address public owner = makeAddr("owner");
    address public whale = makeAddr("whale");
    address public ant = makeAddr("ant");
    address public governance = makeAddr("governance");

    // TODO: Add more tests

    // add a fork test to check deposit
    // add a fork test to check withdrawal
    // add a fork test to check liquidations
    // add a fork test to check rewards
}

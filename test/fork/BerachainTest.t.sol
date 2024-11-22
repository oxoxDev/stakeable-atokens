// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IPool} from "lib/core-contracts/contracts/interfaces/IPool.sol";
import {IERC20} from "lib/core-contracts/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {Test, Vm, console } from "lib/forge-std/src/Test.sol";

contract BerachainTest is Test {
    IPool public pool = IPool(0x431B8680f2BbDEB51ee366C51Db3aC60d58a3789);
    IERC20 public HONEY = IERC20(0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03);
    address HONEY_ATOKEN = 0x189BE736aB64f25b5eb524Ee2Af08aAbE8E38187; 
    address RewardsVault = 0x9f37B421A0294cA7A568D1cb1F6562D2443891dC;
    address USER = 0xF152dA370FA509f08685Fa37a09BA997E41Fb65b; 

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("sepolia"));
    }

    function testSupply() public {
        uint256 amount = 89703958322112092315;
        vm.startPrank(USER);
        HONEY.approve(address(pool), amount);
        pool.supply(address(HONEY), amount, USER, 0);

        vm.assertGt(IERC20(HONEY_ATOKEN).balanceOf(USER), 0);
    }
}
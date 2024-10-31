// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, console, Vm} from "lib/forge-std/src/Test.sol";

import {IAToken, IPool, IERC20} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";

import {IPoolConfigurator, ConfiguratorInputTypes} from "@zerolendxyz/core-v3/contracts/interfaces/IPoolConfigurator.sol";
import {ATokenCornStaking, ICornStakingVault} from "contracts/corn/ATokenCornStaking.sol";

contract CornATokenTest is Test {
    IPoolConfigurator public constant POOL_CONFIGURATOR = IPoolConfigurator(0x6864B4DBfb0c2Ee6d1135cd7f5f896eCEF03Ff93);
    address public constant CBBTC_ATOKEN_PROXY = 0x0Ea724A5571ED15209dD173B77fE3cDa3F371Fe3;
    address public constant WBTC_ATOKEN_PROXY = 0x1d5f4e8c842a5655f9B722cAC40C6722794b75f5;
    address public constant ADMIN = 0x00000Ab6Ee5A6c1a7Ac819b01190B020F7c6599d;
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    IPool public constant pool = IPool(0xCD2b31071119D7eA449a9D211AC8eBF7Ee97F987);
    address public constant CORN_STAKING_VAULT = 0x8bc93498b861fd98277c3b51d240e7E56E48F23c;
    address public ALICE = makeAddr("Alice");
    // AToken configs
    address public constant TREASURY = 0x4E88E72bd81C7EA394cB410296d99987c3A242fE;
    address public constant INCENTIVES_CONTROLLER = 0x938e23c10C501CE5D42Bc516eCFDf5AbD9C51d2b;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    function setUp() public {
        uint256 fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);

        // deploy the new AToken with enabled corn staking
        ATokenCornStaking aToken = new ATokenCornStaking(pool);

        // update the AToken implementation in the pool addresses provider
        vm.startPrank(ADMIN, ADMIN);
        POOL_CONFIGURATOR.updateAToken(
            ConfiguratorInputTypes.UpdateATokenInput({
                asset: cbBTC,
                treasury: TREASURY,
                incentivesController: INCENTIVES_CONTROLLER,
                name: "BTC ZeroLend WBTC",
                symbol: "z0BTCWBTC",
                implementation: address(aToken),
                params: abi.encode(CORN_STAKING_VAULT)
            })
        );

        // POOL_CONFIGURATOR.updateAToken(
        //     ConfiguratorInputTypes.UpdateATokenInput({
        //         asset: WBTC,
        //         treasury: TREASURY,
        //         incentivesController: INCENTIVES_CONTROLLER,
        //         name: "BTC ZeroLend WBTC",
        //         symbol: "z0BTCWBTC",
        //         implementation: address(aToken),
        //         params: abi.encode(CORN_STAKING_VAULT)
        //     })
        // );

        // call the stakeUnderlyingInCorn from the POOL ADMIN to send 
        // all the underlying cbBTC to corn vault
        ATokenCornStaking(CBBTC_ATOKEN_PROXY).stakeUnderlyingInCorn();
        // ATokenCornStaking(WBTC_ATOKEN_PROXY).stakeUnderlyingInCorn();
        vm.stopPrank();

        // verify the upgraed AToken implementation
        assertEq(address(ATokenCornStaking(CBBTC_ATOKEN_PROXY).cornVault()), CORN_STAKING_VAULT);

        // fund Alice with some cbBTC and WBTC
        deal(cbBTC, ALICE, 1000000000000000000);
        deal(WBTC, ALICE, 1000000000000000000);

        
    }

    function test_cbBTC_CornStaking_Supply() public {
        vm.startPrank(ALICE, ALICE);
        IERC20(cbBTC).approve(address(pool), 1000000000000000000);
        // supply some cbBTC
        pool.supply(cbBTC, 1000000000000000000, ALICE, 0);

        // verify the balance of ATokens for ALICE
        assertEq(IAToken(CBBTC_ATOKEN_PROXY).balanceOf(ALICE), 1000000000000000000);

        //verify the stake in corn vault
        assertEq(ICornStakingVault(CORN_STAKING_VAULT).sharesOf(CBBTC_ATOKEN_PROXY, cbBTC), 1000000000000000000);
    }

    function test_cbBTC_CornStaking_Borrow() public {
        vm.startPrank(ALICE, ALICE);
        IERC20(WBTC).approve(address(pool), 1000000000000000000);
        // supply some WBTC
        pool.supply(WBTC, 1000000000000000000, ALICE, 0);

        // verify the balance of ATokens for ALICE
        assertEq(IAToken(WBTC_ATOKEN_PROXY).balanceOf(ALICE), 1000000000000000000);

        //donot verify the stake in corn vault since WBTC not yet whitelisted in corn
        uint256 sharesBeforeBorrow = ICornStakingVault(CORN_STAKING_VAULT).sharesOf(CBBTC_ATOKEN_PROXY, cbBTC);
        // borrow some cbBTC
        pool.borrow(cbBTC, 1000000000000000000 / 1000, 2, 0, ALICE);

        uint256 sharesAfterBorrow = ICornStakingVault(CORN_STAKING_VAULT).sharesOf(CBBTC_ATOKEN_PROXY, cbBTC);
        // verify the stake in corn vault is decrease post borrow
        assertLt(sharesAfterBorrow, sharesBeforeBorrow);

    }
    // update the ATokens
    // call a supply borrow repay and withdraw
}
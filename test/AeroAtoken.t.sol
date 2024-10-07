// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Importing necessary libraries and contracts
import {Test, console} from "../lib/forge-std/src/Test.sol";

import {IPool} from "@zerolendxyz/core-v3/contracts/interfaces/IPool.sol";
import {ATokenAerodrome, IAerodromeGauge} from "contracts/aerodrome/ATokenAerodrome.sol";
import {AeroEmissionsStrategy} from "contracts/aerodrome/AeroEmissionsStrategy.sol";

import {IAToken, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "@zerolendxyz/core-v3/contracts/interfaces/IPoolConfigurator.sol";
import {IPoolAddressesProvider} from "@zerolendxyz/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

// Interface Definitions

// Test Contract
contract AeroATokenTest is Test {
    // Addresses
    address public owner = makeAddr("owner");
    address public whale = makeAddr("whale");
    address public ant = makeAddr("ant");
    address public lpWhale = 0xc1342eE2B9d9E8f1B7A612131b69cf03261957E0;
    address public governance = makeAddr("governance");

    // Constants
    uint256 internal mintAmount = 100 * 10 ** 18;
    uint256 internal INDEX = 10 ** 27;
    uint8 internal DECIMALS = 18;

    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");

    // Contract Addresses
    address internal AEROUSDC_LP_ATOKEN =
        0xB6ccD85f92FB9a8bBC99b55091855714aAeEBFEE;
    address internal AEROUSDC_LP = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d;
    address internal POOL_ADDRESS_PROVIDER =
        0x5213ab3997a596c75Ac6ebF81f8aEb9cf9A31007;
    address internal EMISSIONS_MANAGER =
        0x0f9bfa294bE6e3CA8c39221Bb5DFB88032C8936E;
    address internal INCENTIVES_CONTROLLER =
        0x73a7a4B40f3FE11e0BcaB5538c75D3B984082CAE;
    address internal AERODROME = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal TREASURY = 0x6F5Ae60d89dbbc4EeD4B08d08A68dD5679Ac61B4;
    address internal DEPLOYER = 0x0F6e98A756A40dD050dC78959f45559F98d3289d;
    address internal GAUGE = 0x4F09bAb2f0E15e2A078A227FE1537665F55b8360;
    address internal POOL_CONFIGURATOR =
        0xB40e21D5cD8E9E192B0da3107883f8b0f4e4e6E3;
    address internal POOL = 0x766f21277087E18967c1b10bF602d8Fe56d0c671;
    address internal AERO_ORACLE = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0;

    // Contract Interfaces
    IPoolAddressesProvider public provider =
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER);
    IERC20 public aero = IERC20(AERODROME);
    ATokenAerodrome public aToken = ATokenAerodrome(AEROUSDC_LP_ATOKEN);
    IAerodromeGauge public gauge = IAerodromeGauge(GAUGE);
    IPool public pool = IPool(POOL);
    AeroEmissionsStrategy public strategy;
    IERC20 public underlying = IERC20(AEROUSDC_LP);

    IPoolConfigurator public poolConfigurator =
        IPoolConfigurator(POOL_CONFIGURATOR);

    // Setup Function
    function setUp() public {
        uint256 fork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(20755363);

        // Deploy a new ATokenAerodrome instance
        ATokenAerodrome newAToken = new ATokenAerodrome(pool);

        // Deploy and initialize AeroEmissionsStrategy
        strategy = new AeroEmissionsStrategy();
        strategy.initialize(
            DEPLOYER,
            AERODROME,
            AERO_ORACLE,
            EMISSIONS_MANAGER,
            INCENTIVES_CONTROLLER
        );

        // Update the AToken in the Pool Configurator
        vm.prank(TREASURY);
        poolConfigurator.updateAToken(
            ConfiguratorInputTypes.UpdateATokenInput({
                asset: AEROUSDC_LP,
                treasury: TREASURY,
                incentivesController: INCENTIVES_CONTROLLER,
                name: "AeroAToken",
                symbol: "AeroAToken",
                implementation: address(newAToken),
                params: abi.encode(GAUGE, address(strategy))
            })
        );

        // Verify Initialization
        assertEq(address(aToken.gauge()), GAUGE, "!gauge");
        assertEq(address(aToken.aero()), AERODROME, "!aero");
        assertEq(
            address(aToken.aeroEmissionReceiver()),
            address(strategy),
            "!strategy"
        );

        // give labels
        vm.label(lpWhale, "lpWhale");
        vm.label(AEROUSDC_LP_ATOKEN, "AEROUSDC_LP_ATOKEN");
        vm.label(AEROUSDC_LP, "AEROUSDC_LP");
        vm.label(POOL_ADDRESS_PROVIDER, "POOL_ADDRESS_PROVIDER");
        vm.label(EMISSIONS_MANAGER, "EMISSIONS_MANAGER");
        vm.label(INCENTIVES_CONTROLLER, "INCENTIVES_CONTROLLER");
        vm.label(AERODROME, "AERODROME");
        vm.label(TREASURY, "TREASURY");
        vm.label(DEPLOYER, "DEPLOYER");
        vm.label(GAUGE, "GAUGE");
        vm.label(POOL_CONFIGURATOR, "POOL_CONFIGURATOR");
        vm.label(POOL, "POOL");
        vm.label(AERO_ORACLE, "AERO_ORACLE");
    }

    function test_initial_sweep() public {
        uint256 balanceInGaugeBefore = gauge.balanceOf(AEROUSDC_LP_ATOKEN);
        aToken.depositToGauge();
        uint256 balanceInGaugeAfter = gauge.balanceOf(AEROUSDC_LP_ATOKEN);

        assertEq(balanceInGaugeBefore, 0, "!balanceInGaugeBefore");
        assertGt(
            balanceInGaugeAfter,
            balanceInGaugeBefore,
            "Gauge balance did not increase after deposit"
        );
    }

    // Test: Deposit Functionality
    function test_deposit() public {
        aToken.depositToGauge();
        assertGt(gauge.balanceOf(AEROUSDC_LP_ATOKEN), 0);
        assertEq(aero.balanceOf(AEROUSDC_LP_ATOKEN), 0);

        // move time forward to accumulate AERO rewards
        vm.warp(block.timestamp + 10 days);

        // Record initial balances
        uint256 balanceInGaugeBefore = gauge.balanceOf(AEROUSDC_LP_ATOKEN);
        uint256 balance = underlying.balanceOf(lpWhale);

        // deposit LP tokens into the lending pool
        vm.startPrank(lpWhale);
        underlying.approve(POOL, balance);
        pool.deposit(
            AEROUSDC_LP, // address asset,
            balance, // uint256 amount,
            lpWhale, // address onBehalfOf,
            0 // uint16 referralCode
        );
        vm.stopPrank();

        // all tokens should be staked in the gauge; nothing should be there in the atoken
        assertEq(underlying.balanceOf(AEROUSDC_LP_ATOKEN), 0);

        // gauge deposit for the atoken should have increased
        assertGt(gauge.balanceOf(AEROUSDC_LP_ATOKEN), balanceInGaugeBefore);

        // the atokens should have received rewards (later claimable by the strategy)
        assertGt(aero.balanceOf(AEROUSDC_LP_ATOKEN), 0);
    }

    // Test: Withdrawal Functionality
    function test_withdraw() public {
        // Allocate staking tokens to AERO_ATOKEN_PROXY
        deal(address(underlying), AEROUSDC_LP_ATOKEN, mintAmount);

        // Approve GAUGE to spend staking tokens
        vm.startPrank(AEROUSDC_LP_ATOKEN, AEROUSDC_LP_ATOKEN);
        underlying.approve(GAUGE, mintAmount);
        vm.stopPrank();

        // Record initial balances
        uint256 balanceAtokenBefore = gauge.balanceOf(AEROUSDC_LP_ATOKEN);
        uint256 balanceStrategyBefore = aero.balanceOf(address(strategy));

        // Perform deposit
        vm.startPrank(POOL, POOL);
        aToken.mint(ant, ant, mintAmount, INDEX);
        vm.stopPrank();

        uint256 balanceInGaugeAfterDeposit = gauge.balanceOf(
            AEROUSDC_LP_ATOKEN
        );
        assertGt(
            balanceAtokenBefore,
            balanceStrategyBefore,
            "Gauge balance did not increase after deposit"
        );

        // Perform withdrawal
        vm.startPrank(POOL, POOL);
        aToken.burn(ant, AEROUSDC_LP_ATOKEN, mintAmount, INDEX);
        vm.stopPrank();

        uint256 balanceInGaugeAfterWithdrawal = gauge.balanceOf(
            AEROUSDC_LP_ATOKEN
        );
        assertLt(
            balanceInGaugeAfterWithdrawal,
            balanceInGaugeAfterDeposit,
            "Gauge balance did not decrease after withdrawal"
        );
    }

    // Test: Reward Distribution
    function test_rewards() public {
        // Allocate staking tokens to AERO_ATOKEN_PROXY
        deal(address(underlying), AEROUSDC_LP_ATOKEN, mintAmount);

        // Approve GAUGE to spend staking tokens
        vm.startPrank(AEROUSDC_LP_ATOKEN, AEROUSDC_LP_ATOKEN);
        underlying.approve(GAUGE, mintAmount);
        vm.stopPrank();

        // Record initial emission receiver balance
        uint256 balanceEmissionReceiverBefore = aero.balanceOf(
            address(strategy)
        );

        // Perform deposit which should trigger reward distribution
        vm.startPrank(POOL, POOL);
        aToken.mint(ant, ant, mintAmount, INDEX);
        vm.stopPrank();

        // Record post-deposit emission receiver balance
        uint256 balanceEmissionReceiverAfter = aero.balanceOf(
            address(strategy)
        );

        // Assert that rewards have been received
        assertGt(
            balanceEmissionReceiverAfter,
            balanceEmissionReceiverBefore,
            "Emission receiver did not receive rewards"
        );
    }

    // TODO: Add additional fork tests for withdrawal, liquidations, and edge cases
}

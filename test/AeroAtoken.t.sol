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
    address public governance = makeAddr("governance");

    // Constants
    uint256 internal mintAmount = 100 * 10 ** 18;
    uint256 internal INDEX = 10 ** 27;
    uint8 internal DECIMALS = 18;

    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");

    // Contract Addresses
    address internal AERO_ATOKEN_PROXY =
        0x3c2b86d6308c24632Bb8716ED013567C952b53AE;
    address internal POOL_ADDRESS_PROVIDER =
        0x5213ab3997a596c75Ac6ebF81f8aEb9cf9A31007;
    address internal AAVE_EMISSIONS_MANAGER =
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
    IERC20 public aeroToken = IERC20(AERODROME);

    ATokenAerodrome public aToken = ATokenAerodrome(AERO_ATOKEN_PROXY);

    IPoolAddressesProvider public addressProvider =
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER);

    IAerodromeGauge public gauge = IAerodromeGauge(GAUGE);

    IPool public pool = IPool(POOL);

    AeroEmissionsStrategy public emissionStrategy;

    IERC20 public stakingToken = IERC20(gauge.stakingToken());

    IPoolConfigurator public poolConfigurator =
        IPoolConfigurator(POOL_CONFIGURATOR);

    // Setup Function
    function setUp() public {
        uint256 fork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(19_141_574);

        // Deploy a new ATokenAerodrome instance
        ATokenAerodrome newAToken = new ATokenAerodrome(pool);

        // Deploy and initialize AeroEmissionsStrategy
        emissionStrategy = new AeroEmissionsStrategy();
        emissionStrategy.initialize(
            DEPLOYER,
            AERODROME,
            AERO_ORACLE,
            AAVE_EMISSIONS_MANAGER,
            INCENTIVES_CONTROLLER
        );

        // Update the AToken in the Pool Configurator
        vm.prank(TREASURY);
        poolConfigurator.updateAToken(
            ConfiguratorInputTypes.UpdateATokenInput({
                asset: AERODROME,
                treasury: TREASURY,
                incentivesController: INCENTIVES_CONTROLLER,
                name: "AeroAToken",
                symbol: "AeroAToken",
                implementation: address(newAToken),
                params: abi.encode(GAUGE, address(emissionStrategy))
            })
        );

        // Verify Initialization
        assertEq(address(aToken.gauge()), GAUGE, "Gauge address mismatch");
        assertEq(
            address(aToken.aero()),
            AERODROME,
            "AERO token address mismatch"
        );
        assertEq(
            address(aToken.aeroEmissionReceiver()),
            address(emissionStrategy),
            "Emission receiver address mismatch"
        );
    }

    // Test: Deposit Functionality
    function test_deposit() public {
        // Allocate staking tokens to AERO_ATOKEN_PROXY
        deal(address(stakingToken), AERO_ATOKEN_PROXY, mintAmount);

        // Approve GAUGE to spend staking tokens
        vm.startPrank(AERO_ATOKEN_PROXY, AERO_ATOKEN_PROXY);
        stakingToken.approve(GAUGE, mintAmount);
        vm.stopPrank();

        // Record initial balances
        uint256 balanceInGaugeBefore = gauge.balanceOf(AERO_ATOKEN_PROXY);
        uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(
            address(emissionStrategy)
        );

        // Perform deposit
        vm.startPrank(POOL, POOL);
        aToken.mint(ant, ant, mintAmount, INDEX);
        vm.stopPrank();

        // Assert post-deposit balances
        assertGt(
            gauge.balanceOf(AERO_ATOKEN_PROXY),
            balanceInGaugeBefore,
            "Gauge balance did not increase"
        );
        assertGt(
            aeroToken.balanceOf(address(emissionStrategy)),
            balanceEmissionReceiverBefore,
            "Emission receiver balance did not increase"
        );
    }

    // Test: Withdrawal Functionality
    function test_withdraw() public {
        // Allocate staking tokens to AERO_ATOKEN_PROXY
        deal(address(stakingToken), AERO_ATOKEN_PROXY, mintAmount);

        // Approve GAUGE to spend staking tokens
        vm.startPrank(AERO_ATOKEN_PROXY, AERO_ATOKEN_PROXY);
        stakingToken.approve(GAUGE, mintAmount);
        vm.stopPrank();

        // Record initial balances
        uint256 balanceInGaugeBefore = gauge.balanceOf(AERO_ATOKEN_PROXY);
        uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(
            address(emissionStrategy)
        );

        // Perform deposit
        vm.startPrank(POOL, POOL);
        aToken.mint(ant, ant, mintAmount, INDEX);
        vm.stopPrank();

        uint256 balanceInGaugeAfterDeposit = gauge.balanceOf(AERO_ATOKEN_PROXY);
        assertGt(
            balanceInGaugeAfterDeposit,
            balanceInGaugeBefore,
            "Gauge balance did not increase after deposit"
        );

        // Perform withdrawal
        vm.startPrank(POOL, POOL);
        aToken.burn(ant, AERO_ATOKEN_PROXY, mintAmount, INDEX);
        vm.stopPrank();

        uint256 balanceInGaugeAfterWithdrawal = gauge.balanceOf(
            AERO_ATOKEN_PROXY
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
        deal(address(stakingToken), AERO_ATOKEN_PROXY, mintAmount);

        // Approve GAUGE to spend staking tokens
        vm.startPrank(AERO_ATOKEN_PROXY, AERO_ATOKEN_PROXY);
        stakingToken.approve(GAUGE, mintAmount);
        vm.stopPrank();

        // Record initial emission receiver balance
        uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(
            address(emissionStrategy)
        );

        // Perform deposit which should trigger reward distribution
        vm.startPrank(POOL, POOL);
        aToken.mint(ant, ant, mintAmount, INDEX);
        vm.stopPrank();

        // Record post-deposit emission receiver balance
        uint256 balanceEmissionReceiverAfter = aeroToken.balanceOf(
            address(emissionStrategy)
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

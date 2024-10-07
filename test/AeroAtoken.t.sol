// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Importing necessary libraries and contracts
import {Test} from '../lib/forge-std/src/Test.sol';

import {IPool} from '@zerolendxyz/core-v3/contracts/interfaces/IPool.sol';
import {ATokenAerodrome, IAerodromeGauge} from 'contracts/aerodrome/ATokenAerodrome.sol';
import {AeroEmissionsStrategy} from 'contracts/aerodrome/AeroEmissionsStrategy.sol';
import {Constants} from 'test/Constants.sol';

// Interface Definitions

interface IAddressProvider {
  function getPoolConfigurator() external view returns (address);
  function getPool() external view returns (address);
}

interface IERC20 {
  function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
}

interface IAToken {
  function decimals() external view returns (uint8);
  function gauge() external view returns (address);
  function aero() external view returns (address);
  function aeroEmissionReceiver() external view returns (address);
  function mint(address caller, address onBehalfOf, uint256 amount, uint256 index) external returns (bool ret);
  function burn(address from, address receiverOfUnderlying, uint256 amount, uint256 index) external;
  function depositToGauge() external;
}

interface IPoolConfigurator {
  struct UpdateATokenInput {
    address asset;
    address treasury;
    address incentivesController;
    string name;
    string symbol;
    address implementation;
    bytes params;
  }

  function updateAToken(UpdateATokenInput calldata input) external;
}

// Test Contract
contract AeroATokenTest is Test {
  // Addresses
  address public owner = makeAddr('owner');
  address public whale = makeAddr('whale');
  address public ant = makeAddr('ant');
  address public governance = makeAddr('governance');

  // Constants
  uint256 public constant mintAmount = 100 * 10 ** 18;
  uint256 public constant INDEX = 10 ** 27;
  uint8 public constant DECIMALS = 18;

  // Contract Interfaces
  IERC20 public aeroToken = IERC20(Constants.AERODROME);
  IAToken public aToken = IAToken(Constants.AERO_ATOKEN_PROXY);
  IAddressProvider public addressProvider = IAddressProvider(Constants.POOL_ADDRESS_PROVIDER);
  IAerodromeGauge public gauge = IAerodromeGauge(Constants.GAUGE);
  IPool public pool = IPool(Constants.POOL);
  AeroEmissionsStrategy public emissionStrategy;
  IERC20 public stakingToken = IERC20(gauge.stakingToken());
  IPoolConfigurator public poolConfigurator;

  // Setup Function
  function setUp() public {
    // Initialize Pool Configurator
    poolConfigurator = IPoolConfigurator(Constants.POOL_CONFIGURATOR);

    // Deploy a new ATokenAerodrome instance
    ATokenAerodrome newAToken = new ATokenAerodrome(pool);

    // Deploy and initialize AeroEmissionsStrategy
    emissionStrategy = new AeroEmissionsStrategy();
    emissionStrategy.initialize(
      Constants.DEPLOYER, Constants.AERODROME, Constants.AERO_ORACLE, Constants.AAVE_EMISSIONS_MANAGER, Constants.INCENTIVES_CONTROLLER
    );

    // Update the AToken in the Pool Configurator
    vm.prank(Constants.TREASURY);
    poolConfigurator.updateAToken(
      IPoolConfigurator.UpdateATokenInput({
        asset: Constants.AERODROME,
        treasury: Constants.TREASURY,
        incentivesController: Constants.INCENTIVES_CONTROLLER,
        name: 'AeroAToken',
        symbol: 'AeroAToken',
        implementation: address(newAToken),
        params: abi.encode(Constants.GAUGE, address(emissionStrategy))
      })
    );

    // Verify Initialization
    assertEq(aToken.gauge(), Constants.GAUGE, 'Gauge address mismatch');
    assertEq(aToken.aero(), Constants.AERODROME, 'AERO token address mismatch');
    assertEq(aToken.aeroEmissionReceiver(), address(emissionStrategy), 'Emission receiver address mismatch');
  }

  // Test: Deposit Functionality
  function test_deposit() public {
    // Allocate staking tokens to AERO_ATOKEN_PROXY
    deal(address(stakingToken), Constants.AERO_ATOKEN_PROXY, mintAmount);

    // Approve GAUGE to spend staking tokens
    vm.startPrank(Constants.AERO_ATOKEN_PROXY, Constants.AERO_ATOKEN_PROXY);
    stakingToken.increaseAllowance(Constants.GAUGE, mintAmount);
    vm.stopPrank();

    // Record initial balances
    uint256 balanceInGaugeBefore = gauge.balanceOf(Constants.AERO_ATOKEN_PROXY);
    uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(address(emissionStrategy));

    // Perform deposit
    vm.startPrank(Constants.POOL, Constants.POOL);
    aToken.mint(ant, ant, mintAmount, INDEX);
    vm.stopPrank();

    // Assert post-deposit balances
    assertGt(gauge.balanceOf(Constants.AERO_ATOKEN_PROXY), balanceInGaugeBefore, 'Gauge balance did not increase');
    assertGt(aeroToken.balanceOf(address(emissionStrategy)), balanceEmissionReceiverBefore, 'Emission receiver balance did not increase');
  }

  // Test: Withdrawal Functionality
  function test_withdraw() public {
    // Allocate staking tokens to AERO_ATOKEN_PROXY
    deal(address(stakingToken), Constants.AERO_ATOKEN_PROXY, mintAmount);

    // Approve GAUGE to spend staking tokens
    vm.startPrank(Constants.AERO_ATOKEN_PROXY, Constants.AERO_ATOKEN_PROXY);
    stakingToken.increaseAllowance(Constants.GAUGE, mintAmount);
    vm.stopPrank();

    // Record initial balances
    uint256 balanceInGaugeBefore = gauge.balanceOf(Constants.AERO_ATOKEN_PROXY);
    uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(address(emissionStrategy));

    // Perform deposit
    vm.startPrank(Constants.POOL, Constants.POOL);
    aToken.mint(ant, ant, mintAmount, INDEX);
    vm.stopPrank();

    uint256 balanceInGaugeAfterDeposit = gauge.balanceOf(Constants.AERO_ATOKEN_PROXY);
    assertGt(balanceInGaugeAfterDeposit, balanceInGaugeBefore, 'Gauge balance did not increase after deposit');

    // Perform withdrawal
    vm.startPrank(Constants.POOL, Constants.POOL);
    aToken.burn(ant, Constants.AERO_ATOKEN_PROXY, mintAmount, INDEX);
    vm.stopPrank();

    uint256 balanceInGaugeAfterWithdrawal = gauge.balanceOf(Constants.AERO_ATOKEN_PROXY);
    assertLt(balanceInGaugeAfterWithdrawal, balanceInGaugeAfterDeposit, 'Gauge balance did not decrease after withdrawal');
  }

  // Test: Reward Distribution
  function test_rewards() public {
    // Allocate staking tokens to AERO_ATOKEN_PROXY
    deal(address(stakingToken), Constants.AERO_ATOKEN_PROXY, mintAmount);

    // Approve GAUGE to spend staking tokens
    vm.startPrank(Constants.AERO_ATOKEN_PROXY, Constants.AERO_ATOKEN_PROXY);
    stakingToken.increaseAllowance(Constants.GAUGE, mintAmount);
    vm.stopPrank();

    // Record initial emission receiver balance
    uint256 balanceEmissionReceiverBefore = aeroToken.balanceOf(address(emissionStrategy));

    // Perform deposit which should trigger reward distribution
    vm.startPrank(Constants.POOL, Constants.POOL);
    aToken.mint(ant, ant, mintAmount, INDEX);
    vm.stopPrank();

    // Record post-deposit emission receiver balance
    uint256 balanceEmissionReceiverAfter = aeroToken.balanceOf(address(emissionStrategy));

    // Assert that rewards have been received
    assertGt(balanceEmissionReceiverAfter, balanceEmissionReceiverBefore, 'Emission receiver did not receive rewards');
  }

  // TODO: Add additional fork tests for withdrawal, liquidations, and edge cases
}

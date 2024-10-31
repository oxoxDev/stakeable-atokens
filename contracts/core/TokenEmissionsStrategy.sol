// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IPool} from '@zerolendxyz/core-v3/contracts/interfaces/IPool.sol';
import {
  IEACAggregatorProxy,
  IEmissionManager,
  ITransferStrategyBase,
  RewardsDataTypes
} from '@zerolendxyz/periphery-v3/contracts/rewards/interfaces/IEmissionManager.sol';

interface IATokenCustom {
  function refreshRewards() external;
}

/// @notice TokenEmissionsStrategy is a contract that allows the emission of rewards to be notified to the EmissionManager
/// @dev This contract should be the emission admin of the reward tokens to be notified
/// @dev The aTokens need to give approval to this contract to claim the rewards
contract TokenEmissionsStrategy is Initializable, Ownable, ITransferStrategyBase {
  using SafeERC20 for IERC20;

  /// @dev The incentive controller contract used to transfer the rewards
  address public incentiveController;

  /// @dev The emission manager contract used to allocate emissions
  IEmissionManager public emissionManager;

  /// @dev The lending pool contract
  IPool public pool;

  event Whitelisted(address indexed who, bool isWhitelisted);

  /// @dev Mapping to keep track of the rewards that have been received
  mapping(address => mapping(IERC20 => uint256)) public emissionsReceived;

  /// @dev Mapping to keep track of the last time the EmissionManager was notified
  mapping(address => uint256) public lastNotified;

  /// @dev Mapping to keep track of the whitelisted addresses
  mapping(address => bool) public whitelisted;

  /// @dev storage gap to avoid future storage layout conflicts
  uint256[50] private __gap;

  modifier onlyIncentivesController() {
    require(incentiveController == msg.sender, 'CALLER_NOT_INCENTIVES_CONTROLLER');
    _;
  }

  // constructor() {
  //     _disableInitializers();
  // }

  function initialize(address _owner, address _pool, address _emissionManager, address _incentiveController) public initializer {
    emissionManager = IEmissionManager(_emissionManager);
    incentiveController = _incentiveController;
    whitelisted[_owner] = true;
    pool = IPool(_pool);
    _transferOwnership(_owner);
  }

  /// @dev Whitelists an address to be used by the EmissionManager
  function whitelist(address _reserve, bool _what) external onlyOwner {
    whitelisted[_reserve] = _what;
    emit Whitelisted(_reserve, _what);
  }

  /// @dev Helper function to get the aToken address for a reserve
  function getAToken(address _reserve) public view returns (address) {
    return pool.getReserveData(_reserve).aTokenAddress;
  }

  /// @notice Notifies the EmissionManager of the rewards that are available for a specific reserve
  /// @dev can only be called by a whitelisted address
  /// @param _reserve The reserve for which the rewards are being notified
  /// @param _token The reward token that is being notified
  /// @param _oracle The oracle that will be used to calculate the USD value of the rewards
  function notifyEmissionManager(address _reserve, IERC20 _token, address _oracle) external {
    require(whitelisted[_reserve], '!whitelist reserve');
    require(whitelisted[msg.sender], '!whitelist sender');
    require(whitelisted[address(_token)], '!whitelist token');
    require(whitelisted[_oracle], '!whitelist oracle');
    address aTokenAddress = getAToken(_reserve);

    // force the aToken to claim any pending rewards
    IATokenCustom(aTokenAddress).refreshRewards();

    // check if the emission manager was notified in the last 24 hours
    // with a 10 minute buffer.
    require(lastNotified[_reserve] + 1 days - 10 minutes <= block.timestamp, 'too soon to notify');

    RewardsDataTypes.RewardsConfigInput[] memory config = new RewardsDataTypes.RewardsConfigInput[](1);
    config[0] = _notifyEmissionManager(aTokenAddress, _token, _oracle);
    emissionManager.configureAssets(config);

    // keep track of the last time the emission manager was notified
    // so that we don't end up spamming it and losing the previously allocated
    // rewards.
    lastNotified[_reserve] = block.timestamp;
  }

  function _notifyEmissionManager(
    address aTokenAddress,
    IERC20 token,
    address oracle
  ) internal returns (RewardsDataTypes.RewardsConfigInput memory) {
    // check if there are any pending emissions
    uint256 pending = token.balanceOf(aTokenAddress);
    require(pending > 0, 'no emissions to notify');

    // retrieve the pending emissions from the atoken
    token.transferFrom(aTokenAddress, address(this), pending);
    emissionsReceived[aTokenAddress][token] += pending;

    // prepare the data to be sent to the emission manager
    RewardsDataTypes.RewardsConfigInput memory data = RewardsDataTypes.RewardsConfigInput({
      emissionPerSecond: uint88(pending / 1 days),
      totalSupply: IERC20(aTokenAddress).totalSupply(),
      distributionEnd: uint32(block.timestamp + 1 days),
      asset: aTokenAddress,
      reward: address(token),
      rewardOracle: IEACAggregatorProxy(oracle),
      transferStrategy: ITransferStrategyBase(address(this))
    });

    return data;
  }

  /// @inheritdoc ITransferStrategyBase
  function performTransfer(
    address to,
    address reward,
    uint256 amount
  ) external override (ITransferStrategyBase) onlyIncentivesController returns (bool) {
    IERC20(reward).safeTransfer(to, amount);
    return true;
  }

  /// @inheritdoc ITransferStrategyBase
  function getIncentivesController() external view override returns (address) {
    return incentiveController;
  }

  /// @inheritdoc ITransferStrategyBase
  function getRewardsAdmin() external view override returns (address) {
    return owner();
  }

  /// @inheritdoc ITransferStrategyBase
  function emergencyWithdrawal(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
    emit EmergencyWithdrawal(msg.sender, token, to, amount);
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
  AToken,
  Errors,
  GPv2SafeERC20,
  IAaveIncentivesController,
  IERC20,
  IPool,
  WadRayMath
} from '@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol';

import {IBerachainRewardsVault} from '../interfaces/IBerachainRewardsVault.sol';

contract ATokenBerachain is AToken {
  using GPv2SafeERC20 for IERC20;
  using WadRayMath for uint256;

  IBerachainRewardsVault public rewardsVault;

  constructor(IPool pool) AToken(pool) {
    // Intentionally left blank
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return 5;
  }

  function initialize(
    IPool initializingPool,
    address treasury,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 aTokenDecimals,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    bytes calldata params
  ) public virtual override initializer {
    super.initialize(initializingPool, treasury, underlyingAsset, incentivesController, aTokenDecimals, aTokenName, aTokenSymbol, params);

    // decode params
    (address _rewardsVault) = abi.decode(params, (address));

    // set variables
    rewardsVault = IBerachainRewardsVault(_rewardsVault);
  }

  function _transfer(address sender, address recipient, uint128 amount) internal virtual override {
    rewardsVault.notifyATokenBalances(sender, _userState[sender].balance, _userState[sender].balance - amount);
    rewardsVault.notifyATokenBalances(recipient, _userState[recipient].balance, _userState[recipient].balance + amount);
    super._transfer(sender, recipient, amount);
  }

  function _mint(address account, uint128 amount) internal virtual override {
    rewardsVault.notifyATokenBalances(account, _userState[account].balance, _userState[account].balance + amount);
    super._mint(account, amount);
  }

  function _burn(address account, uint128 amount) internal virtual override {
    rewardsVault.notifyATokenBalances(account, _userState[account].balance, _userState[account].balance - amount);
    super._burn(account, amount);
  }
}

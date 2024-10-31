// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICornStakingVault} from '../interfaces/ICornStakingVault.sol';
import {
  AToken, GPv2SafeERC20, IAaveIncentivesController, IERC20, IPool
} from '@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol';

///@notice ATokenCornStaking is a custom AToken for Corn Staking LP tokens
contract ATokenCornStaking is AToken {
  using GPv2SafeERC20 for IERC20;

  ICornStakingVault public cornVault;

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
    address _cornStaking = abi.decode(params, (address));

    // set variable
    cornVault = ICornStakingVault(_cornStaking);
    IERC20(this.UNDERLYING_ASSET_ADDRESS()).approve(address(cornVault), type(uint256).max);
  }

  function stakeUnderlyingToCorn() external onlyPoolAdmin {
    _stakeToCorn(IERC20(this.UNDERLYING_ASSET_ADDRESS()).balanceOf(address(this)));
  }

  function _burn(address account, uint128 amount) internal virtual override {
    super._burn(account, amount);
    _unstakeFromCorn(amount);
  }

  function _mint(address account, uint128 amount) internal virtual override {
    super._mint(account, amount);
    _stakeToCorn(amount);
  }

  function _stakeToCorn(uint256 amount) internal {
    cornVault.deposit(this.UNDERLYING_ASSET_ADDRESS(), amount);
  }

  function _unstakeFromCorn(uint256 amount) internal {
    cornVault.redeemToken(this.UNDERLYING_ASSET_ADDRESS(), amount);
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBerachainRewardsVault {
  /// @notice Notifies the Berachain Rewards Vault of the ATokens balance change
  function notifyATokenBalances(address account, uint256 amountBefore, uint256 amountAfter) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBerachainRewardsVault {
    enum Operation {
        MINT,
        BURN
    }

    /// @notice Notifies the Berachain Rewards Vault of the ATokens balance change
    function notifyATokenBalances(address user, uint256 amount, Operation op) external;
}
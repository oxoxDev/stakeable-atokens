// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAerodromeGauge {
    /// @notice Get the amount of stakingToken deposited by an account
    function balanceOf(address) external view returns (uint256);

    /// @notice Deposit LP tokens into gauge for any user
    /// @param _amount .
    /// @param _recipient Recipient to give balance to
    function deposit(uint256 _amount, address _recipient) external;

    /// @notice Withdraw LP tokens for user
    /// @param _amount .
    function withdraw(uint256 _amount) external;

    /// @notice Retrieve rewards for an address.
    /// @dev Throws if not called by same address or voter.
    /// @param _account .
    function getReward(address _account) external;

    /// @notice Address of the token (AERO) rewarded to stakers
    function rewardToken() external view returns (address);

    /// @notice Address of the token (LP) staked in the gauge
    function stakingToken() external view returns (address);
}

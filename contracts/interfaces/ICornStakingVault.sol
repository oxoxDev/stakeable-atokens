// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ICornStakingVault {
    function deposit(
        address token,
        uint256 assets
    ) external returns (uint256 shares);

    function redeemToken(
        address token,
        uint256 shares
    ) external returns (uint256 assets);

}
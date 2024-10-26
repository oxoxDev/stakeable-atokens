// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AToken, GPv2SafeERC20, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";


import {IBerachainRewardsVault} from "../interfaces/IBerachainRewardsVault.sol";


contract ATokenBerachain is AToken {
    using GPv2SafeERC20 for IERC20;

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
        super.initialize(
            initializingPool,
            treasury,
            underlyingAsset,
            incentivesController,
            aTokenDecimals,
            aTokenName,
            aTokenSymbol,
            params
        );

        // decode params
        (address _rewardsVault) = abi.decode(
            params,
            (address)
        );

        // set variables
        rewardsVault = IBerachainRewardsVault(_rewardsVault);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        _notifyRewardsVault(onBehalfOf, amount, IBerachainRewardsVault.Operation.MINT);
        ret = _mintScaled(caller, onBehalfOf, amount, index);
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        _notifyRewardsVault(from, amount, IBerachainRewardsVault.Operation.BURN);
        _burnScaled(from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    /// @notice Notifies the Berachain Rewards Vault of the ATokens balance change
    function _notifyRewardsVault(address _user, uint256 _amount, IBerachainRewardsVault.Operation op) internal {
        rewardsVault.notifyATokenBalances(_user, _amount, op);
    }

}
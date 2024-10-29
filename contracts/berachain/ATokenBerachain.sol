// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AToken, GPv2SafeERC20, Errors, WadRayMath, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";


import {IBerachainRewardsVault} from "../interfaces/IBerachainRewardsVault.sol";


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
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

        _notifyRewardsVault(onBehalfOf, amountScaled, IBerachainRewardsVault.Operation.MINT);

        ret = _mintScaled(caller, onBehalfOf, amount, index);
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_BURN_AMOUNT);

        _notifyRewardsVault(from, amountScaled, IBerachainRewardsVault.Operation.BURN);

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
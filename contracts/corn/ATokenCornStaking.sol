// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AToken, GPv2SafeERC20, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";
import {ICornStakingVault} from "../interfaces/ICornStakingVault.sol";

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
        address _cornStaking = abi.decode(
            params,
            (address)
        );

        // set variable
        cornVault = ICornStakingVault(_cornStaking);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        ret = _mintScaled(caller, onBehalfOf, amount, index);
        _ensureApprove(amount);
        cornVault.deposit(this.UNDERLYING_ASSET_ADDRESS(), amount);
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        _burnScaled(from, receiverOfUnderlying, amount, index);
        cornVault.redeemToken(this.UNDERLYING_ASSET_ADDRESS(), amount);
    }

    function transferUnderlyingTo(
        address target,
        uint256 amount
    ) external virtual override onlyPool {
        cornVault.redeemToken(this.UNDERLYING_ASSET_ADDRESS(), amount);
        IERC20(this.UNDERLYING_ASSET_ADDRESS()).safeTransfer(target, amount);
    }

    /**
     * @notice Add the current balance of the underlying asset to corn staking vault
     */    
    function stakeUnderlyingInCorn() external onlyPoolAdmin {
        _ensureApprove(type(uint256).max);
        cornVault.deposit(
            this.UNDERLYING_ASSET_ADDRESS(),
            IERC20(this.UNDERLYING_ASSET_ADDRESS()).balanceOf(address(this))
        );
    }

    function _ensureApprove(uint256 amount) internal {
        IERC20(this.UNDERLYING_ASSET_ADDRESS()).approve(address(cornVault), amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken, IAaveIncentivesController, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";
import {IMahaStakingRewards} from "../interfaces/IMahaStakingRewards.sol";

contract ATokenMahaStaker is AToken {
    using SafeERC20 for IERC20;

    address public emissionReceiver;

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
        address _emissionReceiver = abi.decode(params, (address));
        emissionReceiver = _emissionReceiver;

        // set variables
        address token1 = IMahaStakingRewards(_underlyingAsset).rewardToken1();
        address token2 = IMahaStakingRewards(_underlyingAsset).rewardToken2();

        // give approvals
        _ensureApprove(token1, type(uint256).max);
        _ensureApprove(token2, type(uint256).max);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        ret = _mintScaled(caller, onBehalfOf, amount, index);
        refreshRewards();
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        refreshRewards();
        _burnScaled(from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    function refreshRewards() public {
        IMahaStakingRewards(_underlyingAsset).getRewardDual(address(this));
    }

    /// @dev Used to set the emissions manager
    function setEmissionsManager(address newManager) public onlyPoolAdmin {
        address token1 = IMahaStakingRewards(_underlyingAsset).rewardToken1();
        address token2 = IMahaStakingRewards(_underlyingAsset).rewardToken2();

        _ensureApprove(token1, 0);
        _ensureApprove(token2, 0);

        emissionReceiver = newManager;

        _ensureApprove(token1, type(uint256).max);
        _ensureApprove(token2,type(uint256).max);
    }

    function _ensureApprove(address _token, uint _amt) internal {
        if (IERC20(_token).allowance(address(this), address(emissionReceiver)) < _amt) {
            IERC20(_token).forceApprove(address(emissionReceiver), type(uint).max);
        }
    }
}

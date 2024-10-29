// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken, IAaveIncentivesController, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";
import {IAerodromeGauge} from "../interfaces/IAerodromeGauge.sol";

/// @dev NOTE That ATokenAerodromeLP should not be made borrowable
/// @notice ATokenAerodromeLP is a custom AToken for Aerodrome LP tokens
contract ATokenAerodromeLP is AToken {
    using SafeERC20 for IERC20;

    IAerodromeGauge public gauge;
    IERC20 public aero;
    address public aeroEmissionReceiver;

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
        (address _gauge, address _receiver) = abi.decode(
            params,
            (address, address)
        );

        // set variables
        gauge = IAerodromeGauge(_gauge);
        aeroEmissionReceiver = _receiver;
        aero = IERC20(gauge.rewardToken());

        // give approvals
        _ensureApprove(address(aero), address(aeroEmissionReceiver), type(uint256).max);
        _ensureApprove(_underlyingAsset, address(gauge), type(uint256).max);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        ret = _mintScaled(caller, onBehalfOf, amount, index);
        gauge.deposit(amount, address(this));
        refreshRewards();
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        refreshRewards();
        gauge.withdraw(amount);

        _burnScaled(from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    /// @dev Used to deposit any remaining balance in the contract to the gauge
    function depositToGauge() external {
        gauge.deposit(
            IERC20(_underlyingAsset).balanceOf(address(this)),
            address(this)
        );
    }

    /// @dev Used to fetch any remaining rewards in the gauge to the contract
    function refreshRewards() public {
        gauge.getReward(address(this));
    }

    /// @dev Used to set the emissions manager
    function setEmissionsManager(address newManager) public onlyPoolAdmin {
        _ensureApprove(address(aero), address(aeroEmissionReceiver), 0);
        aeroEmissionReceiver = newManager;
        _ensureApprove(address(aero), address(aeroEmissionReceiver), type(uint256).max);
    }

    function _ensureApprove(address _token, address _to, uint _amt) internal {
        if (IERC20(_token).allowance(address(this), _to) < _amt) {
            IERC20(_token).forceApprove(_to, type(uint).max);
        }
    }
}

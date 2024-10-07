// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AToken, GPv2SafeERC20, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";

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

/// @dev NOTE That ATokenAerodrome should not be made borrowable
contract ATokenAerodrome is AToken {
    using GPv2SafeERC20 for IERC20;

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
        aero.approve(address(aeroEmissionReceiver), type(uint256).max);
        IERC20(_underlyingAsset).approve(address(gauge), type(uint256).max);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        ret = _mintScaled(caller, onBehalfOf, amount, index);
        gauge.deposit(amount, address(this));
        gauge.getReward(address(this));
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        gauge.getReward(address(this));
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

    function refreshRewards() external {
        gauge.getReward(address(this));
    }
}

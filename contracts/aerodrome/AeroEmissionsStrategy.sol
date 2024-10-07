// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@zerolendxyz/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {Initializable} from "@zerolendxyz/core-v3/contracts/dependencies/openzeppelin/upgradeability/Initializable.sol";
import {IEACAggregatorProxy, IEmissionManager, ITransferStrategyBase, RewardsDataTypes} from "@zerolendxyz/periphery-v3/contracts/rewards/interfaces/IEmissionManager.sol";

/// @dev NOTE That ATokenAerodrome should not be made borrowable
contract AeroEmissionsStrategy is
    Initializable,
    Ownable,
    ITransferStrategyBase
{
    address public incentiveController;
    IEmissionManager public emissionManager;
    IERC20 public aero;

    mapping(address => uint256) public emissionsReceived;
    mapping(address => uint256) public lastNotified;
    mapping(address => bool) public whitelisted;
    mapping(address => address) public aToken;
    address public oracle;

    modifier onlyIncentivesController() {
        require(
            incentiveController == msg.sender,
            "CALLER_NOT_INCENTIVES_CONTROLLER"
        );
        _;
    }

    function initialize(
        address _owner,
        address _aero,
        address _oracle,
        address _emissionManager,
        address _incentiveController
    ) public initializer {
        aero = IERC20(_aero);
        emissionManager = IEmissionManager(_emissionManager);
        incentiveController = _incentiveController;
        whitelisted[_owner] = true;
        oracle = _oracle;
        _transferOwnership(_owner);
    }

    function whitelist(address who, bool what) external onlyOwner {
        whitelisted[who] = what;
    }

    function notifyEmissionManager(address reserve) external {
        require(whitelisted[msg.sender], "not whitelisted");
        address aTokenAddress = aToken[reserve];

        // claim the aero tokens
        uint256 pending = aero.balanceOf(aTokenAddress);
        aero.transferFrom(aTokenAddress, address(this), pending);
        emissionsReceived[aTokenAddress] += pending;

        require(pending > 0, "no emissions to notify");
        require(
            lastNotified[reserve] + 1 days <= block.timestamp,
            "too soon to notify"
        );

        uint256 emissionPerSecond = pending / 1 days;

        RewardsDataTypes.RewardsConfigInput memory data = RewardsDataTypes
            .RewardsConfigInput({
                emissionPerSecond: uint88(emissionPerSecond),
                totalSupply: 0,
                distributionEnd: uint32(block.timestamp + 1 days),
                asset: reserve,
                reward: address(aero),
                rewardOracle: IEACAggregatorProxy(oracle),
                transferStrategy: ITransferStrategyBase(address(this))
            });

        RewardsDataTypes.RewardsConfigInput[]
            memory config = new RewardsDataTypes.RewardsConfigInput[](1);
        config[0] = data;
        emissionManager.configureAssets(config);

        lastNotified[reserve] = block.timestamp;
    }

    /// @inheritdoc ITransferStrategyBase
    function performTransfer(
        address to,
        address reward,
        uint256 amount
    )
        external
        override(ITransferStrategyBase)
        onlyIncentivesController
        returns (bool)
    {
        return IERC20(reward).transfer(to, amount);
    }

    /// @inheritdoc ITransferStrategyBase
    function getIncentivesController()
        external
        view
        override
        returns (address)
    {
        return incentiveController;
    }

    /// @inheritdoc ITransferStrategyBase
    function getRewardsAdmin() external view override returns (address) {
        return owner();
    }

    /// @inheritdoc ITransferStrategyBase
    function emergencyWithdrawal(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit EmergencyWithdrawal(msg.sender, token, to, amount);
    }
}

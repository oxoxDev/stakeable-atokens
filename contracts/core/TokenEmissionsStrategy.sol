// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@zerolendxyz/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {Initializable} from "@zerolendxyz/core-v3/contracts/dependencies/openzeppelin/upgradeability/Initializable.sol";
import {IEACAggregatorProxy, IEmissionManager, ITransferStrategyBase, RewardsDataTypes} from "@zerolendxyz/periphery-v3/contracts/rewards/interfaces/IEmissionManager.sol";
import {IPool} from "@zerolendxyz/core-v3/contracts/interfaces/IPool.sol";

interface IATokenCustom {
    function refreshRewards() external;
}

contract TokenEmissionsStrategy is
    Initializable,
    Ownable,
    ITransferStrategyBase
{
    address public incentiveController;
    IEmissionManager public emissionManager;
    IPool public pool;

    mapping(address => mapping(IERC20 => uint256)) public emissionsReceived;
    mapping(address => uint256) public lastNotified;
    mapping(address => bool) public whitelisted;
    mapping(address => address) public aToken;

    modifier onlyIncentivesController() {
        require(
            incentiveController == msg.sender,
            "CALLER_NOT_INCENTIVES_CONTROLLER"
        );
        _;
    }

    function initialize(
        address _owner,
        address _pool,
        address _emissionManager,
        address _incentiveController
    ) public initializer {
        emissionManager = IEmissionManager(_emissionManager);
        incentiveController = _incentiveController;
        whitelisted[_owner] = true;
        pool = IPool(_pool);
        _transferOwnership(_owner);
    }

    function whitelist(address _reserve, bool _what) external onlyOwner {
        whitelisted[_reserve] = _what;
    }

    function getAToken(address _reserve) public view returns (address) {
        return pool.getReserveData(_reserve).aTokenAddress;
    }

    function notifyEmissionManager(
        address _reserve,
        IERC20 token,
        address oracle
    ) external {
        require(whitelisted[_reserve], "!whitelist");
        require(whitelisted[msg.sender], "!whitelist");
        require(whitelisted[address(token)], "!whitelist");
        require(whitelisted[oracle], "!whitelist");

        address aTokenAddress = getAToken(_reserve);
        IATokenCustom(aTokenAddress).refreshRewards();

        require(
            lastNotified[_reserve] + 1 days <= block.timestamp,
            "too soon to notify"
        );

        RewardsDataTypes.RewardsConfigInput[]
            memory config = new RewardsDataTypes.RewardsConfigInput[](1);

        config[0] = _notifyEmissionManager(aTokenAddress, token, oracle);

        emissionManager.configureAssets(config);
        lastNotified[_reserve] = block.timestamp;
    }

    function _notifyEmissionManager(
        address aTokenAddress,
        IERC20 token,
        address oracle
    ) internal returns (RewardsDataTypes.RewardsConfigInput memory) {
        uint256 pending = token.balanceOf(aTokenAddress);
        token.transferFrom(aTokenAddress, address(this), pending);
        emissionsReceived[aTokenAddress][token] += pending;
        require(pending > 0, "no emissions to notify");

        uint256 emissionPerSecond = pending / 1 days;

        RewardsDataTypes.RewardsConfigInput memory data = RewardsDataTypes
            .RewardsConfigInput({
                emissionPerSecond: uint88(emissionPerSecond),
                totalSupply: 0,
                distributionEnd: uint32(block.timestamp + 1 days),
                asset: aTokenAddress,
                reward: address(token),
                rewardOracle: IEACAggregatorProxy(oracle),
                transferStrategy: ITransferStrategyBase(address(this))
            });

        return data;
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

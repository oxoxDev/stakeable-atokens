// SPDX-License-Identifier: BUSL-1.1

interface IPoolConfigurator {
    struct UpdateATokenInput {
        address asset;
        address treasury;
        address incentivesController;
        string name;
        string symbol;
        address implementation;
        bytes params;
    }

    /**
     * @dev Updates the aToken implementation for the reserve.
     * @param input The aToken update parameters
     */
    function updateAToken(UpdateATokenInput calldata input) external;
}
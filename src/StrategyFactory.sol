// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {AaveV4LenderStrategy as Strategy} from "./Strategy.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract StrategyFactory {

    event NewStrategy(address indexed strategy, address indexed asset);

    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    /// @notice Track the deployments. spoke + reserveId => strategy
    mapping(address => mapping(uint256 => address)) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    /**
     * @notice Deploy a new Strategy.
     * @param _asset The underlying asset for the strategy to use.
     * @param _name The name of the strategy.
     * @param _spoke The Aave V4 Spoke contract.
     * @param _reserveId The reserve ID on the Spoke.
     * @return . The address of the new strategy.
     */
    function newStrategy(
        address _asset,
        string calldata _name,
        address _spoke,
        uint256 _reserveId
    ) external virtual returns (address) {
        IStrategyInterface _newStrategy = IStrategyInterface(address(new Strategy(_asset, _name, _spoke, _reserveId)));

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _asset);

        deployments[_spoke][_reserveId] = address(_newStrategy);
        return address(_newStrategy);
    }

    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        require(msg.sender == management, "!management");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        IStrategyInterface s = IStrategyInterface(_strategy);
        return deployments[address(s.SPOKE())][s.RESERVE_ID()] == _strategy;
    }

}

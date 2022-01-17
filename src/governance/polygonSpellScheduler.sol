// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {Governance} from "./governance.sol";

// Copied from https://github.com/fx-portal/contracts/blob/main/contracts/FxChild.sol
interface IFxMessageProcessor {
    function processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes calldata data
    ) external;
}

/// @notice An L2 proxy of an L1 owner, executes its commands received from an Fx tunnel
contract PolygonSpellScheduler is IFxMessageProcessor {
    /// @notice The owner of the proxy, the only L1 address from which commands are accepted
    address public immutable owner;
    address public immutable fxChild;
    Governance public immutable governance;

    event Scheduled(address spell, uint256 startTime);
    event GovernanceOwnershipTransferred(address newOwner);

    constructor(
        address owner_,
        address fxChild_,
        Governance governance_
    ) {
        owner = owner_;
        fxChild = fxChild_;
        governance = governance_;
    }

    /// @notice Process a message from L1
    /// @param sender The L1 sender, must be the owner
    /// @param message The commands to execute.
    /// Must be ABI encoded like `Governor::propose` calldata minus the 4-byte selector.
    function processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory message
    ) external override {
        stateId;
        require(msg.sender == fxChild, "Caller is not the fxChild");
        require(sender == owner, "Message not from the owner");
        address spell = abi.decode(message, (address));
        uint256 startTime = block.timestamp + governance.minDelay();
        governance.schedule(spell, startTime);
        emit Scheduled(spell, startTime);
    }

    function transferGovernanceOwnership(address newOwner) external {
        require(msg.sender == address(governance.executor()), "Caller is not the executor");
        governance.transferOwnership(newOwner);
        emit GovernanceOwnershipTransferred(newOwner);
    }
}

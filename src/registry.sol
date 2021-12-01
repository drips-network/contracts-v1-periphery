// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {DripsToken, InputType, SplitsReceiver} from "./token.sol";
import {DaiDripsHub} from "drips-hub/DaiDripsHub.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {IBuilder} from "./builder/base.sol";

contract RadicleRegistry {
    address public governance;
    IBuilder public builder;

    event NewProject(DripsToken indexed fundingToken, address indexed projectOwner, string name);
    event NewBuilder(IBuilder builder);
    modifier onlyGovernance() {
        require(msg.sender == governance, "only-governance");
        _;
    }

    DripsToken public immutable dripTokenTemplate;
    uint256 public nextId;

    constructor(
        DaiDripsHub hub_,
        IBuilder builder_,
        address governance_
    ) {
        governance = governance_;
        changeBuilder(builder_);
        dripTokenTemplate = new DripsToken(hub_);
    }

    function newProject(
        string calldata name,
        string calldata symbol,
        address projectOwner,
        string calldata contractURI,
        InputType[] calldata inputTypes,
        SplitsReceiver[] memory splits
    ) public returns (DripsToken) {
        bytes32 salt = bytes32(nextId++);
        DripsToken fundingToken = DripsToken(
            Clones.cloneDeterministic(address(dripTokenTemplate), salt)
        );
        fundingToken.init(name, symbol, projectOwner, contractURI, inputTypes, builder, splits);
        emit NewProject(fundingToken, projectOwner, name);
        return fundingToken;
    }

    function projectAddr(uint256 id) public view returns (DripsToken) {
        if (id >= nextId) {
            return DripsToken(address(0x0));
        }
        return
            DripsToken(Clones.predictDeterministicAddress(address(dripTokenTemplate), bytes32(id)));
    }

    function changeBuilder(IBuilder newBuilder) public onlyGovernance {
        builder = newBuilder;
        emit NewBuilder(newBuilder);
    }
}

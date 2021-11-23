// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {DripsReceiver, FundingToken, InputType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {IBuilder} from "./builder.sol";

contract RadicleRegistry {
    address public governance;
    IBuilder public builder;

    event NewProject(FundingToken indexed fundingToken, address indexed projectOwner, string name);
    event NewBuilder(IBuilder builder);
    modifier onlyGovernance() {
        require(msg.sender == governance, "only-governance");
        _;
    }

    FundingToken public immutable fundingTokenTemplate;
    uint256 public nextId;

    constructor(
        DaiPool pool_,
        IBuilder builder_,
        address governance_
    ) {
        governance = governance_;
        changeBuilder(builder_);
        fundingTokenTemplate = new FundingToken(pool_);
    }

    function newProject(
        string calldata name,
        string calldata symbol,
        address projectOwner,
        string calldata contractURI,
        InputType[] calldata inputTypes,
        DripsReceiver[] memory drips
    ) public returns (FundingToken) {
        bytes32 salt = bytes32(nextId++);
        FundingToken fundingToken = FundingToken(
            Clones.cloneDeterministic(address(fundingTokenTemplate), salt)
        );
        fundingToken.init(name, symbol, projectOwner, contractURI, inputTypes, builder, drips);
        emit NewProject(fundingToken, projectOwner, name);
        return fundingToken;
    }

    function projectAddr(uint256 id) public view returns (FundingToken) {
        if (id >= nextId) {
            return FundingToken(address(0x0));
        }
        return
            FundingToken(
                Clones.predictDeterministicAddress(address(fundingTokenTemplate), bytes32(id))
            );
    }

    function changeBuilder(IBuilder newBuilder) public onlyGovernance {
        builder = newBuilder;
        emit NewBuilder(newBuilder);
    }
}

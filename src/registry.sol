// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {DripsToken, IDripsToken, InputType, SplitsReceiver} from "./token.sol";
import {DaiDripsHub} from "drips-hub/DaiDripsHub.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {IBuilder} from "./builder/interface.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract RadicleRegistry is Ownable {
    IBuilder public builder;

    event NewProject(
        address dripTokenTemplate,
        address indexed fundingToken,
        address indexed projectOwner,
        string name
    );
    event NewBuilder(IBuilder builder);
    event NewTemplate(address template);

    address public dripsTokenTemplate;
    uint256 public nextId;

    mapping(uint256 => address) public dripsToken;

    constructor(
        DaiDripsHub hub_,
        IBuilder builder_,
        address owner_
    ) {
        _transferOwnership(owner_);
        changeBuilder(builder_);
        changeTemplate(address(new DripsToken(hub_)));
    }

    function changeTemplate(address newTemplate) public onlyOwner {
        dripsTokenTemplate = newTemplate;
        emit NewTemplate(newTemplate);
    }

    function newProject(
        string calldata name,
        string calldata symbol,
        address projectOwner,
        string calldata contractURI,
        InputType[] calldata inputTypes,
        SplitsReceiver[] memory splits
    ) public returns (address fundingToken) {
        fundingToken = Clones.cloneDeterministic(dripsTokenTemplate, bytes32(nextId));
        IDripsToken(fundingToken).init(
            name,
            symbol,
            projectOwner,
            contractURI,
            inputTypes,
            builder,
            splits
        );
        emit NewProject(dripsTokenTemplate, fundingToken, projectOwner, name);
        dripsToken[nextId] = fundingToken;
        nextId++;
    }

    function changeBuilder(IBuilder newBuilder) public onlyOwner {
        builder = newBuilder;
        emit NewBuilder(newBuilder);
    }
}

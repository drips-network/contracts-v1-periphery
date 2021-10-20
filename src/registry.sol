// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";

interface IBuilder {
    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) external view returns (string memory);
}

contract RadicleRegistry {
    mapping(uint => address) public projects;
    uint                public counter;
    address             public governance;
    IBuilder            public builder;

    event NewProject(address indexed nftRegistry, address indexed projectOwner);
    event NewBuilder(address indexed Builder);
    modifier onlyGovernance {require(msg.sender == governance, "only-governance"); _;}

    FundingNFT public immutable fundingNFTTemplate;
    uint public nextId;

    event NewProject(FundingNFT indexed fundingNFT, address indexed projectOwner);

    constructor (DaiPool pool_, address Builder_, address governance_) {
        governance = governance_;
        builder = IBuilder(Builder_);
        fundingNFTTemplate = new FundingNFT(pool_);
    }

    function newProject(string calldata name, string calldata symbol, address projectOwner, string calldata ipfsHash, InputNFTType[] memory inputNFTTypes) public returns(FundingNFT) {
        bytes32 salt = bytes32(nextId++);
        FundingNFT fundingNFT = FundingNFT(Clones.cloneDeterministic(address(fundingNFTTemplate), salt));
        fundingNFT.init(name, symbol, projectOwner, ipfsHash, inputNFTTypes, address(this));
        emit NewProject(fundingNFT, projectOwner);
        return fundingNFT;
    }

    function projectAddr(uint id) public view returns (FundingNFT) {
        if (id >= nextId) {
            return FundingNFT(address(0x0));
        }
        return FundingNFT(Clones.predictDeterministicAddress(address(fundingNFTTemplate), bytes32(id)));
    }

    function changeBuilder(address newBuilder) public onlyGovernance {
        builder =  IBuilder(newBuilder);
        emit NewBuilder(newBuilder);
    }

    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) public view returns (string memory) {
        return builder.buildMetaData(projectName, tokenId, amtPerCycle, active);
    }
}

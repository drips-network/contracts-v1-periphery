// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";

interface IMetaDataBuilder {
    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) external pure returns (string memory);
}

contract RadicleRegistry {
    mapping(uint => address) public projects;
    uint                public counter;
    DaiPool             public pool;
    address             public governance;
    IMetaDataBuilder    public metaDataBuilder;

    event NewProject(address indexed nftRegistry, address indexed projectOwner);
    event NewMetaDataBuilder(address indexed metadataBuilder);

    modifier onlyGovernance {require(msg.sender == governance, "only-governance"); _;}

    constructor (DaiPool pool_, address metaDataBuilder_, address governance_) {
        pool = pool_;
        governance = governance_;
        metaDataBuilder = IMetaDataBuilder(metaDataBuilder_);
    }

    function newProject(string memory name, string memory symbol, address projectOwner, string memory ipfsHash) public returns(address) {
        counter++;
        FundingNFT nftRegistry = new FundingNFT(pool, name, symbol, address(projectOwner), ipfsHash, address(this));
        projects[counter] = address(nftRegistry);
        emit NewProject(address(nftRegistry), projectOwner);
        return address(nftRegistry);
    }

    function changeMetaDataBuilder(address newMetadataBuilder) public onlyGovernance {
        metaDataBuilder =  IMetaDataBuilder(newMetadataBuilder);
        emit NewMetaDataBuilder(newMetadataBuilder);
    }

    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) public view returns (string memory) {
        return metaDataBuilder.buildMetaData(projectName, tokenId, amtPerCycle, active);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";

contract RadicleRegistry {
    mapping(uint => address) public projects;
    uint                public counter;
    address             public governance;
    address             public builder;

    event NewProject(address indexed nftRegistry, address indexed projectOwner);
    event NewBuilder(address indexed builder);
    modifier onlyGovernance {require(msg.sender == governance, "only-governance"); _;}

    FundingNFT public immutable fundingNFTTemplate;
    uint public nextId;

    event NewProject(FundingNFT indexed fundingNFT, address indexed projectOwner);

    constructor (DaiPool pool_, address builder_, address governance_) {
        governance = governance_;
        builder = builder_;
        fundingNFTTemplate = new FundingNFT(pool_);
    }

    function newProject(string calldata name, string calldata symbol, address projectOwner, string calldata ipfsHash, InputNFTType[] memory inputNFTTypes) public returns(FundingNFT) {
        bytes32 salt = bytes32(nextId++);
        FundingNFT fundingNFT = FundingNFT(Clones.cloneDeterministic(address(fundingNFTTemplate), salt));
        fundingNFT.init(name, symbol, projectOwner, ipfsHash, inputNFTTypes, builder);
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
        builder = newBuilder;
        emit NewBuilder(newBuilder);
    }
}

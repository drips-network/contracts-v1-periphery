// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";

contract RadicleRegistry {
    FundingNFT public immutable fundingNFTTemplate;
    uint public nextId;

    event NewProject(FundingNFT indexed fundingNFT, address indexed projectOwner);

    constructor (DaiPool pool) {
        fundingNFTTemplate = new FundingNFT(pool);
    }

    function newProject(string calldata name, string calldata symbol, address projectOwner, string calldata ipfsHash) public returns(FundingNFT) {
        bytes32 salt = bytes32(nextId++);
        FundingNFT fundingNFT = FundingNFT(Clones.cloneDeterministic(address(fundingNFTTemplate), salt));
        fundingNFT.init(name, symbol, projectOwner, ipfsHash);
        emit NewProject(fundingNFT, projectOwner);
        return fundingNFT;
    }

    function projectAddr(uint id) public view returns (FundingNFT) {
        return FundingNFT(Clones.predictDeterministicAddress(address(fundingNFTTemplate), bytes32(id)));
    }
}

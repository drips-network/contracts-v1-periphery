// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {DaiPool} from "../lib/radicle-streaming/src/DaiPool.sol";

contract RadicleRegistry {
    mapping(uint => address) public projects;
    uint public counter;

    DaiPool public pool;
    event NewProject(address indexed nftRegistry, address indexed projectOwner);

    constructor (DaiPool pool_) {
        pool = pool_;
    }

    function newProject(string memory name, string memory symbol, address projectOwner, InputNFTType[] memory inputNFTTypes, string memory ipfsHash) public returns(address) {
        counter++;
        FundingNFT nftRegistry = new FundingNFT(pool, name, symbol, projectOwner, inputNFTTypes, ipfsHash);
        projects[counter] = address(nftRegistry);

        emit NewProject(address(nftRegistry), projectOwner);
        return address(nftRegistry);
    }
}

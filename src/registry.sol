// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {FundingNFT, InputNFTType} from "./nft.sol";
import {FundingPool} from "./pool.sol";

contract RadicleRegistry {
    mapping(uint => address) public projects;
    uint public counter;

    FundingPool public pool;
    event NewProject(address indexed nftRegistry, address indexed projectOwner, uint128 minAmtPerSec);

    constructor (FundingPool pool_) {
        pool = pool_;
    }

    function newProject(string memory name, string memory symbol, address projectOwner, uint128 minAmtPerSec) public returns(address) {
        counter++;
        FundingNFT nftRegistry = new FundingNFT(pool, name, symbol, projectOwner, minAmtPerSec);
        projects[counter] = address(nftRegistry);

        emit NewProject(address(nftRegistry), projectOwner, minAmtPerSec);
        return address(nftRegistry);
    }
}


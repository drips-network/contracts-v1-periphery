pragma solidity ^0.8.4;

import {FundingNFT} from "./nft.sol";

contract FundingRegistry {
    mapping(uint => address) public projects;
    uint public counter;
    uint128 minAmtPerSec;

    address public pool;
    constructor (address pool_, uint128 minAmtPerSec_) {
        pool = pool_;
        minAmtPerSec = minAmtPerSec_;
    }

    function newProject(string memory name, string memory symbol, address projectOwner) public returns(address) {
        counter++;
        FundingNFT nftRegistry = new FundingNFT(pool, name, symbol, projectOwner, minAmtPerSec);
        projects[counter] = address(nftRegistry);
        return address(nftRegistry);
    }
}

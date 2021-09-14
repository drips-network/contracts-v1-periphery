pragma solidity ^0.8.4;

import {FundingNFT} from "./nft.sol";

contract RadicleRegistry {
    // todo use create2 opcode for deterministic address based on counter as salt (no need for mapping)
    mapping(uint => address) public projects;
    uint public counter;

    address public pool;
    constructor (address pool_) {
        pool = pool_;
    }

    function newProject(string memory name, string memory symbol, address projectOwner, uint128 minAmtPerSec, uint128 limitFirstEdition) public returns(address) {
        counter++;
        FundingNFT nftRegistry = new FundingNFT(pool, name, symbol, projectOwner, minAmtPerSec, limitFirstEdition);
        projects[counter] = address(nftRegistry);
        return address(nftRegistry);
    }
}

pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";

contract FundingNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address receiver) external onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newNftTokenId = _tokenIds.current();
        _mint(receiver, newNftTokenId);
        return newNftTokenId;
    }
}

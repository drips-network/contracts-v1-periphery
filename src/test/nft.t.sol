pragma solidity ^0.8.4;

import "ds-test/test.sol";
import "./../nft.sol";

contract NFTTest is DSTest {
    FundingNFT nftRegistry;

    function setUp() public {
        nftRegistry = new FundingNFT("Dummy Project", "DP");
    }

    function testMint() public {
        uint tokenId = nftRegistry.mint(address(0xA));
        assertEq(nftRegistry.ownerOf(tokenId), address(0xA));
    }
}

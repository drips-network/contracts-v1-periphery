// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {RadicleRegistry} from "./../registry.sol";
import {DaiPool} from "../../lib/radicle-streaming/src/DaiPool.sol";
import {FundingNFT, InputNFTType} from "./../nft.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";

contract RegistryTest is BaseTest {
    RadicleRegistry radicleRegistry;
    DaiPool pool;
    Dai public dai;
    Hevm public hevm;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        pool = new DaiPool(CYCLE_SECS, dai);
        radicleRegistry = new RadicleRegistry(pool);
    }

    function testNewNFTRegistry() public {
        uint128 minAmtPerSec = uint128(fundingInSeconds(10 ether));
        string memory name = "First Funding Project";
        string memory symbol = "FFP";
        string memory ipfsHash = "ipfs";
        uint128 limitTypeZero = 10;
        uint128 limitTypeOne = 20;

        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 0, limit:limitTypeZero});
        nftTypes[1] = InputNFTType({nftTypeId: 1, limit:limitTypeOne});

        address nftRegistry_ = radicleRegistry.newProject(name, symbol, address(0xA), minAmtPerSec, nftTypes, ipfsHash);
        FundingNFT nftRegistry = FundingNFT(nftRegistry_);
        assertEq(nftRegistry.owner(), address(0xA));
        assertEq(radicleRegistry.projects(1), nftRegistry_);
        (uint128 limit, uint128 minted) = nftRegistry.nftTypes(0);
        assertEq(limit, limitTypeZero);
        (limit, minted) = nftRegistry.nftTypes(1);
        assertEq(limit, limitTypeOne);
        assertEq(nftRegistry.contractURI(), ipfsHash);
    }
}

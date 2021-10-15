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
        string memory name = "First Funding Project";
        string memory symbol = "FFP";
        string memory ipfsHash = "ipfs";
        uint64 limitTypeZero = 100;
        uint64 limitTypeOne = 200;

        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 0, limit:limitTypeZero, minAmtPerSec: 10});
        nftTypes[1] = InputNFTType({nftTypeId: 1, limit:limitTypeOne, minAmtPerSec: 20});

        FundingNFT nftRegistry = radicleRegistry.newProject(name, symbol, address(this), ipfsHash, nftTypes);
        assertEq(nftRegistry.owner(), address(this));
        assertEq(nftRegistry.name(), name);
        assertEq(nftRegistry.symbol(), symbol);
        assertEq(nftRegistry.contractURI(), ipfsHash);
        assertEq(address(nftRegistry.pool()), address(pool));
        assertEq(address(radicleRegistry.projectAddr(0)), address(nftRegistry));
        (uint64 limit, uint64 minted, uint128 minAmtPerSec) = nftRegistry.nftTypes(0);
        assertEq(limit, limitTypeZero);
        assertEq(minAmtPerSec, 10);
        (limit, minted, minAmtPerSec) = nftRegistry.nftTypes(1);
        assertEq(limit, limitTypeOne);
        assertEq(minAmtPerSec, 20);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {RadicleRegistry} from "./../registry.sol";
import {DaiPool} from "../../lib/radicle-streaming/src/DaiPool.sol";
import {DripsReceiver, FundingNFT, InputType} from "./../nft.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";
import {Builder} from "./../builder.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";

contract RegistryTest is BaseTest {
    RadicleRegistry public radicleRegistry;
    Builder public builder;
    DaiPool public pool;
    Dai public dai;
    Hevm public hevm;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        pool = new DaiPool(CYCLE_SECS, dai);
        builder = new Builder();
        radicleRegistry = new RadicleRegistry(pool, builder, address(this));
    }

    function newNewNFTRegistry() public returns (address) {
        string memory name = "First Funding Project";
        string memory symbol = "FFP";
        string memory ipfsHash = "ipfs";
        uint64 limitTypeZero = 100;
        uint64 limitTypeOne = 200;

        InputType[] memory nftTypes = new InputType[](2);
        nftTypes[0] = InputType({
            nftTypeId: 0,
            limit: limitTypeZero,
            minAmt: 10,
            ipfsHash: "",
            streaming: true
        });
        nftTypes[1] = InputType({
            nftTypeId: 1,
            limit: limitTypeOne,
            minAmt: 20,
            ipfsHash: "",
            streaming: true
        });

        FundingNFT nftRegistry = radicleRegistry.newProject(
            name,
            symbol,
            address(this),
            ipfsHash,
            nftTypes,
            new DripsReceiver[](0)
        );
        assertEq(nftRegistry.owner(), address(this));
        assertEq(nftRegistry.name(), name);
        assertEq(nftRegistry.symbol(), symbol);
        assertEq(nftRegistry.contractURI(), ipfsHash);
        assertEq(address(nftRegistry.pool()), address(pool));
        assertEq(address(radicleRegistry.projectAddr(0)), address(nftRegistry));
        (uint64 limit, uint64 minted, uint128 minAmtPerSec, , ) = nftRegistry.nftTypes(0);
        assertEq(limit, limitTypeZero);
        assertEq(minAmtPerSec, 10);
        (limit, minted, minAmtPerSec, , ) = nftRegistry.nftTypes(1);
        assertEq(limit, limitTypeOne);
        assertEq(minAmtPerSec, 20);
        return address(nftRegistry);
    }

    function testNewNFTRegistry() public {
        newNewNFTRegistry();
    }

    function testProjectAddr() public {
        address nftRegistry = newNewNFTRegistry();
        assertEq(address(radicleRegistry.projectAddr(0)), nftRegistry);
        assertEq(address(radicleRegistry.projectAddr(1)), address(0));
    }
}

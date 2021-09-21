pragma solidity ^0.8.4;

import "ds-test/test.sol";
import "./../nft.sol";
import "./../pool.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";


contract NFTRegistryTest is BaseTest {
    FundingNFT nftRegistry;
    address nftRegistry_;
    FundingPool pool;
    Dai dai;
    Hevm public hevm;

    uint128 public minAmtPerSec;

    uint128 public constant DEFAULT_NFT_TYPE = 0;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        pool = new FundingPool(CYCLE_SECS, dai);
        minAmtPerSec =  uint128(fundingInSeconds(10 ether));
        nftRegistry = new FundingNFT(pool, "Dummy Project", "DP", address(this), minAmtPerSec, uint128(1000));
        nftRegistry_ = address(nftRegistry);
        // start with a full cycle
        hevm.warp(0);
    }

    function testBasicMint() public {
        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));

        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);
        assertEq(nftRegistry.ownerOf(tokenId), address(this));
        assertEq(nftRegistry.tokenType(tokenId), nftRegistry.DEFAULT_TYPE());

        hevm.warp(block.timestamp + CYCLE_SECS);

        uint128 preBalance = uint128(dai.balanceOf(address(this)));
        pool.collect(address(this));
        assertEq(dai.balanceOf(address(this)), preBalance + minAmtPerSec * CYCLE_SECS, "collect-failed");
    }

    function testFailNonMinAmt() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec-1);
    }

    function testFailNoApproval() public {
        uint128 amount = 20 ether;
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);
    }

    function testFailNotEnoughTopUp() public {
        uint128 amount = 9 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);
    }

    function testAddType() public {
        uint128 typeId = 2;
        uint128 limit = 200;
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.addType(typeId, limit);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount, minAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);
        assertEq(bytes32(tokenId), bytes32(0x0000000000000000000000000000000200000000000000000000000000000001));
    }

    function testLimit() public {
        uint128 typeId = 1;
        uint128 limit = 5;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.addType(typeId, limit);
        uint tokenId;
        for (uint i =0; i<limit;i++) {
            tokenId = nftRegistry.mint(address(this), typeId,  amount/5, minAmtPerSec);
            assertEq(nftRegistry.tokenType(tokenId), typeId);
        }
        (, uint minted) = nftRegistry.nftTypes(typeId);
        assertEq(minted, limit);
    }

    function testShouldFailMoreThanLimit() public {
        uint128 typeId = 1;
        uint128 limit = 1;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.addType(typeId, limit);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount/2, minAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);

        (, uint minted) = nftRegistry.nftTypes(typeId);
        emit log_named_uint("minted", minted);

        // should fail nft-type-reached-limit
        try nftRegistry.mint(address(this), typeId, amount/2, minAmtPerSec) {
            assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "nft-type-reached-limit", "Invalid mint revert reason");
        }
    }

    function testUnlimited() public {
        uint128 typeId = 1;
        uint128 limit = nftRegistry.UNLIMITED();
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.addType(typeId, limit);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount, minAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);

        (, uint minted) = nftRegistry.nftTypes(typeId);
        assertEq(minted, 1);
    }

    function testCreateTokenId() public {
        uint128  id = 1;
        uint128  nftType = 2;
        uint tokenId = nftRegistry.createTokenId(id, nftType);
        uint a = (nftType << 12);
        assertEq(bytes32(tokenId), bytes32(0x0000000000000000000000000000000200000000000000000000000000000001));
    }

    function testNFTTypeConversion() public {
        uint128  id = 1;
        uint128  nftType = 2;
        uint tokenId = nftRegistry.createTokenId(id, nftType);
        uint128 resultNFTType = nftRegistry.tokenType(tokenId);
        assertEq(resultNFTType, nftType);
    }

}

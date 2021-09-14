pragma solidity ^0.8.7;

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
        nftRegistry = new FundingNFT(address(pool), "Dummy Project", "DP", address(this), minAmtPerSec, uint128(1000));
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
        uint128 typeId = 1;
        uint128 limit = 200;
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.addType(typeId, limit);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount, minAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);
    }
}

pragma solidity ^0.8.4;

import "ds-test/test.sol";
import "./../nft.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";


contract NFTRegistryTest is BaseTest {
    FundingNFT nftRegistry;
    address nftRegistry_;
    NFTPool pool;
    Dai dai;
    Hevm public hevm;

    uint128 public minAmtPerSec;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        pool = new NFTPool(CYCLE_SECS, dai);
        minAmtPerSec =  uint128(fundingInSeconds(10 ether));
        nftRegistry = new FundingNFT(address(pool), "Dummy Project", "DP", address(this), minAmtPerSec);
        nftRegistry_ = address(nftRegistry);
        // start with a full cycle
        hevm.warp(0);
    }

    function testBasicMint() public {
        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));

        uint tokenId = nftRegistry.mint(address(this), amount, minAmtPerSec);
        assertEq(nftRegistry.ownerOf(tokenId), address(this));

        hevm.warp(block.timestamp + CYCLE_SECS);

        uint128 preBalance = uint128(dai.balanceOf(address(this)));
        pool.collect();
        assertEqTol(dai.balanceOf(address(this)), preBalance + minAmtPerSec * CYCLE_SECS, "collect-failed");
    }

    function testFailNonMinAmt() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        uint tokenId = nftRegistry.mint(address(this), amount, minAmtPerSec-1);
    }

    function testFailNoApproval() public {
        uint128 amount = 20 ether;
        uint tokenId = nftRegistry.mint(address(this), amount, minAmtPerSec);
    }

    function testFailNotEnoughTopUp() public {
        uint128 amount = 9 ether;
        dai.approve(nftRegistry_, uint(amount));
        uint tokenId = nftRegistry.mint(address(this), amount, minAmtPerSec);
    }
}
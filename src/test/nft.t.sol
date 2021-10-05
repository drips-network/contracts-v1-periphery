// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import "ds-test/test.sol";
import "./../nft.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";


contract NFTRegistryTest is BaseTest {
    FundingNFT nftRegistry;
    address nftRegistry_;
    DaiPool pool;
    Dai dai;
    Hevm public hevm;

    uint128 public minAmtPerSec;

    uint128 public constant DEFAULT_NFT_TYPE = 0;

    function addNFTType(uint128 nftTypeId, uint128 limit) public {
        InputNFTType[] memory nftTypes = new InputNFTType[](1);
        nftTypes[0] = InputNFTType({nftTypeId: nftTypeId, limit:limit});
        nftRegistry.addTypes(nftTypes);
    }

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        pool = new DaiPool(CYCLE_SECS, dai);
        minAmtPerSec =  uint128(fundingInSeconds(10 ether));
        nftRegistry = new FundingNFT(pool, "Dummy Project", "DP", address(this), minAmtPerSec, new InputNFTType[](0));
        addNFTType(DEFAULT_NFT_TYPE, 100);
        nftRegistry_ = address(nftRegistry);
        // start with a full cycle
        hevm.warp(0);
    }

    function testBasicMint() public {
        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));

        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);

        assertEq(nftRegistry.ownerOf(tokenId), address(this));
        assertEq(nftRegistry.tokenType(tokenId), DEFAULT_NFT_TYPE);

        hevm.warp(block.timestamp + CYCLE_SECS);

        uint128 preBalance = uint128(dai.balanceOf(address(this)));
        pool.collect(address(this));
        uint128 shouldAmtCollected = preBalance + minAmtPerSec * CYCLE_SECS;
        assertEq(dai.balanceOf(address(this)), shouldAmtCollected, "collect-failed");
        assertEq(uint(amount-(minAmtPerSec * 2 * CYCLE_SECS)), uint(nftRegistry.withdrawable(uint128(tokenId))), "incorrect-withdrawable-amount");
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
        addNFTType(typeId, limit);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount, minAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);
        assertEq(bytes32(tokenId), bytes32(0x0000000000000000000000000000000200000000000000000000000000000001));
    }

    function testShouldFailDoubleNFTTypeId() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));

        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 1, limit:10});
        nftTypes[1] = InputNFTType({nftTypeId: 1, limit:10});

        try nftRegistry.addTypes(nftTypes) {
            assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
        assertEq(reason, "nftTypeId-already-in-usage", "Invalid mint revert reason");
        }
    }

    function testShouldFailLimitZero() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 1, limit:0});

        try nftRegistry.addTypes(nftTypes) {
        assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "zero-limit-not-allowed", "Invalid mint revert reason");
        }
    }

    function testLimit() public {
        uint128 typeId = 1;
        uint128 limit = 5;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint(amount));
        addNFTType(typeId, limit);
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
        addNFTType(typeId, limit);
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

    function testCreateTokenId() public {
        uint128 id = 1;
        uint128 nftType = 2;
        uint tokenId = nftRegistry.createTokenId(id, nftType);
        assertEq(bytes32(tokenId), bytes32(0x0000000000000000000000000000000200000000000000000000000000000001));
    }

    function testNFTTypeConversion() public {
        uint128 id = 1;
        uint128 nftType = 2;
        uint tokenId = nftRegistry.createTokenId(id, nftType);
        uint128 resultNFTType = nftRegistry.tokenType(tokenId);
        assertEq(resultNFTType, nftType);
    }

    function testSecsUntilInactiveCycleStart() public {
        // start: beginning of cycle
        // fundingPerCycle: 10 DAI
        // amount locked:   30 DAI
        // [10 DAI] - [10 DAI] - [10 DAI] - 0 DAI leftover

        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);


        assertEq(nftRegistry.secsUntilInactive(tokenId), CYCLE_SECS*3, "not-enough-three-cycles");

        // jump in the middle of the cycle
        hevm.warp(block.timestamp + CYCLE_SECS/2);

        assertEq(nftRegistry.secsUntilInactive(tokenId), CYCLE_SECS*2 + CYCLE_SECS/2, "fail-middle-cycle");

        // jump one sec before end
        hevm.warp(block.timestamp +  CYCLE_SECS*2 + CYCLE_SECS/2 - 1);

        assertEq(nftRegistry.secsUntilInactive(tokenId), 1, "not-active");
        // jump to the end
        hevm.warp(block.timestamp + 1);
        assertEq(nftRegistry.secsUntilInactive(tokenId), 0, "not-inactive");
    }

    function testSecsUntilInactiveMiddleCycle() public {
        // start: middle of cycle
        // fundingPerCycle: 10 DAI
        // amount locked:   30 DAI
        // [5 DAI] - [10 DAI] - [10 DAI] - 5 DAI leftover

        // jump in the middle of the cycle
        hevm.warp(block.timestamp + CYCLE_SECS/2);

        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, minAmtPerSec);

        assertEq(nftRegistry.secsUntilInactive(tokenId), CYCLE_SECS*2 + CYCLE_SECS/2, "not-enough-three-cycles");


        // jump one sec before end
        hevm.warp(block.timestamp +  CYCLE_SECS*2 + CYCLE_SECS/2 - 1);
        assertEq(nftRegistry.secsUntilInactive(tokenId), 1, "not-active");

        // jump to the end
        hevm.warp(block.timestamp + 1);
        assertEq(nftRegistry.secsUntilInactive(tokenId), 0, "not-inactive");

        // token inactive but withdrawable ~5 DAI
        uint totalStreamed = nftRegistry.amtPerSecond(tokenId) * (CYCLE_SECS*2 + CYCLE_SECS/2);
        assertEq(nftRegistry.withdrawable(tokenId), amount-totalStreamed, "incorrect-withdrawable-amount");
    }

    function testTopUp() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        uint balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawableBefore = nftRegistry.withdrawable(tokenId);
        uint128 topUp = 1 ether;
        dai.approve(address(nftRegistry), topUp);

        nftRegistry.topUp(tokenId, topUp);

        uint balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - topUp, "invalid-balance");
        uint128 withdrawableAfter = nftRegistry.withdrawable(tokenId);
        assertEq(withdrawableAfter, withdrawableBefore + topUp, "invalid-withdrawable");
    }

    function testTopUpForNotOwnedTokenFails() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        uint128 topUp = 1;
        dai.approve(address(nftRegistry), topUp);
        nftRegistry.transferFrom(address(this), address(1234), tokenId);

        try nftRegistry.topUp(tokenId, topUp) {
            assertTrue(false, "top-up-hasnt-reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "not-nft-owner", "invalid-top-up-revert-reason");
        }
    }

    function testWithdraw() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        uint balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawableBefore = nftRegistry.withdrawable(tokenId);
        uint128 withdrawn = 1 ether;

        uint withdrawnActual = nftRegistry.withdraw(tokenId, withdrawn);

        assertEq(withdrawnActual, withdrawn, "invalid-withdrawn");
        uint balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + withdrawn, "invalid-balance");
        uint128 withdrawableAfter = nftRegistry.withdrawable(tokenId);
        assertEq(withdrawableAfter, withdrawableBefore - withdrawn, "invalid-withdrawable");
    }

    function testWithdrawAll() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        uint balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawable = nftRegistry.withdrawable(tokenId);

        uint withdrawnActual = nftRegistry.withdraw(tokenId, nftRegistry.WITHDRAW_ALL());

        assertEq(withdrawnActual, withdrawable, "invalid-withdrawn");
        uint balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + withdrawable, "invalid-balance");
        assertEq(nftRegistry.withdrawable(tokenId), 0, "invalid-withdrawable");
    }

    function testWithdrawTooMuchFails() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        uint128 withdrawable = nftRegistry.withdrawable(tokenId);

        try nftRegistry.withdraw(tokenId, withdrawable + 1) {
            assertTrue(false, "withdraw-hasnt-reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "withdraw-amount-too-high", "invalid-withdraw-revert-reason");
        }
    }

    function testWithdrawForNotOwnedTokenFails() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, minAmtPerSec);
        nftRegistry.transferFrom(address(this), address(1234), tokenId);

        try nftRegistry.withdraw(tokenId, 1) {
            assertTrue(false, "withdraw-hasnt-reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "not-nft-owner", "invalid-withdraw-revert-reason");
        }
    }
}

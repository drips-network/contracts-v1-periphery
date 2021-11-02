// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import "./../nft.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Address.sol";

contract TestDai is Dai {
    function mint(uint amount) public {
        _mint(msg.sender, amount);
    }
}

contract NFTRegistryTest is BaseTest {
    FundingNFT public nftRegistry;
    address public nftRegistry_;
    DaiPool public pool;
    TestDai public dai;
    Hevm public hevm;

    uint constant public ONE_TRILLION_DAI = (1 ether * 10**12);

    uint128 public defaultMinAmtPerSec;

    uint64 public constant DEFAULT_NFT_TYPE = 0;

    function noDrips() public pure returns (Receiver[] memory) {
        return new Receiver[](0);
    }

    function addNFTType(uint128 nftTypeId, uint64 limit, uint128 minAmtPerSec) public {
        InputNFTType[] memory nftTypes = new InputNFTType[](1);
        nftTypes[0] = InputNFTType({nftTypeId: nftTypeId, limit:limit, minAmtPerSec: minAmtPerSec});
        nftRegistry.addTypes(nftTypes);
    }

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new TestDai();
        pool = new DaiPool(CYCLE_SECS, dai);
        defaultMinAmtPerSec =  uint128(fundingInSeconds(10 ether));
        nftRegistry = new FundingNFT(pool);
        nftRegistry.init("Dummy Project", "DP", address(this) ,"ipfsHash",  new InputNFTType[](0));
        // testing addNFTType function
        addNFTType(DEFAULT_NFT_TYPE, uint64(100), defaultMinAmtPerSec);
        nftRegistry_ = address(nftRegistry);
        // start with a full cycle
        hevm.warp(0);
    }

    function mint(uint128 amtPerSec, uint128 amtTopUp) public returns(uint tokenId) {
        dai.approve(nftRegistry_, uint(amtTopUp));
        tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amtTopUp, amtPerSec);
        assertEq(nftRegistry.ownerOf(tokenId), address(this));
        assertEq(nftRegistry.tokenType(tokenId), DEFAULT_NFT_TYPE);
    }

    function testBasicMint() public {
        uint128 amtTopUp = 30 ether;
        uint tokenId =  mint(defaultMinAmtPerSec, amtTopUp);

        hevm.warp(block.timestamp + CYCLE_SECS);

        uint128 preBalance = uint128(dai.balanceOf(address(this)));
        uint128 expectedCollected = defaultMinAmtPerSec * CYCLE_SECS;
        (uint128 collectable, ) = nftRegistry.collectable(noDrips());
        nftRegistry.collect(noDrips());
        assertEq(collectable, expectedCollected, "collectable-invalid");
        assertEq(dai.balanceOf(address(this)), preBalance + expectedCollected, "collect-failed");
        assertEq(uint(amtTopUp-(defaultMinAmtPerSec * 1 * CYCLE_SECS)), uint(nftRegistry.withdrawable(uint128(tokenId))), "incorrect-withdrawable-amount");
    }

    function testFailNonMinAmt() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, defaultMinAmtPerSec-1);
    }

    function testFailNoApproval() public {
        uint128 amount = 20 ether;
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, defaultMinAmtPerSec);
    }

    function testFailNotEnoughTopUp() public {
        uint128 amount = 9 ether;
        dai.approve(nftRegistry_, uint(amount));
        nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amount, defaultMinAmtPerSec);
    }

    function testAddType() public {
        uint64 typeId = 2;
        uint64 shouldLimit = 200;
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        addNFTType(typeId, shouldLimit, defaultMinAmtPerSec);
        (uint limit, uint minted, uint minAmtPerSec) = nftRegistry.nftTypes(typeId);
        assertEq(limit, shouldLimit, "incorrect-limit");
        assertEq(minted, 0, "incorrect-minted");
        assertEq(minAmtPerSec, defaultMinAmtPerSec, "incorrect-minAmtPerSec");

        uint tokenId = nftRegistry.mint(address(this), typeId,  amount, defaultMinAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);
        assertEq(bytes32(tokenId), bytes32(0x0000000000000000000000000000000200000000000000000000000000000001));
    }

    function testShouldFailDoubleNFTTypeId() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));

        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 1, limit:10, minAmtPerSec: defaultMinAmtPerSec});
        nftTypes[1] = InputNFTType({nftTypeId: 1, limit:10, minAmtPerSec: defaultMinAmtPerSec});

        try nftRegistry.addTypes(nftTypes) {
            assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
        assertEq(reason, "nft-type-already-exists", "Invalid mint revert reason");
        }
    }

    function testShouldFailLimitZero() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint(amount));
        InputNFTType[] memory nftTypes = new InputNFTType[](2);
        nftTypes[0] = InputNFTType({nftTypeId: 1, limit:0, minAmtPerSec: 10});

        try nftRegistry.addTypes(nftTypes) {
        assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "zero-limit-not-allowed", "Invalid mint revert reason");
        }
    }

    function testLimit() public {
        uint128 typeId = 1;
        uint64 limit = 5;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint(amount));
        addNFTType(typeId, limit, defaultMinAmtPerSec);
        uint tokenId;
        for (uint i =0; i<limit;i++) {
            tokenId = nftRegistry.mint(address(this), typeId,  amount/5, defaultMinAmtPerSec);
            assertEq(nftRegistry.tokenType(tokenId), typeId);
        }
        (, uint minted, ) = nftRegistry.nftTypes(typeId);
        assertEq(minted, limit);
    }

    function testShouldFailMoreThanLimit() public {
        uint128 typeId = 1;
        uint64 limit = 1;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint(amount));
        addNFTType(typeId, limit, defaultMinAmtPerSec);
        uint tokenId = nftRegistry.mint(address(this), typeId,  amount/2, defaultMinAmtPerSec);
        assertEq(nftRegistry.tokenType(tokenId), typeId);

        (, uint minted, ) = nftRegistry.nftTypes(typeId);
        emit log_named_uint("minted", minted);

        // should fail nft-type-reached-limit
        try nftRegistry.mint(address(this), typeId, amount/2, defaultMinAmtPerSec) {
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

    function testZeroAmtPerSec() public {
        uint128 nftType = 2;
        uint64 limit = 100;
        uint128 minAmtPerSec = 0;
        addNFTType(nftType, limit, minAmtPerSec);
        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint(amount));
        uint tokenId = nftRegistry.mint(address(this), nftType, amount, minAmtPerSec);

        assertEq(nftRegistry.activeUntil(tokenId), type(uint128).max);
    }

    function testTopUp() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
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
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
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
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
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
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
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
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
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
        uint tokenId = nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, initial, defaultMinAmtPerSec);
        nftRegistry.transferFrom(address(this), address(1234), tokenId);

        try nftRegistry.withdraw(tokenId, 1) {
            assertTrue(false, "withdraw-hasnt-reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "not-nft-owner", "invalid-withdraw-revert-reason");
        }
    }

    function testInfluence() public {
        uint128 amtTopUp = 30 ether;
        uint amtPerCycle = 10 ether;
        uint128 amtPerSec = uint128(fundingInSeconds(amtPerCycle));
        uint tokenId = mint(amtPerSec, amtTopUp);
        assertEq(nftRegistry.influence(tokenId), amtPerSec);

        // enough for 3 cycles
        hevm.warp(block.timestamp + CYCLE_SECS * 3-1);
        assertEq(nftRegistry.influence(tokenId), amtPerSec);

        // influence should stop after token is inactive
        hevm.warp(block.timestamp + 1);
        assertEq(nftRegistry.influence(tokenId), 0);
    }

    function testChangeIpfsHash() public {
        nftRegistry.changeIPFSHash("newIpfsHash");
        assertEq(nftRegistry.contractURI(), "newIpfsHash");
    }

    function testActiveUntil() public {
        hevm.warp(block.timestamp + 2 days);
        uint128 amtTopUp = 30 ether;
        uint128 amtPerSec = uint128(fundingInSeconds(10 ether));
        uint tokenId =  mint(amtPerSec, amtTopUp);
        uint activeUntil = nftRegistry.activeUntil(tokenId);

        hevm.warp(activeUntil);
        assertTrue(nftRegistry.active(tokenId), "not-active");
        hevm.warp(block.timestamp + 1 );
        assertTrue(nftRegistry.active(tokenId) == false, "not-inactive");
    }

    function topUpTooLowShouldFail(uint128 amtPerSec, uint128 amtTopUp) public {
        dai.approve(nftRegistry_, uint(amtTopUp));
        try nftRegistry.mint(address(this), DEFAULT_NFT_TYPE, amtTopUp, amtPerSec) {
            assertTrue(false, "mint-did-not-fail-topUp-too-low");
        } catch Error(string memory reason) {
        assertEq(reason, "toUp-too-low", "invalid-error");
        }
    }

    function testTopUp(uint128 amtTopUp) public {
        if (amtTopUp == 0 || amtTopUp > ONE_TRILLION_DAI) {
            return;
        }
        dai.mint(amtTopUp);

        hevm.warp(block.timestamp + amtTopUp % 30 days);
        uint128 amtCycle = 10 ether;
        uint128 amtPerSec = uint128(fundingInSeconds(amtCycle));

        if(amtTopUp < amtCycle) {
            topUpTooLowShouldFail(amtPerSec, amtTopUp);
        } else {
            uint tokenId =  mint(amtPerSec, amtTopUp);
            uint activeUntil = nftRegistry.activeUntil(tokenId);

            hevm.warp(activeUntil);
            assertTrue(nftRegistry.active(tokenId), "not-active");

            // should be inac
            hevm.warp(block.timestamp + 1);
            assertTrue(nftRegistry.active(tokenId) == false, "not-inactive");
        }

    }

    function testDrip() public {
        FundingNFT projectB = new FundingNFT(pool);
        address arbitraryDripReceiver = address(0x123);
        projectB.init("Project B", "B", address(this) ,"ipfsHash",  new InputNFTType[](0));

        //supporter starts to support default project
        mint(defaultMinAmtPerSec, 30 ether);

        // default project decides 40% should go to drips
        uint32 shouldDripFraction = uint32(pool.MAX_DRIPS_FRACTION()/10 * 4);

        // first drips should only go to project B
        Receiver[] memory drips = new Receiver[](1);
        drips[0] = Receiver(address(projectB), 1);
        nftRegistry.drip(shouldDripFraction, noDrips(), drips);

        uint32 dripFraction = pool.getDripsFraction(address(nftRegistry));
        assertEq(dripFraction, shouldDripFraction, "incorrect-drip-fraction");
        hevm.warp(block.timestamp + CYCLE_SECS);

        (uint128 amtProjectA, uint128 dripped) = nftRegistry.collect(drips);
        assertEq(amtProjectA, (CYCLE_SECS * defaultMinAmtPerSec)/10 * 6, "project A didn't receive drips");
        (uint128 amtProjectB, ) = projectB.collect(noDrips());
        assertEq(amtProjectB, (CYCLE_SECS * defaultMinAmtPerSec)/10 * 4, "project B didn't receive drips");
        assertEq(amtProjectB, dripped, "project B didn't receive all drips");

        // default project change drips: project B (80%) and arbitraryDripReceiver (20%)
        // dripFraction to 50%
        Receiver[] memory newDrips = new Receiver[](2);
        newDrips[0] = Receiver(address(projectB), 4);
        newDrips[1] = Receiver(arbitraryDripReceiver, 1);
        if(address(projectB) > arbitraryDripReceiver) {
            (newDrips[0], newDrips[1]) = (newDrips[1], newDrips[0]);
        }

        shouldDripFraction = uint32(pool.MAX_DRIPS_FRACTION()/10 * 5);
        nftRegistry.drip(shouldDripFraction, drips, newDrips);

        // next cycle
        hevm.warp(block.timestamp + CYCLE_SECS);

        // default project gets 50%
        (amtProjectA, ) = nftRegistry.collect(newDrips);
        assertEq(amtProjectA, (CYCLE_SECS * defaultMinAmtPerSec)/10 * 5, "project A didn't receive drips");

        // projectB gets 30%
        (amtProjectB, ) = projectB.collect(noDrips());
        assertEq(amtProjectB, (CYCLE_SECS * defaultMinAmtPerSec)/10 * 4, "project B didn't receive drips");

        // arbitraryDripReceiver gets 10%
        pool.collect(arbitraryDripReceiver, noDrips());
        assertEq(dai.balanceOf(arbitraryDripReceiver), (CYCLE_SECS * defaultMinAmtPerSec)/10, "arbitraryDripReceiver didn't receive");

    }
}

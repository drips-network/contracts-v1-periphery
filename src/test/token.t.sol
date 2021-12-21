// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import "./../token.sol";
import {Dai} from "drips-hub/test/TestDai.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {Hevm} from "./hevm.t.sol";
import {DefaultSVGBuilder} from "../builder/svgBuilder.sol";
import {ManagedDripsHubProxy} from "drips-hub/ManagedDripsHub.sol";
import {ERC20Reserve} from "drips-hub/ERC20Reserve.sol";

import "../../lib/ds-test/src/test.sol";

contract TestDai is Dai {
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract TokenRegistryTest is DSTest {
    DripsToken public nftRegistry;
    address public nftRegistry_;
    DaiDripsHub public hub;
    TestDai public dai;
    DefaultSVGBuilder public builder;
    Hevm public hevm;

    uint256 public constant ONE_TRILLION_DAI = (1 ether * 10**12);
    uint64 public constant CYCLE_SECS = 7 days;
    uint64 public constant LOCK_SECS = 30 days;

    uint128 public defaultMinAmtPerSec;

    uint64 public constant DEFAULT_TOKEN_TYPE = 0;

    function noSplits() public pure returns (SplitsReceiver[] memory) {
        return new SplitsReceiver[](0);
    }

    function splitPercent(uint32 percent) public view returns (uint32 weight) {
        return (hub.TOTAL_SPLITS_WEIGHT() * percent) / 100;
    }

    function addStreamingType(
        DripsToken nftReg,
        uint128 nftTypeId,
        uint64 limit,
        uint128 minAmtPerSec
    ) public {
        addType(nftReg, nftTypeId, limit, minAmtPerSec, true);
    }

    function addType(
        DripsToken nftReg,
        uint128 nftTypeId,
        uint64 limit,
        uint128 minAmt,
        bool streaming
    ) public {
        InputType[] memory nftTypes = new InputType[](1);
        nftTypes[0] = InputType({
            nftTypeId: nftTypeId,
            limit: limit,
            minAmt: minAmt,
            ipfsHash: "",
            streaming: streaming
        });
        nftReg.addTypes(nftTypes);
    }

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new TestDai();

        DaiDripsHub hubLogic = new DaiDripsHub(CYCLE_SECS, dai);
        ManagedDripsHubProxy proxy = new ManagedDripsHubProxy(hubLogic, address(this));
        hub = DaiDripsHub(address(proxy));
        ERC20Reserve reserve = new ERC20Reserve(dai, address(this), address(hub));
        hub.setReserve(reserve);

        defaultMinAmtPerSec = amtPerSecThatLocks(10 ether);
        nftRegistry = new DripsToken(hub, address(this), LOCK_SECS);
        // testing addStreamingType function
        builder = new DefaultSVGBuilder();
        nftRegistry.init(
            "Dummy Project",
            "DP",
            address(this),
            "ipfsHash",
            new InputType[](0),
            builder,
            noSplits()
        );
        addStreamingType(nftRegistry, DEFAULT_TOKEN_TYPE, uint64(100), defaultMinAmtPerSec);
        nftRegistry_ = address(nftRegistry);
        // start with a full cycle
        hevm.warp(0);
    }

    function amtPerSecThatLocks(uint256 amtToLock) public pure returns (uint128) {
        return uint128(amtToLock / LOCK_SECS);
    }

    function mint(uint128 amtPerSec, uint128 amtTopUp) public returns (uint256 tokenId) {
        dai.approve(nftRegistry_, uint256(amtTopUp));
        tokenId = nftRegistry.mintStreaming(address(this), DEFAULT_TOKEN_TYPE, amtTopUp, amtPerSec);
        assertEq(nftRegistry.ownerOf(tokenId), address(this));
        assertEq(nftRegistry.tokenType(tokenId), DEFAULT_TOKEN_TYPE);
    }

    function testBasicMint() public {
        uint128 amtTopUp = 30 ether;
        uint256 tokenId = mint(defaultMinAmtPerSec, amtTopUp);

        hevm.warp(block.timestamp + CYCLE_SECS);

        uint128 preBalance = uint128(dai.balanceOf(address(this)));
        uint128 expectedCollected = defaultMinAmtPerSec * CYCLE_SECS;
        (uint128 collectable, ) = nftRegistry.collectable(noSplits());
        nftRegistry.collect(noSplits());
        assertEq(collectable, expectedCollected, "collectable-invalid");
        assertEq(dai.balanceOf(address(this)), preBalance + expectedCollected, "collect-failed");
        assertEq(
            uint256(amtTopUp - (defaultMinAmtPerSec * LOCK_SECS)),
            uint256(nftRegistry.withdrawable(uint128(tokenId))),
            "incorrect-withdrawable-amount"
        );
    }

    function testFailNonMinAmt() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint256(amount));
        nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            amount,
            defaultMinAmtPerSec - 1
        );
    }

    function testFailNoApproval() public {
        uint128 amount = 20 ether;
        nftRegistry.mintStreaming(address(this), DEFAULT_TOKEN_TYPE, amount, defaultMinAmtPerSec);
    }

    function testFailNotEnoughTopUp() public {
        uint128 amount = 9 ether;
        dai.approve(nftRegistry_, uint256(amount));
        nftRegistry.mintStreaming(address(this), DEFAULT_TOKEN_TYPE, amount, defaultMinAmtPerSec);
    }

    function testAddType() public {
        uint64 typeId = 2;
        uint64 shouldLimit = 200;
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint256(amount));
        addStreamingType(nftRegistry, typeId, shouldLimit, defaultMinAmtPerSec);
        (uint256 limit, uint256 minted, uint256 minAmtPerSec, , ) = nftRegistry.nftTypes(typeId);
        assertEq(limit, shouldLimit, "incorrect-limit");
        assertEq(minted, 0, "incorrect-minted");
        assertEq(minAmtPerSec, defaultMinAmtPerSec, "incorrect-minAmtPerSec");

        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            typeId,
            amount,
            defaultMinAmtPerSec
        );
        assertEq(nftRegistry.tokenType(tokenId), typeId);
        assertEq(
            bytes32(tokenId),
            bytes32(0x0000000000000000000000000000000200000000000000000000000000000001)
        );
    }

    function testShouldFailDoubleTypeId() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint256(amount));

        InputType[] memory nftTypes = new InputType[](2);
        nftTypes[0] = InputType({
            nftTypeId: 1,
            limit: 10,
            minAmt: defaultMinAmtPerSec,
            ipfsHash: "",
            streaming: true
        });
        nftTypes[1] = InputType({
            nftTypeId: 1,
            limit: 10,
            minAmt: defaultMinAmtPerSec,
            ipfsHash: "",
            streaming: true
        });

        try nftRegistry.addTypes(nftTypes) {
            assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "nft-type-already-exists", "Invalid mint revert reason");
        }
    }

    function testShouldFailLimitZero() public {
        uint128 amount = 20 ether;
        dai.approve(nftRegistry_, uint256(amount));
        InputType[] memory nftTypes = new InputType[](2);
        nftTypes[0] = InputType({
            nftTypeId: 1,
            limit: 0,
            minAmt: 10,
            ipfsHash: "",
            streaming: true
        });

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
        dai.approve(nftRegistry_, uint256(amount));
        addStreamingType(nftRegistry, typeId, limit, defaultMinAmtPerSec);
        uint256 tokenId;
        for (uint256 i = 0; i < limit; i++) {
            tokenId = nftRegistry.mintStreaming(
                address(this),
                typeId,
                amount / 5,
                defaultMinAmtPerSec
            );
            assertEq(nftRegistry.tokenType(tokenId), typeId);
        }
        (, uint256 minted, , , ) = nftRegistry.nftTypes(typeId);
        assertEq(minted, limit);
    }

    function testShouldFailMoreThanLimit() public {
        uint128 typeId = 1;
        uint64 limit = 1;
        uint128 amount = 100 ether;
        dai.approve(nftRegistry_, uint256(amount));
        addStreamingType(nftRegistry, typeId, limit, defaultMinAmtPerSec);
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            typeId,
            amount / 2,
            defaultMinAmtPerSec
        );
        assertEq(nftRegistry.tokenType(tokenId), typeId);

        (, uint256 minted, , , ) = nftRegistry.nftTypes(typeId);
        emit log_named_uint("minted", minted);

        // should fail nft-type-reached-limit
        try nftRegistry.mintStreaming(address(this), typeId, amount / 2, defaultMinAmtPerSec) {
            assertTrue(false, "Mint hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "nft-type-reached-limit", "Invalid mint revert reason");
        }
    }

    function testCreateTokenId() public {
        uint128 id = 1;
        uint128 nftType = 2;
        uint256 tokenId = nftRegistry.createTokenId(id, nftType);
        assertEq(
            bytes32(tokenId),
            bytes32(0x0000000000000000000000000000000200000000000000000000000000000001)
        );
    }

    function testTypeConversion() public {
        uint128 id = 1;
        uint128 nftType = 2;
        uint256 tokenId = nftRegistry.createTokenId(id, nftType);
        uint128 resultType = nftRegistry.tokenType(tokenId);
        assertEq(resultType, nftType);
        assertEq(id, uint128(tokenId));
    }

    function testZeroAmtPerSec() public {
        uint128 nftType = 2;
        uint64 limit = 100;
        uint128 minAmtPerSec = 0;
        addStreamingType(nftRegistry, nftType, limit, minAmtPerSec);
        uint128 amount = 30 ether;
        dai.approve(nftRegistry_, uint256(amount));
        uint256 tokenId = nftRegistry.mintStreaming(address(this), nftType, amount, minAmtPerSec);

        assertEq(nftRegistry.activeUntil(tokenId), type(uint128).max);
    }

    function testTopUp() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            initial,
            defaultMinAmtPerSec
        );
        uint256 balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawableBefore = nftRegistry.withdrawable(tokenId);
        uint128 topUp = 1 ether;
        dai.approve(address(nftRegistry), topUp);

        nftRegistry.topUp(tokenId, topUp);

        uint256 balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - topUp, "invalid-balance");
        uint128 withdrawableAfter = nftRegistry.withdrawable(tokenId);
        assertEq(withdrawableAfter, withdrawableBefore + topUp, "invalid-withdrawable");
    }

    function testTopUpForNotOwnedTokenFails() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            initial,
            defaultMinAmtPerSec
        );
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
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            initial,
            defaultMinAmtPerSec
        );
        uint256 balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawableBefore = nftRegistry.withdrawable(tokenId);
        uint128 withdrawn = 1 ether;

        uint256 withdrawnActual = nftRegistry.withdraw(tokenId, withdrawn);

        assertEq(withdrawnActual, withdrawn, "invalid-withdrawn");
        uint256 balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + withdrawn, "invalid-balance");
        uint128 withdrawableAfter = nftRegistry.withdrawable(tokenId);
        assertEq(withdrawableAfter, withdrawableBefore - withdrawn, "invalid-withdrawable");
    }

    function testWithdrawingMoreThanWithdrawable() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            initial,
            defaultMinAmtPerSec
        );
        uint256 balanceBefore = dai.balanceOf(address(this));
        uint128 withdrawable = nftRegistry.withdrawable(tokenId);

        uint256 withdrawnActual = nftRegistry.withdraw(tokenId, type(uint128).max);

        assertEq(withdrawnActual, withdrawable, "invalid-withdrawn");
        uint256 balanceAfter = dai.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + withdrawable, "invalid-balance");
        assertEq(nftRegistry.withdrawable(tokenId), 0, "invalid-withdrawable");
    }

    function testWithdrawForNotOwnedTokenFails() public {
        uint128 initial = 30 ether;
        dai.approve(address(nftRegistry), initial);
        uint256 tokenId = nftRegistry.mintStreaming(
            address(this),
            DEFAULT_TOKEN_TYPE,
            initial,
            defaultMinAmtPerSec
        );
        nftRegistry.transferFrom(address(this), address(1234), tokenId);

        try nftRegistry.withdraw(tokenId, 1) {
            assertTrue(false, "withdraw-hasnt-reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "not-nft-owner", "invalid-withdraw-revert-reason");
        }
    }

    function testInfluence() public {
        uint128 amtTopUp = 30 ether;
        uint128 amtPerSec = amtPerSecThatLocks(10 ether);
        uint256 tokenId = mint(amtPerSec, amtTopUp);
        // zero influence at mint block.timestamp
        assertEq(nftRegistry.influence(tokenId), 0);

        uint256 initTime = block.timestamp;

        // enough for 3 cycles
        hevm.warp(block.timestamp + LOCK_SECS * 3 - 1);
        assertTrue(nftRegistry.streaming(tokenId), "not-streaming-token");
        assertEq(nftRegistry.influence(tokenId), (block.timestamp - initTime) * amtPerSec);

        // influence should stop after token is inactive
        hevm.warp(block.timestamp + 1);
        assertEq(nftRegistry.influence(tokenId), 0);

        // one time support
        uint128 minGiveAmt = 100 ether;
        uint128 nftTypeId = 2;
        uint64 limit = 1;
        uint128 giveAmt = 110 ether;
        tokenId = setup1TimeSupport(minGiveAmt, limit, nftTypeId, giveAmt);

        assertTrue(nftRegistry.streaming(tokenId) == false, "streaming-support");
        assertEq(nftRegistry.influence(tokenId), giveAmt);
        hevm.warp(block.timestamp + 1000 days);
        assertEq(nftRegistry.influence(tokenId), giveAmt);
    }

    function testChangeContractURI() public {
        nftRegistry.changeContractURI("newIpfsHash");
        assertEq(nftRegistry.contractURI(), "newIpfsHash");
    }

    function testActiveUntil() public {
        hevm.warp(block.timestamp + 2 days);
        uint128 amtTopUp = 30 ether;
        uint128 amtPerSec = amtPerSecThatLocks(10 ether);
        uint256 tokenId = mint(amtPerSec, amtTopUp);
        uint256 activeUntil = nftRegistry.activeUntil(tokenId);

        hevm.warp(activeUntil);
        assertTrue(nftRegistry.active(tokenId), "not-active");
        hevm.warp(block.timestamp + 1);
        assertTrue(nftRegistry.active(tokenId) == false, "not-inactive");
    }

    function topUpTooLowShouldFail(uint128 amtPerSec, uint128 amtTopUp) public {
        dai.approve(nftRegistry_, uint256(amtTopUp));
        try nftRegistry.mintStreaming(address(this), DEFAULT_TOKEN_TYPE, amtTopUp, amtPerSec) {
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

        hevm.warp(block.timestamp + (amtTopUp % 30 days));
        uint128 amtLocked = 10 ether;
        uint128 amtPerSec = amtPerSecThatLocks(amtLocked);

        if (amtTopUp < amtLocked) {
            topUpTooLowShouldFail(amtPerSec, amtTopUp);
        } else {
            uint256 tokenId = mint(amtPerSec, amtTopUp);
            uint256 activeUntil = nftRegistry.activeUntil(tokenId);

            hevm.warp(activeUntil);
            assertTrue(nftRegistry.active(tokenId), "not-active");

            // should be inac
            hevm.warp(block.timestamp + 1);
            assertTrue(nftRegistry.active(tokenId) == false, "not-inactive");
        }
    }

    function testSplits() public {
        DripsToken projectB = new DripsToken(hub, address(this), LOCK_SECS);
        address arbitrarySplitsReceiver = address(uint160(address(projectB)) + 1);
        projectB.init(
            "Project B",
            "B",
            address(this),
            "ipfsHash",
            new InputType[](0),
            builder,
            noSplits()
        );

        //supporter starts to support default project
        mint(defaultMinAmtPerSec, 30 ether);

        SplitsReceiver[] memory splits = new SplitsReceiver[](1);
        splits[0] = SplitsReceiver(address(projectB), splitPercent(40));
        nftRegistry.changeSplitsReceivers(noSplits(), splits);

        hevm.warp(block.timestamp + CYCLE_SECS);

        (uint128 amtProjectA, uint128 split) = nftRegistry.collect(splits);
        assertEq(
            amtProjectA,
            ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 6,
            "project A didn't receive splits"
        );
        (uint128 amtProjectB, ) = projectB.collect(noSplits());
        assertEq(
            amtProjectB,
            ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 4,
            "project B didn't receive splits"
        );
        assertEq(amtProjectB, split, "project B didn't receive all splits");

        SplitsReceiver[] memory newSplits = new SplitsReceiver[](2);
        newSplits[0] = SplitsReceiver(address(projectB), splitPercent(40));
        newSplits[1] = SplitsReceiver(arbitrarySplitsReceiver, splitPercent(10));

        nftRegistry.changeSplitsReceivers(splits, newSplits);

        // next cycle
        hevm.warp(block.timestamp + CYCLE_SECS);

        // default project gets 50%
        (amtProjectA, ) = nftRegistry.collect(newSplits);
        assertEq(
            amtProjectA,
            ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 5,
            "project A didn't receive splits"
        );

        // projectB gets 30%
        (amtProjectB, ) = projectB.collect(noSplits());
        assertEq(
            amtProjectB,
            ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 4,
            "project B didn't receive splits"
        );

        // arbitrarySplitsReceiver gets 10%
        hub.collect(arbitrarySplitsReceiver, noSplits());
        assertEq(
            dai.balanceOf(arbitrarySplitsReceiver),
            (CYCLE_SECS * defaultMinAmtPerSec) / 10,
            "arbitrarySplitsReceiver didn't receive"
        );
    }

    function testSplitWithInit() public {
        address alice = address(0x123);
        DripsToken projectB = new DripsToken(hub, address(this), LOCK_SECS);

        uint128 typeId = 0;
        uint64 limit = 1;
        addStreamingType(projectB, typeId, limit, defaultMinAmtPerSec);

        // split to alice
        SplitsReceiver[] memory splits = new SplitsReceiver[](1);
        splits[0] = SplitsReceiver(alice, splitPercent(40));

        // init projcect with splits
        projectB.init(
            "Project B",
            "B",
            address(this),
            "ipfsHash",
            new InputType[](0),
            builder,
            splits
        );

        uint128 amtTopUp = 30 ether;
        dai.approve(address(projectB), uint256(amtTopUp));
        projectB.mintStreaming(address(this), DEFAULT_TOKEN_TYPE, amtTopUp, defaultMinAmtPerSec);

        // next cycle
        hevm.warp(block.timestamp + CYCLE_SECS);

        (uint128 amtProjectB, uint128 amtAlice) = projectB.collect(splits);
        assertEq(
            amtProjectB,
            ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 6,
            "project A didn't receive splits"
        );
        hub.collect(alice, noSplits());
        assertEq(amtAlice, ((CYCLE_SECS * defaultMinAmtPerSec) / 10) * 4);
        assertEq(amtAlice, dai.balanceOf(alice), "incorrect-dai-amount");
    }

    function testTokenURI() public {
        uint128 amtTopUp = 30 ether;
        uint256 tokenId = mint(defaultMinAmtPerSec, amtTopUp);
        assertEq(address(builder), address(nftRegistry.builder()), "builder-not-set");
        nftRegistry.tokenURI(tokenId);
    }

    function testFailNonExistingTokenURI() public view {
        nftRegistry.tokenURI(1234);
    }

    function setup1TimeSupport(
        uint128 minGiveAmt,
        uint64 limit,
        uint128 nftTypeId,
        uint128 giveAmt
    ) public returns (uint256 tokenId) {
        addType(nftRegistry, nftTypeId, limit, minGiveAmt, false);
        dai.approve(address(nftRegistry), uint256(giveAmt));

        uint256 preBalance = dai.balanceOf(address(this));
        tokenId = nftRegistry.mint(address(this), nftTypeId, giveAmt);
        assertEq(dai.balanceOf(address(this)), preBalance - giveAmt);

        assertEq(nftRegistry.activeUntil(tokenId), type(uint128).max);
    }

    function testOneTimeGive() public {
        uint128 minGiveAmt = 100 ether;
        uint128 nftTypeId = 2;
        uint64 limit = 1;
        uint128 giveAmt = 110 ether;
        setup1TimeSupport(minGiveAmt, limit, nftTypeId, giveAmt);
        (uint128 collected, ) = nftRegistry.collect(noSplits());
        assertEq(collected, giveAmt);
    }

    function testOneTimeMinGive() public {
        uint128 minGiveAmt = 100 ether;
        uint128 nftTypeId = 2;
        uint64 limit = 1;
        uint128 giveAmt = 100 ether;
        setup1TimeSupport(minGiveAmt, limit, nftTypeId, giveAmt);
        (uint128 collected, ) = nftRegistry.collect(noSplits());
        assertEq(collected, giveAmt);
    }

    function testAuthMint() public {
        uint128 influence = 10 ether;
        uint128 nftTypeId = 2;
        uint64 limit = 10;
        addType(nftRegistry, nftTypeId, limit, 20 ether, false);

        uint256 tokenId = nftRegistry.authMint(address(0xB), 2, influence);
        assertEq(nftRegistry.ownerOf(tokenId), address(0xB));
        assertEq(nftRegistry.influence(tokenId), influence);

        // check only owner
        nftRegistry.transferOwnership(address(0xC));
        try nftRegistry.authMint(address(0xB), 2, influence) {
            assertTrue(false, "auth-mint-should-fail");
        } catch Error(string memory reason) {
            assertEq(reason, "Ownable: caller is not the owner");
        }
    }
}

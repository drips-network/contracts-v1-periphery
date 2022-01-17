// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable no-inline-assembly
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {Governance, Executor, Spell} from "./governance.sol";
import {IFxMessageProcessor, PolygonSpellScheduler} from "./polygonSpellScheduler.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Hevm} from "../test/hevm.t.sol";

contract FxChild {
    function sendMessage(
        IFxMessageProcessor receiver,
        address sender,
        bytes memory message
    ) public {
        receiver.processMessageFromRoot(0, sender, message);
    }
}

contract TestSpell is Spell {
    function execute() external pure override {
        return;
    }
}

contract ChangeOwnerSpell is Spell {
    PolygonSpellScheduler public immutable scheduler;
    address public immutable newOwner;

    constructor(PolygonSpellScheduler scheduler_, address newOwner_) {
        scheduler = scheduler_;
        newOwner = newOwner_;
    }

    function execute() external override {
        scheduler.transferGovernanceOwnership(newOwner);
    }
}

contract GovernanceTest is DSTest {
    // Hevm public hevm;
    // dummy L1 owner address
    address public constant OWNER = address(0xC0FFEE);
    PolygonSpellScheduler public scheduler;
    FxChild public fxChild;
    Governance public governance;
    address public spell;

    function setUp() public {
        // Spell scheduling doesn't work with block timestamp 0
        Hevm(HEVM_ADDRESS).warp(1);
        fxChild = new FxChild();
        governance = new Governance(address(this));
        scheduler = new PolygonSpellScheduler(OWNER, address(fxChild), governance);
        governance.transferOwnership(address(scheduler));
        spell = address(new TestSpell());
    }

    function testSchedulesSpell() public {
        fxChild.sendMessage(scheduler, OWNER, abi.encode(spell));
        governance.execute(spell);
    }

    function testRejectsSchedulingNotFromFxChild() public {
        FxChild fakeFxChild = new FxChild();
        try fakeFxChild.sendMessage(scheduler, OWNER, abi.encode(spell)) {
            assertTrue(false, "Hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "Caller is not the fxChild", "Invalid revert reason");
        }
    }

    function testRejectsSchedulingFromInvaildOwner() public {
        try fxChild.sendMessage(scheduler, address(0xBAD), abi.encode(spell)) {
            assertTrue(false, "Hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "Message not from the owner", "Invalid revert reason");
        }
    }

    function testFailRejectsMalformedMessages() public {
        fxChild.sendMessage(scheduler, OWNER, abi.encode(uint168(type(uint160).max) + 1));
    }

    function testChangeOwnership() public {
        assertEq(governance.owner(), address(scheduler), "Invalid owner before");
        address newScheduler = address(0x1234);
        address ownerSpell = address(new ChangeOwnerSpell(scheduler, newScheduler));
        fxChild.sendMessage(scheduler, OWNER, abi.encode(ownerSpell));
        governance.execute(ownerSpell);
        assertEq(governance.owner(), address(newScheduler), "Invalid owner after");
    }

    function testRejectsChangeOwnershipIfSenderNotExecutor() public {
        try scheduler.transferGovernanceOwnership(address(0xBAD)) {
            assertTrue(false, "Hasn't reverted");
        } catch Error(string memory reason) {
            assertEq(reason, "Caller is not the executor", "Invalid revert reason");
        }
    }
}

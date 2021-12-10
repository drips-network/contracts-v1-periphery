// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable no-inline-assembly
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {Governance, Executor, Spell} from "./governance.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Hevm} from "../test/hevm.t.sol";

// contract should be maintained by governance
contract DripsContract is Ownable {
    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    uint256 public value = 0;

    function setValue(uint256 newValue) public onlyOwner {
        value = newValue;
    }
}

// contract which performs a set of instructions
// no state
contract ChangeValueSpell is Spell {
    DripsContract public immutable dripsContract;

    constructor(DripsContract dripsContract_) {
        dripsContract = dripsContract_;
    }

    function execute() public override {
        dripsContract.setValue(1);
    }
}

contract GovernanceDelaySpellAction is Spell {
    Governance public immutable governance;

    constructor(Governance governance_) {
        governance = governance_;
    }

    // constant and in spell action
    uint256 public constant MIN_DELAY = 1 days;

    function execute() public override {
        governance.setMinDelay(MIN_DELAY);
    }
}

contract GovernanceTest is DSTest {
    Governance public governance;
    DripsContract public dripsContract;
    Hevm public hevm;

    function setUp() public {
        governance = new Governance(address(this));
        dripsContract = new DripsContract(address(governance.executor()));
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(block.timestamp + 1 days);
    }

    function assertPreCondition() public {
        assertEq(dripsContract.value(), 0, "pre-condition-err");
    }

    function assertPostCondition() public {
        assertEq(dripsContract.value(), 1, "post-condition-err");
    }

    function testSpell() public {
        address spell = address(new ChangeValueSpell(dripsContract));
        governance.schedule(address(spell), block.timestamp);
        assertEq(governance.scheduler(spell), block.timestamp);
        assertPreCondition();
        governance.execute(address(spell));
        assertPostCondition();

        // not possible to execute twice
        try governance.execute(address(spell)) {
            assertTrue(false, "execute-should-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "spell-not-scheduled", "Invalid revert reason");
        }
    }

    function testExecuteWithoutSchedule() public {
        address spell = address(new ChangeValueSpell(dripsContract));
        assertPreCondition();
        try governance.execute(address(spell)) {
            assertTrue(false, "execute-should-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "spell-not-scheduled", "Invalid revert reason");
        }
    }

    function testTimeDelay() public {
        address spell = address(new ChangeValueSpell(dripsContract));
        governance.schedule(address(spell), block.timestamp + 1 days);
        assertPreCondition();
        try governance.execute(address(spell)) {
            assertTrue(false, "execute-should-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "execute-too-early", "Invalid revert reason");
        }

        hevm.warp(block.timestamp + 1 days);
        governance.execute(address(spell));
        assertPostCondition();
    }

    function testUnSchedule() public {
        address spell = address(new ChangeValueSpell(dripsContract));
        governance.schedule(address(spell), block.timestamp + 1 days);
        assertPreCondition();
        governance.unSchedule(address(spell));
        try governance.execute(address(spell)) {
            assertTrue(false, "execute-should-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "spell-not-scheduled", "Invalid revert reason");
        }
    }

    function testMinDelayChange() public {
        // pre condition
        assertEq(governance.minDelay(), 0, "delay-pre-condition");

        address spell = address(new GovernanceDelaySpellAction(governance));
        governance.schedule(address(spell), block.timestamp);
        assertPreCondition();
        governance.execute(address(spell));

        // post condition
        assertEq(governance.minDelay(), 1 days, "delay-pre-condition");
    }

    function testScheduleNotOwner() public {
        governance.transferOwnership(address(0xA));
        address spell = address(new ChangeValueSpell(dripsContract));
        try governance.schedule(address(spell), block.timestamp) {
            assertTrue(false, "schedule-should-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "Ownable: caller is not the owner", "Invalid revert reason");
        }
    }

    function testFailCallExecutorDirectly() public {
        address spell = address(new ChangeValueSpell(dripsContract));
        Executor e = governance.executor();
        e.exec(spell);
    }
}

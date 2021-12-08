// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable no-inline-assembly
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {Governance} from "./governance.sol";
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
contract ChangeValueSpellAction {
    function execute(DripsContract dripsContract) public {
        dripsContract.setValue(1);
    }
}

contract ChangeValueSpell {
    bytes public sig;
    address public action;
    Governance public governance;
    uint256 public earliestExeTime;
    bool public done;
    uint256 public delay;
    bytes32 public actionHash;

    constructor(
        Governance governance_,
        address dripsContract,
        uint256 delay_
    ) {
        sig = abi.encodeWithSignature("execute(address)", dripsContract);
        address action_ = address(new ChangeValueSpellAction());
        governance = governance_;
        delay = delay_;
        bytes32 actionHash_;
        assembly {
            actionHash_ := extcodehash(action_)
        }
        action = action_;
        actionHash = actionHash_;
    }

    function schedule() public {
        require(earliestExeTime == 0, "already-scheduled");
        earliestExeTime = block.timestamp + delay;
        governance.schedule(action, actionHash, sig, earliestExeTime);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        governance.execute(action, actionHash, sig, earliestExeTime);
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
    }

    function assertPreCondition() public {
        assertEq(dripsContract.value(), 0, "pre-condition-err");
    }

    function assertPostCondition() public {
        assertEq(dripsContract.value(), 1, "post-condition-err");
    }

    function testSpell() public {
        ChangeValueSpell spell = new ChangeValueSpell(governance, address(dripsContract), 0);
        governance.approveSpell(address(spell));
        spell.schedule();
        assertPreCondition();
        spell.cast();
        assertPostCondition();
    }

    function testScheduleExecuteDirectly() public {
        bytes memory sig = abi.encodeWithSignature("execute(address)", dripsContract);
        address action = address(new ChangeValueSpellAction());
        bytes32 actionHash;
        assembly {
            actionHash := extcodehash(action)
        }
        governance.schedule(action, actionHash, sig, block.timestamp);
        assertPreCondition();
        governance.execute(action, actionHash, sig, block.timestamp);
        assertPostCondition();
    }

    function testSpellScheduleWithoutApproval() public {
        ChangeValueSpell spell = new ChangeValueSpell(governance, address(dripsContract), 0);
        try spell.schedule() {
            assertTrue(false, "schedule-schould-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "spell-not-approved", "Invalid revert reason");
        }
    }

    function testExecuteWithoutSchedule() public {
        bytes memory sig = abi.encodeWithSignature("execute(address)", dripsContract);
        address action = address(new ChangeValueSpellAction());
        bytes32 actionHash;
        assembly {
            actionHash := extcodehash(action)
        }
        try governance.execute(action, actionHash, sig, block.timestamp) {
            assertTrue(false, "execute-schould-revert");
        } catch Error(string memory reason) {
            assertEq(reason, "unknown-spell", "Invalid revert reason");
        }
    }

    function testTimeDelay() public {
        bytes memory sig = abi.encodeWithSignature("execute(address)", dripsContract);
        address action = address(new ChangeValueSpellAction());
        bytes32 actionHash;
        assembly {
            actionHash := extcodehash(action)
        }
        governance.schedule(action, actionHash, sig, block.timestamp + 1 days);
        assertPreCondition();
        try governance.execute(action, actionHash, sig, block.timestamp) {
            assertTrue(false, "execution-too-early");
        } catch Error(string memory reason) {
            assertEq(reason, "unknown-spell", "Invalid revert reason");
        }
        hevm.warp(block.timestamp + 1 days);
        governance.execute(action, actionHash, sig, block.timestamp);
        assertPostCondition();
    }
}

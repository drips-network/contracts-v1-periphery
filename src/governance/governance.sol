// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable avoid-low-level-calls

pragma solidity ^0.8.7;
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

interface Spell {
    function execute() external;
}

// inspired by MakerDAO DSPaused
contract Governance is Ownable {
    mapping(address => uint256) public scheduler;
    Executor public immutable executor;

    event Scheduled(address spell, uint256 startTime);
    event UnScheduled(address spell, uint256 startTime);
    event Executed(address spell);

    // governance parameter which can be changed by spells
    uint256 public minDelay = 0;

    constructor(address owner_) {
        executor = new Executor();
        _transferOwnership(owner_);
    }

    // changing the min delay requires a spell and enforces the current minDelay for the change
    function setMinDelay(uint256 newDelay) public {
        require(msg.sender == address(executor), "not-a-spell");
        minDelay = newDelay;
    }

    function schedule(address spell, uint256 startTime) public onlyOwner {
        require(startTime >= block.timestamp + minDelay, "exe-time-not-in-the-future");
        scheduler[spell] = startTime;
        emit Scheduled(spell, startTime);
    }

    function unSchedule(address spell) public onlyOwner {
        emit UnScheduled(spell, scheduler[spell]);
        scheduler[spell] = 0;
    }

    // can be called by anyone after delay has passed
    function execute(address spell) public {
        require(scheduler[spell] != 0, "spell-not-scheduled");
        require(block.timestamp >= scheduler[spell], "execute-too-early");
        executor.exec(spell);
        scheduler[spell] = 0;
        emit Executed(spell);
    }
}

// plans are executed in an isolated storage context to protect the Governance from
// malicious storage modification during execution
// inspired by MakerDAO DSPauseProxy
contract Executor {
    address public immutable owner;
    bytes public constant SIG = abi.encodeWithSignature("execute()");

    constructor() {
        owner = msg.sender;
    }

    function exec(address spell) public returns (bytes memory out) {
        require(msg.sender == owner, "notOwner");
        return Address.functionDelegateCall(spell, SIG);
    }
}

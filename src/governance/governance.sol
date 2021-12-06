// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable avoid-low-level-calls
pragma solidity ^0.8.7;
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

// inspired by MakerDAO DSPaused
contract Governance is Ownable {
    mapping(bytes32 => bool) public scheduler;
    mapping(address => bool) public approvedSpells;

    modifier onlyApprovedSpells() {
        require(approvedSpells[msg.sender] == true || msg.sender == owner(), "spell-not-approved");
        _;
    }

    Executor public executor;

    event Scheduled(address spell, bytes sig, uint256 earliestExeTime, bytes32 scheduleHash);
    event Unscheduled(address spell, bytes sig, uint256 earliestExeTime, bytes32 scheduleHash);
    event Executed(address spell, bytes sig, uint256 earliestExeTime, bytes32 scheduleHash);

    event ApproveSpell(address spell);
    event DenySpell(address spell);

    constructor(address owner_) {
        executor = new Executor();
        _transferOwnership(owner_);
    }

    function hash(
        address spell,
        bytes memory sig,
        uint256 earliestExeTime
    ) public pure returns (bytes32 hash_) {
        return keccak256(abi.encode(spell, sig, earliestExeTime));
    }

    function schedule(
        address spell,
        bytes memory sig,
        uint256 earliestExeTime
    ) public onlyApprovedSpells {
        require(earliestExeTime >= block.timestamp, "exe-time-not-in-the-future");
        bytes32 hash_ = hash(spell, sig, earliestExeTime);
        scheduler[hash_] = true;
        emit Scheduled(spell, sig, earliestExeTime, hash_);
    }

    function unSchedule(
        address spell,
        bytes memory sig,
        uint256 earliestExeTime
    ) public onlyApprovedSpells {
        bytes32 hash_ = hash(spell, sig, earliestExeTime);
        scheduler[hash(spell, sig, earliestExeTime)] = false;
        emit Scheduled(spell, sig, earliestExeTime, hash_);
    }

    // can be called by anyone after delay has passed
    function execute(
        address spell,
        bytes memory sig,
        uint256 earliestExeTime
    ) public {
        bytes32 hash_ = hash(spell, sig, earliestExeTime);
        require(scheduler[hash_], "unknown-spell");
        require(block.timestamp >= earliestExeTime, "execution-too-early");

        executor.exec(spell, sig);
        scheduler[hash_] = false;
        emit Executed(spell, sig, earliestExeTime, hash_);
    }

    function approveSpell(address spell) public onlyOwner {
        approvedSpells[spell] = true;
        emit ApproveSpell(spell);
    }

    function denySpell(address spell) public onlyOwner {
        approvedSpells[spell] = false;
        emit DenySpell(spell);
    }
}

// plans are executed in an isolated storage context to protect the Governance from
// malicious storage modification during execution
// inspired by MakerDAO DSPauseProxy
contract Executor is Ownable {
    function exec(address usr, bytes memory fax) public onlyOwner returns (bytes memory out) {
        bool ok;
        address currOwner = owner();
        (ok, out) = usr.delegatecall(fax);
        require(owner() == currOwner, "owner-not-changable");
        require(ok, "delegatecall-error");
    }
}

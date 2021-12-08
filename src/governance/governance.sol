// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
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

    event Scheduled(address spell, bytes sig, uint256 startTime, bytes32 scheduleHash);
    event Unscheduled(address spell, bytes sig, uint256 startTime, bytes32 scheduleHash);
    event Executed(address spell, bytes sig, uint256 startTime, bytes32 scheduleHash);

    event ApproveSpell(address spell);
    event DenySpell(address spell);

    constructor(address owner_) {
        executor = new Executor();
        _transferOwnership(owner_);
    }

    function _getContractHash(address spell) internal view returns (bytes32 h) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            h := extcodehash(spell)
        }
    }

    function hash(
        address spellActionAddr,
        bytes32 spellActionHash,
        bytes memory sig,
        uint256 startTime
    ) public pure returns (bytes32 hash_) {
        return keccak256(abi.encode(spellActionAddr, spellActionHash, sig, startTime));
    }

    function schedule(
        address spellActionAddr,
        bytes32 spellActionHash,
        bytes memory sig,
        uint256 startTime
    ) public onlyApprovedSpells {
        require(startTime >= block.timestamp, "exe-time-not-in-the-future");
        bytes32 hash_ = hash(spellActionAddr, spellActionHash, sig, startTime);
        scheduler[hash_] = true;
        emit Scheduled(spellActionAddr, sig, startTime, hash_);
    }

    function unSchedule(
        address spellActionAddr,
        bytes32 spellActionHash,
        bytes memory sig,
        uint256 startTime
    ) public onlyApprovedSpells {
        bytes32 hash_ = hash(spellActionAddr, spellActionHash, sig, startTime);
        scheduler[hash_] = false;
        emit Scheduled(spellActionAddr, sig, startTime, hash_);
    }

    // can be called by anyone after delay has passed
    function execute(
        address spellActionAddr,
        bytes32 spellActionHash,
        bytes memory sig,
        uint256 startTime
    ) public {
        bytes32 hash_ = hash(spellActionAddr, spellActionHash, sig, startTime);
        require(scheduler[hash_], "unknown-spell");
        require(block.timestamp >= startTime, "execution-too-early");

        executor.exec(spellActionAddr, sig);
        scheduler[hash_] = false;
        emit Executed(spellActionAddr, sig, startTime, hash_);
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
contract Executor {
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "notOwner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function exec(address usr, bytes memory fax) public onlyOwner returns (bytes memory out) {
        bool ok;
        address currOwner = owner;
        (ok, out) = usr.delegatecall(fax);
        require(owner == currOwner, "owner-not-changable");
        require(ok, "delegatecall-error");
    }
}

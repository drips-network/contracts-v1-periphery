// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

contract MetaData {
    event MultiHash(address indexed addr, uint8 hashFunction, uint8 size, bytes32 digest);

    function publish(
        uint8 hashFunction,
        uint8 size,
        bytes32 digest
    ) external {
        emit MultiHash(msg.sender, hashFunction, size, digest);
    }
}

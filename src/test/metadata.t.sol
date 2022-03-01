// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import {MetaData} from "../metadata.sol";

// Libary for base58 encoding https://github.com/saurfang/ipfs-multihash-on-solidity
contract MetaDataTest is DSTest {
    MetaData public metadata;

    function setUp() public {
        metadata = new MetaData();
    }

    function testStoreMultiHash() public {
        // multiHash base58 example "QmYphyME6tvpmLUaz2zG7zNGJNnDpPkecj5Egg3eERDafA";
        // in hex 12209bc4d23950b5a91c9dc71883209424a145574a5e0f9aabd34a5f4ffc7f759409
        // 0-1:  hashFunction
        // 1-2:  size
        // 2-34: hash
        uint8 hashFunction = uint8(0x12);
        uint8 size = uint8(0x20);
        bytes32 digest = bytes32(
            0x9bc4d23950b5a91c9dc71883209424a145574a5e0f9aabd34a5f4ffc7f759409
        );
        bytes memory multiHash = abi.encode(hashFunction, size, digest);
        metadata.publish(multiHash);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

contract MetaData {
    event MultiHash(address indexed addr, bytes multiHash);

    /// @notice publish an IPFS hash as an event
    /// @param multiHash as bytes array
    function publish(bytes calldata multiHash) external {
        // correct multiHash construction see https://github.com/multiformats/multihash
        // 0-1  bytes:  hashFunction
        // 1-2  bytes:  size
        // 2-34 bytes:  hash (in most cases 32 bytes but not guranteed)
        emit MultiHash(msg.sender, multiHash);
    }
}

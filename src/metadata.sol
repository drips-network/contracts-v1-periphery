// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

contract MetaData {
    bytes32 public constant DEFAULT_ID = "identity";

    // correct multiHash construction see https://github.com/multiformats/multihash
    // 0-1  bytes:  hashFunction
    // 1-2  bytes:  size
    // 2-34 bytes:  hash (in most cases 32 bytes but not guranteed)
    event MultiHash(bytes32 indexed id, address indexed addr, bytes multiHash);

    /// @notice publish an IPFS hash as an event
    /// @param multiHash as bytes array
    function publish(bytes calldata multiHash) external {
        emit MultiHash(DEFAULT_ID, msg.sender, multiHash);
    }

    /// @notice publish an IPFS hash as an event with an id
    /// @param multiHash as bytes array
    /// @param id identifier for the multiHash
    function publish(bytes32 id, bytes calldata multiHash) external {
        emit MultiHash(id, msg.sender, multiHash);
    }
}

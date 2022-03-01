// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

contract MetaData {
    event MultiHash(address indexed addr, bytes multiHash);

    /// @notice publish an IPFS hash as an event
    /// @param multiHash as bytes array
    /// more information: https://github.com/multiformats/multihash
    function publish(bytes calldata multiHash) external {
        emit MultiHash(msg.sender, multiHash);
    }
}

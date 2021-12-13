// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

interface IBuilder {
    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerSec,
        bool active
    ) external view returns (string memory);

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerSec,
        bool active,
        string memory ipfsHash
    ) external view returns (string memory);
}

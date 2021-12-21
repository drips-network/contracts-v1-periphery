// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable quotes
pragma solidity ^0.8.7;
import "./baseBuilder.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract DefaultIPFSBuilder is BaseBuilder {
    address public governance;
    string public defaultIpfsHash;

    // --- Auth Owner---
    mapping(address => bool) public owner;

    function rely(address usr) external onlyOwner {
        owner[usr] = true;
    }

    function deny(address usr) external onlyOwner {
        owner[usr] = false;
    }

    modifier onlyOwner() {
        require(owner[msg.sender] == true, "not-authorized");
        _;
    }

    event NewDefaultIPFS(string ipfsHash);

    constructor(address owner_, string memory defaultIpfsHash_) {
        owner[owner_] = true;
        defaultIpfsHash = defaultIpfsHash_;
        emit NewDefaultIPFS(defaultIpfsHash);
    }

    function changeDefaultIPFS(string calldata newDefaultIpfsHash) public onlyOwner {
        defaultIpfsHash = newDefaultIpfsHash;
        emit NewDefaultIPFS(defaultIpfsHash);
    }

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerSec,
        bool active
    ) external view override returns (string memory) {
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory nftTypeStr = Strings.toString(nftType);
        string memory supportRate = _formatSupportRate(amtPerSec);
        return
            _buildJSON(
                projectName,
                tokenIdStr,
                nftTypeStr,
                supportRate,
                active,
                streaming,
                defaultIpfsHash
            );
    }

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerSec,
        bool active,
        string memory ipfsHash
    ) external pure override returns (string memory) {
        string memory supportRate = _formatSupportRate(amtPerSec);
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory nftTypeStr = Strings.toString(nftType);
        return
            _buildJSON(
                projectName,
                tokenIdStr,
                nftTypeStr,
                supportRate,
                active,
                streaming,
                ipfsHash
            );
    }
}

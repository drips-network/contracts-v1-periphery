// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable quotes
pragma solidity ^0.8.7;
import "./baseBuilder.sol";

contract DefaultIPFSBuilder is BaseBuilder {
    address public governance;
    string public defaultIpfsHash;

    constructor(address governance_, string memory defaultIpfsHash_) {
        governance = governance_;
        defaultIpfsHash = defaultIpfsHash_;
    }

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerCycle,
        bool active
    ) external view override returns (string memory) {
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory nftTypeStr = Strings.toString(nftType);
        string memory supportRate = _toTwoDecimals(amtPerCycle);
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
        uint128 amtPerCycle,
        bool active,
        string memory ipfsHash
    ) external pure override returns (string memory) {
        string memory supportRate = _toTwoDecimals(amtPerCycle);
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;
import "./base64.sol";

contract MetaDataBuilder {
    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) public pure returns (string memory) {
        string memory supportRateString = uint2str(amtPerCycle / 1 ether);
        string memory tokenIdString = uint2str(tokenId);
        string memory tokenActiveString = "false";
        if (active) {
            tokenActiveString = "true";
        }
        uint128 decimal2Digits = (amtPerCycle % 1 ether) / 10**16;
        if (decimal2Digits > 0) {
            supportRateString = string(
                abi.encodePacked(supportRateString, ".", uint2str(decimal2Digits))
            );
        }

        string memory svg = string(
            abi.encodePacked(
                '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" fill="white" xmlns="http://www.w3.org/2000/svg">',
                "<style>svg { background-color: black; }</style>",
                '<text x="20" y="20" font-family="Courier New, Courier, Lucida Sans Typewriter" class="small"> \xf0\x9f\x8c\xb1 Radicle Funding \xf0\x9f\x8c\xb1 </text>',
                '<text x="20" y="80" class="medium">Project Name:</text>  <text x="150" y="80" class="small">',
                projectName,
                "</text>",
                '<text x="20" y="100" class="medium">NFT-ID:</text><text x="150" y="100" class="small">',
                tokenIdString,
                "</text>",
                '<text x="20" y="120" class="medium">Support-Rate:</text><text x="150" y="120" class="small">',
                supportRateString,
                " DAI</text>",
                "</svg>"
            )
        );
        return
            string(
                abi.encodePacked(
                    '{"projectName":"',
                    projectName,
                    '", ',
                    '"tokenId":"',
                    tokenIdString,
                    '", ',
                    '"supportRate":"',
                    supportRateString,
                    " DAI",
                    '", ',
                    '"active":"',
                    tokenActiveString,
                    '", ',
                    '"image": "',
                    "data:image/svg+xml;base64,",
                    Base64.encode(bytes(svg)),
                    '"}'
                )
            );
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

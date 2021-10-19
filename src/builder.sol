// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;
import "./base64.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract Builder {
    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active
    ) public pure returns (string memory) {
        string memory supportRateString = toTwoDecimals(amtPerCycle);
        string memory tokenIdString = Strings.toString(tokenId);
        string memory tokenActiveString = "false";
        if (active) {
            tokenActiveString = "true";
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
    function toTwoDecimals(uint128 number) public pure returns(string memory numberString) {
        // decimal after the first two decimals are rounded up or down
        number += 0.005 * 10**18;
        numberString = Strings.toString(number/1 ether);
        uint128 twoDecimals = (number % 1 ether) / 10**16;
        if(twoDecimals > 0) {
            string memory point = ".";
            if (twoDecimals > 0 && twoDecimals < 10) {
                point = ".0";
            }
            numberString = string(
                abi.encodePacked(numberString, point, Strings.toString(twoDecimals))
            );
        }
        return numberString;
    }
}

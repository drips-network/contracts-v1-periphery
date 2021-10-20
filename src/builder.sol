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

        // not optimized for gas-usage because it is only a testing svg
        string memory svg = string(
            abi.encodePacked(
                '<svg class="svgBody" width="350" height="350" viewBox="0 0 350 350" fill="white" xmlns="http://www.w3.org/2000/svg">',
                "<style>svg { background-color: black; }</style>",
                // headline
                '<text x="20" y="35" font-family="Courier New, Courier, Lucida Sans Typewriter" class="small" font-size="25px"> \xf0\x9f\x8c\xb1 Radicle Funding \xf0\x9f\x8c\xb1 </text>',
                '<text x="50" y="80" class="medium" font-size="15px">Project Name:</text>  <text x="175" y="80" class="small" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="15px">',
                projectName,
                "</text>",
                '<text x="50" y="110" class="medium" font-size="15px">NFT-ID:</text><text x="175" y="110" class="small" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="15px">',
                tokenIdString,
                "</text>",
                '<text x="50" y="140" class="medium" font-size="15px">Support-Rate:</text><text x="175" y="140" class="small" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="15px">',
                supportRateString,
                " DAI</text>",
                "</svg>"
            )
        );
        return
            string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(
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
                ))))
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

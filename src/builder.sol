// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "./base64.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract Builder {
    string public defaultBackground;

    struct Data {
        string projectName;
        string tokenId;
        string supportRate;
        string active;
        string background;
    }

    constructor(string memory defaultBackground_) {
        defaultBackground = defaultBackground_;
    }
        
    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active) public view returns (string memory) {
        return buildMetaData(projectName, tokenId, amtPerCycle, active, defaultBackground);
    }

    function buildMetaData(
        string memory projectName,
        uint256 tokenId,
        uint128 amtPerCycle,
        bool active,
        string memory background
    ) public view returns (string memory) {
        string memory tokenActiveString = "false";
        if (active) {
            tokenActiveString = "true";
        }
        return _buildJSON(Data({projectName:projectName, tokenId: Strings.toString(tokenId), supportRate: toTwoDecimals(amtPerCycle), active: tokenActiveString, background:background}));
    }


    function _buildSVG(Data memory data) internal view returns (string memory) {
        // not optimized for gas-usage because it is only a testing svg
        return string(
            abi.encodePacked(
                '<svg class="svgBody" width="350" height="350" viewBox="0 0 350 350" fill="black" xmlns="http://www.w3.org/2000/svg"><style>svg { background-color: #2980B9;}</style>',
                '<image href="', data.background, '" x="0" y="0" height="350px"  width="350px"/><text  dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" y="100px" class="small" font-size="25px">',
                data.projectName,
                '</text><text  y="50%" dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="40px" fill="black">--',
                data.tokenId,
                '--</text><text  y="270" dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="30px" fill="orange" >',
                data.supportRate, ' DAI',
                '</text></svg>'));
    }

    function _buildJSON(Data memory data) internal view returns (string memory) {
        return
        string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(
                abi.encodePacked(
                    '{"projectName":"',
                    data.projectName,
                    '", ',
                    '"tokenId":"',
                    data.tokenId,
                    '", ',
                    '"supportRate":"',
                    data.supportRate,
                    " DAI",
                    '", ',
                    '"active":"',
                    data.active,
                    '", ',
                    '"image": "',
                    "data:image/svg+xml;base64,",
                    Base64.encode(bytes(_buildSVG(data))),
                    '"}'
                ))))
        );
    }

    function toTwoDecimals(uint128 number) public pure returns (string memory numberString) {
        // decimal after the first two decimals are rounded up or down
        number += 0.005 * 10 ** 18;
        numberString = Strings.toString(number / 1 ether);
        uint128 twoDecimals = (number % 1 ether) / 10 ** 16;
        if (twoDecimals > 0) {
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

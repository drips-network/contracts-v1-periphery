// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable quotes
pragma solidity ^0.8.7;

import "./base64.sol";
import "./interface.sol";
import "openzeppelin-contracts/utils/Strings.sol";

abstract contract BaseBuilder is IBuilder {
    function _buildJSON(
        string memory projectName,
        string memory tokenId,
        string memory nftType,
        string memory supportRate,
        bool active,
        bool streaming,
        string memory imageObj
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{ "projectName":"',
                                projectName,
                                '", ',
                                _buildJSONAttributes(
                                    tokenId,
                                    nftType,
                                    supportRate,
                                    active,
                                    streaming
                                ),
                                ', "image": "',
                                imageObj,
                                '" }'
                            )
                        )
                    )
                )
            );
    }

    function _buildJSONAttributes(
        string memory tokenId,
        string memory nftType,
        string memory supportRate,
        bool active,
        bool streaming
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '"attributes": [ { "trait_type": "TokenId", "value": "',
                    tokenId,
                    '"},{ "trait_type": "Type", "value": "',
                    nftType,
                    '"},{ "trait_type": "Active", "value": "',
                    active ? "true" : "false",
                    '"},{ "trait_type": "Streaming Token", "value": "',
                    streaming ? "true" : "false",
                    '"},{ "trait_type": "SupportRate", "value": "',
                    supportRate,
                    ' DAI"}]'
                )
            );
    }

    function _toTwoDecimals(uint128 number) internal pure returns (string memory numberString) {
        // decimal after the first two decimals are rounded up or down
        number += 0.005 * 10**18;
        numberString = Strings.toString(number / 1 ether);
        uint128 twoDecimals = (number % 1 ether) / 10**16;
        if (twoDecimals > 0) {
            numberString = string(
                abi.encodePacked(
                    numberString,
                    ".",
                    twoDecimals < 10 ? "0" : "",
                    Strings.toString(twoDecimals)
                )
            );
        }
        return numberString;
    }
}

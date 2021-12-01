// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import "../svgBuilder.sol";

contract WrapperBuilder is DefaultSVGBuilder {
    function toTwoDecimals(uint128 number) public pure returns (string memory numberString) {
        return _toTwoDecimals(number);
    }
}

contract BuilderTest is DSTest {
    WrapperBuilder public builder;

    function setUp() public {
        builder = new WrapperBuilder();
    }

    function testDigits() public {
        assertEq(builder.toTwoDecimals(12.23 * 10**18), "12.23", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.01 * 10**18), "12.01", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.00 * 10**18), "12", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(0.001 * 10**18), "0", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(0.01 * 10**18), "0.01", "incorrect-number-string");
        // round up
        assertEq(builder.toTwoDecimals(12.019 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.0150 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.019 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.995 * 10**18), "13", "incorrect-number-string");
        // round down
        assertEq(builder.toTwoDecimals(12.014 * 10**18), "12.01", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.0149 * 10**18), "12.01", "incorrect-number-string");
    }

    function testSVGJSON() public view {
        builder.buildMetaData("Test", 1, 2, true, 5 ether, true);
    }

    function testIPFSJSON() public view {
        builder.buildMetaData("Test", 1, 2, true, 5 ether, true, "ipfsHash");
    }
}

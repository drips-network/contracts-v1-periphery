// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "ds-test/test.sol";
import "../builder.sol";

contract BuilderTest is DSTest {
    Builder public builder;

    function setUp() public {
        builder = new Builder();
    }

    function testDigits() public {
        assertEq(builder.toTwoDecimals(12.23 * 10**18), "12.23", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.01 * 10**18), "12.01", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.00 * 10**18), "12", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(0.001 * 10**18), "0", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(0.01 * 10**18),  "0.01", "incorrect-number-string");
        // round up
        assertEq(builder.toTwoDecimals(12.019 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.0150 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.019 * 10**18), "12.02", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.995 * 10**18), "13", "incorrect-number-string");
        // round down
        assertEq(builder.toTwoDecimals(12.014 * 10**18), "12.01", "incorrect-number-string");
        assertEq(builder.toTwoDecimals(12.0149 * 10**18), "12.01", "incorrect-number-string");
    }

    function testSVGJSON() public {
        builder.buildMetaData("Test", 1, 5 ether, true);
    }

    function testIPFSJSON() public {
        builder.buildMetaData("Test", 1, 5 ether, true, "ipfsHash");
    }

}

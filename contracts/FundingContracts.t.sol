pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "./FundingContracts.sol";

contract FundingContractsTest is DSTest {
    FundingContracts contracts;

    function setUp() public {
        contracts = new FundingContracts();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}

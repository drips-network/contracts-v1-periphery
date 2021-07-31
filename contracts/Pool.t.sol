pragma solidity ^0.7.5;

import "ds-test/test.sol";
import "./Pool.sol";

contract PoolTest is DSTest {
    DaiPool pool;
    Dai dai;
    uint64 constant cycleSecs = 5;

    function setUp() public {
        dai = new Dai();
        pool = new DaiPool(cycleSecs, dai);
    }

    function testBasic() public {
        assertTrue(true);
    }

}

pragma solidity ^0.7.5;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./Pool.sol";

interface Hevm {
    function warp(uint256) external;
}

contract User {
    DaiPool public pool;
    Dai public dai;
    constructor(DaiPool pool_, Dai dai_) public {
        pool = pool_;
        dai = dai_;
    }

    function withdraw(uint withdrawAmount) public {
        pool.updateSender(0, uint128(withdrawAmount), 0,  new ReceiverWeight[](0), new ReceiverWeight[](0));
    }

    function collect() public {
        pool.collect();
    }

    function send(address to, uint daiPerSecond, uint lockAmount) public {
        ReceiverWeight[] memory receivers = new ReceiverWeight[](1);
        receivers[0] = ReceiverWeight({receiver:to, weight:pool.SENDER_WEIGHTS_SUM_MAX()});

        dai.approve(address(pool), uint(-1));
        pool.updateSender(uint128(lockAmount), 0, uint128(daiPerSecond), receivers, new ReceiverWeight[](0));
    }
}

contract PoolTest is DSTest {
    Hevm public hevm;

    DaiPool pool;
    Dai dai;
    uint64 constant cycleSecs = 5;

    // test user
    User public alice;
    address public alice_;

    User public bob;
    address public bob_;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        emit log_named_uint("block.timestamp start", block.timestamp);

        dai = new Dai();
        pool = new DaiPool(cycleSecs, dai);

        alice = new User(pool, dai);
        alice_ = address(alice);

        bob = new User(pool, dai);
        bob_ = address(bob);
    }

    function testBasic() public {
        dai.transfer(bob_, 100 ether);
        uint daiPerSecond = 1 ether;
        uint lockAmount = 50 ether;
        bob.send(alice_, daiPerSecond, lockAmount);

        uint t = 15 seconds;
        hevm.warp(block.timestamp + t);

        uint receivedAmount = daiPerSecond * t;

        assertEq(dai.balanceOf(alice_), 0);
        alice.collect();
        assertEq(dai.balanceOf(alice_), receivedAmount, "incorrect received amount");
        emit log_named_uint("block.timestamp end", block.timestamp);
    }
}

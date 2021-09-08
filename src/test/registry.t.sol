pragma solidity ^0.8.4;

import "ds-test/test.sol";
import {RadicleRegistry} from "./../registry.sol";
import {FundingPool} from "./../pool.sol";
import {FundingNFT} from "./../nft.sol";
import {Dai} from "../../lib/radicle-streaming/src/test/TestDai.sol";
import "../../lib/radicle-streaming/src/test/BaseTest.t.sol";

contract RegistryTest is BaseTest {
    RadicleRegistry radicleRegistry;
    FundingPool fundingPool;
    Dai public dai;
    Hevm public hevm;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        dai = new Dai();
        fundingPool = new FundingPool(CYCLE_SECS, dai);
        radicleRegistry = new RadicleRegistry(address(fundingPool));
    }

    function testNewNFTRegistry() public {
        uint128 minAmtPerSec = uint128(fundingInSeconds(10 ether));
        string memory name = "First Funding Project";
        string memory symbol = "FFP";

        address nftRegistry_ = radicleRegistry.newProject(name, symbol, address(0xA), minAmtPerSec);
        FundingNFT nftRegistry = FundingNFT(nftRegistry_);
        assertEq(nftRegistry.owner(), address(0xA));
        assertEq(radicleRegistry.projects(1), nftRegistry_);
    }
}

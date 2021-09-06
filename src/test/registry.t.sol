//pragma solidity ^0.8.4;
//
//import "ds-test/test.sol";
//import {FundingRegistry} from "./../registry.sol";
//import {FundingPool} from "./../pool.sol";
//
//contract RegistryTest is DSTest {
//    FundingRegistry fundingRegistry;
//    FundingPool fundingPool;
//
//    function setUp() public {
//        fundingPool = new FundingPool();
//        fundingRegistry = new FundingRegistry();
//    }
//
//    function testCreateNFTRegistry() public {
//        fundingRegistry = new FundingRegistry();
//        string memory name = "First Funding Project";
//        string memory symbol = "FFP";
//
//        address nftRegistry = fundingRegistry.newProject(name, symbol, address(0xA));
//
////        assertEq(address(0xA), nftRegistry.owner());
//    }
//}

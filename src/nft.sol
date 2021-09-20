pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ReceiverWeight} from "../lib/radicle-streaming/src/Pool.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";

import {FundingPool} from "./pool.sol";

contract FundingNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    FundingPool public pool;
    IERC20 public dai;

    // minimum streaming amount per second to receive a fundingNFT
    uint128 minAmtPerSec;

    constructor(FundingPool pool_, string memory name_, string memory symbol_, address owner_, uint128 minAmtPerSec_) ERC721(name_, symbol_) {
        pool = pool_;
        dai = pool.erc20();
        transferOwnership(owner_);
        minAmtPerSec = minAmtPerSec_;
    }

    function mint(address nftReceiver, uint128 topUp, uint128 amtPerSec) external returns (uint256) {
        require(amtPerSec >= minAmtPerSec, "amt-per-sec-too-low");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        // todo currLeftSecs*amtPerSec should be immediately transferred to receiver instead of streaming
        require(topUp >= amtPerSec * cycleSecs, "toUp-too-low");

        //  mint token
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(address(this), newTokenId);

        // transfer currency to NFT registry
        dai.transferFrom(nftReceiver, address(this), topUp);
        dai.approve(address(pool), topUp);

        // start streaming
        ReceiverWeight[] memory receivers = new ReceiverWeight[](1);
        receivers[0] = ReceiverWeight({receiver: owner(), weight:1});
        pool.updateSender(address(this), uint128(newTokenId), topUp, 0, amtPerSec, receivers);

        // transfer nft from contract to receiver
        _transfer(address(this), nftReceiver, newTokenId);

        return newTokenId;
    }

    // todo needs to be implemented
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)  {
        // test metadata json
        return "QmaoWScnNv3PvguuK8mr7HnPaHoAD2vhBLrwiPuqH3Y9zm";
    }

    // todo needs to be implemented
    function contractURI() public view returns (string memory) {
        // test project data json
        return "QmdFspZJyihiG4jESmXC72VfkqKKHCnNSZhPsamyWujXxt";
    }
}

pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";

struct Weights {
    address receiver;
    uint32 weight;
}

interface IFundingPool {
    function updateSender(
        address nftRegistry,
        uint128 tokenId,
        uint128 topUpAmt,
        uint128 withdraw,
        uint128 amtPerSec,
        Weights[] calldata updatedReceivers,
        Weights[] calldata updatedProxies
    ) external;

    function erc20() external returns(address);
    function SENDER_WEIGHTS_SUM_MAX() external returns(uint32);
    function cycleSecs() external returns(uint64);
}

interface IERC20 {
    function approve(address usr,uint amount) external;
    function transferFrom(address from, address to, uint amount) external;
}

contract FundingNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    IFundingPool public pool;
    IERC20 public dai;

    // minimum streaming amount per second to receive a fundingNFT
    uint128 minAmtPerSec;

    constructor(address pool_, string memory name_, string memory symbol_, address owner_, uint128 minAmtPerSec_) ERC721(name_, symbol_) {
        pool = IFundingPool(pool_);
        dai = IERC20(pool.erc20());
        transferOwnership(owner_);
        minAmtPerSec = minAmtPerSec_;
    }

    function mint(address nftReceiver, uint128 topUp, uint128 amtPerSec) external returns (uint256) {
        require(amtPerSec >= minAmtPerSec, "amt-per-sec-too-low");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        // uint128 currLeftSecs = cycleSecs - (uint128(block.timestamp) % cycleSecs);
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
        Weights[] memory receivers = new Weights[](1);
        receivers[0] = Weights({receiver: owner(), weight:pool.SENDER_WEIGHTS_SUM_MAX()});
        pool.updateSender(address(this), uint128(newTokenId), topUp, 0, amtPerSec, receivers, new Weights[](0));

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

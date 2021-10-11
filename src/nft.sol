// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ReceiverWeight} from "../lib/radicle-streaming/src/Pool.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {DaiPool, IDai} from "../lib/radicle-streaming/src/DaiPool.sol";

struct InputNFTType {
    uint128 nftTypeId;
    uint64 limit;
    uint128 minAmtPerSec;
}

contract FundingNFT is ERC721, Ownable {
    /// @notice The amount passed as the withdraw amount to withdraw all the withdrawable funds
    uint128 public constant WITHDRAW_ALL = type(uint128).max;

    DaiPool public pool;
    IDai public dai;

    struct NFTType {
        uint64 limit;
        uint64 minted;
        uint128 minAmtPerSec;
    }

    mapping (uint128 => NFTType) public nftTypes;

    mapping (uint => uint64) public minted;

    string public contractURI;

    // events
    event NewNFTType(uint128 indexed nftType, uint64 limit, uint128 minAmtPerSec);
    event NewNFT(uint indexed tokenId, address indexed receiver, uint128 indexed typeId, uint128 topUp, uint128 amtPerSec);
    event NewContractURI(string contractURI);

    constructor(DaiPool pool_, string memory name_, string memory symbol_, address owner_, string memory ipfsHash) ERC721(name_, symbol_) {
        pool = pool_;
        dai = IDai(address(pool.erc20()));
        transferOwnership(owner_);
        contractURI = ipfsHash;
        emit NewContractURI(ipfsHash);
    }

    modifier onlyTokenHolder(uint tokenId) {
        require(ownerOf(tokenId) == msg.sender, "not-nft-owner");
        _;
    }

    function changeIPFSHash(string memory ipfsHash) public onlyOwner {
        contractURI = ipfsHash;
        emit NewContractURI(ipfsHash);
    }

    function addTypes(InputNFTType[] memory inputNFTTypes) external onlyOwner {
        for(uint i = 0; i < inputNFTTypes.length; i++) {
            addType(inputNFTTypes[i].nftTypeId, inputNFTTypes[i].limit, inputNFTTypes[i].minAmtPerSec);
        }
    }

    function addType(uint128 newTypeId, uint64 limit, uint128 minAmtPerSec) public onlyOwner {
        require(nftTypes[newTypeId].limit == 0, "nft-type-already-exists");
        require(limit > 0, "zero-limit-not-allowed");

        nftTypes[newTypeId].minAmtPerSec = minAmtPerSec;
        nftTypes[newTypeId].limit = limit;
        emit NewNFTType(newTypeId, limit, minAmtPerSec);
    }

    function createTokenId(uint128 id, uint128 nftType) public pure returns(uint tokenId) {
        return uint((uint(nftType) << 128)) | id;
    }

    function tokenType(uint tokenId) public pure returns(uint128 nftType) {
        return uint128(tokenId >> 128);
    }

    function mint(address nftReceiver, uint128 typeId, uint128 topUpAmt, uint128 amtPerSec,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    external returns (uint256) {
        dai.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
        mint(nftReceiver, typeId, topUpAmt, amtPerSec);
    }

    function mint(address nftReceiver, uint128 typeId, uint128 topUpAmt, uint128 amtPerSec) public returns (uint256) {
        require(amtPerSec >= nftTypes[typeId].minAmtPerSec, "amt-per-sec-too-low");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        require(topUpAmt >= amtPerSec * cycleSecs, "toUp-too-low");
        require(nftTypes[typeId].minted++ < nftTypes[typeId].limit, "nft-type-reached-limit");

        uint256 newTokenId = createTokenId(nftTypes[typeId].minted, typeId);

        _mint(nftReceiver, newTokenId);
        minted[newTokenId] = uint64(block.timestamp);

        // transfer currency to NFT registry
        dai.transferFrom(nftReceiver, address(this), topUpAmt);
        dai.approve(address(pool), topUpAmt);

        // start streaming
        ReceiverWeight[] memory receivers = new ReceiverWeight[](1);
        receivers[0] = ReceiverWeight({receiver: address(this), weight:1});
        pool.updateSubSender(newTokenId, topUpAmt, 0, amtPerSec, receivers);

        emit NewNFT(newTokenId, nftReceiver, typeId, topUpAmt, amtPerSec);

        return newTokenId;
    }

    function collect() public onlyOwner {
        pool.collect(address(this));
        dai.transfer(owner(), dai.balanceOf(address(this)));
    }

    function topUp(uint tokenId, uint128 topUpAmt,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    public returns (uint256) {
        dai.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
        topUp(tokenId, topUpAmt);
    }

    function topUp(uint tokenId, uint128 topUpAmt) public onlyTokenHolder(tokenId) {
        dai.transferFrom(msg.sender, address(this), topUpAmt);
        dai.approve(address(pool), topUpAmt);
        pool.updateSubSender(tokenId, topUpAmt, 0, pool.AMT_PER_SEC_UNCHANGED(), new ReceiverWeight[](0));

    }

    function withdraw(uint tokenId, uint128 withdrawAmt) public onlyTokenHolder(tokenId) returns(uint128 withdrawn) {
        uint128 withdrawableAmt = withdrawable(tokenId);
        if (withdrawAmt == WITHDRAW_ALL) {
            withdrawAmt = withdrawableAmt;
        } else {
            require(withdrawAmt <= withdrawableAmt, "withdraw-amount-too-high");
        }
        withdrawn = pool.updateSubSender(tokenId, 0, withdrawAmt, pool.AMT_PER_SEC_UNCHANGED(), new ReceiverWeight[](0));
        dai.transfer(msg.sender, withdrawn);
    }

    function withdrawable(uint tokenId) public view returns(uint128) {
        uint128 withdrawable_ = pool.withdrawableSubSender(address(this), tokenId);

        uint128 amtLocked = 0;
        uint64 fullCycleTimestamp = minted[tokenId] + uint64(pool.cycleSecs());
        if(block.timestamp < fullCycleTimestamp) {
            amtLocked = uint128(fullCycleTimestamp - block.timestamp) * pool.getAmtPerSecSubSender(address(this), tokenId);
        }

        //  mint requires topUp to be at least amtPerSec * pool.cycleSecs therefore
        // if amtLocked > 0 => withdrawable_ > amtLocked
        return withdrawable_ - amtLocked;

    }

    function amtPerSecond(uint tokenId) public view returns(uint128) {
        return pool.getAmtPerSecSubSender(address(this), tokenId);
    }

    function activeUntil(uint tokenId) public view returns(uint128) {
        if(!_exists(tokenId)) {
            return 0;
        }

        if (nftTypes[tokenType(tokenId)].minAmtPerSec == 0) {
            return type(uint128).max;
        }
        uint128 amtWithdrawable = pool.withdrawableSubSender(address(this), tokenId);
        uint128 amtPerSec = pool.getAmtPerSecSubSender(address(this), tokenId);
        if (amtWithdrawable < amtPerSec) {
            return 0;
        }

        return uint128(block.timestamp + amtWithdrawable/amtPerSec - 1);
    }

    function active(uint tokenId) public view returns(bool) {
        return activeUntil(tokenId) >= block.timestamp;
    }

    // todo needs to be implemented
    function tokenURI(uint256) public view virtual override returns (string memory)  {
        // test metadata json
        return "QmaoWScnNv3PvguuK8mr7HnPaHoAD2vhBLrwiPuqH3Y9zm";
    }

    function currLeftSecsInCycle() public view returns(uint64) {
        uint64 cycleSecs = pool.cycleSecs();
        return cycleSecs - (uint64(block.timestamp) % cycleSecs);
    }

    function influence(uint tokenId) public view returns(uint influenceScore) {
        if(active(tokenId)) {
            return pool.getAmtPerSecSubSender(address(this), tokenId);
        }
        return 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {DripsReceiver, Receiver} from "../lib/radicle-streaming/src/Pool.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {IBuilder} from "./builder.sol";
import {DaiPool, IDai} from "../lib/radicle-streaming/src/DaiPool.sol";

struct InputNFTType {
    uint128 nftTypeId;
    uint64 limit;
    // minimum amtPerSecond or minGiveAmt
    uint128 minAmt;
    bool streaming;
    string ipfsHash;
}

contract FundingNFT is ERC721, Ownable {
    address public immutable deployer;
    DaiPool public immutable pool;
    IDai public immutable dai;
    IBuilder public builder;

    string internal _name;
    string internal _symbol;
    string public contractURI;
    bool public initialized;

    struct NFTType {
        uint64 limit;
        uint64 minted;
        uint128 minAmt;
        bool streaming;
        string ipfsHash;
    }

    struct NFT {
        uint64 timeMinted;
        // amtPerSec if the NFT is streaming otherwise the amt given at mint
        uint128 amt;
    }

    mapping(uint128 => NFTType) public nftTypes;
    mapping(uint256 => NFT) public nfts;

    // events
    event NewNFTType(uint128 indexed nftType, uint64 limit, uint128 minAmt, bool streaming);
    event NewStreamingNFT(
        uint256 indexed tokenId,
        address indexed receiver,
        uint128 indexed typeId,
        uint128 topUp,
        uint128 amtPerSec
    );
    event NewNFT(
        uint256 indexed tokenId,
        address indexed receiver,
        uint128 indexed typeId,
        uint128 giveAmt
    );

    event NewContractURI(string contractURI);
    event NewBuilder(IBuilder builder);
    event DripsUpdated(DripsReceiver[] drips);

    constructor(DaiPool pool_) ERC721("", "") {
        deployer = msg.sender;
        pool = pool_;
        dai = pool_.dai();
    }

    modifier onlyTokenHolder(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "not-nft-owner");
        _;
    }

    function init(
        string calldata name_,
        string calldata symbol_,
        address owner,
        string calldata contractURI_,
        InputNFTType[] memory inputNFTTypes,
        IBuilder builder_,
        DripsReceiver[] memory drips
    ) public {
        require(!initialized, "already-initialized");
        initialized = true;
        require(msg.sender == deployer, "not-deployer");
        require(owner != address(0), "owner-address-is-zero");
        _name = name_;
        _symbol = symbol_;
        _changeBuilder(builder_);
        _addTypes(inputNFTTypes);
        _changeContractURI(contractURI_);
        _transferOwnership(owner);
        if (drips.length > 0) {
            _changeDripReceiver(new DripsReceiver[](0), drips);
        }
        dai.approve(address(pool), type(uint256).max);
    }

    function changeContractURI(string calldata contractURI_) public onlyOwner {
        _changeContractURI(contractURI_);
    }

    function _changeContractURI(string calldata contractURI_) internal {
        contractURI = contractURI_;
        emit NewContractURI(contractURI_);
    }

    function _changeBuilder(IBuilder newBuilder) internal {
        builder = newBuilder;
        emit NewBuilder(newBuilder);
    }

    function addTypes(InputNFTType[] memory inputNFTTypes) public onlyOwner {
        _addTypes(inputNFTTypes);
    }

    function _addTypes(InputNFTType[] memory inputNFTTypes) internal {
        for (uint256 i = 0; i < inputNFTTypes.length; i++) {
            _addType(
                inputNFTTypes[i].nftTypeId,
                inputNFTTypes[i].limit,
                inputNFTTypes[i].minAmt,
                inputNFTTypes[i].ipfsHash,
                inputNFTTypes[i].streaming
            );
        }
    }

    function addStreamingType(
        uint128 newTypeId,
        uint64 limit,
        uint128 minAmtPerSec,
        string memory ipfsHash
    ) public onlyOwner {
        _addType(newTypeId, limit, minAmtPerSec, ipfsHash, true);
    }

    function addType(
        uint128 newTypeId,
        uint64 limit,
        uint128 minGiveAmt,
        string memory ipfsHash
    ) public onlyOwner {
        _addType(newTypeId, limit, minGiveAmt, ipfsHash, false);
    }

    function _addType(
        uint128 newTypeId,
        uint64 limit,
        uint128 minAmt,
        string memory ipfsHash,
        bool streaming
    ) internal {
        require(nftTypes[newTypeId].limit == 0, "nft-type-already-exists");
        require(limit > 0, "zero-limit-not-allowed");

        nftTypes[newTypeId].minAmt = minAmt;
        nftTypes[newTypeId].limit = limit;
        nftTypes[newTypeId].ipfsHash = ipfsHash;
        nftTypes[newTypeId].streaming = streaming;
        emit NewNFTType(newTypeId, limit, minAmt, streaming);
    }

    function createTokenId(uint128 id, uint128 nftType) public pure returns (uint256 tokenId) {
        return uint256((uint256(nftType) << 128)) | id;
    }

    function tokenType(uint256 tokenId) public pure returns (uint128 nftType) {
        return uint128(tokenId >> 128);
    }

    function mintStreaming(
        address nftReceiver,
        uint128 typeId,
        uint128 topUpAmt,
        uint128 amtPerSec,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        dai.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
        return mintStreaming(nftReceiver, typeId, topUpAmt, amtPerSec);
    }

    function mint(
        address nftReceiver,
        uint128 typeId,
        uint128 amtGive,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        dai.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
        return mint(nftReceiver, typeId, amtGive);
    }

    function mint(
        address nftReceiver,
        uint128 typeId,
        uint128 giveAmt
    ) public returns (uint256 newTokenId) {
        require(giveAmt > nftTypes[typeId].minAmt, "giveAmt-too-low");
        require(nftTypes[typeId].streaming == false, "type-is-streaming");
        newTokenId = _mintInternal(nftReceiver, typeId, giveAmt);
        // one time give instead of streaming
        pool.giveFromSubSender(newTokenId, address(this), giveAmt);
        nfts[newTokenId].amt = giveAmt;
        emit NewNFT(newTokenId, nftReceiver, typeId, giveAmt);
    }

    function _mintInternal(
        address nftReceiver,
        uint128 typeId,
        uint128 topUpAmt
    ) internal returns (uint256 newTokenId) {
        require(nftTypes[typeId].minted++ < nftTypes[typeId].limit, "nft-type-reached-limit");
        newTokenId = createTokenId(nftTypes[typeId].minted, typeId);
        _mint(nftReceiver, newTokenId);
        nfts[newTokenId].timeMinted = uint64(block.timestamp);
        // transfer currency to NFT registry
        dai.transferFrom(nftReceiver, address(this), topUpAmt);
    }

    function mintStreaming(
        address nftReceiver,
        uint128 typeId,
        uint128 topUpAmt,
        uint128 amtPerSec
    ) public returns (uint256 newTokenId) {
        require(amtPerSec >= nftTypes[typeId].minAmt, "amt-per-sec-too-low");
        require(nftTypes[typeId].streaming, "nft-type-not-streaming");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        require(topUpAmt >= amtPerSec * cycleSecs, "toUp-too-low");

        newTokenId = _mintInternal(nftReceiver, typeId, topUpAmt);
        // start streaming
        pool.updateSubSender(newTokenId, topUpAmt, 0, _receivers(0), _receivers(amtPerSec));
        nfts[newTokenId].amt = amtPerSec;
        emit NewStreamingNFT(newTokenId, nftReceiver, typeId, topUpAmt, amtPerSec);
    }

    function collect(DripsReceiver[] calldata currDrips)
        public
        onlyOwner
        returns (uint128 collected, uint128 dripped)
    {
        (, dripped) = pool.collect(address(this), currDrips);
        collected = uint128(dai.balanceOf(address(this)));
        dai.transfer(owner(), collected);
    }

    function collectable(DripsReceiver[] calldata currDrips)
        public
        view
        returns (uint128 toCollect, uint128 toDrip)
    {
        (toCollect, toDrip) = pool.collectable(address(this), currDrips);
        toCollect += uint128(dai.balanceOf(address(this)));
    }

    function topUp(
        uint256 tokenId,
        uint128 topUpAmt,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        dai.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
        topUp(tokenId, topUpAmt);
    }

    function topUp(uint256 tokenId, uint128 topUpAmt) public onlyTokenHolder(tokenId) {
        require(nftTypes[tokenType(tokenId)].streaming, "not-a-streaming-nft");
        dai.transferFrom(msg.sender, address(this), topUpAmt);
        Receiver[] memory receivers = _tokenReceivers(tokenId);
        pool.updateSubSender(tokenId, topUpAmt, 0, receivers, receivers);
    }

    function withdraw(uint256 tokenId, uint128 withdrawAmt)
        public
        onlyTokenHolder(tokenId)
        returns (uint128 withdrawn)
    {
        uint128 withdrawableAmt = withdrawable(tokenId);
        if (withdrawAmt > withdrawableAmt) {
            withdrawAmt = withdrawableAmt;
        }
        Receiver[] memory receivers = _tokenReceivers(tokenId);
        withdrawn = pool.updateSubSender(tokenId, 0, withdrawAmt, receivers, receivers);
        dai.transfer(msg.sender, withdrawn);
    }

    function changeDripReceiver(DripsReceiver[] memory currDrips, DripsReceiver[] memory newDrips)
        public
        onlyOwner
    {
        _changeDripReceiver(currDrips, newDrips);
    }

    function _changeDripReceiver(DripsReceiver[] memory currDrips, DripsReceiver[] memory newDrips)
        internal
    {
        pool.setDripsReceivers(currDrips, newDrips);
        emit DripsUpdated(newDrips);
    }

    function withdrawable(uint256 tokenId) public view returns (uint128) {
        if (nftTypes[tokenType(tokenId)].streaming == false) {
            return 0;
        }
        uint128 amtPerSec = nfts[tokenId].amt;
        uint128 withdrawable_ = pool.withdrawableSubSender(
            address(this),
            tokenId,
            _receivers(amtPerSec)
        );

        uint128 amtLocked = 0;
        uint64 fullCycleTimestamp = nfts[tokenId].timeMinted + uint64(pool.cycleSecs());
        if (block.timestamp < fullCycleTimestamp) {
            amtLocked = uint128(fullCycleTimestamp - block.timestamp) * amtPerSec;
        }

        //  mint requires topUp to be at least amtPerSec * pool.cycleSecs therefore
        // if amtLocked > 0 => withdrawable_ > amtLocked
        return withdrawable_ - amtLocked;
    }

    function activeUntil(uint256 tokenId) public view returns (uint128) {
        if (!_exists(tokenId)) {
            return 0;
        }
        uint128 amtPerSec = nfts[tokenId].amt;
        if (nftTypes[tokenType(tokenId)].streaming == false || amtPerSec == 0) {
            return type(uint128).max;
        }

        uint128 amtWithdrawable = pool.withdrawableSubSender(
            address(this),
            tokenId,
            _receivers(amtPerSec)
        );
        return uint128(block.timestamp + amtWithdrawable / amtPerSec - 1);
    }

    function active(uint256 tokenId) public view returns (bool) {
        return activeUntil(tokenId) >= block.timestamp;
    }

    function streaming(uint256 tokenId) public view returns (bool) {
        return nftTypes[tokenType(tokenId)].streaming;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function changeBuilder(IBuilder newBuilder) public onlyOwner {
        _changeBuilder(newBuilder);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "nonexistent-token");
        string memory ipfsHash = nftTypes[tokenType(tokenId)].ipfsHash;
        if (bytes(ipfsHash).length == 0) {
            return
                builder.buildMetaData(
                    name(),
                    uint128(tokenId),
                    tokenType(tokenId),
                    nftTypes[tokenType(tokenId)].streaming,
                    nfts[tokenId].amt * pool.cycleSecs(),
                    active(tokenId)
                );
        }
        return
            builder.buildMetaData(
                name(),
                uint128(tokenId),
                tokenType(tokenId),
                nftTypes[tokenType(tokenId)].streaming,
                nfts[tokenId].amt * pool.cycleSecs(),
                active(tokenId),
                ipfsHash
            );
    }

    function currLeftSecsInCycle() public view returns (uint64) {
        uint64 cycleSecs = pool.cycleSecs();
        return cycleSecs - (uint64(block.timestamp) % cycleSecs);
    }

    function influence(uint256 tokenId) public view returns (uint256 influenceScore) {
        if (active(tokenId)) {
            if (streaming(tokenId) == false) {
                return nfts[tokenId].amt;
            }
            return nfts[tokenId].amt * (block.timestamp - nfts[tokenId].timeMinted);
        }
        return 0;
    }

    function _tokenReceivers(uint256 tokenId) internal view returns (Receiver[] memory receivers) {
        return _receivers(nfts[tokenId].amt);
    }

    function _receivers(uint128 amtPerSec) internal view returns (Receiver[] memory receivers) {
        if (amtPerSec == 0) return new Receiver[](0);
        receivers = new Receiver[](1);
        receivers[0] = Receiver(address(this), amtPerSec);
    }
}

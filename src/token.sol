// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import {DaiDripsHub, DripsReceiver, IDai, SplitsReceiver} from "drips-hub/DaiDripsHub.sol";
import {IBuilder} from "./builder/interface.sol";

struct InputType {
    uint128 nftTypeId;
    uint64 limit;
    // minimum amtPerSecond or minGiveAmt
    uint128 minAmt;
    bool streaming;
    string ipfsHash;
}

contract DripsToken is ERC721, Ownable {
    address public immutable deployer;
    DaiDripsHub public immutable hub;
    IDai public immutable dai;
    uint64 public immutable cycleSecs;
    IBuilder public builder;

    string internal _name;
    string internal _symbol;
    string public contractURI;
    bool public initialized;

    struct Type {
        uint64 limit;
        uint64 minted;
        uint128 minAmt;
        bool streaming;
        string ipfsHash;
    }

    struct Token {
        uint64 timeMinted;
        // amtPerSec if the Token is streaming otherwise the amt given at mint
        uint128 amt;
        uint128 lastBalance;
        uint64 lastUpdate;
    }

    mapping(uint128 => Type) public nftTypes;
    mapping(uint256 => Token) public nfts;

    // events
    event NewType(uint128 indexed nftType, uint64 limit, uint128 minAmt, bool streaming);
    event NewStreamingToken(
        uint256 indexed tokenId,
        address indexed receiver,
        uint128 indexed typeId,
        uint128 topUp,
        uint128 amtPerSec
    );
    event NewToken(
        uint256 indexed tokenId,
        address indexed receiver,
        uint128 indexed typeId,
        uint128 giveAmt
    );

    event NewContractURI(string contractURI);
    event NewBuilder(IBuilder builder);
    event SplitsUpdated(SplitsReceiver[] splits);

    constructor(DaiDripsHub hub_) ERC721("", "") {
        deployer = msg.sender;
        hub = hub_;
        dai = hub_.dai();
        cycleSecs = hub_.cycleSecs();
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
        InputType[] memory inputTypes,
        IBuilder builder_,
        SplitsReceiver[] memory splits
    ) public {
        require(!initialized, "already-initialized");
        initialized = true;
        require(msg.sender == deployer, "not-deployer");
        require(owner != address(0), "owner-address-is-zero");
        _name = name_;
        _symbol = symbol_;
        _changeBuilder(builder_);
        _addTypes(inputTypes);
        _changeContractURI(contractURI_);
        _transferOwnership(owner);
        if (splits.length > 0) {
            _changeSplitsReceivers(new SplitsReceiver[](0), splits);
        }
        dai.approve(address(hub), type(uint256).max);
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

    function addTypes(InputType[] memory inputTypes) public onlyOwner {
        _addTypes(inputTypes);
    }

    function _addTypes(InputType[] memory inputTypes) internal {
        for (uint256 i = 0; i < inputTypes.length; i++) {
            _addType(
                inputTypes[i].nftTypeId,
                inputTypes[i].limit,
                inputTypes[i].minAmt,
                inputTypes[i].ipfsHash,
                inputTypes[i].streaming
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
        bool streaming_
    ) internal {
        require(nftTypes[newTypeId].limit == 0, "nft-type-already-exists");
        require(limit > 0, "zero-limit-not-allowed");

        nftTypes[newTypeId].minAmt = minAmt;
        nftTypes[newTypeId].limit = limit;
        nftTypes[newTypeId].ipfsHash = ipfsHash;
        nftTypes[newTypeId].streaming = streaming_;
        emit NewType(newTypeId, limit, minAmt, streaming_);
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
        require(giveAmt >= nftTypes[typeId].minAmt, "giveAmt-too-low");
        require(nftTypes[typeId].streaming == false, "type-is-streaming");
        newTokenId = _mintInternal(nftReceiver, typeId, giveAmt);
        // one time give instead of streaming
        hub.give(newTokenId, address(this), giveAmt);
        nfts[newTokenId].amt = giveAmt;
        emit NewToken(newTokenId, nftReceiver, typeId, giveAmt);
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
        // transfer currency to Token registry
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
        require(topUpAmt >= amtPerSec * cycleSecs, "toUp-too-low");

        newTokenId = _mintInternal(nftReceiver, typeId, topUpAmt);
        // start streaming
        hub.setDrips(newTokenId, 0, 0, _receivers(0), int128(topUpAmt), _receivers(amtPerSec));
        nfts[newTokenId].amt = amtPerSec;
        nfts[newTokenId].lastUpdate = uint64(block.timestamp);
        nfts[newTokenId].lastBalance = topUpAmt;
        emit NewStreamingToken(newTokenId, nftReceiver, typeId, topUpAmt, amtPerSec);
    }

    function collect(SplitsReceiver[] calldata currSplits)
        public
        onlyOwner
        returns (uint128 collected, uint128 split)
    {
        (, split) = hub.collect(address(this), currSplits);
        collected = uint128(dai.balanceOf(address(this)));
        dai.transfer(owner(), collected);
    }

    function collectable(SplitsReceiver[] calldata currSplits)
        public
        view
        returns (uint128 toCollect, uint128 toSplit)
    {
        (toCollect, toSplit) = hub.collectable(address(this), currSplits);
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
        DripsReceiver[] memory receivers = _tokenReceivers(tokenId);
        (uint128 newBalance, ) = hub.setDrips(
            tokenId,
            nfts[tokenId].lastUpdate,
            nfts[tokenId].lastBalance,
            receivers,
            int128(topUpAmt),
            receivers
        );
        nfts[tokenId].lastUpdate = uint64(block.timestamp);
        nfts[tokenId].lastBalance = newBalance;
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
        DripsReceiver[] memory receivers = _tokenReceivers(tokenId);
        (uint128 newBalance, int128 realBalanceDelta) = hub.setDrips(
            tokenId,
            nfts[tokenId].lastUpdate,
            nfts[tokenId].lastBalance,
            receivers,
            -int128(withdrawAmt),
            receivers
        );
        nfts[tokenId].lastUpdate = uint64(block.timestamp);
        nfts[tokenId].lastBalance = newBalance;
        withdrawn = uint128(-realBalanceDelta);
        dai.transfer(msg.sender, withdrawn);
    }

    function changeSplitsReceivers(
        SplitsReceiver[] memory currSplits,
        SplitsReceiver[] memory newSplits
    ) public onlyOwner {
        _changeSplitsReceivers(currSplits, newSplits);
    }

    function _changeSplitsReceivers(
        SplitsReceiver[] memory currSplits,
        SplitsReceiver[] memory newSplits
    ) internal {
        hub.setSplits(currSplits, newSplits);
        emit SplitsUpdated(newSplits);
    }

    function withdrawable(uint256 tokenId) public view returns (uint128) {
        require(_exists(tokenId), "nonexistent-token");
        if (nftTypes[tokenType(tokenId)].streaming == false) return 0;
        Token storage nft = nfts[tokenId];
        uint64 spentUntil = uint64(block.timestamp);
        uint64 minSpentUntil = nft.timeMinted + cycleSecs;
        if (spentUntil < minSpentUntil) spentUntil = minSpentUntil;
        uint192 spent = (spentUntil - nft.lastUpdate) * uint192(nft.amt);
        if (nft.lastBalance < spent) return nft.lastBalance % nft.amt;
        return nft.lastBalance - uint128(spent);
    }

    function activeUntil(uint256 tokenId) public view returns (uint128) {
        require(_exists(tokenId), "nonexistent-token");
        Type storage nftType = nftTypes[tokenType(tokenId)];
        if (nftType.streaming == false || nftType.minAmt == 0) {
            return type(uint128).max;
        }
        Token storage nft = nfts[tokenId];
        return nft.lastUpdate + nft.lastBalance / nft.amt - 1;
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
        uint128 amtPerCycle = nfts[tokenId].amt * cycleSecs;
        if (bytes(ipfsHash).length == 0) {
            return
                builder.buildMetaData(
                    name(),
                    uint128(tokenId),
                    tokenType(tokenId),
                    nftTypes[tokenType(tokenId)].streaming,
                    amtPerCycle,
                    active(tokenId)
                );
        }
        return
            builder.buildMetaData(
                name(),
                uint128(tokenId),
                tokenType(tokenId),
                nftTypes[tokenType(tokenId)].streaming,
                amtPerCycle,
                active(tokenId),
                ipfsHash
            );
    }

    function currLeftSecsInCycle() public view returns (uint64) {
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

    function _tokenReceivers(uint256 tokenId)
        internal
        view
        returns (DripsReceiver[] memory receivers)
    {
        return _receivers(nfts[tokenId].amt);
    }

    function _receivers(uint128 amtPerSec)
        internal
        view
        returns (DripsReceiver[] memory receivers)
    {
        if (amtPerSec == 0) return new DripsReceiver[](0);
        receivers = new DripsReceiver[](1);
        receivers[0] = DripsReceiver(address(this), amtPerSec);
    }
}

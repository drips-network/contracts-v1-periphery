pragma solidity ^0.8.4;

import {DaiPool, ReceiverWeight, Dai} from "../lib/radicle-streaming/src/Pool.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

contract FundingPool is DaiPool {
    modifier nftOwner (address nftRegistry, uint tokenId) {
        require(IERC721(nftRegistry).ownerOf(tokenId) == msg.sender, "not-NFT-owner");
        _;
    }
    constructor(uint64 cycleSecs, Dai dai) DaiPool(cycleSecs, dai) {}

    /// @notice generates a unique 20 bytes by hashing the nft registry  and tokenId
    /// @param nftRegistry address of the NFT specific registry
    /// @param tokenId the unique token id for the NFT registry
    function nftID(address nftRegistry, uint128 tokenId) public pure returns (address id) {
        // gas optimized without local variables
        return address(uint160(uint256(
                keccak256(abi.encodePacked(nftRegistry, tokenId)
                ))));
    }

    /// @notice collect the funds of an NFT. Requires the msg.sender to own the NFT
    /// @param nftRegistry address of the NFT specific registry
    /// @param tokenId the unique token id for the NFT registry
    function collect(address nftRegistry, uint128 tokenId) public nftOwner(nftRegistry, tokenId) {
        uint128 collected = _collectInternal(nftID(nftRegistry, tokenId));
        if (collected > 0) {
            // msg.sender === nft owner
            _transferToSender(msg.sender, collected);
        }
        emit Collected(msg.sender, collected);
    }

    function _sendFromNFT(
        address to,
        uint128 topUpAmt,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata updatedReceivers,
        ReceiverWeight[] calldata updatedProxies
    ) internal {
        // msg.sender === nft owner
        _transferToContract(msg.sender, topUpAmt);
        uint128 withdrawn =
        _updateSenderInternal(to, topUpAmt, withdraw, amtPerSec,
            updatedReceivers, updatedProxies);
        _transferToSender(msg.sender, withdrawn);
    }

    function updateSender(
        address nftRegistry,
        uint128 tokenId,
        uint128 topUpAmt,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata updatedReceivers,
        ReceiverWeight[] calldata updatedProxies
    ) public nftOwner(nftRegistry, tokenId) {
        address id = nftID(nftRegistry, tokenId);

        // not possible to change the rate per second
        require(senders[id].amtPerSec == amtPerSec
        || senders[id].amtPerSec == 0, "rate-per-second-not-changeable");

        // calculate max withdraw
        require(withdraw <= maxWithdraw(id), "withdraw-amount-too-high");

        _sendFromNFT(id,
            topUpAmt, withdraw, amtPerSec, updatedReceivers, updatedProxies);
    }

    function maxWithdraw(address to) public view returns (uint128) {
        uint128 amtPerSec = senders[to].amtPerSec;
        if (amtPerSec == 0) {
            return 0;
        }

        uint128 balance = senders[to].startBalance;
        uint128 sentFunds = uint128(block.timestamp - uint128(senders[to].startTime)) * amtPerSec;
        uint128 currLeftSecs = cycleSecs - (uint128(block.timestamp) % cycleSecs);
        uint128 neededCurrCycle = (currLeftSecs * amtPerSec);
        // entire balance used for streaming
        if (sentFunds + neededCurrCycle >= balance) {
            return 0;
        }

        return (balance - sentFunds) - (currLeftSecs * amtPerSec);
    }
}

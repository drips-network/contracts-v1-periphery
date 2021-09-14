pragma solidity ^0.8.4;

import {NFTPool, ReceiverWeight, IDai} from "../lib/radicle-streaming/src/NFTPool.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

contract FundingPool is NFTPool {
    constructor(uint64 cycleSecs, IDai dai) NFTPool(cycleSecs, dai) {}

    function updateSender(
        address nftRegistry,
        uint128 tokenId,
        uint128 topUpAmt,
        uint128 withdraw,
        uint128 amtPerSec,
        ReceiverWeight[] calldata updatedReceivers)
    public override nftOwner(nftRegistry, tokenId) returns(uint128 withdrawn)  {
        address id = nftID(nftRegistry, tokenId);

        // init with receiver can only happen once
        require(senders[id].amtPerSec == 0);

        // not possible to change the rate per second
        require(amtPerSec == AMT_PER_SEC_UNCHANGED
        || senders[id].amtPerSec == 0, "rate-per-second-not-changeable");

        // calculate max withdraw
        require(withdraw <= maxWithdraw(id), "withdraw-amount-too-high");

        return _sendFromNFT(id,
            topUpAmt, withdraw, amtPerSec, updatedReceivers);
    }

    function maxWithdraw(address to) public view returns (uint128) {
        uint128 amtPerSec = senders[to].amtPerSec;
        if (amtPerSec == 0) {
            return 0;
        }

        uint128 withdrawable_ = withdrawable(to);
        uint128 currLeftSecs = cycleSecs - (uint128(block.timestamp) % cycleSecs);
        uint128 neededCurrCycle = (currLeftSecs * amtPerSec);

        if(neededCurrCycle > withdrawable_) {
            return 0;
        }

        return withdrawable_ - neededCurrCycle;
    }
}

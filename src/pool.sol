pragma solidity ^0.8.7;

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

    function maxWithdraw(address id) public view returns (uint128) {
        uint128 amtPerSec = senders[id].amtPerSec;
        if (amtPerSec == 0) {
            return 0;
        }

        uint128 withdrawable_ = withdrawable(id);
        uint128 neededCurrCycle = (currLeftSecsInCycle() * amtPerSec);

        if(neededCurrCycle > withdrawable_) {
            // in this case support is already inactive
            // the supporter can still withdraw the leftovers
            return withdrawable_;
        }

        return withdrawable_ - neededCurrCycle;
    }

    function currLeftSecsInCycle() public view returns(uint128) {
        return cycleSecs - (uint128(block.timestamp) % cycleSecs);
    }

    function amtPerSecond(address id) public view returns(uint128) {
        return senders[id].amtPerSec;
    }

    function startTime(address id) public view returns(uint64) {
        return senders[id].startTime;
    }
}

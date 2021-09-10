# Technical Design for Radicle Community Tokens

## Summary
The following document describes the technical design for the Radicle funding project.

## Requirements 

A detailed description of the token design and requirements can be found here. 

Some important requirements which influenced the technical design are outlined here.

- It should be possible to stream or drip to an address which is not part of Radicle funding (like a charity org). 
- A receiver address should be able to receive the funds without the need for this specific address to ever interact  with any Radicle contract.
- It should be not possible for a sender to withdraw the money for the current cycle
- An increase of the funding per cycle rate should require the full payment for the current cycle
- A decrease of the funding per cycle should only be possible in the upcoming cycle

## Main Components

### Ethereum Contracts

#### NFT Contract
- Each project has its own ERC721 NFT contract

#### Streaming Contract (Dispersal Contract)
- One contract which locks funds for all projects
- Allows NFT and address based streaming

#### Registry Contract
- Used to create the individual NFT contracts
- Keeps track of all NFT contracts

### Roles

#### Project Owner
Ethereum address which represents a Radicle Funding project

#### Supporter (NFT Owner)
Ethereum address which owns an NFT and streams DAI to Radicle Funding project

#### Arbitrary Ethereum Address
address of a charity or another address which receives funds from a Radicle funding project


### NFT - Contract

For each radicle funding project an NFT registry contract should be deployed. The created NFT registry should allow to store metadata about the project itself.

#### NFT Contract (NFT-Registry) 

| Name | Description | Type |
| --- | --- | --- |
| Token Name | Name of the Community Token | String |
|  |  |  |
|  |  |  |





Token Symbol
Short Version of Token Name
String
Project Owner
All NFTs will stream to this address. address can collect fundings.
Address
MetaData
Hash to offchain Metadata 
Bytes32



Individual NFT

The unique attributes 

Name
Description 
Type
ID
Sequential Number of the NFT
uint


Type Code
 the code used to indicate which type of community token it is. This is intended to be used by projects that wish to offer different types of community tokens, in order to distinguish them
uint



Additional Individual NFT 

These fields are needed for the streaming contract. It is not decided, yet if they should be stored in the NFT Registry contract or in the Streaming Contract.

Name
Description 
Type
fundingRate
current funding rate per cycle
uint 
(denominated in 10^18)
total Funded
total amount funded by this NFT until lastUpdateTimestamp.
uint
(denominated in 10^18)
amountLocked
ERC20 balance locked for a specific NFT
uint
(denominated in 10^18)


If the look of the NFT is based on the fundingRate and totalFunded the should be stored in the NFT Registry contract.
Method: Mint

function mint(address nftReceiver, uint128 topUp, uint128 amtPerSec) external returns (uint256)

Mints a new project NFT 
Creates a new stream based on the nft to the project owner
moves the topUp amount from msg.sender into the streaming pool contract

Parameter:
nftReceiver: address which should receive the NFT
topUp: amount which should be locked in the pool contract
amtPerSec: amount of Dai streamed per second


View-Method: isActive
function isActive(uint tokenId) public view returns(boolean);
 

View-Method: lockedFunds
function lockedFunds(uint tokenId) public view returns(uint);

View-Method: fundingEnd
function fundingEnd(uint tokenId) public view returns(uint timestamp);

View-Method: totalFunded
function totalFunded(uint tokenId) public view returns(uint);

View-Method: nftType
function nftType(uint tokenId) public view returns(uint type);

View-Method: supportAmtPerCycle
function supportAmtPerCycle(uint tokenId) public view returns(uint supportAmount);


Streaming Pool contract

Method: updateSender

    function updateSender(
        address nftRegistry,
        uint128 tokenId,
        uint128 topUpAmt,
        uint128 withdraw,
        uint128 amtPerSec,
        Weights[] calldata updatedReceivers,
    ) public nftOwner(nftRegistry, tokenId)


method of updating an existing stream as a sender
msg.sender needs to own the nft

Parameter:
nftRegistry: address of the nftRegistry
tokenID: NFT token id
toUpAmt: additional amount which should be locked in the contract
withdraw: amount which should be unlocked
 


Method: collect()
function collect(address id) public
Collects the funds for a streaming id

Method: drip()
function drip(address id) public
drips the funds for a streaming id
function drip(address calldata ids[]) public
drips the funds for a streaming id
Radicle Registry 

Factory Contract for generating the ERC721 contracts.

Name
Description
Value
project Counter
counter variable for project used for the ERC721 address generation
uint
Mapping of all Radicle funding Projects
Map of all Radicle Funding NFT registries
Map
CycleSecs
Number of Seconds per cycle
View Method returns uint



function newProject(string memory name, string memory symbol, address projectOwner, uint128 minAmtPerSec) public returns(address)
Generate a new NFT registry for a project
name: Name of the NFT token
symbol: symbol of the NFT token



Still Needed
function updateProject()
A function to define and update drips.





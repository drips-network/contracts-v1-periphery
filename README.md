# Radicle Drips
The main repository for Radicle Drips

## Getting started
Radicle Drips uses [dapp.tools](https://github.com/dapphub/dapptools) for development.
Please install the `dapp` client. Then, run the following command to install the dependencies:

```bash
dapp update
```

## Run all tests
```bash
dapp test
```

## Run specific tests
A regular expression can be used to only run specific tests.

```bash
dapp test -m <REGEX>
dapp test -m testName
dapp test -m ':ContractName\.'
```

## Deploy to a local testnet
Start a local testnet node and let it run in the background:

```bash
dapp testnet
```

Set up environment variables.
See instructions for public network deployment to see all the options.
To automatically set bare minimum environment variables run:

```bash
source scripts/local-env.sh
```

Run deployment:

```bash
scripts/deploy.sh
```

## Deploy to a public network

Use dapp.tools' `ethsign` to query or add keys available on the system for signing transactions.

Set up environment variables controlling the deployment process:

```bash
# The RPC URL to use, e.g. `https://mainnet.infura.io/MY_INFURA_KEY`.
# Contracts will be deployed to whatever network that endpoint works in.
export ETH_RPC_URL="<URL>"

# One of addresses available in `ethsign`
export ETH_FROM="<ADDRESS>"

# OPTIONAL
# The file containing password to decrypt `ETH_FROM` private key from keystore.
# If not set, the password will be prompted multiple times during deployment.
# If `ETH_FROM` is not password protected, can be set to `/dev/null`.
export ETH_PASSWORD="<KEYSTORE_PASSWORD>"

# OPTIONAL
# The API key to use to submit contracts' code to Etherscan.
# In case of deployments to networks other than Ethereum an appropriate equivalent service is used.
export ETHERSCAN_API_KEY="<KEY>"

# OPTIONAL
# The file to write deployment addresses to. Default is `./deployment_<BLOCKCHAIN_NAME>.json`.
export DEPLOYMENT_FILE="FILE"
```

Set up environment variables configuring the deployed contracts:

```bash
# OPTIONAL
# Address of Dai token to use.
# If not set, a dummy instance is deployed where `ETH_FROM` holds all the tokens.
export DAI="<ADDRESS>"

# OPTIONAL
# Address of the governance DAO to use. If not set, `ETH_FROM` is used.
export GOVERNANCE="<ADDRESS>"

# OPTIONAL
# Address of the Polygon bridge Fx Child contract to accept governance messages from.
# Use only on Polygon network to keep GOVERNANCE on L1.
# If set, an intermediate contract will be deployed passing messages to DRIPS_GOVERNANCE.
# If not set, DRIPS_GOVERNANCE is controlled by GOVERNANCE directly.
export POLYGON_FX_CHILD="<ADDRESS>"

# OPTIONAL
# Address of a governance timelock contract to use. If not set, a new instance is deployed.
export DRIPS_GOVERNANCE="<ADDRESS>"

# OPTIONAL
# Address of NFT registry to use. If not set, a new instance is deployed.
export RADICLE_REGISTRY="<ADDRESS>"

# OPTIONAL
# Address of the initial NFT logic template to use in the NFT registry when deploying a new token.
# If not set, a new instance is deployed.
export TOKEN_TEMPLATE="<ADDRESS>"

# OPTIONAL
# Streaming NFT minimum duration. Default is 30 days.
export LOCK_SECS="<SECONDS>"

# OPTIONAL
# Address of the default NFT images builder to use.
# If not set, a new instance using IPFS images is deployed.
export BUILDER="<ADDRESS>"

# OPTIONAL
# The IPFS hash of the default image to use in minted NFTs. Default is a generic Radicle image.
export DEFAULT_IPFS_IMG="<IPFS_HASH>"

# OPTIONAL
# The address besides `$DRIPS_GOVERNANCE` which can change
# the default image IPFS hash of the default NFT images builder.
# If not set, only `$DRIPS_GOVERNANCE` can do that.
export IPFS_OWNER="<ADDRESS>"

# OPTIONAL
# Address of the DripsHub proxy to use. If not set, a new instance is deployed.
export DRIPS_HUB="<ADDRESS>"

# OPTIONAL
# Address of the initial DripsHub logic contract to use. If not set, a new instance is deployed.
export DRIPS_HUB_LOGIC="<ADDRESS>"

# OPTIONAL
# Cycle length to set in the deployed DripsHub logic. Default is 1 week.
export CYCLE_SECS="<SECONDS>"

# OPTIONAL
# Address of Dai reserve to use. If not set, a new instance is deployed.
export RESERVE="<ADDRESS>"
```

Run deployment:

```bash
scripts/deploy.sh
```

### Deploying to Polygon Mumbai

Polygon Mumbai is supported by dapp.tools' `seth` in versions **newer than** 0.11.0.
If no such version is officially released yet, you must install it from `master`:

```bash
git clone git@github.com:dapphub/dapptools.git
cd dapptools
nix-env -iA solc dapp seth hevm -f .
```

As of now gas estimation isn't working and you need to set it manually to an arbitrary high value:

```bash
export ETH_GAS=10000000
```

For deployment you can use the public MaticVigil RPC endpoint:

```bash
export ETH_RPC_URL='https://rpc-mumbai.maticvigil.com/'
```

To publish smart contracts to `https://mumbai.polygonscan.com/` you need to
use the API key generated for an account on regular `https://polygonscan.com/`.

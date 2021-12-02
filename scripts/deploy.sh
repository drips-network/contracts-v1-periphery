#! /usr/bin/env bash

set -e

message() {

    echo
    echo -----------------------------------------------------------------------------
    echo "$@"
    echo -----------------------------------------------------------------------------
    echo
}

addValuesToFile() {
    result=$(jq -s add "$1" /dev/stdin)
    printf %s "$result" > "$1"
}

DEPLOYMENT_FILE=${1:-./deployment_$(seth chain).json}
GOVERNANCE=${1:-0x$ETH_FROM}
DEFAULT_IPFS_IMG=${1:-QmcjdWo3oDYPGdLCdmEpGGpFsFKbfXwCLc5kdTJj9seuLx}

message Deployment Config
echo "Governance Address:       $GOVERNANCE"
echo "DAI Address:              $DAI"
echo "Default IPFS Hash image:  $DEFAULT_IPFS_IMG"

# build contracts
message Build Contracts
dapp build

# deploy Test Dai if not defined
[ -z "$DAI" ] && DAI=$(dapp create Dai)
[ -z "$CYCLE_SECS" ] && CYCLE_SECS=86400 # one day secs
message Funding Contracts Deployment

[ -z "$DRIPS_HUB" ] && DRIPS_HUB=$(dapp create DaiDripsHub $CYCLE_SECS $GOVERNANCE $DAI)
echo "Drips Hub Contract: $DRIPS_HUB"

[ -z "$BUILDER" ] && BUILDER=$(dapp create DefaultIPFSBuilder $GOVERNANCE "\"$DEFAULT_IPFS_IMG\"")
echo "Builder Contract: $BUILDER"

[ -z "$RADICLE_REGISTRY" ] && RADICLE_REGISTRY=$(dapp create RadicleRegistry $DRIPS_HUB $BUILDER $GOVERNANCE)

echo "Radicle Registry Contract: $RADICLE_REGISTRY"

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "CONTRACT_DAI"               : "$DAI",
    "CONTRACT_DRIPS_HUB"         : "$DRIPS_HUB",
    "CONTRACT_RADICLE_REGISTRY"  : "$RADICLE_REGISTRY",
    "CONTRACT_BUILDER"           : "$BUILDER",
    "NETWORK"                    : "$(seth chain)",
    "DEPLOY_ADDRESS"             : "$ETH_FROM",
    "CYCLE_SECS"                 : "$CYCLE_SECS",
    "COMMIT_HASH"                : "$(git --git-dir .git rev-parse HEAD )",
    "GOVERNANCE_ADDRESS"         : "$GOVERNANCE"
}
EOF

message Deployment JSON: $DEPLOYMENT_FILE

cat $DEPLOYMENT_FILE

message Verify Contracts on Etherscan
if [ -n "$ETHERSCAN_API_KEY" ]; then
  dapp verify-contract --async 'lib/radicle-drips-hub/src/DaiDripsHub.sol:DaiDripsHub' $DRIPS_HUB $CYCLE_SECS $GOVERNANCE $DAI
  dapp verify-contract --async 'src/registry.sol:RadicleRegistry' $RADICLE_REGISTRY $DRIPS_HUB $BUILDER $GOVERNANCE
  dapp verify-contract --async 'src/ipfsBuilder.sol:DefaultIPFSBuilder' $BUILDER $GOVERNANCE "\"$DEFAULT_IPFS_IMG\""
  TOKEN_TEMPLATE=$(seth call $RADICLE_REGISTRY 'dripTokenTemplate()(address)')
  dapp verify-contract --async 'src/token.sol:DripsToken' $TOKEN_TEMPLATE $DRIPS_HUB
else
  echo "No ETHERSCAN_API_KEY for contract verification provided"
fi

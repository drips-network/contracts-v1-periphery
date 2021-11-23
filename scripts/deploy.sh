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

message Deployment Config
echo "Governance Address: $GOVERNANCE"
echo "DAI Address:        $DAI"

# build contracts
message Build Contracts
dapp build

# deploy Test Dai if not defined
[ -z "$DAI" ] && DAI=$(dapp create Dai)
[ -z "$CYCLE_SECS" ] && CYCLE_SECS=86400 # one day secs
message Funding Contracts Deployment

[ -z "$FUNDING_POOL" ] && FUNDING_POOL=$(dapp create DaiPool $CYCLE_SECS $DAI)
echo "Funding Pool Contract: $FUNDING_POOL"

[ -z "$BUILDER" ] && BUILDER=$(dapp create Builder)
echo "Builder Contract: $BUILDER"

[ -z "$RADICLE_REGISTRY" ] && RADICLE_REGISTRY=$(dapp create RadicleRegistry $FUNDING_POOL $BUILDER $GOVERNANCE)

echo "Radicle Registry Contract: $RADICLE_REGISTRY"

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "CONTRACT_DAI"               : "$DAI",
    "CONTRACT_FUNDING_POOL"      : "$FUNDING_POOL",
    "CONTRACT_RADICLE_REGISTRY"  : "$RADICLE_REGISTRY",
    "CONTRACT_BUILDER"           : "$BUILDER",
    "NETWORK"                    : "$(seth chain)",
    "DEPLOY_ADDRESS"             : "$ETH_FROM",
    "CYCLE_SECS"                 : "$CYCLE_SECS",
    "COMMIT_HASH"                :  "$(git --git-dir .git rev-parse HEAD )"
}
EOF

message Deployment JSON: $DEPLOYMENT_FILE

cat $DEPLOYMENT_FILE

message Verify Contracts on Etherscan
if [ -n "$ETHERSCAN_API_KEY" ]; then
  dapp verify-contract --async 'lib/radicle-streaming/src/DaiPool.sol:DaiPool' $FUNDING_POOL $CYCLE_SECS $DAI
  dapp verify-contract --async 'src/registry.sol:RadicleRegistry' $RADICLE_REGISTRY $FUNDING_POOL $BUILDER $GOVERNANCE
  dapp verify-contract --async 'src/builder.sol:Builder' $BUILDER
  TOKEN_TEMPLATE=$(seth call $RADICLE_REGISTRY 'dripTokenTemplate()(address)')
  dapp verify-contract --async 'src/token.sol:DripsToken' $TOKEN_TEMPLATE $FUNDING_POOL
else
    echo "No ETHERSCAN_API_KEY for contract verification provided"
fi



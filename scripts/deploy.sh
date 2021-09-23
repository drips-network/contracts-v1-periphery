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

# build contracts
dapp build

DEPLOYMENT_FILE=${1:-./deployment_$(seth chain).json}

# deploy Test Dai if not defined
[ -z "$DAI" ] && DAI=$(dapp create Dai)
[ -z "$CYCLE_SECS" ] && CYCLE_SECS=86400 # 1 day cycle
message Funding Contracts Deployment

echo "Dai Contract: $DAI"
FUNDING_POOL=$(dapp create FundingPool $CYCLE_SECS $DAI)

echo "Funding Pool Contract: $FUNDING_POOL"

RADICLE_REGISTRY=$(dapp create RadicleRegistry $FUNDING_POOL)

echo "Funding Pool Contract: $RADICLE_REGISTRY"

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "CONTRACT_DAI"               : "$DAI",
    "CONTRACT_FUNDING_POOL"      : "$FUNDING_POOL",
    "CONTRACT_RADICLE_REGISTRY"  : "$RADICLE_REGISTRY",
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
  dapp verify-contract --async 'src/pool.sol:FundingPool' $FUNDING_POOL $CYCLE_SECS $DAI
  dapp verify-contract --async 'src/registry.sol:RadicleRegistry' $RADICLE_REGISTRY $FUNDING_POOL
else
    echo "No ETHERSCAN_API_KEY provided"
fi



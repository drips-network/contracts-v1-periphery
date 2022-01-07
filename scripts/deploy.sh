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

DEPLOYMENT_FILE=${DEPLOYMENT_FILE:-./deployment_$(seth chain).json}
GOVERNANCE=${GOVERNANCE:-$ETH_FROM}
DEFAULT_IPFS_IMG=${DEFAULT_IPFS_IMG:-QmcjdWo3oDYPGdLCdmEpGGpFsFKbfXwCLc5kdTJj9seuLx}
CYCLE_SECS=${CYCLE_SECS:-$(( 7 * 24 * 60 * 60 ))} # 1 week
LOCK_SECS=${LOCK_SECS:-$(( 30 * 24 * 60 * 60 ))} # 30 days

message Deployment Config
echo "Governance Address:       $GOVERNANCE"
echo "DAI Address:              $DAI"
echo "Default IPFS Hash image:  $DEFAULT_IPFS_IMG"
echo "Config Cycle Secs:        $CYCLE_SECS"
echo "Config Lock Secs:         $LOCK_SECS"
echo "Ethereum Chain:           $(seth chain)"
echo "ETH_FROM:                 $ETH_FROM"
echo "ETH_GAS_PRICE:            $ETH_GAS_PRICE"
echo "ETH_GAS:                  $ETH_GAS"
echo "ETHERSCAN_API_KEY:        $ETHERSCAN_API_KEY"
echo "IPFS_OWNER"               $IPFS_OWNER

read -p "Ready to deploy? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# build contracts
message Build Contracts
dapp build

# deploy Test Dai if not defined
[ -z "$DAI" ] && DAI=$(dapp create Dai)

[ -z "$DRIPS_GOVERNANCE" ] && DRIPS_GOVERNANCE=$(dapp create Governance $GOVERNANCE)
echo "Drips Governance Contract: $DRIPS_GOVERNANCE"

GOVERNANCE_EXECUTOR=$(seth call $DRIPS_GOVERNANCE 'executor()(address)')
echo "Governance Executor Contract: $GOVERNANCE_EXECUTOR"

message Drips Contracts Deployment

[ -z "$DRIPS_HUB_LOGIC" ] && DRIPS_HUB_LOGIC=$(dapp create DaiDripsHub $CYCLE_SECS $DAI)
echo "Drips Hub Logic Contract: $DRIPS_HUB_LOGIC"
[ -z "$DRIPS_HUB" ] && DRIPS_HUB=$(dapp create ManagedDripsHubProxy $DRIPS_HUB_LOGIC $ETH_FROM)
echo "Drips Hub Contract: $DRIPS_HUB"

[ -z "$RESERVE" ] && RESERVE=$(dapp create DaiReserve $DAI $GOVERNANCE_EXECUTOR $DRIPS_HUB)
echo "Reserve Contract: $RESERVE"

# set reserve dependency in drips hub
seth send $DRIPS_HUB 'setReserve(address)()' $RESERVE

# give hub ownership to executor
seth send $DRIPS_HUB 'changeAdmin(address)()' $GOVERNANCE_EXECUTOR

[ -z "$BUILDER" ] && BUILDER=$(dapp create DefaultIPFSBuilder $ETH_FROM "\"$DEFAULT_IPFS_IMG\"")
echo "Builder Contract: $BUILDER"

# ownership permissions Builder
seth send $BUILDER 'rely(address)' $GOVERNANCE_EXECUTOR
[ -n "$IPFS_OWNER" ] && seth send $BUILDER 'rely(address)' $IPFS_OWNER
seth send $BUILDER 'deny(address)' $ETH_FROM


# Set initial ownership to the deployer address
[ -z "$RADICLE_REGISTRY" ] && RADICLE_REGISTRY=$(dapp create RadicleRegistry $BUILDER $ETH_FROM)

echo "Radicle Registry Contract: $RADICLE_REGISTRY"

[ -z "$TOKEN_TEMPLATE" ] && TOKEN_TEMPLATE=$(dapp create DripsToken $DRIPS_HUB $RADICLE_REGISTRY $LOCK_SECS)

echo "Token template Contract: $TOKEN_TEMPLATE"

# Set token template
seth send $RADICLE_REGISTRY 'changeTemplate(address)()' $TOKEN_TEMPLATE
# Transfer ownership to the governance
seth send $RADICLE_REGISTRY 'transferOwnership(address)()' $GOVERNANCE_EXECUTOR

message Check Correct Governance
echo "Governance (Multi-Sig): $GOVERNANCE"
echo "Governance Contract controlled by Owner: $(seth call $DRIPS_GOVERNANCE 'owner()(address)')"
echo "Governance Executor:                     $GOVERNANCE_EXECUTOR"
echo "DRIPS_HUB                         Admin: $(seth call $DRIPS_HUB 'admin()(address)')"
echo "RESERVE                           Owner: $(seth call $RESERVE 'owner()(address)')"
echo "RADICLE_REGISTRY                  Owner: $(seth call $RADICLE_REGISTRY 'owner()(address)')"
echo "BUILDER                           Owner: $(seth call $BUILDER 'owner()(address)')"

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "CONTRACT_DAI"               : "$DAI",
    "CONTRACT_DRIPS_HUB"         : "$DRIPS_HUB",
    "CONTRACT_DRIPS_HUB_LOGIC"   : "$DRIPS_HUB_LOGIC",
    "CONTRACT_RESERVE"           : "$RESERVE",
    "CONTRACT_RADICLE_REGISTRY"  : "$RADICLE_REGISTRY",
    "CONTRACT_BUILDER"           : "$BUILDER",
    "NETWORK"                    : "$(seth chain)",
    "DEPLOY_ADDRESS"             : "$ETH_FROM",
    "CYCLE_SECS"                 : "$CYCLE_SECS",
    "COMMIT_HASH"                : "$(git --git-dir .git rev-parse HEAD )",
    "GOVERNANCE_ADDRESS"         : "$GOVERNANCE",
    "CONTRACT_DRIPS_GOVERNANCE"  : "$DRIPS_GOVERNANCE"
}
EOF

message Deployment JSON: $DEPLOYMENT_FILE

cat $DEPLOYMENT_FILE

message Verify Contracts on Etherscan
if [ -n "$ETHERSCAN_API_KEY" ]; then
  dapp verify-contract --async 'src/governance/governance.sol:Governance' $DRIPS_GOVERNANCE $GOVERNANCE
  dapp verify-contract --async 'src/governance/governance.sol:Executor' $GOVERNANCE_EXECUTOR
  dapp verify-contract --async 'lib/radicle-drips-hub/src/DaiDripsHub.sol:DaiDripsHub' $DRIPS_HUB_LOGIC $CYCLE_SECS $DAI
  dapp verify-contract --async 'lib/radicle-drips-hub/src/ManagedDripsHub.sol:ManagedDripsHubProxy' $DRIPS_HUB $DRIPS_HUB_LOGIC $ETH_FROM
  dapp verify-contract --async 'lib/radicle-drips-hub/src/DaiReserve.sol:DaiReserve' $RESERVE $DAI $GOVERNANCE_EXECUTOR $DRIPS_HUB
  dapp verify-contract --async 'src/registry.sol:RadicleRegistry' $RADICLE_REGISTRY $BUILDER $ETH_FROM
  dapp verify-contract --async 'src/builder/ipfsBuilder.sol:DefaultIPFSBuilder' $BUILDER $GOVERNANCE "\"$DEFAULT_IPFS_IMG\""
  TOKEN_TEMPLATE=$(seth call $RADICLE_REGISTRY 'dripsTokenTemplate()(address)')
  dapp verify-contract --async 'src/token.sol:DripsToken' $TOKEN_TEMPLATE $DRIPS_HUB $RADICLE_REGISTRY $LOCK_SECS
else
  echo "No ETHERSCAN_API_KEY for contract verification provided"
fi

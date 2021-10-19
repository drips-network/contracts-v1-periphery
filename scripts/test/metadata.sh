# metadata test
dapp build
METADATA=$(dapp create Builder)
echo "first test"
seth call $METADATA 'buildMetaData(string memory,uint,uint128,bool)' '"Project"' 1 10000000000000000000 true | seth --to-ascii
echo "second test"
seth call $METADATA 'buildMetaData(string memory,uint,uint128,bool)' '"Project"' 1 12300000000000000000 true | seth --to-ascii


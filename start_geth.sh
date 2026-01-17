#!/bin/sh
set -e

# Data directory
DATADIR="/root/.ethereum"

# Check if already initialized
if [ ! -d "$DATADIR/geth/chaindata" ]; then
    echo "Initializing genesis..."
    geth --datadir "$DATADIR" init /root/genesis.json
fi

# Create password file
echo "password" > /root/password.txt

# Import private key if keystore is empty
if [ -z "$(ls -A $DATADIR/keystore 2>/dev/null)" ]; then
    echo "Importing private key..."
    # ETH_PRIVATE_KEY should be passed from ENV (without 0x prefix if possible, but geth handles both usually, extract 0x if needed)
    # Strip 0x prefix if present
    KEY=${ETH_PRIVATE_KEY#0x}
    echo "$KEY" > /root/account.key
    geth --datadir "$DATADIR" account import --password /root/password.txt /root/account.key
    rm /root/account.key
fi

echo "Starting Geth..."
# Ensure we unlock the account for mining
# --mine enables mining (essential for Clique to produce blocks)
# --unlock unlocks the account for signing
# --allow-insecure-unlock needed because we unlock via HTTP/command line
exec geth \
  --datadir "$DATADIR" \
  --networkid 1337 \
  --mine \
  --miner.etherbase "$ETH_ADMIN_ADDRESS" \
  --unlock "$ETH_ADMIN_ADDRESS" \
  --password /root/password.txt \
  --allow-insecure-unlock \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api "eth,net,web3,personal,debug,miner,clique" \
  --http.corsdomain "*" \
  --http.vhosts "*" \
  --ws \
  --ws.addr 0.0.0.0 \
  --ws.port 8546 \
  --ws.api "eth,net,web3,personal,debug,miner,clique" \
  --ws.origins "*"

#!/bin/bash
# script to fund admin account
# ADMIN_ADDRESS=0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
docker exec exchangestaging-staging-uzecog-ethereum-1 geth --exec 'eth.sendTransaction({from: eth.accounts[0], to: "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1", value: web3.toWei(1000, "ether")})' attach http://localhost:8545

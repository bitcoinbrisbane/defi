# PositionManager Smart Contract

Automated Uniswap V3 liquidity position manager for WBTC/USDC pool with concentrated liquidity rebalancing.

## Overview

The `PositionManager` contract provides:
- **Automated Position Creation**: Create concentrated liquidity positions within ±15% range
- **Fee Collection**: Collect trading fees earned from the position
- **Rebalancing**: Close and recreate positions when price moves out of range
- **Emergency Controls**: Owner-controlled emergency withdrawal functions

## Contract Details

- **Pool**: WBTC/USDC (0.30% fee tier)
- **Network**: Ethereum Mainnet
- **Uniswap**: V3 NonfungiblePositionManager
- **Solidity**: ^0.8.20

## Installation

```bash
# Install dependencies
forge install

# Copy environment file
cp .env.example .env
```

## Build

```bash
forge build
```

## Test

```bash
# Set MAINNET_RPC_URL in .env first
forge test -vvv
```

## Deploy

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Mainnet Addresses

```
Uniswap V3 Position Manager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
WBTC:                        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
USDC:                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
WBTC/USDC Pool (0.30%):      0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16
```

## Resources

- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [Main Project README](../README.md)

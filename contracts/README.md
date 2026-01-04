# PositionManager Smart Contract

Automated Uniswap V3 liquidity position manager for WBTC/USDC pool with concentrated liquidity rebalancing.

## Overview

The `PositionManager` contract provides automated management of Uniswap V3 concentrated liquidity positions through a clean interface abstraction.

### Architecture

- **`IPositionManager.sol`** - Interface defining all public functions and events
- **`PositionManager.sol`** - Implementation of the position manager
- **`examples/PositionManagerExample.sol`** - Example usage of the interface

### Key Features

- ✅ **Abstracted Interface** - Clean separation between interface and implementation
- ✅ **Automated Position Creation** - Create concentrated liquidity positions within ±15% range
- ✅ **Fee Collection & Compounding** - Collect and reinvest trading fees
- ✅ **Rebalancing** - Close and recreate positions when price moves out of range
- ✅ **Emergency Controls** - Owner-controlled emergency withdrawal functions

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

## Interface Functions

### Core Functions

- `addLiquidity()` - Add liquidity to create or increase a position
- `underlying()` - Get underlying token balances for a position
- `getPools()` - Get information about all managed pools
- `emergencyWithdraw()` - Emergency withdraw tokens from the contract
- `rebalance()` - Rebalance position when price moves out of range
- `compound()` - Compound accumulated fees back into the position
- `calculateTickRange()` - Calculate tick range for ±15% from current price
- `updateRange()` - Update the range percentage

### Example Usage

```solidity
import "./IPositionManager.sol";

contract MyContract {
    IPositionManager public manager;

    constructor(address _manager) {
        manager = IPositionManager(_manager);
    }

    function addPosition() external {
        // Calculate tick range
        (int24 lower, int24 upper) = manager.calculateTickRange(currentTick);
        
        // Add liquidity
        (uint256 tokenId, , , ) = manager.addLiquidity(
            wbtcAmount,
            usdcAmount,
            lower,
            upper
        );
    }
}
```

See `src/examples/PositionManagerExample.sol` for more examples.

## Project Structure

```
contracts/
├── src/
│   ├── IPositionManager.sol           # Interface
│   ├── PositionManager.sol            # Implementation (stubbed)
│   └── examples/
│       └── PositionManagerExample.sol # Usage examples
├── test/
│   └── PositionManager.t.sol          # Tests
├── script/
│   └── Deploy.s.sol                   # Deployment script
└── foundry.toml                       # Configuration
```

## Stubbed Methods (TODO)

The following methods are currently stubbed and need implementation:

- [ ] `addLiquidity()` - Token transfers, approval, position minting
- [ ] `underlying()` - Calculate token amounts from liquidity
- [ ] `getPools()` - Query all positions owned by contract
- [ ] `emergencyWithdraw()` - Emergency token withdrawal
- [ ] `rebalance()` - Position rebalancing logic
- [ ] `compound()` - Fee collection and reinvestment

Each stubbed method includes detailed TODO comments explaining the implementation steps.

## Mainnet Addresses

```
Uniswap V3 Position Manager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
WBTC:                        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
USDC:                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
WBTC/USDC Pool (0.30%):      0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16
```

## Development

### Run Tests

```bash
forge test -vvv --fork-url $MAINNET_RPC_URL
```

### Test Specific Function

```bash
forge test --match-test testCalculateTickRange -vvv
```

### Generate Gas Report

```bash
forge test --gas-report
```

### Coverage

```bash
forge coverage
```

## Resources

- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [Main Project README](../README.md)

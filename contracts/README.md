# PositionManager Smart Contract

Automated Uniswap V3 liquidity position manager for WBTC/USDC pool with concentrated liquidity rebalancing.

## Overview

The `PositionManager` contract provides automated management of Uniswap V3 concentrated liquidity positions through a clean interface abstraction. All operations are **zero-parameter** for maximum automation compatibility.

### Architecture

- **`IPositionManager.sol`** - Interface defining all public functions and events
- **`IUniswap.sol`** - Uniswap V3 and Chainlink interfaces
- **`PositionManager.sol`** - Full implementation of the position manager
- **`examples/PositionManagerExample.sol`** - Example usage of the interface

### Key Features

- ✅ **Zero-Parameter Functions** - Fully automated operations using Chainlink oracles and Uniswap pool data
- ✅ **Automated Token Swapping** - Automatically swaps tokens to achieve 50/50 balance before adding liquidity
- ✅ **Automated Position Creation** - Create concentrated liquidity positions within ±15% range
- ✅ **Fee Collection & Compounding** - Collect and reinvest trading fees (public function - anyone can trigger!)
- ✅ **Auto-Rebalancing** - Close and recreate positions at current market price
- ✅ **Emergency Controls** - Owner-controlled emergency withdrawal of all assets
- ✅ **Price Feed Protection** - Chainlink price staleness checks (1-hour threshold)
- ✅ **Reentrancy Protection** - All state-changing functions protected with ReentrancyGuard
- ✅ **Gas Optimized** - Uses immutable `_self` address for gas savings
- ✅ **ETH Compatible** - Can receive and sweep ETH

## Contract Details

- **Pool**: WBTC/USDC (0.30% fee tier)
- **Network**: Ethereum Mainnet
- **Uniswap**: V3 NonfungiblePositionManager
- **Oracle**: Chainlink WBTC/USD Price Feed
- **Solidity**: ^0.8.19
- **Range**: ±15% (configurable)

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

## Core Functions

### Position Management (Owner Only)

#### `createPosition(amount0, amount1, tickLower, tickUpper)`
Create a new position with specific tick range.
```solidity
(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
    manager.createPosition(1e8, 90000e6, tickLower, tickUpper);
```

#### `addLiquidityFromContract()`
**Zero-parameter function** that automatically:
- Fetches current tick from Uniswap pool
- Calculates optimal ±15% range
- Uses 100% of contract's WBTC and USDC balances

```solidity
(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
    manager.addLiquidityFromContract();
```

#### `addLiquidityFromContractPrioritized(wbtcPrice, tickLower, tickUpper)`
Add liquidity using 100% of the token with higher USD value.
```solidity
(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
    manager.addLiquidityFromContractPrioritized(89892e6, tickLower, tickUpper);
```

#### `rebalance()`
**Zero-parameter function** that automatically:
- Collects fees from current position
- Closes current position
- Gets current tick from pool
- Creates new position at current price with ±15% range

```solidity
uint256 newTokenId = manager.rebalance();
```

#### `collectFees(tokenId)`
Collect accumulated fees from a position to owner.
```solidity
(uint256 amount0, uint256 amount1) = manager.collectFees(tokenId);
```

#### `collectFeesAndWithdraw()`
One-click function to collect all fees and withdraw all tokens to owner.
```solidity
(uint256 fees0, uint256 fees1, uint256 withdrawn0, uint256 withdrawn1) =
    manager.collectFeesAndWithdraw();
```

### Fee Compounding (Public - Anyone Can Call!)

#### `compound()`
**Zero-parameter PUBLIC function** that automatically:
- Collects fees from current position
- Gets WBTC price from Chainlink
- Gets current tick from pool
- Creates new position with 100% of higher-value token

```solidity
(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
    manager.compound();
```

**Note**: This function has NO `onlyOwner` restriction - anyone can trigger compounding and pay the gas! Perfect for automation services like Gelato or Chainlink Keepers.

### Emergency Functions (Owner Only)

#### `emergencyWithdraw()`
**Zero-parameter function** that sweeps ALL assets:
- All ETH in contract
- All WBTC in contract
- All USDC in contract

```solidity
(uint256 ethAmount, uint256 wbtcAmount, uint256 usdcAmount) =
    manager.emergencyWithdraw();
```

### View Functions

#### `tokenA()` / `tokenB()`
Get WBTC and USDC token interfaces.
```solidity
IERC20 wbtc = manager.tokenA();
IERC20 usdc = manager.tokenB();
```

#### `balance()`
Get contract's current token balances.
```solidity
(uint256 wbtcBalance, uint256 usdcBalance) = manager.balance();
```

#### `name()`
Get pool name (e.g., "Pool Wrapped BTC USD Coin").
```solidity
string memory poolName = manager.name();
```

#### `getPositionInfo(tokenId)`
Get detailed information about a position.
```solidity
IPositionManager.PositionInfo memory info = manager.getPositionInfo(tokenId);
```

#### `calculateTickRange(currentTick)`
Calculate tick range for ±15% from current tick.
```solidity
(int24 tickLower, int24 tickUpper) = manager.calculateTickRange(currentTick);
```

### Configuration (Owner Only)

#### `updateRange(newRangePercent)`
Update the range percentage (e.g., change from ±15% to ±20%).
```solidity
manager.updateRange(20); // Change to ±20%
```

## Automation Example

Perfect for Gelato, Chainlink Keepers, or any automation service:

```solidity
// Automation contract
contract AutoCompounder {
    IPositionManager public manager;

    // Called by Gelato/Chainlink Keeper
    function performUpkeep(bytes calldata) external {
        // Anyone can call compound() - no auth needed!
        manager.compound();
    }

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        // Check if there are fees to compound
        // (Implementation depends on your strategy)
        return (shouldCompound, "");
    }
}
```

## Example Usage

```solidity
import "./IPositionManager.sol";

contract MyContract {
    IPositionManager public manager;

    constructor(address _manager) {
        manager = IPositionManager(_manager);
    }

    function createAndManagePosition() external {
        // Send tokens to manager
        IERC20(WBTC).transfer(address(manager), 1e8);
        IERC20(USDC).transfer(address(manager), 90000e6);

        // Create position automatically
        manager.addLiquidityFromContract();
    }

    function autoRebalance() external {
        // Rebalance at current price - no parameters needed!
        manager.rebalance();
    }

    function autoCompound() external {
        // Anyone can trigger - pays gas for owner's benefit
        manager.compound();
    }
}
```

See `src/examples/PositionManagerExample.sol` for more examples.

## Project Structure

```
contracts/
├── src/
│   ├── IPositionManager.sol           # Interface
│   ├── IUniswap.sol                   # Uniswap & Chainlink interfaces
│   ├── PositionManager.sol            # Full implementation
│   └── examples/
│       └── PositionManagerExample.sol # Usage examples
├── test/
│   ├── PositionManager.t.sol          # Core tests
│   └── EmergencyWithdraw.t.sol        # Emergency withdraw tests
├── script/
│   └── Deploy.s.sol                   # Deployment script
└── foundry.toml                       # Configuration
```

## Implementation Status

### ✅ Fully Implemented

- ✅ `createPosition()` - Create positions with tokens from sender
- ✅ `addLiquidityFromContract()` - Zero-parameter automated position creation
- ✅ `addLiquidityFromContractPrioritized()` - Smart token prioritization
- ✅ `collectFees()` - Fee collection to owner
- ✅ `collectFeesAndWithdraw()` - One-click fee collection + withdrawal
- ✅ `rebalance()` - Zero-parameter auto-rebalancing
- ✅ `compound()` - Zero-parameter public compounding
- ✅ `emergencyWithdraw()` - Zero-parameter sweep all assets
- ✅ `calculateTickRange()` - Tick math for ±% ranges
- ✅ `updateRange()` - Configure range percentage
- ✅ `getPositionInfo()` - Position details
- ✅ `tokenA()`, `tokenB()`, `balance()`, `name()` - Helper functions

### ❌ Not Implemented (Stubs)

- ❌ `addLiquidity()` - Not needed (use `createPosition` or `addLiquidityFromContract`)
- ❌ `getPools()` - Not needed (single pool contract)

## Mainnet Addresses

```
Uniswap V3 Position Manager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
WBTC/USDC Pool (0.30%):      0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16
Chainlink WBTC/USD Feed:     0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
WBTC:                        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
USDC:                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
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

## Gas Optimizations

- Uses `_self` immutable for `address(this)` (~97 gas saved per usage)
- Immutable variables for all config addresses
- Efficient tick math calculations
- Minimal external calls

## Security Features

- Owner-only controls for sensitive operations
- Public `compound()` for trustless automation
- Safe ETH transfers with success checks
- Slippage set to 0 (use private RPCs for production)
- No unused token left behind (sweep on emergency)

## Documentation

- [Add Liquidity Refactored Guide](contracts/ADD_LIQUIDITY_REFACTORED.md)
- [Collect Fees and Withdraw](contracts/COLLECT_FEES_AND_WITHDRAW.md)
- [Emergency Withdraw Guide](EMERGENCY_WITHDRAW.md)
- [Interface Guide](INTERFACE_GUIDE.md)
- [Project Status](PROJECT_STATUS.md)

## Resources

- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Foundry Book](https://book.getfoundry.sh/)
- [Main Project README](../README.md)

## License

MIT

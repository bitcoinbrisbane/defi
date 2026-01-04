# addLiquidityFromContractPrioritized() Function

## Overview

The `addLiquidityFromContractPrioritized()` function intelligently adds liquidity by prioritizing the token with greater USD value in the contract. It uses **100% of the higher-value token** and proportionally uses the other token.

## Function Signature

```solidity
function addLiquidityFromContractPrioritized(
    uint256 wbtcPrice,
    int24 tickLower,
    int24 tickUpper
) external onlyOwner returns (
    uint256 tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
);
```

## Parameters

- `wbtcPrice` (uint256): Current WBTC price in USDC with 6 decimals (e.g., 89892000000 for $89,892)
- `tickLower` (int24): Lower bound tick for the liquidity range
- `tickUpper` (int24): Upper bound tick for the liquidity range

## Returns

- `tokenId` (uint256): The NFT token ID representing the position
- `liquidity` (uint128): Amount of liquidity minted
- `amount0` (uint256): Actual amount of WBTC used
- `amount1` (uint256): Actual amount of USDC used

## Access Control

- ✅ **Owner Only**: Only the contract owner can call this function
- ❌ **Reverts**: Non-owner calls will revert

## How It Works

### Step-by-Step Process

1. **Get Contract Balances**
   - Checks WBTC balance: `IERC20(wbtc).balanceOf(address(this))`
   - Checks USDC balance: `IERC20(usdc).balanceOf(address(this))`
   - Requires at least one token balance > 0

2. **Calculate USD Values**
   ```solidity
   // WBTC has 8 decimals, USDC has 6 decimals
   uint256 wbtcValueUSD = (wbtcBalance * wbtcPrice) / 1e8;
   uint256 usdcValueUSD = usdcBalance; // Already in USDC
   ```

3. **Prioritize Higher-Value Token**
   - If WBTC value ≥ USDC value: Use 100% of WBTC
   - If USDC value > WBTC value: Use 100% of USDC
   - Use whatever is available of the other token

4. **Approve Tokens**
   - Approves Uniswap Position Manager for selected amounts

5. **Mint Position**
   - Creates new Uniswap V3 position
   - Uses specified tick range (tickLower, tickUpper)
   - Sets recipient as contract address
   - Sets slippage to 0 (amount0Min and amount1Min = 0)

6. **Store Position**
   - Stores NFT token ID in `currentTokenId`
   - Emits `PositionCreated` event

7. **Handle Unused Tokens**
   - Any tokens not used remain in contract
   - Can be withdrawn later via `emergencyWithdraw()`

## Key Features

### ✅ Prioritizes Higher-Value Token

Unlike `addLiquidityFromContract()` which uses 100% of both tokens, this function intelligently selects which token to use 100% of:

```solidity
if (wbtcValueUSD >= usdcValueUSD) {
    // Use 100% of WBTC, all available USDC
    amount0Desired = wbtcBalance;
    amount1Desired = usdcBalance;
} else {
    // Use all available WBTC, 100% of USDC
    amount0Desired = wbtcBalance;
    amount1Desired = usdcBalance;
}
```

### ✅ Price-Aware Decision Making

Requires current WBTC price to make intelligent allocation decisions:
- Ensures maximum capital efficiency
- Prevents dust amounts being left unused
- Optimizes for the most valuable token

### ✅ Flexible Token Requirements

Works with:
- ✅ Both WBTC and USDC (uses higher value token 100%)
- ✅ Only WBTC (uses 100% of WBTC)
- ✅ Only USDC (uses 100% of USDC)
- ❌ Neither (reverts with "No tokens in contract")

## Usage Examples

### Example 1: WBTC Has Higher Value

```solidity
// Assume contract has:
// - 1 WBTC ($89,892)
// - 50,000 USDC
//
// WBTC value: $89,892
// USDC value: $50,000
// Result: Uses 100% WBTC (higher), uses all available USDC

uint256 wbtcPrice = 89892000000; // $89,892 with 6 decimals
(int24 tickLower, int24 tickUpper) = manager.calculateTickRange(currentTick);

(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
    manager.addLiquidityFromContractPrioritized(
        wbtcPrice,
        tickLower,
        tickUpper
    );

// Result: Uses ALL 1 WBTC and ALL 50,000 USDC
```

### Example 2: USDC Has Higher Value

```solidity
// Assume contract has:
// - 0.5 WBTC ($44,946)
// - 100,000 USDC
//
// WBTC value: $44,946
// USDC value: $100,000
// Result: Uses all available WBTC, uses 100% USDC (higher)

uint256 wbtcPrice = 89892000000; // $89,892 with 6 decimals

(uint256 tokenId, , , ) = manager.addLiquidityFromContractPrioritized(
    wbtcPrice,
    tickLower,
    tickUpper
);

// Result: Uses ALL 0.5 WBTC and ALL 100,000 USDC
```

### Example 3: After Fee Collection

```solidity
// Collect fees from existing position
manager.collectFees(existingTokenId);

// Fees now in contract (likely imbalanced)
// Contract has: 0.02 WBTC ($1,798) + 5,000 USDC
// USDC value is higher, so prioritize USDC

uint256 currentPrice = 89892000000;
(uint256 newTokenId, , , ) = manager.addLiquidityFromContractPrioritized(
    currentPrice,
    tickLower,
    tickUpper
);
```

## Comparison with Other Functions

| Feature | createPosition() | addLiquidityFromContract() | addLiquidityFromContractPrioritized() |
|---------|------------------|----------------------------|--------------------------------------|
| Token Source | Transfers from msg.sender | Uses contract balance | Uses contract balance |
| Amount Logic | Specify exact amounts | Uses 100% of both | Uses 100% of higher-value token |
| Price Awareness | No | No | Yes (requires price param) |
| Approval Needed | Yes (from sender) | No | No |
| Refunds | Yes (to sender) | No | No |
| Use Case | New deposits | Reusing all funds | Optimal capital efficiency |

## Price Parameter Format

The `wbtcPrice` parameter must be in USDC terms with 6 decimals:

```solidity
// Example: WBTC = $89,892
// Format: 89892 * 10^6 = 89,892,000,000
uint256 wbtcPrice = 89892000000;

// Calculation:
// If WBTC balance = 100000000 (1 WBTC with 8 decimals)
// wbtcValueUSD = (100000000 * 89892000000) / 1e8
//              = 89892000000 (USDC with 6 decimals)
//              = $89,892
```

## Error Cases

### No Tokens in Contract

```solidity
// Contract has 0 WBTC and 0 USDC
vm.expectRevert("No tokens in contract");
manager.addLiquidityFromContractPrioritized(wbtcPrice, tickLower, tickUpper);
```

### Not Owner

```solidity
vm.prank(notOwner);
vm.expectRevert(); // Ownable error
manager.addLiquidityFromContractPrioritized(wbtcPrice, tickLower, tickUpper);
```

### Invalid Price

```solidity
// Price = 0 will cause division issues
vm.expectRevert();
manager.addLiquidityFromContractPrioritized(0, tickLower, tickUpper);
```

## Important Notes

### ⚠️ Price Accuracy Critical

The function's decision depends entirely on the accuracy of the `wbtcPrice` parameter:
- Use a reliable oracle (Chainlink, Uniswap TWAP)
- Update price before each call
- Incorrect price leads to suboptimal allocation

### ⚠️ Unused Tokens

Due to the price ratio, Uniswap may not use all tokens:

```solidity
// Contract has: 1 WBTC ($89,892) + 100,000 USDC
// Price ratio might only need: 1 WBTC + 85,000 USDC

// After addLiquidityFromContractPrioritized():
// - 1 WBTC used ✓
// - 85,000 USDC used ✓
// - 15,000 USDC remains in contract 📦

// Retrieve unused USDC:
manager.emergencyWithdraw(USDC);
```

### ⚠️ No Slippage Protection

The function uses `amount0Min: 0` and `amount1Min: 0`:
- ✅ Will always succeed (no slippage revert)
- ❌ Vulnerable to sandwich attacks
- ⚠️ Use only in safe conditions (e.g., after fee collection)

### ⚠️ Overwrites currentTokenId

```solidity
currentTokenId = tokenId; // New position becomes "current"
```

## Gas Costs

Approximate gas costs (mainnet, 30 gwei):

| Operation | Gas Used | Cost @ 30 gwei |
|-----------|----------|----------------|
| Prioritized add (both tokens) | ~420,000 | $12.60 |
| Prioritized add (one token) | ~360,000 | $10.80 |

## Events Emitted

```solidity
event PositionCreated(
    uint256 indexed tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
);
```

## Oracle Integration Example

### Using Chainlink Price Feed

```solidity
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PositionManagerWithOracle {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // WBTC/USD price feed on Ethereum mainnet
        priceFeed = AggregatorV3Interface(
            0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
        );
    }

    function getCurrentWBTCPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // Chainlink returns 8 decimals, convert to 6 for USDC
        return uint256(price) / 100;
    }

    function addLiquidityWithOraclePrice(
        int24 tickLower,
        int24 tickUpper
    ) external {
        uint256 currentPrice = getCurrentWBTCPrice();
        manager.addLiquidityFromContractPrioritized(
            currentPrice,
            tickLower,
            tickUpper
        );
    }
}
```

## Use Cases

1. **Optimal Fee Compounding**: After collecting fees (usually imbalanced), use all of the higher-value token
2. **Capital Efficiency**: Maximize usage of your most valuable asset
3. **Imbalanced Deposits**: When contract receives more of one token than the other
4. **Dynamic Rebalancing**: Adapt to changing token balances over time

## Related Functions

- `createPosition()` - Create position from sender's tokens
- `addLiquidityFromContract()` - Add 100% of both tokens equally
- `collectFees()` - Collect fees into contract
- `emergencyWithdraw()` - Withdraw unused tokens
- `calculateTickRange()` - Calculate tick range

## Resources

- [PositionManager.sol](../src/PositionManager.sol) - Implementation
- [IPositionManager.sol](../src/IPositionManager.sol) - Interface
- [Uniswap V3 Docs](https://docs.uniswap.org/contracts/v3/overview)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)

# addLiquidityFromContract() Function

## Overview

The `addLiquidityFromContract()` function allows the PositionManager to create a new Uniswap V3 liquidity position using **100% of the tokens currently held by the contract**.

## Function Signature

```solidity
function addLiquidityFromContract(
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

2. **Approve Tokens**
   - Approves Uniswap Position Manager for full WBTC balance (if any)
   - Approves Uniswap Position Manager for full USDC balance (if any)

3. **Mint Position**
   - Creates new Uniswap V3 position with ALL available tokens
   - Uses specified tick range (tickLower, tickUpper)
   - Sets recipient as contract address
   - Sets slippage to 0 (amount0Min and amount1Min = 0)

4. **Store Position**
   - Stores NFT token ID in `currentTokenId`
   - Emits `PositionCreated` event

5. **Handle Unused Tokens**
   - Any tokens not used (due to price ratio) remain in contract
   - Can be withdrawn later via `emergencyWithdraw()`

## Key Features

### ✅ Uses 100% of Contract Balance

Unlike `createPosition()` which requires specifying amounts, this function automatically uses **all available tokens**:

```solidity
uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));

// Uses 100% of both balances
amount0Desired: wbtcBalance,
amount1Desired: usdcBalance,
```

### ✅ Flexible Token Requirements

Works with:
- ✅ Both WBTC and USDC
- ✅ Only WBTC (USDC = 0)
- ✅ Only USDC (WBTC = 0)
- ❌ Neither (reverts with "No tokens in contract")

### ✅ No Transfer Needed

Tokens must already be in the contract:
- Sent via regular transfer
- Accumulated from fees
- Remaining from previous operations

## Usage Examples

### Example 1: Add All Available Tokens

```solidity
// Assume contract has 0.5 WBTC and 25,000 USDC

// Calculate tick range for ±15%
int24 currentTick = 253320; // Example tick
(int24 tickLower, int24 tickUpper) = manager.calculateTickRange(currentTick);

// Add 100% of contract's tokens as liquidity
(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = 
    manager.addLiquidityFromContract(tickLower, tickUpper);

// Result: Uses ALL 0.5 WBTC and ALL 25,000 USDC (or as much as needed for ratio)
```

### Example 2: After Collecting Fees

```solidity
// Collect fees from existing position
manager.collectFees(existingTokenId);

// Fees now sit in the contract
// Add them as new liquidity position
(uint256 newTokenId, , , ) = manager.addLiquidityFromContract(
    tickLower,
    tickUpper
);
```

### Example 3: With Manual Token Transfer

```solidity
// Transfer tokens to contract first
IERC20(WBTC).transfer(address(manager), wbtcAmount);
IERC20(USDC).transfer(address(manager), usdcAmount);

// Then add as liquidity
manager.addLiquidityFromContract(tickLower, tickUpper);
```

## Comparison with createPosition()

| Feature | createPosition() | addLiquidityFromContract() |
|---------|------------------|----------------------------|
| Token Source | Transfers from msg.sender | Uses contract's balance |
| Amount Control | Specify exact amounts | Uses 100% of balance |
| Approval Needed | Yes (from sender) | No (contract self-approves) |
| Refunds | Yes (to sender) | No (stays in contract) |
| Use Case | New deposits | Reusing contract funds |

## Error Cases

### No Tokens in Contract

```solidity
// Contract has 0 WBTC and 0 USDC
vm.expectRevert("No tokens in contract");
manager.addLiquidityFromContract(tickLower, tickUpper);
```

### Not Owner

```solidity
vm.prank(notOwner);
vm.expectRevert(); // Ownable error
manager.addLiquidityFromContract(tickLower, tickUpper);
```

## Important Notes

### ⚠️ Unused Tokens

Due to the price ratio, Uniswap may not use all of both tokens:

```solidity
// Contract has: 1 WBTC + 50,000 USDC
// Price ratio might only need: 1 WBTC + 45,000 USDC

// After addLiquidityFromContract():
// - 1 WBTC used ✓
// - 45,000 USDC used ✓
// - 5,000 USDC remains in contract 📦

// Retrieve unused USDC:
manager.emergencyWithdraw(USDC);
```

### ⚠️ No Slippage Protection

The function uses `amount0Min: 0` and `amount1Min: 0`, meaning:
- ✅ Will always succeed (no slippage revert)
- ❌ Vulnerable to sandwich attacks
- ⚠️ Use only when safe (e.g., collected fees, not fresh deposits)

### ⚠️ Overwrites currentTokenId

Calling this function updates `currentTokenId`:
```solidity
currentTokenId = tokenId; // New position becomes "current"
```

Make sure this is intended behavior for your use case.

## Gas Costs

Approximate gas costs (mainnet, 30 gwei):

| Operation | Gas Used | Cost @ 30 gwei |
|-----------|----------|----------------|
| Add liquidity (both tokens) | ~400,000 | $12 |
| Add liquidity (one token) | ~350,000 | $10.50 |

## Events Emitted

```solidity
event PositionCreated(
    uint256 indexed tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
);
```

## Implementation Code

```solidity
function addLiquidityFromContract(
    int24 tickLower,
    int24 tickUpper
) external onlyOwner returns (
    uint256 tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
) {
    // Get 100% of contract's token balances
    uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
    uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));

    require(wbtcBalance > 0 || usdcBalance > 0, "No tokens in contract");

    // Approve position manager for all available tokens
    if (wbtcBalance > 0) {
        IERC20(wbtc).approve(address(positionManager), wbtcBalance);
    }
    if (usdcBalance > 0) {
        IERC20(usdc).approve(address(positionManager), usdcBalance);
    }

    // Mint position with all available tokens
    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
        token0: wbtc,
        token1: usdc,
        fee: feeTier,
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: wbtcBalance,
        amount1Desired: usdcBalance,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
    });

    (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);

    // Store position ID
    currentTokenId = tokenId;

    emit PositionCreated(tokenId, liquidity, amount0, amount1);

    // Note: Any unused tokens remain in contract
}
```

## Testing

```solidity
function testAddLiquidityFromContract() public {
    // Send tokens to contract
    deal(WBTC, address(manager), 1e8); // 1 WBTC
    deal(USDC, address(manager), 50000e6); // 50,000 USDC

    // Add liquidity
    (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = 
        manager.addLiquidityFromContract(tickLower, tickUpper);

    // Verify
    assertGt(tokenId, 0);
    assertGt(liquidity, 0);
    assertGt(amount0, 0);
    assertGt(amount1, 0);
}
```

## Related Functions

- `createPosition()` - Create position from sender's tokens
- `collectFees()` - Collect fees into contract
- `emergencyWithdraw()` - Withdraw unused tokens
- `calculateTickRange()` - Calculate tick range

## Use Cases

1. **Fee Compounding**: Collect fees and re-add as liquidity
2. **Batch Deposits**: Accumulate tokens, then add all at once
3. **Position Consolidation**: Combine multiple small amounts
4. **Recovery**: Add accidentally sent tokens as liquidity

## Resources

- [PositionManager.sol](./src/PositionManager.sol) - Implementation
- [IPositionManager.sol](./src/IPositionManager.sol) - Interface
- [Uniswap V3 Docs](https://docs.uniswap.org/contracts/v3/overview)

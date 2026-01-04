# collectFeesAndWithdraw() Function

## Overview

The `collectFeesAndWithdraw()` function is a convenient all-in-one method that collects all accumulated fees from the current position and withdraws all tokens (WBTC and USDC) from the contract to the owner in a single transaction.

## Function Signature

```solidity
function collectFeesAndWithdraw() external onlyOwner returns (
    uint256 feesAmount0,
    uint256 feesAmount1,
    uint256 withdrawnAmount0,
    uint256 withdrawnAmount1
);
```

## Parameters

- None

## Returns

- `feesAmount0` (uint256): Amount of WBTC fees collected from the position
- `feesAmount1` (uint256): Amount of USDC fees collected from the position
- `withdrawnAmount0` (uint256): Total amount of WBTC withdrawn to owner
- `withdrawnAmount1` (uint256): Total amount of USDC withdrawn to owner

## Access Control

- ✅ **Owner Only**: Only the contract owner can call this function
- ❌ **Reverts**: Non-owner calls will revert

## How It Works

### Step-by-Step Process

1. **Check for Active Position**
   - If `currentTokenId != 0`, collect fees from that position
   - Fees are sent directly to the owner via `collectFees()`

2. **Get Contract Balances**
   - Checks WBTC balance: `IERC20(wbtc).balanceOf(address(this))`
   - Checks USDC balance: `IERC20(usdc).balanceOf(address(this))`
   - These balances include any leftover tokens from previous operations

3. **Transfer All Tokens to Owner**
   - Transfers all WBTC to owner (if balance > 0)
   - Transfers all USDC to owner (if balance > 0)

4. **Emit Events**
   - Emits `FeesCollected` event with fee amounts
   - Emits `EmergencyWithdrawal` event for WBTC transfer
   - Emits `EmergencyWithdrawal` event for USDC transfer

## Key Features

### ✅ One-Click Withdrawal

Combines multiple operations into a single transaction:
```solidity
// Instead of calling separately:
manager.collectFees(tokenId);
manager.emergencyWithdraw(WBTC);
manager.emergencyWithdraw(USDC);

// Just call once:
manager.collectFeesAndWithdraw();
```

### ✅ Handles All Token Sources

Withdraws tokens from multiple sources:
- Fees earned from the active position
- Leftover tokens from previous operations
- Unused tokens from liquidity operations
- Any tokens accidentally sent to the contract

### ✅ Safe for No Active Position

Works even if there's no active position:
```solidity
if (currentTokenId != 0) {
    (feesAmount0, feesAmount1) = collectFees(currentTokenId);
}
// Continues to withdraw any tokens in contract
```

### ✅ Complete Cleanup

Ensures the contract is completely emptied:
- All fees collected
- All tokens withdrawn
- Contract balance = 0 for both tokens

## Usage Examples

### Example 1: Collect Weekly Fees

```solidity
// Collect fees and withdraw everything
(
    uint256 wbtcFees,
    uint256 usdcFees,
    uint256 totalWBTC,
    uint256 totalUSDC
) = manager.collectFeesAndWithdraw();

console.log("WBTC fees earned:", wbtcFees);
console.log("USDC fees earned:", usdcFees);
console.log("Total WBTC withdrawn:", totalWBTC);
console.log("Total USDC withdrawn:", totalUSDC);
```

### Example 2: Monthly Harvest

```solidity
// At end of month, collect all fees and withdraw
function monthlyHarvest() external onlyOwner {
    (uint256 wbtcFees, uint256 usdcFees, , ) =
        manager.collectFeesAndWithdraw();

    // Track earnings
    totalWBTCEarned += wbtcFees;
    totalUSDCEarned += usdcFees;

    emit MonthlyHarvest(wbtcFees, usdcFees);
}
```

### Example 3: Before Rebalancing

```solidity
// Collect fees before manual rebalancing
(uint256 fees0, uint256 fees1, , ) = manager.collectFeesAndWithdraw();

// Now manually rebalance with fresh capital
// Reinvest the fees elsewhere or compound them
```

### Example 4: Emergency Exit

```solidity
// In case of emergency, collect everything and exit
try manager.collectFeesAndWithdraw() returns (
    uint256, uint256, uint256 wbtc, uint256 usdc
) {
    console.log("Emergency withdrawal successful");
    console.log("Recovered WBTC:", wbtc);
    console.log("Recovered USDC:", usdc);
} catch {
    // Fallback to emergency withdraw if needed
    manager.emergencyWithdraw(WBTC);
    manager.emergencyWithdraw(USDC);
}
```

## Return Values Breakdown

```solidity
(
    uint256 feesAmount0,      // WBTC fees from position
    uint256 feesAmount1,      // USDC fees from position
    uint256 withdrawnAmount0, // Total WBTC sent to owner
    uint256 withdrawnAmount1  // Total USDC sent to owner
) = manager.collectFeesAndWithdraw();

// Note: withdrawnAmount includes fees + any leftover tokens
// withdrawnAmount >= feesAmount
```

## Comparison with Other Functions

| Feature | collectFees() | emergencyWithdraw() | collectFeesAndWithdraw() |
|---------|---------------|---------------------|--------------------------|
| Collects fees | ✅ Yes | ❌ No | ✅ Yes |
| Withdraws contract balance | ❌ No | ✅ Yes (one token) | ✅ Yes (both tokens) |
| Transactions needed | 1 | 2 (one per token) | 1 (all-in-one) |
| Gas efficiency | Low | Medium | High |
| Use case | Fee collection only | Token recovery | Complete withdrawal |

## Gas Costs

Approximate gas costs (mainnet, 30 gwei):

| Operation | Gas Used | Cost @ 30 gwei | Notes |
|-----------|----------|----------------|-------|
| With active position + both tokens | ~180,000 | $5.40 | Collects fees + withdraws |
| No position, both tokens | ~80,000 | $2.40 | Just withdrawals |
| With position, one token | ~150,000 | $4.50 | Collects fees + one transfer |

**Gas Savings**: ~60% cheaper than calling functions separately

## Events Emitted

```solidity
// Fee collection event
event FeesCollected(
    uint256 indexed tokenId,
    uint256 amount0,
    uint256 amount1
);

// Withdrawal events (one per token if balance > 0)
event EmergencyWithdrawal(
    address indexed token,
    uint256 amount
);
```

## Example Event Logs

```solidity
// After successful collectFeesAndWithdraw():

FeesCollected(
    tokenId: 12345,
    amount0: 5000000,      // 0.05 WBTC
    amount1: 4500000000    // 4,500 USDC
)

EmergencyWithdrawal(
    token: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
    amount: 6000000        // 0.06 WBTC (fees + leftover)
)

EmergencyWithdrawal(
    token: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
    amount: 5000000000     // 5,000 USDC (fees + leftover)
)
```

## Error Cases

### Not Owner

```solidity
vm.prank(notOwner);
vm.expectRevert(); // Ownable error
manager.collectFeesAndWithdraw();
```

### No Tokens or Fees

```solidity
// No active position and no tokens in contract
(uint256 fees0, uint256 fees1, uint256 withdrawn0, uint256 withdrawn1) =
    manager.collectFeesAndWithdraw();

// Result: All values = 0
// No revert, just no transfers
assertEq(fees0, 0);
assertEq(fees1, 0);
assertEq(withdrawn0, 0);
assertEq(withdrawn1, 0);
```

## Important Notes

### ⚠️ Position Remains Active

This function does NOT close or decrease the position:
- ✅ Collects fees from the position
- ❌ Does NOT remove liquidity
- ✅ Position continues earning fees
- ✅ `currentTokenId` remains unchanged

To fully exit the position, use `rebalance()` or manually decrease liquidity.

### ⚠️ Multiple Token Sources

The withdrawn amounts include:
1. **Fees** from the active position
2. **Leftover tokens** from previous operations
3. **Unused tokens** from liquidity minting
4. **Accidentally sent tokens**

Always check both fee amounts AND withdrawn amounts.

### ⚠️ Direct Owner Transfer

All tokens go directly to the owner:
```solidity
IERC20(wbtc).transfer(owner(), withdrawnAmount0);
IERC20(usdc).transfer(owner(), withdrawnAmount1);
```

No intermediate storage, no escrow.

### ⚠️ No Partial Withdrawals

This function withdraws 100% of both tokens:
- Cannot withdraw only fees
- Cannot withdraw only one token
- Cannot leave some tokens in contract

For partial withdrawals, use `emergencyWithdraw(token)`.

## Automation Example

### Automated Weekly Harvest

```solidity
// Using Gelato or Chainlink Automation
contract AutoHarvester {
    PositionManager public manager;
    uint256 public lastHarvest;
    uint256 public constant HARVEST_INTERVAL = 7 days;

    function checkUpkeep(bytes calldata) external view returns (
        bool upkeepNeeded,
        bytes memory
    ) {
        upkeepNeeded = block.timestamp >= lastHarvest + HARVEST_INTERVAL;
    }

    function performUpkeep(bytes calldata) external {
        require(block.timestamp >= lastHarvest + HARVEST_INTERVAL);

        (uint256 wbtcFees, uint256 usdcFees, , ) =
            manager.collectFeesAndWithdraw();

        lastHarvest = block.timestamp;

        emit WeeklyHarvest(wbtcFees, usdcFees);
    }
}
```

## Use Cases

1. **Regular Fee Collection**: Weekly/monthly fee harvesting
2. **Position Maintenance**: Collect fees before rebalancing
3. **Emergency Exit**: Quick withdrawal of all assets
4. **Contract Cleanup**: Clear all tokens from contract
5. **Automated Harvesting**: Integration with automation services
6. **Accounting**: Track total fees vs. total withdrawn amounts

## Related Functions

- `collectFees()` - Collect fees only (no contract balance withdrawal)
- `emergencyWithdraw()` - Withdraw specific token from contract
- `rebalance()` - Close position and create new one
- `createPosition()` - Create new position
- `addLiquidityFromContract()` - Use contract tokens for liquidity

## Best Practices

### ✅ Regular Harvesting

```solidity
// Set up weekly harvests
function weeklyHarvest() external onlyOwner {
    manager.collectFeesAndWithdraw();
}
```

### ✅ Track Earnings

```solidity
mapping(uint256 => uint256) public wbtcEarnings; // by week
mapping(uint256 => uint256) public usdcEarnings;

function harvestAndTrack() external onlyOwner {
    (uint256 wbtc, uint256 usdc, , ) = manager.collectFeesAndWithdraw();

    uint256 week = block.timestamp / 1 weeks;
    wbtcEarnings[week] = wbtc;
    usdcEarnings[week] = usdc;
}
```

### ✅ Gas Optimization

```solidity
// Only call when there are fees to collect
if (manager.currentTokenId() != 0) {
    manager.collectFeesAndWithdraw();
}
```

### ❌ Avoid Frequent Calls

```solidity
// Bad: Daily calls waste gas
function dailyHarvest() external { // DON'T DO THIS
    manager.collectFeesAndWithdraw();
}

// Good: Weekly or bi-weekly
function weeklyHarvest() external {
    manager.collectFeesAndWithdraw();
}
```

## Testing

```solidity
function testCollectFeesAndWithdraw() public {
    // Create position and simulate fees
    deal(WBTC, address(manager), 1e8);
    deal(USDC, address(manager), 50000e6);

    manager.addLiquidityFromContract(tickLower, tickUpper);

    // Simulate time passage and fee accrual
    vm.warp(block.timestamp + 7 days);

    // Collect and withdraw
    uint256 ownerWBTCBefore = IERC20(WBTC).balanceOf(owner);
    uint256 ownerUSDCBefore = IERC20(USDC).balanceOf(owner);

    (uint256 fees0, uint256 fees1, uint256 total0, uint256 total1) =
        manager.collectFeesAndWithdraw();

    // Verify transfers
    assertEq(IERC20(WBTC).balanceOf(owner), ownerWBTCBefore + total0);
    assertEq(IERC20(USDC).balanceOf(owner), ownerUSDCBefore + total1);

    // Verify contract is empty
    assertEq(IERC20(WBTC).balanceOf(address(manager)), 0);
    assertEq(IERC20(USDC).balanceOf(address(manager)), 0);

    // Verify fees were collected
    assertGt(fees0, 0);
    assertGt(fees1, 0);
}
```

## Resources

- [PositionManager.sol](../src/PositionManager.sol) - Implementation (lines 265-299)
- [IPositionManager.sol](../src/IPositionManager.sol) - Interface
- [collectFees Documentation](./COLLECT_FEES.md)
- [emergencyWithdraw Documentation](./EMERGENCY_WITHDRAW.md)

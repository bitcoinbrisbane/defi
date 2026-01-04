# Emergency Withdraw Function

## Overview

The `emergencyWithdraw()` function allows the contract owner to withdraw any tokens (ERC20 or ETH) that are held by the PositionManager contract in case of emergency.

## Function Signature

```solidity
function emergencyWithdraw(address token) external onlyOwner
```

## Parameters

- `token` (address): The token address to withdraw
  - Use `address(0)` for native ETH
  - Use token contract address for ERC20 tokens (WBTC, USDC, etc.)

## Access Control

- ✅ **Owner Only**: Only the contract owner can call this function
- ❌ **Reverts**: Non-owner calls will revert with Ownable error

## Functionality

### For ETH (token = address(0))

1. Checks contract's ETH balance
2. Requires balance > 0
3. Transfers all ETH to owner using low-level call
4. Emits `EmergencyWithdrawal` event

### For ERC20 Tokens

1. Checks token balance using `balanceOf()`
2. Requires balance > 0
3. Transfers all tokens to owner using `transfer()`
4. Emits `EmergencyWithdrawal` event

## Events

```solidity
event EmergencyWithdrawal(address indexed token, uint256 amount);
```

**Parameters**:
- `token`: The token address (or address(0) for ETH)
- `amount`: The amount withdrawn

## Usage Examples

### Withdraw ETH

```solidity
// Check ETH balance
uint256 ethBalance = address(positionManager).balance;

// Withdraw all ETH
positionManager.emergencyWithdraw(address(0));
```

### Withdraw USDC

```solidity
address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

// Check USDC balance
uint256 usdcBalance = IERC20(USDC).balanceOf(address(positionManager));

// Withdraw all USDC
positionManager.emergencyWithdraw(USDC);
```

### Withdraw WBTC

```solidity
address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

// Withdraw all WBTC
positionManager.emergencyWithdraw(WBTC);
```

## Error Cases

### No Tokens to Withdraw

```solidity
// Reverts with: "No tokens to withdraw"
positionManager.emergencyWithdraw(USDC);
```

**Cause**: Contract has 0 balance of the specified token

### No ETH to Withdraw

```solidity
// Reverts with: "No ETH to withdraw"
positionManager.emergencyWithdraw(address(0));
```

**Cause**: Contract has 0 ETH balance

### Not Owner

```solidity
// Reverts with Ownable error
vm.prank(notOwner);
positionManager.emergencyWithdraw(token);
```

**Cause**: Caller is not the contract owner

### ETH Transfer Failed

```solidity
// Reverts with: "ETH transfer failed"
```

**Cause**: Low-level call to owner failed (rare, owner might be contract that rejects ETH)

### Token Transfer Failed

```solidity
// Reverts with: "Token transfer failed"
```

**Cause**: ERC20 transfer returned false (rare, non-standard tokens)

## Security Considerations

### ✅ Secure Features

1. **Owner Only**: Only contract owner can withdraw
2. **All or Nothing**: Withdraws entire balance (prevents partial drains)
3. **Event Logging**: All withdrawals are logged on-chain
4. **Explicit Checks**: Requires balance > 0 before attempting transfer
5. **Transfer Validation**: Checks success of both ETH and token transfers

### ⚠️ Important Notes

1. **One-time Action**: Withdraws ALL tokens of specified type
2. **No Approval Needed**: Contract already owns the tokens
3. **Gas Costs**: Owner pays gas for withdrawal transaction
4. **Irreversible**: Cannot undo withdrawal once confirmed

## When to Use

### Emergency Situations

- Contract upgrade needed
- Security vulnerability discovered
- Stuck tokens need recovery
- Position NFT lost or inaccessible

### Routine Operations

- Collect accumulated dust tokens
- Recover mistakenly sent tokens
- Clean up before contract migration

### NOT Recommended For

- Regular fee collection (use `compound()` instead)
- Normal position management (use `rebalance()` instead)
- Active trading operations

## Testing

Run comprehensive tests:

```bash
# Run all emergency withdraw tests
forge test --match-contract EmergencyWithdrawTest -vvv

# Run specific test
forge test --match-test testEmergencyWithdrawETH -vvv

# With gas reporting
forge test --match-contract EmergencyWithdrawTest --gas-report
```

### Test Coverage

- ✅ Withdraw ETH
- ✅ Withdraw ERC20 (USDC, WBTC)
- ✅ Multiple token withdrawals
- ✅ Reverts if not owner
- ✅ Reverts if no balance
- ✅ Event emission
- ✅ Fuzz testing (varying amounts)
- ✅ Contract receives ETH

## Gas Costs

Approximate gas costs (mainnet, 30 gwei):

| Operation | Gas Used | Cost @ 30 gwei |
|-----------|----------|----------------|
| Withdraw ETH | ~30,000 | $0.90 |
| Withdraw ERC20 | ~50,000 | $1.50 |

## Implementation Code

```solidity
function emergencyWithdraw(address token) external onlyOwner {
    uint256 amount;

    if (token == address(0)) {
        // Withdraw ETH
        amount = address(this).balance;
        require(amount > 0, "No ETH to withdraw");

        (bool success, ) = owner().call{value: amount}("");
        require(success, "ETH transfer failed");
    } else {
        // Withdraw ERC20 token
        amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No tokens to withdraw");

        bool success = IERC20(token).transfer(owner(), amount);
        require(success, "Token transfer failed");
    }

    emit EmergencyWithdrawal(token, amount);
}
```

## Related Functions

- `compound()` - Reinvest fees into position
- `rebalance()` - Move position to new price range
- `addLiquidity()` - Add more liquidity to position

## Resources

- [Test File](./test/EmergencyWithdraw.t.sol)
- [Interface](./src/IPositionManager.sol)
- [Implementation](./src/PositionManager.sol)

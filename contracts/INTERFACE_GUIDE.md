# IPositionManager Interface Guide

This guide explains the interface abstraction for the PositionManager contract.

## Why Use an Interface?

1. **Abstraction** - Separates contract specification from implementation
2. **Upgradability** - Allows different implementations of the same interface
3. **Testing** - Easy to create mocks and test contracts
4. **Documentation** - Interface serves as a clear API contract
5. **Integration** - Other contracts can interact without knowing implementation details

## Interface Overview

The `IPositionManager` interface defines:
- All public/external functions
- Events
- Structs
- Function signatures and return types

## Complete Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPositionManager {
    // Structs
    struct PoolInfo {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    // Events
    event LiquidityAdded(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionRebalanced(uint256 indexed oldTokenId, uint256 indexed newTokenId);
    event FeesCompounded(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    event RangeUpdated(int24 newRangePercent);

    // Functions
    function addLiquidity(...) external returns (...);
    function underlying(...) external view returns (...);
    function getPools() external view returns (PoolInfo[] memory);
    function emergencyWithdraw(address token) external;
    function rebalance(...) external returns (uint256 newTokenId);
    function compound(uint256 tokenId) external returns (uint128 liquidity);
    function calculateTickRange(...) external view returns (...);
    function updateRange(int24 newRangePercent) external;
}
```

## Using the Interface

### 1. In External Contracts

```solidity
import "./IPositionManager.sol";

contract LiquidityBot {
    IPositionManager public manager;

    constructor(address _manager) {
        manager = IPositionManager(_manager);
    }

    function autoRebalance(int24 currentTick) external {
        // Use interface without knowing implementation
        (int24 lower, int24 upper) = manager.calculateTickRange(currentTick);
        manager.rebalance(lower, upper);
    }
}
```

### 2. In Tests

```solidity
import "./IPositionManager.sol";

contract PositionManagerTest is Test {
    IPositionManager public manager;

    function setUp() public {
        // Can test against interface
        manager = IPositionManager(address(new PositionManager(...)));
    }

    function testRebalance() public {
        uint256 newTokenId = manager.rebalance(tickLower, tickUpper);
        assertGt(newTokenId, 0);
    }
}
```

### 3. For Mocking

```solidity
contract MockPositionManager is IPositionManager {
    // Implement only what you need for testing
    function addLiquidity(...) external returns (...) {
        // Mock implementation
        return (1, 1000, 100, 100);
    }
    
    // ... other required functions
}
```

## Implementation Pattern

The PositionManager contract implements the interface:

```solidity
contract PositionManager is IPositionManager, IERC721Receiver, Ownable {
    // Implementation
}
```

This ensures the contract:
- ✅ Implements all required functions
- ✅ Matches function signatures exactly
- ✅ Emits specified events
- ✅ Is compatible with any code using IPositionManager

## Benefits

### Compile-Time Checking
If PositionManager doesn't implement all interface functions, compilation fails.

### Type Safety
Function signatures must match exactly:
```solidity
// ❌ Wrong - won't compile
function addLiquidity(uint256 x) external returns (uint256) { }

// ✅ Correct - matches interface
function addLiquidity(
    uint256 amount0Desired,
    uint256 amount1Desired,
    int24 tickLower,
    int24 tickUpper
) external returns (
    uint256 tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
) { }
```

### Documentation
The interface serves as living documentation:
```solidity
/// @notice Add liquidity to create or increase a position
/// @param amount0Desired Amount of token0 (WBTC) to add
/// @param amount1Desired Amount of token1 (USDC) to add
/// @param tickLower Lower tick of the range
/// @param tickUpper Upper tick of the range
/// @return tokenId The NFT token ID of the position
function addLiquidity(...) external returns (...);
```

## Advanced Usage

### Multiple Implementations

You can have different implementations of the same interface:

```solidity
// Conservative strategy
contract ConservativePositionManager is IPositionManager {
    // Wide ranges, less frequent rebalancing
}

// Aggressive strategy
contract AggressivePositionManager is IPositionManager {
    // Tight ranges, frequent rebalancing
}

// Both can be used interchangeably
IPositionManager manager = useConservative 
    ? IPositionManager(address(conservative))
    : IPositionManager(address(aggressive));
```

### Factory Pattern

```solidity
contract PositionManagerFactory {
    function createManager(
        address wbtc,
        address usdc,
        uint24 feeTier
    ) external returns (IPositionManager) {
        return IPositionManager(
            address(new PositionManager(wbtc, usdc, feeTier))
        );
    }
}
```

## Best Practices

1. **Keep Interfaces Minimal** - Only include essential public functions
2. **Document Thoroughly** - Use NatSpec comments for all functions
3. **Version Carefully** - Interface changes can break integrations
4. **Event Definitions** - Include all events that external contracts might listen for
5. **Struct Definitions** - Define structs in interface if returned by functions

## Next Steps

1. Implement stubbed functions in `PositionManager.sol`
2. Write comprehensive tests using the interface
3. Create additional implementations if needed
4. Document integration examples

## Resources

- [Solidity Interfaces](https://docs.soliditylang.org/en/latest/contracts.html#interfaces)
- [IPositionManager.sol](./src/IPositionManager.sol)
- [PositionManager.sol](./src/PositionManager.sol)
- [PositionManagerExample.sol](./src/examples/PositionManagerExample.sol)

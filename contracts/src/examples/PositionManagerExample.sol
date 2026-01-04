// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IPositionManager.sol";

/// @title Position Manager Example
/// @notice Example contract showing how to interact with PositionManager via interface
/// @dev This demonstrates the abstraction provided by IPositionManager
contract PositionManagerExample {
    IPositionManager public positionManager;

    constructor(address _positionManager) {
        positionManager = IPositionManager(_positionManager);
    }

    /// @notice Example: Add liquidity using the interface
    function exampleAddLiquidity(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) external returns (uint256 tokenId) {
        // The caller would interact through the abstracted interface
        // without needing to know implementation details
        (tokenId, , , ) = positionManager.addLiquidity(
            amount0,
            amount1,
            tickLower,
            tickUpper
        );
    }

    /// @notice Example: Rebalance a position
    function exampleRebalance() external returns (uint256 newTokenId) {
        // Rebalance through the interface - automatically uses current price
        newTokenId = positionManager.rebalance();
    }

    /// @notice Example: Compound fees
    function exampleCompound() external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        (tokenId, liquidity, amount0, amount1) = positionManager.compound();
    }

    /// @notice Example: Get all pools
    function exampleGetPools() external view returns (IPositionManager.PoolInfo[] memory) {
        return positionManager.getPools();
    }

    /// @notice Example: Update range percentage
    function exampleUpdateRange(int24 newRange) external {
        positionManager.updateRange(newRange);
    }
}

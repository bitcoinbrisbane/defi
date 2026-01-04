// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IPositionManager Interface
/// @notice Interface for managing Uniswap V3 concentrated liquidity positions
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

    struct PositionInfo {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    // Events
    event LiquidityAdded(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionCreated(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionRebalanced(uint256 indexed oldTokenId, uint256 indexed newTokenId);
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event FeesCompounded(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    event RangeUpdated(int24 newRangePercent);

    // Core Position Management Functions

    /// @notice Create a new concentrated liquidity position
    /// @param amount0Desired Amount of token0 (WBTC) to add
    /// @param amount1Desired Amount of token1 (USDC) to add
    /// @param tickLower Lower tick of the range
    /// @param tickUpper Upper tick of the range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
    function createPosition(
        uint256 amount0Desired,
        uint256 amount1Desired,
        int24 tickLower,
        int24 tickUpper
    ) external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Add liquidity to create or increase a position
    /// @param amount0Desired Amount of token0 (WBTC) to add
    /// @param amount1Desired Amount of token1 (USDC) to add
    /// @param tickLower Lower tick of the range
    /// @param tickUpper Upper tick of the range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
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
    );

    /// @notice Add liquidity using contract's own token balance
    /// @dev Uses 100% of available WBTC and USDC in the contract
    /// @dev Automatically fetches current tick from pool and calculates range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
    function addLiquidityFromContract() external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Add liquidity using 100% of the token with greater USD value
    /// @dev Prioritizes the token with higher value, uses all available amount of that token
    /// @param wbtcPrice Current WBTC price in USDC (with 6 decimals, e.g., 89892000000 for $89,892)
    /// @param tickLower Lower tick of the range
    /// @param tickUpper Upper tick of the range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
    function addLiquidityFromContractPrioritized(
        uint256 wbtcPrice,
        int24 tickLower,
        int24 tickUpper
    ) external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Collect accumulated fees from the position
    /// @param tokenId The position NFT token ID
    /// @return amount0 Amount of token0 fees collected
    /// @return amount1 Amount of token1 fees collected
    function collectFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collect all fees and withdraw all tokens from contract to owner
    /// @dev Collects fees from current position, then withdraws all WBTC and USDC in contract
    /// @return feesAmount0 Amount of WBTC fees collected from position
    /// @return feesAmount1 Amount of USDC fees collected from position
    /// @return withdrawnAmount0 Total amount of WBTC withdrawn to owner
    /// @return withdrawnAmount1 Total amount of USDC withdrawn to owner
    function collectFeesAndWithdraw() external returns (
        uint256 feesAmount0,
        uint256 feesAmount1,
        uint256 withdrawnAmount0,
        uint256 withdrawnAmount1
    );

    /// @notice Rebalance position when price moves out of range
    /// @dev Automatically fetches current tick from pool and calculates range
    /// @return newTokenId The new position NFT token ID
    function rebalance() external returns (uint256 newTokenId);

    /// @notice Compound accumulated fees back into the position
    /// @param tokenId The position NFT token ID to compound
    /// @return liquidity Amount of new liquidity added from fees
    function compound(uint256 tokenId) external returns (uint128 liquidity);

    // View Functions

    /// @notice Get token A (WBTC)
    /// @return WBTC token interface
    function tokenA() external view returns (IERC20);

    /// @notice Get token B (USDC)
    /// @return USDC token interface
    function tokenB() external view returns (IERC20);

    /// @notice Get contract's current token balances
    /// @return amount0 WBTC balance in contract
    /// @return amount1 USDC balance in contract
    function balance() external view returns (uint256 amount0, uint256 amount1);

    /// @notice Get the pool name
    /// @return Pool name in format "Pool {tokenA.name} {tokenB.name}"
    function name() external view returns (string memory);

    /// @notice Get the underlying token balances for a position
    /// @param tokenId The position NFT token ID
    /// @return amount0 Amount of token0 (WBTC) in the position
    /// @return amount1 Amount of token1 (USDC) in the position
    function underlying(uint256 tokenId) external view returns (
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Get detailed information about a position
    /// @param tokenId The position NFT token ID
    /// @return Position information struct
    function getPositionInfo(uint256 tokenId) external view returns (PositionInfo memory);

    /// @notice Get information about all pools managed by this contract
    /// @return pools Array of pool information
    function getPools() external view returns (PoolInfo[] memory pools);

    /// @notice Calculate tick range for current price ± rangePercent
    /// @param currentTick The current pool tick
    /// @return tickLower Lower bound tick
    /// @return tickUpper Upper bound tick
    function calculateTickRange(int24 currentTick) external view returns (int24 tickLower, int24 tickUpper);

    // Configuration Functions

    /// @notice Update range percentage
    /// @param newRangePercent New range (e.g., 15 for ±15%)
    function updateRange(int24 newRangePercent) external;

    /// @notice Emergency withdraw tokens from the contract
    /// @param token Token address to withdraw (use address(0) for ETH)
    function emergencyWithdraw(address token) external;
}

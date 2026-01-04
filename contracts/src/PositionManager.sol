// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPositionManager.sol";

/// @title Uniswap V3 Position Manager for WBTC/USDC
/// @notice Manages concentrated liquidity positions with automated rebalancing
/// @dev Interacts with Uniswap V3 NonfungiblePositionManager
contract PositionManager is IPositionManager, IERC721Receiver, Ownable {
    // Uniswap V3 interfaces
    INonfungiblePositionManager public immutable POSITION_MANAGER;

    // Pool configuration
    address private immutable WBTC;
    address private immutable USDC;
    uint24 public immutable FEE_TIER; // 3000 = 0.30%

    // Position parameters
    uint256 public currentTokenId;
    int24 public rangePercent; // 15 = ±15%

    address private immutable _self;

    function tokenA() external view returns(IERC20) {
        return IERC20(WBTC);
    }

    function tokenB() external view returns(IERC20) {
        return IERC20(USDC);
    }

    function balance(address token) external view (uint256) {
        return IERC20(token).balanceOf(_self);
    }

    constructor(
        address _positionManager,
        address _wbtc,
        address _usdc,
        uint24 _feeTier,
        int24 _rangePercent
    ) Ownable(msg.sender) {
        POSITION_MANAGER = INonfungiblePositionManager(_positionManager);
        WBTC = _wbtc;
        USDC = _usdc;
        FEE_TIER = _feeTier;
        rangePercent = _rangePercent;
        _self = address(this);
    }

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
    ) external onlyOwner returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // TODO: Implement liquidity addition
        // 1. Transfer tokens from sender
        // 2. Approve position manager
        // 3. Mint new position or increase existing
        // 4. Refund unused tokens
        // 5. Emit event

        revert("Not implemented");
    }

    /// @notice Get the underlying token balances for a position
    /// @param tokenId The position NFT token ID
    /// @return amount0 Amount of token0 (WBTC) in the position
    /// @return amount1 Amount of token1 (USDC) in the position
    function underlying(uint256 tokenId) external view returns (
        uint256 amount0,
        uint256 amount1
    ) {
        // TODO: Implement underlying calculation
        // 1. Get position info from position manager
        // 2. Calculate token amounts from liquidity and ticks
        // 3. Return token amounts

        revert("Not implemented");
    }

    /// @notice Get information about all pools managed by this contract
    /// @return pools Array of pool information
    function getPools() external view returns (PoolInfo[] memory pools) {
        // TODO: Implement pool information retrieval
        // 1. Query position manager for all positions owned by this contract
        // 2. Build array of pool info structs
        // 3. Return pools array

        revert("Not implemented");
    }

    /// @notice Emergency withdraw tokens from the contract
    /// @param token Token address to withdraw (use address(0) for ETH)
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

    /// @notice Rebalance position when price moves out of range
    /// @param newTickLower Lower tick for new position
    /// @param newTickUpper Upper tick for new position
    /// @return newTokenId The new position NFT token ID
    function rebalance(
        int24 newTickLower,
        int24 newTickUpper
    ) external onlyOwner returns (uint256 newTokenId) {
        // TODO: Implement rebalancing
        // 1. Collect fees from current position
        // 2. Decrease liquidity to 0 (withdraw all)
        // 3. Burn old position NFT
        // 4. Create new position at new price range
        // 5. Update currentTokenId
        // 6. Emit event

        revert("Not implemented");
    }

    /// @notice Compound accumulated fees back into the position
    /// @param tokenId The position NFT token ID to compound
    /// @return liquidity Amount of new liquidity added from fees
    function compound(uint256 tokenId) external onlyOwner returns (uint128 liquidity) {
        // TODO: Implement fee compounding
        // 1. Collect fees from position
        // 2. Get position info (tickLower, tickUpper)
        // 3. Add collected fees back as liquidity
        // 4. Emit event

        revert("Not implemented");
    }

    /// @notice Calculate tick range for current price ± rangePercent
    /// @param currentTick The current pool tick
    /// @return tickLower Lower bound tick
    /// @return tickUpper Upper bound tick
    function calculateTickRange(int24 currentTick) public view returns (int24 tickLower, int24 tickUpper) {
        // Calculate tick spacing (for 0.30% pool = 60)
        int24 tickSpacing = 60;

        // Calculate range in ticks (approximate)
        // For ±15%: log(1.15) / log(1.0001) ≈ 1398 ticks
        int24 tickRange = (int24(uint24(rangePercent)) * 1398) / 15;

        // Round to nearest tick spacing
        tickLower = ((currentTick - tickRange) / tickSpacing) * tickSpacing;
        tickUpper = ((currentTick + tickRange) / tickSpacing) * tickSpacing;
    }

    /// @notice Update range percentage
    /// @param newRangePercent New range (e.g., 15 for ±15%)
    function updateRange(int24 newRangePercent) external onlyOwner {
        require(newRangePercent > 0 && newRangePercent <= 100, "Invalid range");
        rangePercent = newRangePercent;
        emit RangeUpdated(newRangePercent);
    }

    /// @notice Required for receiving NFT positions
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Fallback to receive ETH
    receive() external payable {}
}

// Minimal interfaces for Uniswap V3
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function mint(MintParams calldata params) external payable returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    function increaseLiquidity(IncreaseLiquidityParams calldata params) external payable returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    function collect(CollectParams calldata params) external payable returns (
        uint256 amount0,
        uint256 amount1
    );

    function decreaseLiquidity(DecreaseLiquidityParams calldata params) external payable returns (
        uint256 amount0,
        uint256 amount1
    );

    function burn(uint256 tokenId) external payable;

    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
}

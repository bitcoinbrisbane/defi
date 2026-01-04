// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Uniswap V3 Position Manager for WBTC/USDC
/// @notice Manages concentrated liquidity positions with automated rebalancing
/// @dev Interacts with Uniswap V3 NonfungiblePositionManager
contract PositionManager is IERC721Receiver, Ownable {
    // Uniswap V3 interfaces
    INonfungiblePositionManager public immutable positionManager;

    // Pool configuration
    address public immutable wbtc;
    address public immutable usdc;
    uint24 public immutable feeTier; // 3000 = 0.30%

    // Position parameters
    uint256 public currentTokenId;
    int24 public rangePercent; // 15 = ±15%

    // Events
    event PositionCreated(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionRebalanced(uint256 indexed oldTokenId, uint256 indexed newTokenId);
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event RangeUpdated(int24 newRangePercent);

    // Structs
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

    constructor(
        address _positionManager,
        address _wbtc,
        address _usdc,
        uint24 _feeTier,
        int24 _rangePercent
    ) Ownable(msg.sender) {
        positionManager = INonfungiblePositionManager(_positionManager);
        wbtc = _wbtc;
        usdc = _usdc;
        feeTier = _feeTier;
        rangePercent = _rangePercent;
    }

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
    ) external onlyOwner returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Transfer tokens from sender
        IERC20(wbtc).transferFrom(msg.sender, address(this), amount0Desired);
        IERC20(usdc).transferFrom(msg.sender, address(this), amount1Desired);

        // Approve position manager
        IERC20(wbtc).approve(address(positionManager), amount0Desired);
        IERC20(usdc).approve(address(positionManager), amount1Desired);

        // Mint position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: wbtc,
            token1: usdc,
            fee: feeTier,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);

        // Store position ID
        currentTokenId = tokenId;

        // Refund any unused tokens
        if (amount0 < amount0Desired) {
            IERC20(wbtc).transfer(msg.sender, amount0Desired - amount0);
        }
        if (amount1 < amount1Desired) {
            IERC20(usdc).transfer(msg.sender, amount1Desired - amount1);
        }

        emit PositionCreated(tokenId, liquidity, amount0, amount1);
    }

    /// @notice Add liquidity using contract's own token balance
    /// @dev Uses 100% of available WBTC and USDC in the contract
    /// @param tickLower Lower tick of the range
    /// @param tickUpper Upper tick of the range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
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

        // Note: Any unused tokens remain in contract (due to price ratio)
        // They can be withdrawn via emergencyWithdraw if needed
    }

    /// @notice Collect accumulated fees from the position
    /// @param tokenId The position NFT token ID
    /// @return amount0 Amount of token0 fees collected
    /// @return amount1 Amount of token1 fees collected
    function collectFees(uint256 tokenId) public onlyOwner returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: owner(),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (amount0, amount1) = positionManager.collect(params);

        emit FeesCollected(tokenId, amount0, amount1);
    }

    /// @notice Close existing position and create a new one at current price
    /// @param newTickLower Lower tick for new position
    /// @param newTickUpper Upper tick for new position
    /// @return newTokenId The new position NFT token ID
    function rebalance(
        int24 newTickLower,
        int24 newTickUpper
    ) external onlyOwner returns (uint256 newTokenId) {
        uint256 oldTokenId = currentTokenId;
        require(oldTokenId != 0, "No active position");

        // Collect fees first
        collectFees(oldTokenId);

        // Decrease liquidity to 0 (withdraw all)
        PositionInfo memory posInfo = getPositionInfo(oldTokenId);

        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: oldTokenId,
                liquidity: posInfo.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        positionManager.decreaseLiquidity(decreaseParams);

        // Collect withdrawn liquidity
        (uint256 amount0, uint256 amount1) = collectFees(oldTokenId);

        // Burn old NFT
        positionManager.burn(oldTokenId);

        // Create new position with withdrawn amounts
        (newTokenId, , , ) = this.createPosition(amount0, amount1, newTickLower, newTickUpper);

        emit PositionRebalanced(oldTokenId, newTokenId);
    }

    /// @notice Get detailed information about a position
    /// @param tokenId The position NFT token ID
    /// @return Position information struct
    function getPositionInfo(uint256 tokenId) public view returns (PositionInfo memory) {
        (
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
        ) = positionManager.positions(tokenId);

        return PositionInfo({
            nonce: nonce,
            operator: operator,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1
        });
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

    /// @notice Emergency withdraw tokens
    /// @param token Token address to withdraw
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner(), balance);
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

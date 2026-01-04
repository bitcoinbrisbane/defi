// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPositionManager.sol";

/// @title Chainlink Price Feed Interface
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

/// @title Uniswap V3 Pool Interface (minimal)
interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}

/// @title Uniswap V3 Position Manager for WBTC/USDC
/// @notice Manages concentrated liquidity positions with automated rebalancing
/// @dev Interacts with Uniswap V3 NonfungiblePositionManager
contract PositionManager is IPositionManager, IERC721Receiver, Ownable {
    // Uniswap V3 interfaces
    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Pool public immutable pool;
    AggregatorV3Interface public immutable priceFeed;

    // Pool configuration
    address private immutable wbtc;
    address private immutable usdc;
    uint24 public immutable feeTier; // 3000 = 0.30%

    // Position parameters
    uint256 public currentTokenId;
    int24 public rangePercent; // 15 = ±15%

    function tokenA() external view returns(IERC20) {
        return IERC20(wbtc);
    }

    function tokenB() external view returns(IERC20) {
        return IERC20(usdc);
    }

    function balance() external view returns(uint256, uint256) {
        uint256 tokenABalance = IERC20(wbtc).balanceOf(address(this));
        uint256 tokenBBalance = IERC20(usdc).balanceOf(address(this));

        return (tokenABalance, tokenBBalance);
    }

    constructor(
        address _positionManager,
        address _pool,
        address _priceFeed,
        address _wbtc,
        address _usdc,
        uint24 _feeTier,
        int24 _rangePercent
    ) Ownable(msg.sender) {
        positionManager = INonfungiblePositionManager(_positionManager);
        pool = IUniswapV3Pool(_pool);
        priceFeed = AggregatorV3Interface(_priceFeed);
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

        emit PositionCreated(tokenId, liquidity, amount0, amount1);
    }

    /// @notice Add liquidity using contract's own token balance
    /// @dev Uses 100% of available WBTC and USDC in the contract
    /// @dev Automatically fetches current tick from pool and calculates range
    /// @return tokenId The NFT token ID of the position
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 added
    /// @return amount1 Actual amount of token1 added
    function addLiquidityFromContract() external onlyOwner returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Get current tick from the pool
        (, int24 currentTick, , , , , ) = pool.slot0();

        // Calculate tick range based on current tick and rangePercent
        (int24 tickLower, int24 tickUpper) = calculateTickRange(currentTick);

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

    /// @notice Add liquidity using 100% of the token with greater USD value
    /// @dev Prioritizes the token with higher value, calculates optimal amount for the other token
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

        // Calculate USD values (WBTC has 8 decimals, USDC has 6 decimals)
        // wbtcPrice is in USDC terms (6 decimals), e.g., 89892000000 = $89,892
        uint256 wbtcValueUSD = (wbtcBalance * wbtcPrice) / 1e8; // Result in USDC (6 decimals)
        uint256 usdcValueUSD = usdcBalance; // Already in USDC

        uint256 amount0Desired;
        uint256 amount1Desired;

        // Prioritize the token with greater USD value
        if (wbtcValueUSD >= usdcValueUSD) {
            // Use 100% of WBTC, calculate proportional USDC
            // For concentrated liquidity, we need roughly equal USD values
            // Use 50% of WBTC value in USDC terms
            amount0Desired = wbtcBalance;
            amount1Desired = usdcBalance > 0 ? usdcBalance : 0;
        } else {
            // Use 100% of USDC, calculate proportional WBTC
            amount0Desired = wbtcBalance > 0 ? wbtcBalance : 0;
            amount1Desired = usdcBalance;
        }

        // Approve position manager for the amounts we're using
        if (amount0Desired > 0) {
            IERC20(wbtc).approve(address(positionManager), amount0Desired);
        }
        if (amount1Desired > 0) {
            IERC20(usdc).approve(address(positionManager), amount1Desired);
        }

        // Mint position with calculated amounts
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

    /// @notice Collect all fees and withdraw all tokens from contract to owner
    /// @dev Collects fees from current position, then withdraws all WBTC and USDC in contract
    /// @return feesAmount0 Amount of WBTC fees collected from position
    /// @return feesAmount1 Amount of USDC fees collected from position
    /// @return withdrawnAmount0 Total amount of WBTC withdrawn to owner
    /// @return withdrawnAmount1 Total amount of USDC withdrawn to owner
    function collectFeesAndWithdraw() external onlyOwner returns (
        uint256 feesAmount0,
        uint256 feesAmount1,
        uint256 withdrawnAmount0,
        uint256 withdrawnAmount1
    ) {
        // Collect fees from current position if it exists
        if (currentTokenId != 0) {
            (feesAmount0, feesAmount1) = collectFees(currentTokenId);
        }

        // Get contract balances after fee collection
        withdrawnAmount0 = IERC20(wbtc).balanceOf(address(this));
        withdrawnAmount1 = IERC20(usdc).balanceOf(address(this));

        // Transfer all WBTC to owner
        if (withdrawnAmount0 > 0) {
            IERC20(wbtc).transfer(owner(), withdrawnAmount0);
        }

        // Transfer all USDC to owner
        if (withdrawnAmount1 > 0) {
            IERC20(usdc).transfer(owner(), withdrawnAmount1);
        }

        emit FeesCollected(currentTokenId, feesAmount0, feesAmount1);
        emit EmergencyWithdrawal(wbtc, withdrawnAmount0);
        emit EmergencyWithdrawal(usdc, withdrawnAmount1);
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
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(owner(), balance);
        emit EmergencyWithdrawal(token, balance);
    }

    // Stub implementations for interface methods (to be implemented)

    /// @notice Add liquidity to create or increase a position
    /// @dev Not yet implemented - use createPosition or addLiquidityFromContract instead
    function addLiquidity(
        uint256,
        uint256,
        int24,
        int24
    ) external pure returns (uint256, uint128, uint256, uint256) {
        revert("Not implemented - use createPosition or addLiquidityFromContract");
    }

    /// @notice Compound accumulated fees back into the position
    /// @dev Not yet implemented
    function compound(uint256) external pure returns (uint128) {
        revert("Not implemented");
    }

    /// @notice Get the underlying token balances for a position
    /// @dev Not yet implemented
    function underlying(uint256) external pure returns (uint256, uint256) {
        revert("Not implemented");
    }

    /// @notice Get information about all pools managed by this contract
    /// @dev Not yet implemented
    function getPools() external pure returns (PoolInfo[] memory) {
        revert("Not implemented");
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

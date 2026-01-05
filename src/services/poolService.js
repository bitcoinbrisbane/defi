/**
 * Uniswap V4 Pool Service
 * Handles pool interactions and position data
 */

import { ethers } from "ethers";

// Uniswap V4 Pool Manager address (will need to be updated when V4 launches)
// Using V3 contracts as reference for now since V4 is not yet deployed
const UNISWAP_V3_POSITION_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

// Minimal ABI for position NFT
const POSITION_MANAGER_ABI = [
  {
    inputs: [{ name: "tokenId", type: "uint256" }],
    name: "positions",
    outputs: [
      { name: "nonce", type: "uint96" },
      { name: "operator", type: "address" },
      { name: "token0", type: "address" },
      { name: "token1", type: "address" },
      { name: "fee", type: "uint24" },
      { name: "tickLower", type: "int24" },
      { name: "tickUpper", type: "int24" },
      { name: "liquidity", type: "uint128" },
      { name: "feeGrowthInside0LastX128", type: "uint256" },
      { name: "feeGrowthInside1LastX128", type: "uint256" },
      { name: "tokensOwed0", type: "uint128" },
      { name: "tokensOwed1", type: "uint128" }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [{ name: "tokenId", type: "uint256" }],
    name: "collect",
    outputs: [
      { name: "amount0", type: "uint256" },
      { name: "amount1", type: "uint256" }
    ],
    stateMutability: "nonpayable",
    type: "function"
  }
];

// Pool ABI for getting current state
const POOL_ABI = [
  {
    inputs: [],
    name: "slot0",
    outputs: [
      { name: "sqrtPriceX96", type: "uint160" },
      { name: "tick", type: "int24" },
      { name: "observationIndex", type: "uint16" },
      { name: "observationCardinality", type: "uint16" },
      { name: "observationCardinalityNext", type: "uint16" },
      { name: "feeProtocol", type: "uint8" },
      { name: "unlocked", type: "bool" }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "liquidity",
    outputs: [{ name: "", type: "uint128" }],
    stateMutability: "view",
    type: "function"
  }
];

// ERC20 ABI for token info
const ERC20_ABI = [
  {
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
    type: "function"
  }
];

export class PoolService {
  constructor(rpcUrl) {
    if (!rpcUrl) {
      throw new Error("RPC URL is required for PoolService");
    }
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.positionManager = new ethers.Contract(
      UNISWAP_V3_POSITION_MANAGER,
      POSITION_MANAGER_ABI,
      this.provider
    );
  }

  /**
   * Get position details from NFT token ID
   */
  async getPosition(tokenId) {
    try {
      const position = await this.positionManager.positions(tokenId);

      return {
        nonce: Number(position.nonce),
        operator: position.operator,
        token0: position.token0,
        token1: position.token1,
        fee: Number(position.fee),
        tickLower: Number(position.tickLower),
        tickUpper: Number(position.tickUpper),
        liquidity: position.liquidity,
        feeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
        feeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
        tokensOwed0: position.tokensOwed0,
        tokensOwed1: position.tokensOwed1
      };
    } catch (error) {
      console.error("Error fetching position:", error.message);
      throw error;
    }
  }

  /**
   * Get pool state (current price, tick, liquidity)
   */
  async getPoolState(poolAddress) {
    try {
      const pool = new ethers.Contract(poolAddress, POOL_ABI, this.provider);

      const slot0 = await pool.slot0();
      const liquidity = await pool.liquidity();

      // Convert sqrtPriceX96 to actual price
      const sqrtPriceX96 = slot0.sqrtPriceX96;
      const price = this.sqrtPriceX96ToPrice(sqrtPriceX96);

      return {
        price,
        sqrtPriceX96: sqrtPriceX96.toString(),
        tick: Number(slot0.tick),
        observationIndex: Number(slot0.observationIndex),
        observationCardinality: Number(slot0.observationCardinality),
        liquidity: liquidity.toString()
      };
    } catch (error) {
      console.error("Error fetching pool state:", error.message);
      throw error;
    }
  }

  /**
   * Convert sqrtPriceX96 to human-readable price
   */
  sqrtPriceX96ToPrice(sqrtPriceX96) {
    const Q96 = 2n ** 96n;
    const price = (BigInt(sqrtPriceX96) ** 2n * (10n ** 18n)) / (Q96 ** 2n);
    return Number(price) / 1e18;
  }

  /**
   * Get token decimals
   */
  async getTokenDecimals(tokenAddress) {
    try {
      const token = new ethers.Contract(tokenAddress, ERC20_ABI, this.provider);
      return await token.decimals();
    } catch (error) {
      console.error("Error fetching token decimals:", error.message);
      return 18; // Default
    }
  }

  /**
   * Get token symbol
   */
  async getTokenSymbol(tokenAddress) {
    try {
      const token = new ethers.Contract(tokenAddress, ERC20_ABI, this.provider);
      return await token.symbol();
    } catch (error) {
      console.error("Error fetching token symbol:", error.message);
      return "UNKNOWN";
    }
  }

  /**
   * Calculate tick to price conversion
   */
  tickToPrice(tick) {
    return Math.pow(1.0001, Number(tick));
  }

  /**
   * Check if position is in range
   */
  isPositionInRange(currentTick, tickLower, tickUpper) {
    return Number(currentTick) >= Number(tickLower) && Number(currentTick) <= Number(tickUpper);
  }

  /**
   * Calculate fees earned (approximation)
   * Note: Actual fee calculation requires more complex tracking
   */
  async calculateFeesEarned(position, currentPoolState) {
    // This is a simplified version
    // Real implementation would need to track feeGrowthGlobal values
    const tokensOwed0 = Number(position.tokensOwed0);
    const tokensOwed1 = Number(position.tokensOwed1);

    return {
      token0Fees: tokensOwed0,
      token1Fees: tokensOwed1
    };
  }

  /**
   * Get comprehensive position info
   */
  async getPositionInfo(tokenId, poolAddress) {
    try {
      const [position, poolState] = await Promise.all([
        this.getPosition(tokenId),
        this.getPoolState(poolAddress)
      ]);

      const inRange = this.isPositionInRange(
        poolState.tick,
        position.tickLower,
        position.tickUpper
      );

      const priceLower = this.tickToPrice(position.tickLower);
      const priceUpper = this.tickToPrice(position.tickUpper);

      return {
        position,
        poolState,
        inRange,
        priceRange: {
          lower: priceLower,
          upper: priceUpper,
          current: poolState.price
        }
      };
    } catch (error) {
      console.error("Error fetching position info:", error.message);
      throw error;
    }
  }

  /**
   * Monitor position changes
   */
  async monitorPosition(tokenId, poolAddress, callback, intervalMs = 60000) {
    const checkPosition = async () => {
      try {
        const positionInfo = await this.getPositionInfo(tokenId, poolAddress);
        callback(null, positionInfo);
      } catch (error) {
        callback(error, null);
      }
    };

    // Initial check
    await checkPosition();

    // Set up interval
    const intervalId = setInterval(checkPosition, intervalMs);

    // Return cleanup function
    return () => clearInterval(intervalId);
  }
}

// Export singleton instance creator
export function createPoolService(rpcUrl) {
  return new PoolService(rpcUrl);
}

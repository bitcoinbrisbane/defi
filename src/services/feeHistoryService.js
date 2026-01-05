/**
 * Fee History Service
 * Fetches fee data for Uniswap V3 positions using on-chain data and Alchemy
 */

import axios from "axios";
import { ethers } from "ethers";

// Uniswap V3 contracts
const POSITION_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

const POOL_ABI = [
  "function feeGrowthGlobal0X128() view returns (uint256)",
  "function feeGrowthGlobal1X128() view returns (uint256)",
  "function ticks(int24 tick) view returns (uint128 liquidityGross, int128 liquidityNet, uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128, int56 tickCumulativeOutside, uint160 secondsPerLiquidityOutsideX128, uint32 secondsOutside, bool initialized)",
  "function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)"
];

const POSITION_MANAGER_ABI = [
  "function positions(uint256 tokenId) view returns (uint96 nonce, address operator, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)"
];

// Q128 constant for fee calculation
const Q128 = 2n ** 128n;

export class FeeHistoryService {
  constructor(config) {
    this.config = config;
    this.provider = null;
    this.positionManager = null;
  }

  /**
   * Initialize provider with RPC URL
   */
  initProvider(rpcUrl) {
    if (!this.provider && rpcUrl) {
      this.provider = new ethers.JsonRpcProvider(rpcUrl);
      this.positionManager = new ethers.Contract(POSITION_MANAGER, POSITION_MANAGER_ABI, this.provider);
    }
  }

  /**
   * Get uncollected fees from position data
   * Uses tokensOwed values which are updated by Uniswap when liquidity changes
   */
  async getUnclaimedFees(tokenId) {
    if (!this.provider) {
      throw new Error("Provider not initialized");
    }

    try {
      const position = await this.positionManager.positions(tokenId);

      // tokensOwed represents fees that have been accounted for but not collected
      // Note: Additional fees may have accrued since last interaction
      return {
        token0: BigInt(position.tokensOwed0),
        token1: BigInt(position.tokensOwed1)
      };
    } catch (error) {
      console.error("Error getting unclaimed fees:", error.message);
      return null;
    }
  }

  /**
   * Get recent fee collections (optimized for free tier RPCs)
   * Only queries last ~100 blocks to check for very recent collections
   */
  async getRecentCollections(tokenId) {
    if (!this.provider) {
      return { last24h: null };
    }

    try {
      const collectEventSignature = ethers.id("Collect(uint256,address,uint128,uint128)");
      const currentBlock = await this.provider.getBlockNumber();

      // Parse events helper
      const iface = new ethers.Interface([
        "event Collect(uint256 indexed tokenId, address recipient, uint128 amount0, uint128 amount1)"
      ]);

      // Only query last 100 blocks (~20 min) to stay within free tier limits
      // This is enough to catch recent collections
      const recentBlocks = 100;
      const fromBlock = currentBlock - recentBlocks;

      let amount0 = 0n, amount1 = 0n;
      let collectCount = 0;

      try {
        const logs = await this.provider.getLogs({
          address: POSITION_MANAGER,
          topics: [
            collectEventSignature,
            ethers.zeroPadValue(ethers.toBeHex(tokenId), 32)
          ],
          fromBlock: fromBlock,
          toBlock: "latest"
        });

        for (const log of logs) {
          try {
            const parsed = iface.parseLog({ topics: log.topics, data: log.data });
            amount0 += BigInt(parsed.args.amount0);
            amount1 += BigInt(parsed.args.amount1);
            collectCount++;
          } catch {
            continue;
          }
        }
      } catch {
        // Query failed, return null
        return { last24h: null };
      }

      return {
        last24h: { token0: amount0, token1: amount1, collectCount }
      };
    } catch (error) {
      return { last24h: null };
    }
  }

  /**
   * Get comprehensive fee summary for a position
   */
  async getFeeSummary(tokenId, _poolAddress, token0Price, token1Price = 1, rpcUrl = null) {
    // Initialize provider if needed
    if (rpcUrl) {
      this.initProvider(rpcUrl);
    } else {
      this.initProvider(process.env.ETHEREUM_RPC_URL);
    }

    if (!this.provider) {
      return null;
    }

    try {
      // Fetch unclaimed fees from on-chain (tokensOwed values)
      const unclaimed = await this.getUnclaimedFees(tokenId);

      // WBTC has 8 decimals, USDC has 6
      const decimals0 = 8;
      const decimals1 = 6;

      // Format unclaimed fees
      const unclaimedToken0 = unclaimed ? Number(unclaimed.token0) / Math.pow(10, decimals0) : 0;
      const unclaimedToken1 = unclaimed ? Number(unclaimed.token1) / Math.pow(10, decimals1) : 0;

      // Try to get recent collections (limited query for free tier)
      const recent = await this.getRecentCollections(tokenId);
      let recentCollected = null;

      if (recent.last24h && recent.last24h.collectCount > 0) {
        const last0 = Number(recent.last24h.token0) / Math.pow(10, decimals0);
        const last1 = Number(recent.last24h.token1) / Math.pow(10, decimals1);
        recentCollected = {
          token0: { symbol: "WBTC", amount: last0, usd: last0 * token0Price },
          token1: { symbol: "USDC", amount: last1, usd: last1 * token1Price },
          totalUSD: (last0 * token0Price) + (last1 * token1Price),
          collectCount: recent.last24h.collectCount
        };
      }

      return {
        total: null, // Would require full history scan (not feasible on free tier)
        last24h: recentCollected,
        unclaimed: {
          token0: { symbol: "WBTC", amount: unclaimedToken0, usd: unclaimedToken0 * token0Price },
          token1: { symbol: "USDC", amount: unclaimedToken1, usd: unclaimedToken1 * token1Price },
          totalUSD: (unclaimedToken0 * token0Price) + (unclaimedToken1 * token1Price)
        }
      };
    } catch (error) {
      console.error("Error getting fee summary:", error.message);
      return null;
    }
  }
}

// Export factory function
export function createFeeHistoryService(config) {
  return new FeeHistoryService(config);
}

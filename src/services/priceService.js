/**
 * Price fetching service for WBTC and USDC
 * Supports multiple data sources with fallbacks
 */

import axios from "axios";
import { ethers } from "ethers";

// Chainlink Price Feed Addresses (Ethereum Mainnet)
const CHAINLINK_FEEDS = {
  BTC_USD: "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
  ETH_USD: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"
};

// Chainlink AggregatorV3Interface ABI (minimal)
const CHAINLINK_ABI = [
  {
    inputs: [],
    name: "latestRoundData",
    outputs: [
      { name: "roundId", type: "uint80" },
      { name: "answer", type: "int256" },
      { name: "startedAt", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
      { name: "answeredInRound", type: "uint80" }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function"
  }
];

export class PriceService {
  constructor(rpcUrl) {
    this.provider = rpcUrl ? new ethers.JsonRpcProvider(rpcUrl) : null;
  }

  /**
   * Fetch WBTC price from CoinGecko API
   */
  async getPriceFromCoinGecko() {
    try {
      const response = await axios.get(
        "https://api.coingecko.com/api/v3/simple/price",
        {
          params: {
            ids: "wrapped-bitcoin,usd-coin",
            vs_currencies: "usd"
          },
          timeout: 5000
        }
      );

      return {
        wbtc: response.data["wrapped-bitcoin"]?.usd || null,
        usdc: response.data["usd-coin"]?.usd || 1.0,
        source: "coingecko"
      };
    } catch (error) {
      console.error("CoinGecko API error:", error.message);
      return null;
    }
  }

  /**
   * Fetch BTC price from Chainlink oracle
   */
  async getPriceFromChainlink() {
    if (!this.provider) {
      console.warn("No RPC provider configured for Chainlink");
      return null;
    }

    try {
      const priceFeed = new ethers.Contract(
        CHAINLINK_FEEDS.BTC_USD,
        CHAINLINK_ABI,
        this.provider
      );

      const [, answer, , updatedAt] = await priceFeed.latestRoundData();
      const decimals = await priceFeed.decimals();

      const price = Number(answer) / Math.pow(10, Number(decimals));
      const timestamp = Number(updatedAt);

      // Check if price is stale (older than 1 hour)
      const now = Math.floor(Date.now() / 1000);
      if (now - timestamp > 3600) {
        console.warn("Chainlink price data is stale");
        return null;
      }

      return {
        wbtc: price,
        usdc: 1.0,
        source: "chainlink",
        timestamp
      };
    } catch (error) {
      console.error("Chainlink oracle error:", error.message);
      return null;
    }
  }

  /**
   * Fetch price from CoinCap API (backup)
   */
  async getPriceFromCoinCap() {
    try {
      const response = await axios.get("https://api.coincap.io/v2/assets/bitcoin", {
        timeout: 5000
      });

      return {
        wbtc: parseFloat(response.data.data.priceUsd),
        usdc: 1.0,
        source: "coincap"
      };
    } catch (error) {
      console.error("CoinCap API error:", error.message);
      return null;
    }
  }

  /**
   * Get current WBTC/USDC price with fallback sources
   */
  async getCurrentPrice() {
    // Try CoinGecko first (free, no API key needed)
    let priceData = await this.getPriceFromCoinGecko();
    if (priceData?.wbtc) {
      return priceData;
    }

    // Fallback to Chainlink if configured
    if (this.provider) {
      priceData = await this.getPriceFromChainlink();
      if (priceData?.wbtc) {
        return priceData;
      }
    }

    // Last resort: CoinCap
    priceData = await this.getPriceFromCoinCap();
    if (priceData?.wbtc) {
      return priceData;
    }

    throw new Error("Failed to fetch price from all sources");
  }

  /**
   * Calculate WBTC/USDC pool price
   * Returns price as USDC per WBTC
   */
  async getWBTCUSDCPrice() {
    const priceData = await this.getCurrentPrice();
    return {
      price: priceData.wbtc, // WBTC in USD (USDC ≈ 1 USD)
      wbtcUSD: priceData.wbtc,
      usdcUSD: priceData.usdc,
      source: priceData.source,
      timestamp: priceData.timestamp || Date.now()
    };
  }

  /**
   * Get historical price data (placeholder for future implementation)
   * Would integrate with The Graph or other historical data providers
   */
  async getHistoricalPrices(startDate, endDate) {
    // TODO: Implement with The Graph or CoinGecko Pro API
    console.warn("Historical price fetching not yet implemented");
    return [];
  }

  /**
   * Monitor price changes with callback
   */
  async monitorPrice(callback, intervalMs = 60000) {
    const checkPrice = async () => {
      try {
        const priceData = await this.getWBTCUSDCPrice();
        callback(null, priceData);
      } catch (error) {
        callback(error, null);
      }
    };

    // Initial check
    await checkPrice();

    // Set up interval
    const intervalId = setInterval(checkPrice, intervalMs);

    // Return cleanup function
    return () => clearInterval(intervalId);
  }
}

// Export singleton instance creator
export function createPriceService(rpcUrl = null) {
  return new PriceService(rpcUrl);
}

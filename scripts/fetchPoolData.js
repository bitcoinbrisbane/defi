/**
 * Fetch actual on-chain pool data for WBTC/USDC
 * Uses The Graph protocol to get real trading volume and liquidity
 *
 * ⚠️ IMPORTANT: The Graph has deprecated their free hosted service.
 * This script requires an API key from The Graph Studio to work.
 *
 * ALTERNATIVES:
 * - Use fetchPoolDataDirect.js instead (uses DexScreener & Defined.fi APIs)
 * - Get a free API key from https://thegraph.com/studio/
 *
 * If you have an API key, update the endpoint URL below to:
 * https://gateway.thegraph.com/api/[YOUR-API-KEY]/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV
 */

import axios from "axios";
import { readFileSync } from "fs";

const config = JSON.parse(readFileSync("./config/position.json", "utf8"));

// The Graph endpoints - Requires API key (free from thegraph.com/studio)
// Replace [YOUR-API-KEY] with your actual API key
const GRAPH_API_KEY = process.env.GRAPH_API_KEY || "[YOUR-API-KEY]";
const UNISWAP_V3_SUBGRAPH = `https://gateway.thegraph.com/api/${GRAPH_API_KEY}/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV`;
const UNISWAP_V2_SUBGRAPH = "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2";

// WBTC and USDC token addresses
const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599";
const USDC_ADDRESS = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

/**
 * Query The Graph for Uniswap V3 pool data
 */
async function queryUniswapV3Pools() {
  const query = `
    {
      pools(
        where: {
          token0: "${WBTC_ADDRESS.toLowerCase()}"
          token1: "${USDC_ADDRESS.toLowerCase()}"
        }
        orderBy: totalValueLockedUSD
        orderDirection: desc
      ) {
        id
        feeTier
        token0 {
          symbol
          decimals
        }
        token1 {
          symbol
          decimals
        }
        totalValueLockedUSD
        volumeUSD
        txCount
        liquidity
        sqrtPrice
        tick
      }
    }
  `;

  try {
    const response = await axios.post(UNISWAP_V3_SUBGRAPH, { query });

    // Check for errors in response
    if (response.data.errors) {
      console.error("\n⚠️  The Graph API Error:");
      console.error(JSON.stringify(response.data.errors, null, 2));
      console.error("\n💡 This is likely because:");
      console.error("   1. The Graph deprecated their free hosted service");
      console.error("   2. You need an API key from https://thegraph.com/studio/");
      console.error("   3. Set GRAPH_API_KEY environment variable or update the script");
      console.error("\n🔧 RECOMMENDED: Use 'node scripts/fetchPoolDataDirect.js' instead");
      console.error("   (uses DexScreener & Defined.fi - no API key needed)\n");
      return [];
    }

    if (!response.data || !response.data.data) {
      console.error("Unexpected response structure:", JSON.stringify(response.data, null, 2));
      return [];
    }

    return response.data.data.pools;
  } catch (error) {
    console.error("Error querying Uniswap V3:", error.message);
    return [];
  }
}

/**
 * Query historical daily data for a specific pool
 */
async function queryPoolDayData(poolAddress, days = 30) {
  const timestamp = Math.floor(Date.now() / 1000) - (days * 24 * 60 * 60);

  const query = `
    {
      poolDayDatas(
        where: {
          pool: "${poolAddress.toLowerCase()}"
          date_gte: ${timestamp}
        }
        orderBy: date
        orderDirection: desc
        first: ${days}
      ) {
        date
        volumeUSD
        tvlUSD
        feesUSD
        txCount
        open
        high
        low
        close
      }
    }
  `;

  try {
    const response = await axios.post(UNISWAP_V3_SUBGRAPH, { query });
    return response.data.data.poolDayDatas;
  } catch (error) {
    console.error("Error querying pool day data:", error.message);
    return [];
  }
}

/**
 * Calculate statistics from daily data
 */
function calculateStats(dayData) {
  if (!dayData || dayData.length === 0) {
    return null;
  }

  const volumes = dayData.map(d => parseFloat(d.volumeUSD));
  const tvls = dayData.map(d => parseFloat(d.tvlUSD));
  const fees = dayData.map(d => parseFloat(d.feesUSD));

  const avgVolume = volumes.reduce((a, b) => a + b, 0) / volumes.length;
  const avgTVL = tvls.reduce((a, b) => a + b, 0) / tvls.length;
  const avgDailyFees = fees.reduce((a, b) => a + b, 0) / fees.length;

  const minVolume = Math.min(...volumes);
  const maxVolume = Math.max(...volumes);

  const totalVolume = volumes.reduce((a, b) => a + b, 0);
  const totalFees = fees.reduce((a, b) => a + b, 0);

  return {
    days: dayData.length,
    avgDailyVolume: avgVolume,
    minDailyVolume: minVolume,
    maxDailyVolume: maxVolume,
    avgTVL,
    avgDailyFees,
    totalVolume,
    totalFees,
    volumes,
    tvls,
    dates: dayData.map(d => new Date(d.date * 1000).toISOString().split("T")[0])
  };
}

/**
 * Calculate fee APR from pool data
 */
function calculateAPR(avgDailyVolume, feeTier, avgTVL) {
  const annualVolume = avgDailyVolume * 365;
  const feeRate = feeTier / 1000000; // Convert basis points to decimal
  const annualFees = annualVolume * feeRate;
  const apr = (annualFees / avgTVL) * 100;
  return apr;
}

/**
 * Display pool information
 */
function displayPoolInfo(pool, stats) {
  const feeTierPercent = (pool.feeTier / 10000).toFixed(2);

  console.log(`\n${  "=".repeat(70)}`);
  console.log(`WBTC/USDC Pool - ${feeTierPercent}% Fee Tier`);
  console.log("=".repeat(70));
  console.log(`Pool Address: ${pool.id}`);
  console.log(`Current TVL: $${parseFloat(pool.totalValueLockedUSD).toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
  console.log(`Total Volume: $${parseFloat(pool.volumeUSD).toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
  console.log(`Total Transactions: ${pool.txCount.toLocaleString()}`);

  if (stats) {
    console.log(`\nLast ${stats.days} Days Statistics:`);
    console.log(`  Average Daily Volume: $${stats.avgDailyVolume.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Volume Range: $${stats.minDailyVolume.toLocaleString("en-US", { maximumFractionDigits: 0 })} - $${stats.maxDailyVolume.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Average TVL: $${stats.avgTVL.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Average Daily Fees: $${stats.avgDailyFees.toLocaleString("en-US", { maximumFractionDigits: 2 })}`);
    console.log(`  Total Volume (${stats.days}d): $${stats.totalVolume.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Total Fees (${stats.days}d): $${stats.totalFees.toLocaleString("en-US", { maximumFractionDigits: 2 })}`);

    // Calculate APR
    const baseAPR = calculateAPR(stats.avgDailyVolume, pool.feeTier, stats.avgTVL);
    const concentrationFactor = 100 / (2 * config.position.rangePercent); // ±15% = 3.33x
    const effectiveAPR = baseAPR * concentrationFactor;

    console.log("\nAPR Analysis:");
    console.log(`  Base APR (full-range): ${baseAPR.toFixed(2)}%`);
    console.log(`  Concentration Factor (±${config.position.rangePercent}%): ${concentrationFactor.toFixed(2)}x`);
    console.log(`  Effective APR (concentrated): ${effectiveAPR.toFixed(2)}%`);

    // Calculate required capital
    const targetAnnualFees = config.position.targetAnnualFees;
    const requiredCapital = (targetAnnualFees / effectiveAPR) * 100;

    console.log(`\nCapital Requirements for $${config.position.targetWeeklyFees}/week target:`);
    console.log(`  Required Capital: $${requiredCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);

    // Show recent trend
    console.log("\nRecent Volume Trend (last 7 days):");
    const recentVolumes = stats.volumes.slice(0, 7);
    const recentDates = stats.dates.slice(0, 7);
    recentDates.forEach((date, i) => {
      const vol = recentVolumes[i];
      const bar = "█".repeat(Math.floor(vol / 500000)); // Scale for display
      console.log(`  ${date}: $${vol.toLocaleString("en-US", { maximumFractionDigits: 0 })} ${bar}`);
    });
  }
}

/**
 * Main function
 */
async function main() {
  console.log("Fetching on-chain WBTC/USDC pool data from The Graph...\n");

  // Query all WBTC/USDC pools
  const pools = await queryUniswapV3Pools();

  if (pools.length === 0) {
    console.log("No WBTC/USDC pools found.");
    console.log("Note: Token addresses might be in different order (token0/token1)");
    console.log("Trying reverse order...\n");

    // Try reverse order
    const reverseQuery = `
      {
        pools(
          where: {
            token0: "${USDC_ADDRESS.toLowerCase()}"
            token1: "${WBTC_ADDRESS.toLowerCase()}"
          }
          orderBy: totalValueLockedUSD
          orderDirection: desc
        ) {
          id
          feeTier
          token0 { symbol decimals }
          token1 { symbol decimals }
          totalValueLockedUSD
          volumeUSD
          txCount
        }
      }
    `;

    try {
      const response = await axios.post(UNISWAP_V3_SUBGRAPH, { query: reverseQuery });

      if (response.data.errors) {
        // Skip error message for reverse query since we already showed it above
      } else if (response.data.data && response.data.data.pools) {
        const reversePools = response.data.data.pools;
        if (reversePools.length > 0) {
          console.log(`Found ${reversePools.length} pools with reversed token order\n`);
          pools.push(...reversePools);
        }
      }
    } catch (error) {
      // Suppress error for reverse query
    }
  }

  if (pools.length === 0) {
    console.log("\nNo pools found. This could mean:");
    console.log("1. The Graph indexer is behind");
    console.log("2. Token addresses are incorrect");
    console.log("3. No WBTC/USDC pools exist on Uniswap V3");
    return;
  }

  console.log(`Found ${pools.length} WBTC/USDC pool(s)\n`);

  // Process each pool
  for (const pool of pools) {
    const feeTierBps = pool.feeTier;

    // Fetch historical data
    console.log(`Fetching 30-day historical data for ${(feeTierBps/10000).toFixed(2)}% fee tier pool...`);
    const dayData = await queryPoolDayData(pool.id, 30);

    if (dayData.length > 0) {
      const stats = calculateStats(dayData);
      displayPoolInfo(pool, stats);
    } else {
      console.log(`No historical data available for pool ${pool.id}`);
      displayPoolInfo(pool, null);
    }
  }

  console.log(`\n${  "=".repeat(70)}`);
  console.log("Data fetched successfully from The Graph!");
  console.log("=".repeat(70));
}

// Run the script
main().catch(error => {
  console.error("Fatal error:", error);
  process.exit(1);
});

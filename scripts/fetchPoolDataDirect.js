/**
 * Fetch pool data directly using public APIs and explorers
 * Alternative to The Graph when subgraph is unavailable
 *
 * ⚠️ CRITICAL LIMITATION:
 * This script uses TOTAL pool TVL from public APIs (DexScreener, Defined.fi).
 * However, in Uniswap V3, most liquidity is CONCENTRATED in specific price ranges.
 *
 * The ACTUAL active liquidity at current price can be 100-300x higher than
 * what these APIs report as "total TVL". This means APR calculations will be
 * significantly OVERESTIMATED.
 *
 * For ACCURATE calculations, you need to:
 * 1. Query pool.liquidity() on-chain (active liquidity at current tick)
 * 2. Use that instead of total TVL in APR calculations
 * 3. See check_position_public.js for how to get real active liquidity
 *
 * Example: Pool shows $3.85M TVL, but active liquidity = 606B units (~$160M+ equivalent)
 */

import axios from "axios";
import { readFileSync } from "fs";

const config = JSON.parse(readFileSync("./config/position.json", "utf8"));

// Known Uniswap V3 WBTC/USDC pool addresses
const KNOWN_POOLS = [
  {
    address: "0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35",
    feeTier: 500,   // 0.05%
    name: "WBTC/USDC 0.05%"
  },
  {
    address: "0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16",
    feeTier: 3000,  // 0.30%
    name: "WBTC/USDC 0.30%"
  },
  {
    address: "0x88fC345ce29d97E15B1846878bEe9F7e1Cd0F6fF",
    feeTier: 10000, // 1.00%
    name: "WBTC/USDC 1.00%"
  }
];

/**
 * Fetch pool info from DexScreener API (free, no key needed)
 */
async function fetchFromDexScreener(poolAddress) {
  try {
    const response = await axios.get(
      `https://api.dexscreener.com/latest/dex/pairs/ethereum/${poolAddress}`,
      { timeout: 10000 }
    );

    if (response.data?.pair) {
      const pair = response.data.pair;
      return {
        source: "DexScreener",
        priceUsd: parseFloat(pair.priceUsd || 0),
        volume24h: parseFloat(pair.volume?.h24 || 0),
        liquidity: parseFloat(pair.liquidity?.usd || 0),
        priceChange24h: parseFloat(pair.priceChange?.h24 || 0),
        txns24h: pair.txns?.h24?.buys + pair.txns?.h24?.sells || 0,
        fdv: parseFloat(pair.fdv || 0)
      };
    }
    return null;
  } catch (error) {
    console.error("DexScreener error:", error.message);
    return null;
  }
}

/**
 * Fetch data from Defined.fi API (formerly Defined)
 */
async function fetchFromDefined(poolAddress) {
  try {
    const query = `
      query {
        getPoolByAddress(address: "${poolAddress}", networkId: 1) {
          address
          liquidity
          volume24h
          volumeChange24h
          txCount24h
          token0 { symbol price }
          token1 { symbol price }
        }
      }
    `;

    const response = await axios.post(
      "https://graph.defined.fi/graphql",
      { query },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 10000
      }
    );

    if (response.data?.data?.getPoolByAddress) {
      const pool = response.data.data.getPoolByAddress;
      return {
        source: "Defined.fi",
        volume24h: parseFloat(pool.volume24h || 0),
        liquidity: parseFloat(pool.liquidity || 0),
        txCount24h: pool.txCount24h || 0
      };
    }
    return null;
  } catch (error) {
    console.error("Defined.fi error:", error.message);
    return null;
  }
}

/**
 * Estimate historical averages based on 24h data
 * This is a rough estimate - ideally we'd have 30-day data
 */
function estimateHistoricalData(volume24h, liquidity) {
  // Assume some variance in volume (±30%)
  const avgVolume = volume24h;
  const minVolume = volume24h * 0.7;
  const maxVolume = volume24h * 1.3;

  return {
    avgDailyVolume: avgVolume,
    minDailyVolume: minVolume,
    maxDailyVolume: maxVolume,
    avgTVL: liquidity,
    dataSource: "24h data (estimated 30-day average)",
    confidence: "medium"
  };
}

/**
 * Calculate APR and capital requirements
 */
function calculateMetrics(poolData, feeTier) {
  const { avgDailyVolume, avgTVL } = poolData;

  // Calculate base APR
  const annualVolume = avgDailyVolume * 365;
  const feeRate = feeTier / 1000000;
  const annualFees = annualVolume * feeRate;
  const baseAPR = (annualFees / avgTVL) * 100;

  // Calculate with concentration using Uniswap V3 sqrt price formula
  const rangePercent = config.position.rangePercent;
  const priceLower = 1 * (1 - rangePercent / 100);
  const priceUpper = 1 * (1 + rangePercent / 100);
  const concentrationFactor = 1 / (Math.sqrt(priceUpper) - Math.sqrt(priceLower));
  const effectiveAPR = baseAPR * concentrationFactor;

  // Required capital
  const targetAnnualFees = config.position.targetAnnualFees;
  const requiredCapital = (targetAnnualFees / effectiveAPR) * 100;

  return {
    baseAPR,
    concentrationFactor,
    effectiveAPR,
    requiredCapital,
    annualFees
  };
}

/**
 * Display pool analysis
 */
function displayPoolAnalysis(pool, data, metrics) {
  console.log(`\n${  "=".repeat(70)}`);
  console.log(`${pool.name} Pool Analysis`);
  console.log("=".repeat(70));
  console.log(`Pool Address: ${pool.address}`);
  console.log(`Data Source: ${data.source || "Multiple sources"}`);
  console.log();

  console.log("CURRENT METRICS:");
  console.log(`  24h Volume: $${data.volume24h?.toLocaleString("en-US", { maximumFractionDigits: 0 }) || "N/A"}`);
  console.log(`  Liquidity (TVL): $${data.liquidity?.toLocaleString("en-US", { maximumFractionDigits: 0 }) || "N/A"}`);
  if (data.txns24h) {
    console.log(`  24h Transactions: ${data.txns24h.toLocaleString()}`);
  }
  if (data.priceChange24h !== undefined) {
    console.log(`  24h Price Change: ${data.priceChange24h.toFixed(2)}%`);
  }

  if (metrics) {
    console.log();
    console.log("ESTIMATED AVERAGES (Based on 24h data):");
    console.log(`  Daily Volume: $${metrics.avgDailyVolume?.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Volume Range: $${metrics.minDailyVolume?.toLocaleString("en-US", { maximumFractionDigits: 0 })} - $${metrics.maxDailyVolume?.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
    console.log(`  Average TVL: $${metrics.avgTVL?.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);

    const calc = calculateMetrics(metrics, pool.feeTier);

    console.log();
    console.log("APR ANALYSIS:");
    console.log(`  Base APR (full-range): ${calc.baseAPR.toFixed(2)}%`);
    console.log(`  Concentration Factor (±${config.position.rangePercent}%): ${calc.concentrationFactor.toFixed(2)}x`);
    console.log(`  Effective APR (concentrated): ${calc.effectiveAPR.toFixed(2)}%`);

    console.log();
    console.log(`CAPITAL REQUIRED FOR $${config.position.targetWeeklyFees}/week:`);
    console.log(`  Required Investment: $${calc.requiredCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);

    // Calculate token split
    const wbtcPrice = 89892; // Approximate
    const halfCapital = calc.requiredCapital / 2;
    const wbtcAmount = halfCapital / wbtcPrice;

    console.log("  Token Allocation (50/50):");
    console.log(`    - ${wbtcAmount.toFixed(4)} WBTC ($${halfCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })})`);
    console.log(`    - ${halfCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })} USDC`);

    console.log();
    console.log("EXPECTED PERFORMANCE:");
    console.log(`  Daily Fees: $${(config.position.targetWeeklyFees / 7).toFixed(2)}`);
    console.log(`  Weekly Fees: $${config.position.targetWeeklyFees.toFixed(2)}`);
    console.log(`  Monthly Fees: $${(config.position.targetWeeklyFees * 4.33).toFixed(2)}`);
    console.log(`  Annual Fees: $${config.position.targetAnnualFees.toLocaleString()}`);
  }
}

/**
 * Main function
 */
async function main() {
  console.log("Fetching on-chain WBTC/USDC pool data...\n");
  console.log("Using public APIs: DexScreener, Defined.fi");
  console.log();

  for (const pool of KNOWN_POOLS) {
    console.log(`\nQuerying ${pool.name}...`);

    // Try DexScreener first
    let poolData = await fetchFromDexScreener(pool.address);

    // Fallback to Defined.fi
    if (!poolData || !poolData.volume24h) {
      console.log("Trying Defined.fi...");
      poolData = await fetchFromDefined(pool.address);
    }

    if (poolData && poolData.volume24h && poolData.liquidity) {
      const estimates = estimateHistoricalData(poolData.volume24h, poolData.liquidity);
      displayPoolAnalysis(pool, poolData, estimates);
    } else {
      console.log(`❌ Could not fetch data for ${pool.name}`);
      displayPoolAnalysis(pool, poolData || {}, null);
    }

    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  console.log(`\n${  "=".repeat(70)}`);
  console.log("SUMMARY & RECOMMENDATIONS");
  console.log("=".repeat(70));
  console.log();
  console.log("Note: This data is based on 24-hour snapshots.");
  console.log("For more accurate estimates, monitor pools over 7-30 days.");
  console.log();
  console.log("Compare the pools and choose based on:");
  console.log("  1. Capital requirements (lower fee tier = more capital needed)");
  console.log("  2. Volume consistency (check multiple times per day)");
  console.log("  3. Your risk tolerance (higher fees = less stable)");
  console.log();
}

// Run the script
main().catch(error => {
  console.error("Fatal error:", error);
  console.error(error.stack);
  process.exit(1);
});

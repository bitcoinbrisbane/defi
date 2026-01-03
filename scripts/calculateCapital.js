/**
 * Calculate required capital investment for LP position
 * Based on historical pool data and target fee earnings
 */

import axios from "axios";
import { readFileSync } from "fs";
import {
  calculateConcentrationFactor,
  calculateRequiredCapital,
  calculateFeeAPR
} from "../src/utils/calculations.js";

const config = JSON.parse(readFileSync("./config/position.json", "utf8"));

// ACTUAL on-chain pool data for WBTC/USDC 0.30% fee tier
// Source: DexScreener API (January 4, 2026)
// Pool: 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16
const HISTORICAL_DATA_ESTIMATES = {
  // Average daily volume (USD) - REAL on-chain data
  avgDailyVolume: {
    min: 701_450,       // $701k (70% of current)
    avg: 1_002_071,     // $1.002M (ACTUAL 24h volume)
    max: 1_302_692      // $1.303M (130% of current)
  },
  // Total pool liquidity (USD) - REAL on-chain data
  avgTotalLiquidity: {
    min: 2_482_776,     // $2.48M (70% of current)
    avg: 3_546_823,     // $3.55M (ACTUAL TVL)
    max: 4_610_870      // $4.61M (130% of current)
  }
};

/**
 * Fetch current WBTC/USDC price from CoinGecko
 */
async function getCurrentPrice() {
  try {
    const response = await axios.get(
      "https://api.coingecko.com/api/v3/simple/price?ids=wrapped-bitcoin&vs_currencies=usd"
    );
    return response.data["wrapped-bitcoin"].usd;
  } catch (error) {
    console.error("Error fetching price:", error.message);
    // Fallback estimate
    return 95000; // Approximate WBTC price
  }
}

/**
 * Simulate historical pool data analysis
 * In production, this would query The Graph or Dune Analytics
 */
function analyzeHistoricalData() {
  const { feeTier } = config.pool;
  const { targetAnnualFees } = config.position;
  const scenarios = ["conservative", "moderate", "optimistic"];

  const results = scenarios.map(scenario => {
    let dailyVolume, totalLiquidity;

    switch(scenario) {
    case "conservative":
      dailyVolume = HISTORICAL_DATA_ESTIMATES.avgDailyVolume.min;
      totalLiquidity = HISTORICAL_DATA_ESTIMATES.avgTotalLiquidity.max;
      break;
    case "optimistic":
      dailyVolume = HISTORICAL_DATA_ESTIMATES.avgDailyVolume.max;
      totalLiquidity = HISTORICAL_DATA_ESTIMATES.avgTotalLiquidity.min;
      break;
    default: // moderate
      dailyVolume = HISTORICAL_DATA_ESTIMATES.avgDailyVolume.avg;
      totalLiquidity = HISTORICAL_DATA_ESTIMATES.avgTotalLiquidity.avg;
    }

    // Calculate base APR for full-range LP
    const baseAPR = calculateFeeAPR(dailyVolume, feeTier, totalLiquidity);

    // Calculate concentration factor for our range
    const concentrationFactor = calculateConcentrationFactor(config.position.rangePercent);

    // Effective APR with concentrated liquidity
    const effectiveAPR = baseAPR * concentrationFactor;

    // Required capital to achieve target
    // Note: effectiveAPR already includes concentration, so pass 1 as factor
    const requiredCapital = targetAnnualFees / effectiveAPR;

    return {
      scenario,
      dailyVolume,
      totalLiquidity,
      baseAPR: baseAPR * 100, // Convert to percentage
      concentrationFactor,
      effectiveAPR: effectiveAPR * 100, // Convert to percentage
      requiredCapital
    };
  });

  return results;
}

/**
 * Calculate capital allocation between WBTC and USDC
 */
function calculateTokenAllocation(totalCapital, wbtcPrice) {
  // For 50/50 position at current price
  const usdcValue = totalCapital / 2;
  const wbtcValue = totalCapital / 2;

  const wbtcAmount = wbtcValue / wbtcPrice;
  const usdcAmount = usdcValue;

  return {
    wbtc: {
      amount: wbtcAmount,
      valueUSD: wbtcValue
    },
    usdc: {
      amount: usdcAmount,
      valueUSD: usdcValue
    }
  };
}

/**
 * Main calculation function
 */
async function main() {
  console.log("=".repeat(70));
  console.log("UNISWAP V4 WBTC/USDC LP CAPITAL CALCULATOR");
  console.log("=".repeat(70));
  console.log();

  // Fetch current price
  console.log("Fetching current WBTC price...");
  const wbtcPrice = await getCurrentPrice();
  console.log(`Current WBTC Price: $${wbtcPrice.toLocaleString()}`);
  console.log();

  // Position parameters
  console.log("POSITION PARAMETERS:");
  console.log(`  Target Weekly Fees: $${config.position.targetWeeklyFees.toLocaleString()}`);
  console.log(`  Target Annual Fees: $${config.position.targetAnnualFees.toLocaleString()}`);
  console.log(`  Liquidity Range: ±${config.position.rangePercent}%`);
  console.log(`  Fee Tier: ${config.pool.feeTier / 10000}%`);
  console.log();

  // Analyze historical data
  console.log("HISTORICAL ANALYSIS & CAPITAL REQUIREMENTS:");
  console.log("-".repeat(70));

  const scenarios = analyzeHistoricalData();

  scenarios.forEach(scenario => {
    console.log();
    console.log(`${scenario.scenario.toUpperCase()} SCENARIO:`);
    console.log(`  Daily Volume: $${(scenario.dailyVolume / 1_000_000).toFixed(1)}M`);
    console.log(`  Pool Liquidity: $${(scenario.totalLiquidity / 1_000_000).toFixed(1)}M`);
    console.log(`  Base APR (full-range): ${scenario.baseAPR.toFixed(2)}%`);
    console.log(`  Concentration Factor: ${scenario.concentrationFactor.toFixed(2)}x`);
    console.log(`  Effective APR (±${config.position.rangePercent}%): ${scenario.effectiveAPR.toFixed(2)}%`);
    console.log(`  REQUIRED CAPITAL: $${scenario.requiredCapital.toLocaleString("en-US", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    })}`);

    // Calculate token allocation
    const allocation = calculateTokenAllocation(scenario.requiredCapital, wbtcPrice);
    console.log("  Token Allocation (50/50):");
    console.log(`    - ${allocation.wbtc.amount.toFixed(4)} WBTC ($${allocation.wbtc.valueUSD.toLocaleString("en-US", { maximumFractionDigits: 0 })})`);
    console.log(`    - ${allocation.usdc.amount.toLocaleString("en-US", { maximumFractionDigits: 0 })} USDC ($${allocation.usdc.valueUSD.toLocaleString("en-US", { maximumFractionDigits: 0 })})`);
  });

  console.log();
  console.log("=".repeat(70));
  console.log("SUMMARY:");
  console.log(`  Estimated Capital Range: $${scenarios[0].requiredCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })} - $${scenarios[2].requiredCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
  console.log(`  Recommended (Moderate): $${scenarios[1].requiredCapital.toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
  console.log("=".repeat(70));
  console.log();
  console.log("Note: These estimates are based on historical averages and simplified models.");
  console.log("Actual results may vary based on market conditions, volatility, and timing.");
  console.log("Consider starting with a smaller position and scaling up as you gain confidence.");
  console.log();
}

// Run the calculator
main().catch(console.error);

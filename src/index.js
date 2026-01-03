#!/usr/bin/env node

/**
 * Uniswap V4 WBTC/USDC LP Position Monitor
 * Main application entry point
 */

import dotenv from "dotenv";
import { readFileSync } from "fs";
import { createPriceService } from "./services/priceService.js";
import { createPoolService } from "./services/poolService.js";
import { createPositionService } from "./services/positionService.js";
import { createAnalyticsService } from "./services/analyticsService.js";
import { createAlertSystem } from "./utils/alerts.js";

// Load environment variables
dotenv.config();

// Load configuration
const config = JSON.parse(readFileSync("./config/position.json", "utf8"));

class LPMonitor {
  constructor() {
    this.config = config;
    this.running = false;
    this.stopMonitoring = null;
  }

  /**
   * Initialize all services
   */
  async initialize() {
    console.log("Initializing LP Position Monitor...");
    console.log(`Pool: ${this.config.pool.token0}/${this.config.pool.token1}`);
    console.log(`Target: $${this.config.position.targetWeeklyFees}/week`);
    console.log(`Range: ±${this.config.position.rangePercent}%`);
    console.log();

    // Create services
    const rpcUrl = process.env.ETHEREUM_RPC_URL;

    this.priceService = createPriceService(rpcUrl);
    this.poolService = rpcUrl ? createPoolService(rpcUrl) : null;
    this.analyticsService = createAnalyticsService(this.config);
    this.alertSystem = createAlertSystem(this.config);

    // Create position service
    this.positionService = createPositionService(
      this.priceService,
      this.poolService,
      this.config
    );

    // Initialize position tracking
    await this.positionService.initialize();

    console.log("✅ All services initialized successfully\n");
  }

  /**
   * Start monitoring
   */
  async start() {
    if (this.running) {
      console.log("Monitor is already running");
      return;
    }

    console.log("Starting position monitoring...");
    console.log(`Check interval: ${this.config.monitoring.checkIntervalSeconds}s\n`);

    this.running = true;

    // Start position monitoring
    this.stopMonitoring = await this.positionService.startMonitoring(
      async (error, data) => {
        if (error) {
          console.error("Monitoring error:", error.message);
          return;
        }

        const { status, alert, history } = data;

        // Log position status
        this.alertSystem.logPositionStatus(status);

        // Send alert if needed
        if (alert) {
          await this.alertSystem.sendAlert(alert);
        }

        // Log history summary if available
        if (history) {
          console.log(`\nHistory: ${history.totalSnapshots} snapshots, ${history.inRangePercent.toFixed(1)}% in range\n`);
        }

        console.log("-".repeat(70));
      }
    );
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (!this.running) {
      console.log("Monitor is not running");
      return;
    }

    console.log("\nStopping position monitoring...");

    if (this.stopMonitoring) {
      this.stopMonitoring();
    }

    this.running = false;
    console.log("Monitor stopped");
  }

  /**
   * Generate and display weekly report
   */
  async generateReport() {
    console.log("Generating weekly report...\n");

    // Get position history summary
    const history = this.positionService.getHistorySummary();

    // Generate report (with estimated capital - would need actual value)
    const estimatedCapital = 78000; // From moderate scenario
    const report = this.analyticsService.generateWeeklyReport(
      estimatedCapital,
      history
    );

    // Format and display
    const formattedReport = this.analyticsService.formatReport(report);
    console.log(formattedReport);

    // Get recommendation
    const recommendation = this.analyticsService.getRecommendation();
    console.log("RECOMMENDATION:");
    console.log(`  ${recommendation.message}`);
    if (recommendation.actions.length > 0) {
      console.log("  Actions:");
      recommendation.actions.forEach(action => {
        console.log(`    - ${action}`);
      });
    }
    console.log();
  }

  /**
   * Display current status
   */
  async showStatus() {
    console.log("Fetching current position status...\n");

    const status = await this.positionService.getDetailedPositionStatus();
    this.alertSystem.logPositionStatus(status);

    // Show fee projection
    const projection = this.analyticsService.getFeeProjection();
    console.log("\nFEE PROJECTION:");
    console.log(`  Weekly Target: $${projection.weeklyTarget.toLocaleString()}`);
    console.log(`  Weekly Earned: $${projection.weeklyEarned.toFixed(2)}`);
    console.log(`  Percent of Target: ${projection.percentOfTarget.toFixed(1)}%`);
    console.log(`  Status: ${projection.onTrack ? "ON TRACK ✅" : "BELOW TARGET ⚠️"}`);
    console.log();
  }
}

/**
 * Main function
 */
async function main() {
  const monitor = new LPMonitor();

  try {
    // Initialize
    await monitor.initialize();

    // Parse command line arguments
    const args = process.argv.slice(2);
    const command = args[0];

    switch (command) {
    case "status":
      // Show current status and exit
      await monitor.showStatus();
      break;

    case "report":
      // Generate report and exit
      await monitor.generateReport();
      break;

    case "--watch":
    case "watch":
      // Start monitoring (default behavior)
      await monitor.start();
      break;

    default:
      // Default: show status once and exit
      console.log("Usage:");
      console.log("  npm start           - Show current status");
      console.log("  npm start watch     - Start continuous monitoring");
      console.log("  npm start status    - Show current status");
      console.log("  npm run report      - Generate weekly report");
      console.log();
      await monitor.showStatus();
      break;
    }

    // Handle graceful shutdown for monitoring mode
    if (monitor.running) {
      process.on("SIGINT", () => {
        console.log("\nReceived SIGINT, shutting down...");
        monitor.stop();
        process.exit(0);
      });

      process.on("SIGTERM", () => {
        console.log("\nReceived SIGTERM, shutting down...");
        monitor.stop();
        process.exit(0);
      });
    }

  } catch (error) {
    console.error("Fatal error:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the application
main();

/**
 * Position monitoring and management service
 * Combines price and pool data to track LP position health
 */

import {
  calculatePriceRange,
  isPriceInRange,
  calculateDistanceToRangeBounds,
  calculateTokenAmounts,
  calculatePositionValue,
  calculateImpermanentLoss
} from "../utils/calculations.js";

export class PositionService {
  constructor(priceService, poolService, config) {
    this.priceService = priceService;
    this.poolService = poolService;
    this.config = config;
    this.initialPrice = null;
    this.initialValue = null;
    this.positionHistory = [];
  }

  /**
   * Initialize position tracking
   */
  async initialize() {
    try {
      const priceData = await this.priceService.getWBTCUSDCPrice();
      this.initialPrice = priceData.price;

      console.log(`Position tracking initialized at price: $${this.initialPrice.toLocaleString()}`);
    } catch (error) {
      console.error("Failed to initialize position:", error.message);
      throw error;
    }
  }

  /**
   * Get current position status
   */
  async getPositionStatus() {
    try {
      // Fetch current price
      const priceData = await this.priceService.getWBTCUSDCPrice();
      const currentPrice = priceData.price;

      // Calculate price range based on configuration
      const priceRange = calculatePriceRange(
        currentPrice,
        this.config.position.rangePercent
      );

      // Check if in range
      const inRange = isPriceInRange(currentPrice, priceRange.lower, priceRange.upper);

      // Calculate distance to bounds
      const distanceToBounds = calculateDistanceToRangeBounds(
        currentPrice,
        priceRange.lower,
        priceRange.upper
      );

      // Determine alert level
      let alertLevel = "normal";
      const warningThreshold = this.config.monitoring.alertThresholds.priceWarningPercent;
      const urgentThreshold = this.config.monitoring.alertThresholds.priceUrgentPercent;

      if (!inRange) {
        alertLevel = "critical";
      } else if (
        distanceToBounds.toLower < urgentThreshold ||
        distanceToBounds.toUpper < urgentThreshold
      ) {
        alertLevel = "urgent";
      } else if (
        distanceToBounds.toLower < warningThreshold ||
        distanceToBounds.toUpper < warningThreshold
      ) {
        alertLevel = "warning";
      }

      return {
        timestamp: new Date().toISOString(),
        price: {
          current: currentPrice,
          initial: this.initialPrice,
          change: this.initialPrice
            ? ((currentPrice - this.initialPrice) / this.initialPrice) * 100
            : 0,
          source: priceData.source
        },
        range: {
          lower: priceRange.lower,
          upper: priceRange.upper,
          rangePercent: this.config.position.rangePercent,
          inRange
        },
        distance: {
          toLowerBound: distanceToBounds.toLower,
          toUpperBound: distanceToBounds.toUpper
        },
        alertLevel,
        needsRebalancing: !inRange
      };
    } catch (error) {
      console.error("Error getting position status:", error.message);
      throw error;
    }
  }

  /**
   * Get position status with on-chain data (if NFT token ID provided)
   */
  async getDetailedPositionStatus() {
    const basicStatus = await this.getPositionStatus();

    // If we have an NFT token ID, fetch on-chain position data
    if (this.config.position.nftTokenId && this.config.pool.poolAddress) {
      try {
        const positionInfo = await this.poolService.getPositionInfo(
          this.config.position.nftTokenId,
          this.config.pool.poolAddress
        );

        return {
          ...basicStatus,
          onChain: {
            liquidity: positionInfo.position.liquidity.toString(),
            tickLower: positionInfo.position.tickLower,
            tickUpper: positionInfo.position.tickUpper,
            tokensOwed0: positionInfo.position.tokensOwed0.toString(),
            tokensOwed1: positionInfo.position.tokensOwed1.toString(),
            inRange: positionInfo.inRange
          }
        };
      } catch (error) {
        console.warn("Could not fetch on-chain position data:", error.message);
      }
    }

    return basicStatus;
  }

  /**
   * Calculate estimated position value and IL
   */
  async calculatePositionMetrics(capitalInvested) {
    try {
      const status = await this.getPositionStatus();
      const currentPrice = status.price.current;

      // Simple 50/50 split assumption
      const initialWBTC = (capitalInvested / 2) / this.initialPrice;
      const initialUSDC = capitalInvested / 2;

      // Calculate current token amounts based on price movement
      // This is simplified - actual amounts depend on liquidity math
      const currentTokens = calculateTokenAmounts(
        1000000, // Dummy liquidity value
        currentPrice,
        status.range.lower,
        status.range.upper
      );

      // Calculate impermanent loss
      let il = 0;
      if (this.initialPrice) {
        const priceRatio = currentPrice / this.initialPrice;
        il = calculateImpermanentLoss(priceRatio);
      }

      return {
        capital: {
          invested: capitalInvested,
          current: capitalInvested * (1 + status.price.change / 100), // Simplified
          change: status.price.change
        },
        impermanentLoss: {
          percentage: il,
          valueUSD: capitalInvested * (il / 100)
        },
        inRange: status.range.inRange
      };
    } catch (error) {
      console.error("Error calculating position metrics:", error.message);
      throw error;
    }
  }

  /**
   * Track position status over time
   */
  recordPositionSnapshot(status) {
    this.positionHistory.push({
      timestamp: status.timestamp,
      price: status.price.current,
      inRange: status.range.inRange,
      alertLevel: status.alertLevel
    });

    // Keep only last 1000 snapshots
    if (this.positionHistory.length > 1000) {
      this.positionHistory.shift();
    }
  }

  /**
   * Get position history summary
   */
  getHistorySummary() {
    if (this.positionHistory.length === 0) {
      return null;
    }

    const inRangeCount = this.positionHistory.filter(s => s.inRange).length;
    const inRangePercent = (inRangeCount / this.positionHistory.length) * 100;

    const prices = this.positionHistory.map(s => s.price);
    const minPrice = Math.min(...prices);
    const maxPrice = Math.max(...prices);

    return {
      totalSnapshots: this.positionHistory.length,
      inRangePercent,
      priceRange: {
        min: minPrice,
        max: maxPrice,
        volatility: ((maxPrice - minPrice) / minPrice) * 100
      },
      firstSnapshot: this.positionHistory[0].timestamp,
      lastSnapshot: this.positionHistory[this.positionHistory.length - 1].timestamp
    };
  }

  /**
   * Generate alert message based on position status
   */
  generateAlertMessage(status) {
    if (status.alertLevel === "normal") {
      return null;
    }

    const messages = {
      warning: `⚠️ Price approaching range boundary. Current: $${status.price.current.toLocaleString()}, Range: $${status.range.lower.toLocaleString()} - $${status.range.upper.toLocaleString()}`,
      urgent: `🚨 Price very close to range boundary! Distance to bounds: ${Math.min(status.distance.toLowerBound, status.distance.toUpperBound).toFixed(2)}%`,
      critical: `🔴 CRITICAL: Position is OUT OF RANGE! Current price: $${status.price.current.toLocaleString()}, Range: $${status.range.lower.toLocaleString()} - $${status.range.upper.toLocaleString()}`
    };

    return {
      level: status.alertLevel,
      message: messages[status.alertLevel],
      timestamp: status.timestamp,
      price: status.price.current,
      needsAction: status.needsRebalancing
    };
  }

  /**
   * Monitor position continuously
   */
  async startMonitoring(callback) {
    console.log("Starting position monitoring...");

    const checkInterval = this.config.monitoring.checkIntervalSeconds * 1000;

    const monitor = async () => {
      try {
        const status = await this.getDetailedPositionStatus();
        this.recordPositionSnapshot(status);

        const alert = this.generateAlertMessage(status);

        callback(null, {
          status,
          alert,
          history: this.getHistorySummary()
        });
      } catch (error) {
        callback(error, null);
      }
    };

    // Initial check
    await monitor();

    // Set up interval
    const intervalId = setInterval(monitor, checkInterval);

    // Return cleanup function
    return () => {
      clearInterval(intervalId);
      console.log("Position monitoring stopped");
    };
  }
}

// Export factory function
export function createPositionService(priceService, poolService, config) {
  return new PositionService(priceService, poolService, config);
}

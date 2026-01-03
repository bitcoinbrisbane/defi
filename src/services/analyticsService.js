/**
 * Analytics and fee tracking service
 * Tracks fees earned, performance metrics, and generates reports
 */

export class AnalyticsService {
  constructor(config) {
    this.config = config;
    this.feeHistory = [];
    this.performanceMetrics = {
      totalFeesEarned: { wbtc: 0, usdc: 0, usd: 0 },
      startDate: new Date().toISOString(),
      dailySnapshots: []
    };
  }

  /**
   * Record fees earned
   */
  recordFees(wbtcFees, usdcFees, wbtcPrice, usdcPrice = 1.0) {
    const feeRecord = {
      timestamp: new Date().toISOString(),
      wbtcFees,
      usdcFees,
      wbtcPrice,
      usdcPrice,
      totalUSD: (wbtcFees * wbtcPrice) + (usdcFees * usdcPrice)
    };

    this.feeHistory.push(feeRecord);

    // Update cumulative totals
    this.performanceMetrics.totalFeesEarned.wbtc += wbtcFees;
    this.performanceMetrics.totalFeesEarned.usdc += usdcFees;
    this.performanceMetrics.totalFeesEarned.usd += feeRecord.totalUSD;

    return feeRecord;
  }

  /**
   * Calculate daily fees earned
   */
  getDailyFees() {
    const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const recentFees = this.feeHistory.filter(
      f => new Date(f.timestamp).getTime() > oneDayAgo
    );

    return recentFees.reduce(
      (acc, fee) => {
        acc.wbtc += fee.wbtcFees;
        acc.usdc += fee.usdcFees;
        acc.usd += fee.totalUSD;
        return acc;
      },
      { wbtc: 0, usdc: 0, usd: 0 }
    );
  }

  /**
   * Calculate weekly fees earned
   */
  getWeeklyFees() {
    const oneWeekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const recentFees = this.feeHistory.filter(
      f => new Date(f.timestamp).getTime() > oneWeekAgo
    );

    return recentFees.reduce(
      (acc, fee) => {
        acc.wbtc += fee.wbtcFees;
        acc.usdc += fee.usdcFees;
        acc.usd += fee.totalUSD;
        return acc;
      },
      { wbtc: 0, usdc: 0, usd: 0 }
    );
  }

  /**
   * Calculate fee earning rate and project to target
   */
  getFeeProjection() {
    const weeklyFees = this.getWeeklyFees();
    const target = this.config.position.targetWeeklyFees;

    const percentOfTarget = (weeklyFees.usd / target) * 100;
    const onTrack = percentOfTarget >= 90; // Within 10% of target

    return {
      weeklyEarned: weeklyFees.usd,
      weeklyTarget: target,
      percentOfTarget,
      onTrack,
      projection: {
        daily: weeklyFees.usd / 7,
        monthly: (weeklyFees.usd / 7) * 30,
        annual: (weeklyFees.usd / 7) * 365
      }
    };
  }

  /**
   * Calculate effective APR based on actual fees
   */
  calculateEffectiveAPR(capitalInvested) {
    const projection = this.getFeeProjection();

    if (!projection.projection.annual || capitalInvested === 0) {
      return 0;
    }

    return (projection.projection.annual / capitalInvested) * 100;
  }

  /**
   * Record daily snapshot
   */
  recordDailySnapshot(positionValue, feesEarned, inRangePercent) {
    const snapshot = {
      date: new Date().toISOString().split("T")[0],
      positionValue,
      feesEarned,
      inRangePercent,
      cumulativeFees: this.performanceMetrics.totalFeesEarned.usd
    };

    this.performanceMetrics.dailySnapshots.push(snapshot);

    // Keep only last 90 days
    if (this.performanceMetrics.dailySnapshots.length > 90) {
      this.performanceMetrics.dailySnapshots.shift();
    }

    return snapshot;
  }

  /**
   * Generate performance summary
   */
  getPerformanceSummary(capitalInvested) {
    const weeklyFees = this.getWeeklyFees();
    const projection = this.getFeeProjection();
    const effectiveAPR = this.calculateEffectiveAPR(capitalInvested);

    const daysActive = Math.floor(
      (Date.now() - new Date(this.performanceMetrics.startDate).getTime()) /
      (24 * 60 * 60 * 1000)
    );

    return {
      period: {
        startDate: this.performanceMetrics.startDate,
        daysActive
      },
      fees: {
        total: this.performanceMetrics.totalFeesEarned,
        weekly: weeklyFees,
        projection
      },
      performance: {
        effectiveAPR,
        onTrackForTarget: projection.onTrack,
        capitalInvested
      },
      snapshots: this.performanceMetrics.dailySnapshots.slice(-7) // Last 7 days
    };
  }

  /**
   * Generate weekly report
   */
  generateWeeklyReport(capitalInvested, positionHistory) {
    const summary = this.getPerformanceSummary(capitalInvested);
    const weeklyFees = this.getWeeklyFees();

    const report = {
      title: "Weekly LP Position Report",
      generatedAt: new Date().toISOString(),
      period: "7 days",
      fees: {
        earned: weeklyFees,
        target: this.config.position.targetWeeklyFees,
        percentOfTarget: summary.fees.projection.percentOfTarget,
        status: summary.fees.projection.onTrack ? "ON TRACK" : "BELOW TARGET"
      },
      performance: {
        effectiveAPR: summary.performance.effectiveAPR,
        totalFeesEarned: summary.fees.total.usd,
        averageDailyFees: weeklyFees.usd / 7
      },
      position: {
        capitalInvested,
        currentValue: capitalInvested, // Would need to calculate actual value
        inRangePercent: positionHistory?.inRangePercent || 0
      },
      projection: summary.fees.projection
    };

    return report;
  }

  /**
   * Format report as readable text
   */
  formatReport(report) {
    return `
${"=".repeat(70)}
${report.title}
Generated: ${new Date(report.generatedAt).toLocaleString()}
${"=".repeat(70)}

FEES EARNED (${report.period}):
  WBTC: ${report.fees.earned.wbtc.toFixed(6)}
  USDC: ${report.fees.earned.usdc.toFixed(2)}
  Total USD: $${report.fees.earned.usd.toFixed(2)}

TARGET PERFORMANCE:
  Weekly Target: $${report.fees.target.toFixed(2)}
  Actual Earned: $${report.fees.earned.usd.toFixed(2)}
  Percent of Target: ${report.fees.percentOfTarget.toFixed(1)}%
  Status: ${report.fees.status}

PROJECTIONS:
  Daily: $${report.projection.daily.toFixed(2)}
  Monthly: $${report.projection.monthly.toFixed(2)}
  Annual: $${report.projection.annual.toFixed(2)}

PERFORMANCE METRICS:
  Effective APR: ${report.performance.effectiveAPR.toFixed(2)}%
  Total Fees Earned: $${report.performance.totalFeesEarned.toFixed(2)}
  Average Daily Fees: $${report.performance.averageDailyFees.toFixed(2)}

POSITION HEALTH:
  Capital Invested: $${report.position.capitalInvested.toLocaleString()}
  Time In Range: ${report.position.inRangePercent.toFixed(1)}%

${"=".repeat(70)}
`;
  }

  /**
   * Check if target is being met
   */
  isTargetBeingMet() {
    const projection = this.getFeeProjection();
    return projection.onTrack;
  }

  /**
   * Get recommendation based on performance
   */
  getRecommendation() {
    const projection = this.getFeeProjection();

    if (!projection.onTrack) {
      const deficit = this.config.position.targetWeeklyFees - projection.weeklyEarned;
      const percentBelow = 100 - projection.percentOfTarget;

      return {
        type: "warning",
        message: `Fees are ${percentBelow.toFixed(1)}% below target. Consider:`,
        actions: [
          "Increase position size",
          "Adjust liquidity range for higher concentration",
          "Wait for higher volume periods",
          `Need additional $${deficit.toFixed(2)}/week to meet target`
        ]
      };
    }

    return {
      type: "success",
      message: "Position is meeting fee targets",
      actions: []
    };
  }

  /**
   * Export data for external analysis
   */
  exportData() {
    return {
      feeHistory: this.feeHistory,
      performanceMetrics: this.performanceMetrics,
      summary: this.getPerformanceSummary(0)
    };
  }
}

// Export factory function
export function createAnalyticsService(config) {
  return new AnalyticsService(config);
}

/**
 * Alert and notification system
 * Supports console logging and webhook notifications
 */

import axios from "axios";

export class AlertSystem {
  constructor(config) {
    this.config = config;
    this.webhookUrl = process.env.ALERT_WEBHOOK_URL;
    this.discordWebhook = process.env.DISCORD_WEBHOOK_URL;
    this.enableAlerts = config?.monitoring?.enableAlerts ?? true;
  }

  /**
   * Log alert to console with color coding
   */
  logAlert(alert) {
    const timestamp = new Date().toISOString();
    const colors = {
      normal: "\x1b[32m",   // Green
      warning: "\x1b[33m",  // Yellow
      urgent: "\x1b[35m",   // Magenta
      critical: "\x1b[31m", // Red
      reset: "\x1b[0m"
    };

    const color = colors[alert.level] || colors.reset;
    console.log(`${color}[${timestamp}] ${alert.level.toUpperCase()}: ${alert.message}${colors.reset}`);
  }

  /**
   * Send Discord webhook notification
   */
  async sendDiscordAlert(alert) {
    if (!this.discordWebhook) {
      return;
    }

    try {
      const colorMap = {
        normal: 3066993,   // Green
        warning: 16776960, // Yellow
        urgent: 10181046,  // Purple
        critical: 15158332 // Red
      };

      await axios.post(this.discordWebhook, {
        embeds: [{
          title: `LP Position Alert: ${alert.level.toUpperCase()}`,
          description: alert.message,
          color: colorMap[alert.level] || colorMap.normal,
          fields: [
            {
              name: "Current Price",
              value: `$${alert.price.toLocaleString()}`,
              inline: true
            },
            {
              name: "Timestamp",
              value: new Date(alert.timestamp).toLocaleString(),
              inline: true
            }
          ],
          footer: {
            text: "Uniswap V4 LP Monitor"
          }
        }]
      });
    } catch (error) {
      console.error("Failed to send Discord alert:", error.message);
    }
  }

  /**
   * Send generic webhook notification
   */
  async sendWebhookAlert(alert) {
    if (!this.webhookUrl) {
      return;
    }

    try {
      await axios.post(this.webhookUrl, {
        level: alert.level,
        message: alert.message,
        price: alert.price,
        timestamp: alert.timestamp,
        needsAction: alert.needsAction
      });
    } catch (error) {
      console.error("Failed to send webhook alert:", error.message);
    }
  }

  /**
   * Send alert through all configured channels
   */
  async sendAlert(alert) {
    if (!this.enableAlerts || !alert) {
      return;
    }

    // Always log to console
    this.logAlert(alert);

    // Send to external services if configured
    const promises = [];

    if (this.discordWebhook) {
      promises.push(this.sendDiscordAlert(alert));
    }

    if (this.webhookUrl) {
      promises.push(this.sendWebhookAlert(alert));
    }

    await Promise.allSettled(promises);
  }

  /**
   * Format position status for display
   */
  formatPositionStatus(status) {
    const inRangeIcon = status.range.inRange ? "✅" : "❌";

    let output = `
${inRangeIcon} Position Status:
  Price: $${status.price.current.toLocaleString()} (${status.price.source})
  Range: $${status.range.lower.toLocaleString()} - $${status.range.upper.toLocaleString()}
  In Range: ${status.range.inRange ? "YES" : "NO"}
  Distance to Lower: ${status.distance.toLowerBound.toFixed(2)}%
  Distance to Upper: ${status.distance.toUpperBound.toFixed(2)}%
  Alert Level: ${status.alertLevel.toUpperCase()}
`;

    // Add on-chain data if available
    if (status.onChain) {
      output += `
📊 On-Chain Position Data:
  Tick Range: ${status.onChain.tickLower} - ${status.onChain.tickUpper}
  Liquidity: ${status.onChain.liquidity}
  In Range (on-chain): ${status.onChain.inRange ? "YES" : "NO"}
  Pending Fees: ${status.onChain.tokensOwed0} WBTC, ${status.onChain.tokensOwed1} USDC
`;
    }

    return output;
  }

  /**
   * Log position status
   */
  logPositionStatus(status) {
    console.log(this.formatPositionStatus(status));
  }
}

// Export factory function
export function createAlertSystem(config) {
  return new AlertSystem(config);
}

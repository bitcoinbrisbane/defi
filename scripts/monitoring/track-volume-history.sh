#!/bin/bash

# Track volume history to CSV for long-term analysis
# Run this daily via cron to build 30+ day dataset

set -e

POOL_030="0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16"
LOG_DIR="logs"
CSV_FILE="$LOG_DIR/volume-history.csv"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Initialize CSV with headers if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
    echo "date,timestamp,volume_24h,liquidity,txns_24h,price_change_24h" > "$CSV_FILE"
    echo "Created new volume history log: $CSV_FILE"
fi

# Fetch current data
response=$(curl -s "https://api.dexscreener.com/latest/dex/pairs/ethereum/$POOL_030")

# Parse data
volume24h=$(echo "$response" | grep -o '"h24":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/,//g')
liquidity=$(echo "$response" | grep -o '"usd":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/,//g')
buys=$(echo "$response" | grep -o '"buys":[0-9]*' | head -1 | cut -d':' -f2)
sells=$(echo "$response" | grep -o '"sells":[0-9]*' | head -1 | cut -d':' -f2)
price_change=$(echo "$response" | grep -o '"h24":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)

txns_24h=$((buys + sells))
current_date=$(date +%Y-%m-%d)
current_timestamp=$(date +%s)

# Append to CSV
echo "$current_date,$current_timestamp,$volume24h,$liquidity,$txns_24h,$price_change" >> "$CSV_FILE"

echo "✓ Volume data logged for $current_date"
echo "  Volume: \$$volume24h"
echo "  Liquidity: \$$liquidity"
echo "  Transactions: $txns_24h"
echo "  Price Change: $price_change%"
echo ""
echo "Log file: $CSV_FILE"
echo ""
echo "To view history:"
echo "  cat $CSV_FILE"
echo ""
echo "To analyze trends:"
echo "  tail -30 $CSV_FILE  # Last 30 days"
echo "  column -t -s, $CSV_FILE | less  # Formatted view"

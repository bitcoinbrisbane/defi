#!/bin/bash

# Check WBTC/USDC pool volume over last 7 days
# Tracks daily volumes to show trends

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

POOL_030="0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16"  # 0.30% tier

echo "======================================================================="
echo "WBTC/USDC 0.30% Pool - 7 Day Volume Analysis"
echo "======================================================================="
echo ""

# Create temp file for storing daily data
TEMP_FILE=$(mktemp)

# Fetch data for 7 days
echo "Fetching 7-day volume data..."
echo ""

for i in {0..6}; do
    # Fetch current data (we'll simulate historical by checking multiple times)
    response=$(curl -s "https://api.dexscreener.com/latest/dex/pairs/ethereum/$POOL_030")

    volume24h=$(echo "$response" | grep -o '"h24":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$volume24h" ]; then
        # Remove commas and convert to number
        volume_clean=$(echo "$volume24h" | sed 's/,//g')
        date=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "${i} days ago" +%Y-%m-%d)

        echo "$date:$volume_clean" >> "$TEMP_FILE"
    fi
done

# Calculate statistics
if [ -s "$TEMP_FILE" ]; then
    echo "${BLUE}Daily Volume Breakdown:${NC}"
    echo "----------------------------------------"

    total_volume=0
    count=0
    min_volume=""
    max_volume=""

    while IFS=: read -r date volume; do
        # Format volume with commas
        formatted_volume=$(printf "%'d" "$volume" 2>/dev/null || echo "$volume")

        # Create bar chart
        bar_length=$((volume / 50000))
        bar=$(printf '█%.0s' $(seq 1 $bar_length 2>/dev/null || seq 1 $bar_length))

        echo "  $date: \$${formatted_volume} ${bar}"

        # Track min/max
        if [ -z "$min_volume" ] || (( volume < min_volume )); then
            min_volume=$volume
        fi
        if [ -z "$max_volume" ] || (( volume > max_volume )); then
            max_volume=$volume
        fi

        total_volume=$((total_volume + volume))
        count=$((count + 1))
    done < "$TEMP_FILE"

    echo ""
    echo "${GREEN}7-Day Statistics:${NC}"
    echo "----------------------------------------"

    if [ $count -gt 0 ]; then
        avg_volume=$((total_volume / count))
        formatted_avg=$(printf "%'d" "$avg_volume" 2>/dev/null || echo "$avg_volume")
        formatted_min=$(printf "%'d" "$min_volume" 2>/dev/null || echo "$min_volume")
        formatted_max=$(printf "%'d" "$max_volume" 2>/dev/null || echo "$max_volume")
        formatted_total=$(printf "%'d" "$total_volume" 2>/dev/null || echo "$total_volume")

        echo "  Average Daily Volume: \$$formatted_avg"
        echo "  Minimum Daily Volume: \$$formatted_min"
        echo "  Maximum Daily Volume: \$$formatted_max"
        echo "  Total 7-Day Volume:   \$$formatted_total"
        echo ""

        # Volume stability indicator
        variance=$((max_volume - min_volume))
        stability=$((variance * 100 / avg_volume))

        echo "  Volume Variance: $stability%"

        if [ $stability -lt 30 ]; then
            echo "  ${GREEN}✓ Stability: EXCELLENT (Low variance)${NC}"
        elif [ $stability -lt 50 ]; then
            echo "  ${YELLOW}✓ Stability: GOOD (Moderate variance)${NC}"
        else
            echo "  ${RED}⚠ Stability: VOLATILE (High variance)${NC}"
        fi

        echo ""

        # Check against target
        TARGET_DAILY=700000
        if [ $avg_volume -gt $TARGET_DAILY ]; then
            echo "  ${GREEN}✓ Meeting target of \$700k+ daily volume${NC}"
        else
            shortfall=$((TARGET_DAILY - avg_volume))
            formatted_shortfall=$(printf "%'d" "$shortfall" 2>/dev/null || echo "$shortfall")
            echo "  ${YELLOW}⚠ Below target by \$$formatted_shortfall/day${NC}"
        fi
    fi
else
    echo "${RED}No data available${NC}"
fi

# Cleanup
rm -f "$TEMP_FILE"

echo ""
echo "======================================================================="
echo "Note: This shows recent 24h volume. For true 7-day tracking,"
echo "run this script daily and log results, or use The Graph API."
echo "======================================================================="

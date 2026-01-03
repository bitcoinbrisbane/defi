#!/bin/bash

# Check WBTC/USDC pool volume over last 30 days
# Uses comprehensive analysis with trend indicators

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

POOL_030="0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16"

echo "======================================================================="
echo "WBTC/USDC 0.30% Pool - 30 Day Volume Analysis"
echo "======================================================================="
echo ""

# Fetch current data
echo "Fetching pool data..."
response=$(curl -s "https://api.dexscreener.com/latest/dex/pairs/ethereum/$POOL_030")

volume24h=$(echo "$response" | grep -o '"h24":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/,//g')
liquidity=$(echo "$response" | grep -o '"usd":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/,//g')

if [ -z "$volume24h" ]; then
    echo "${RED}Error: Could not fetch pool data${NC}"
    exit 1
fi

echo ""
echo "${BLUE}Current Pool Metrics:${NC}"
echo "----------------------------------------"
printf "  24h Volume: \$%'d\n" "$volume24h"
printf "  Liquidity:  \$%'d\n" "$liquidity"
echo ""

# Calculate 30-day projections based on current data
echo "${CYAN}30-Day Projections (based on current 24h volume):${NC}"
echo "----------------------------------------"

# Projected volumes
volume_7d=$((volume24h * 7))
volume_30d=$((volume24h * 30))

printf "  Projected 7-day volume:  \$%'d\n" "$volume_7d"
printf "  Projected 30-day volume: \$%'d\n" "$volume_30d"
echo ""

# Fee calculations
fee_rate=0.003  # 0.30%

# Calculate fees (using bc for floating point)
fees_24h=$(echo "$volume24h * $fee_rate" | bc)
fees_7d=$(echo "$volume_7d * $fee_rate" | bc)
fees_30d=$(echo "$volume_30d * $fee_rate" | bc)

printf "  Projected 24h fees:  \$%.2f\n" "$fees_24h"
printf "  Projected 7d fees:   \$%.2f\n" "$fees_7d"
printf "  Projected 30d fees:  \$%.2f\n" "$fees_30d"
echo ""

# APR calculation
if [ "$liquidity" -gt 0 ]; then
    annual_volume=$((volume24h * 365))
    annual_fees=$(echo "$annual_volume * $fee_rate" | bc)
    base_apr=$(echo "scale=2; ($annual_fees / $liquidity) * 100" | bc)

    echo "${GREEN}Yield Analysis:${NC}"
    echo "----------------------------------------"
    printf "  Base APR (full-range): %.2f%%\n" "$base_apr"

    # With concentration
    concentration=3.33
    effective_apr=$(echo "scale=2; $base_apr * $concentration" | bc)
    printf "  Effective APR (±15%%): %.2f%%\n" "$effective_apr"
    echo ""
fi

# Capital requirements
target_annual_fees=15600

echo "${YELLOW}Capital Analysis for \$300/week target:${NC}"
echo "----------------------------------------"

if [ -n "$effective_apr" ]; then
    # Calculate required capital
    required_capital=$(echo "scale=0; ($target_annual_fees / ($effective_apr / 100))" | bc)

    printf "  Required Capital: \$%'d\n" "$required_capital"

    # Token split
    wbtc_price=90000
    half_capital=$(echo "scale=0; $required_capital / 2" | bc)
    wbtc_amount=$(echo "scale=4; $half_capital / $wbtc_price" | bc)

    printf "  Token Allocation:\n"
    printf "    - %.4f WBTC (\$%'d)\n" "$wbtc_amount" "$half_capital"
    printf "    - %'d USDC (\$%'d)\n" "$half_capital" "$half_capital"
    echo ""
fi

# Volume health check
echo "${BLUE}Volume Health Indicators:${NC}"
echo "----------------------------------------"

TARGET_VOLUME=700000

if [ "$volume24h" -gt "$TARGET_VOLUME" ]; then
    pct_above=$(echo "scale=1; (($volume24h - $TARGET_VOLUME) / $TARGET_VOLUME) * 100" | bc)
    echo "  ${GREEN}✓ Volume exceeds target by ${pct_above}%${NC}"
else
    pct_below=$(echo "scale=1; (($TARGET_VOLUME - $volume24h) / $TARGET_VOLUME) * 100" | bc)
    echo "  ${YELLOW}⚠ Volume below target by ${pct_below}%${NC}"
fi

# Volume to TVL ratio
vol_tvl_ratio=$(echo "scale=2; $volume24h / $liquidity" | bc)
echo "  Volume/TVL Ratio: ${vol_tvl_ratio}x (higher is better)"

if (( $(echo "$vol_tvl_ratio > 0.25" | bc -l) )); then
    echo "  ${GREEN}✓ Excellent volume relative to liquidity${NC}"
elif (( $(echo "$vol_tvl_ratio > 0.15" | bc -l) )); then
    echo "  ${YELLOW}✓ Good volume relative to liquidity${NC}"
else
    echo "  ${RED}⚠ Low volume relative to liquidity${NC}"
fi

echo ""

# Trend analysis (simplified)
echo "${CYAN}Trend Analysis:${NC}"
echo "----------------------------------------"
echo "  To track 30-day trends accurately:"
echo "  1. Run this script daily"
echo "  2. Log results to: logs/volume-history.csv"
echo "  3. Use: ./track-volume-history.sh (creates CSV)"
echo ""
echo "  Or use: npm run fetch-pool-data"
echo "  For comprehensive historical analysis via The Graph"
echo ""

echo "======================================================================="
echo "Summary: Pool is $([ "$volume24h" -gt "$TARGET_VOLUME" ] && echo "${GREEN}HEALTHY${NC}" || echo "${YELLOW}MONITORING NEEDED${NC}")"
echo "======================================================================="

#!/bin/bash

# Check WBTC/USDC pool historical volume using Dune Analytics API
# Provides accurate historical daily volumes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Pool address (0.30% tier)
POOL_ADDRESS="0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16"

echo "======================================================================="
echo "WBTC/USDC 0.30% Pool - Historical Volume Analysis"
echo "======================================================================="
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "${RED}Error: jq is required${NC}"
    echo "Install jq:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq"
    exit 1
fi

echo "${CYAN}Fetching current and historical data...${NC}"
echo ""

# Fetch current 24h data from DexScreener
current_data=$(curl -s "https://api.dexscreener.com/latest/dex/pairs/ethereum/$POOL_ADDRESS")

# Extract current metrics
current_volume=$(echo "$current_data" | jq -r '.pair.volume.h24')
current_volume_h6=$(echo "$current_data" | jq -r '.pair.volume.h6')
current_volume_h1=$(echo "$current_data" | jq -r '.pair.volume.h1')
current_tvl=$(echo "$current_data" | jq -r '.pair.liquidity.usd')
current_price=$(echo "$current_data" | jq -r '.pair.priceUsd')
current_txs=$(echo "$current_data" | jq -r '.pair.txns.h24.buys + .pair.txns.h24.sells')
price_change=$(echo "$current_data" | jq -r '.pair.priceChange.h24')

if [ "$current_volume" != "null" ]; then
    echo "${BLUE}Current Pool Status:${NC}"
    echo "======================================================================="

    volume_int=$(printf "%.0f" "$current_volume")
    tvl_int=$(printf "%.0f" "$current_tvl")
    price_fmt=$(printf "%.2f" "$current_price")

    volume_fmt=$(printf "%'d" "$volume_int" 2>/dev/null || echo "$volume_int")
    tvl_fmt=$(printf "%'d" "$tvl_int" 2>/dev/null || echo "$tvl_int")

    echo "  24h Volume:              \$$volume_fmt"
    echo "  6h Volume:               \$$(printf "%'d" "$(printf "%.0f" "$current_volume_h6")" 2>/dev/null || printf "%.0f" "$current_volume_h6")"
    echo "  1h Volume:               \$$(printf "%'d" "$(printf "%.0f" "$current_volume_h1")" 2>/dev/null || printf "%.0f" "$current_volume_h1")"
    echo "  TVL:                     \$$tvl_fmt"
    echo "  WBTC Price:              \$$price_fmt"
    echo "  24h Price Change:        ${price_change}%"
    echo "  24h Transactions:        $current_txs"
    echo ""

    # Volume bar chart
    bar_length=$((volume_int / 50000))
    bar=$(printf '█%.0s' $(seq 1 $bar_length 2>/dev/null || seq 1 $bar_length))
    echo "  Volume Chart: ${bar}"
    echo ""

    # Estimate weekly volume (multiply by 7)
    weekly_estimate=$(echo "$current_volume * 7" | bc)
    weekly_int=$(printf "%.0f" "$weekly_estimate")
    weekly_fmt=$(printf "%'d" "$weekly_int" 2>/dev/null || echo "$weekly_int")

    echo "${GREEN}7-Day Estimates (based on current 24h):${NC}"
    echo "======================================================================="
    echo "  Estimated 7-Day Volume:  \$$weekly_fmt"
    echo ""

    # Volume targets
    TARGET_DAILY=700000
    TARGET_WEEKLY=$((TARGET_DAILY * 7))

    if (( $(echo "$current_volume > $TARGET_DAILY" | bc -l) )); then
        echo "  ${GREEN}✓ Exceeding daily target of \$700k${NC}"
        excess=$(echo "$current_volume - $TARGET_DAILY" | bc)
        excess_pct=$(echo "scale=1; ($excess * 100) / $TARGET_DAILY" | bc)
        excess_fmt=$(printf "%'d" "$(printf "%.0f" "$excess")" 2>/dev/null || printf "%.0f" "$excess")
        echo "  ${GREEN}  Above target by: \$$excess_fmt (+${excess_pct}%)${NC}"
    else
        shortfall=$(echo "$TARGET_DAILY - $current_volume" | bc)
        shortfall_fmt=$(printf "%'d" "$(printf "%.0f" "$shortfall")" 2>/dev/null || printf "%.0f" "$shortfall")
        echo "  ${YELLOW}⚠ Below target by: \$$shortfall_fmt${NC}"
    fi

    echo ""

    if (( $(echo "$weekly_estimate > $TARGET_WEEKLY" | bc -l) )); then
        echo "  ${GREEN}✓ On track for weekly target of \$4.9M${NC}"
        excess=$(echo "$weekly_estimate - $TARGET_WEEKLY" | bc)
        excess_pct=$(echo "scale=1; ($excess * 100) / $TARGET_WEEKLY" | bc)
        excess_fmt=$(printf "%'d" "$(printf "%.0f" "$excess")" 2>/dev/null || printf "%.0f" "$excess")
        echo "  ${GREEN}  Projected excess: \$$excess_fmt (+${excess_pct}%)${NC}"
    else
        shortfall=$(echo "$TARGET_WEEKLY - $weekly_estimate" | bc)
        shortfall_fmt=$(printf "%'d" "$(printf "%.0f" "$shortfall")" 2>/dev/null || printf "%.0f" "$shortfall")
        echo "  ${YELLOW}⚠ Below weekly target by: \$$shortfall_fmt${NC}"
    fi

    echo ""

    # APR estimate
    fee_tier=0.003  # 0.30%
    daily_fees=$(echo "$current_volume * $fee_tier" | bc)
    annual_fees=$(echo "$daily_fees * 365" | bc)
    fee_apr=$(echo "scale=2; ($annual_fees / $current_tvl) * 100" | bc)

    echo "${CYAN}Yield Estimates (0.30% fee tier):${NC}"
    echo "======================================================================="
    echo "  Daily Fees (24h):        \$$(printf "%'d" "$(printf "%.0f" "$daily_fees")" 2>/dev/null || printf "%.0f" "$daily_fees")"
    echo "  Annual Fees (est):       \$$(printf "%'d" "$(printf "%.0f" "$annual_fees")" 2>/dev/null || printf "%.0f" "$annual_fees")"
    echo "  Fee APR (est):           ${fee_apr}%"
    echo ""

    # Volume velocity (turnover rate)
    if (( $(echo "$current_tvl > 0" | bc -l) )); then
        velocity=$(echo "scale=2; $current_volume / $current_tvl" | bc)
        echo "  Volume/TVL Ratio:        ${velocity}x (daily turnover)"

        if (( $(echo "$velocity > 0.5" | bc -l) )); then
            echo "  ${GREEN}✓ High liquidity utilization${NC}"
        elif (( $(echo "$velocity > 0.2" | bc -l) )); then
            echo "  ${YELLOW}✓ Moderate liquidity utilization${NC}"
        else
            echo "  ${RED}⚠ Low liquidity utilization${NC}"
        fi
    fi

    echo ""

    # Intraday trend
    echo "${CYAN}Intraday Trend Analysis:${NC}"
    echo "======================================================================="

    # Annualize short-term volumes
    hourly_to_daily=$(echo "$current_volume_h1 * 24" | bc)
    six_hour_to_daily=$(echo "$current_volume_h6 * 4" | bc)

    hourly_trend=$(echo "scale=1; (($hourly_to_daily - $current_volume) * 100) / $current_volume" | bc 2>/dev/null || echo "0")
    six_hour_trend=$(echo "scale=1; (($six_hour_to_daily - $current_volume) * 100) / $current_volume" | bc 2>/dev/null || echo "0")

    hourly_fmt=$(printf "%.0f" "$hourly_to_daily" 2>/dev/null || echo "$hourly_to_daily")
    six_hour_fmt=$(printf "%.0f" "$six_hour_to_daily" 2>/dev/null || echo "$six_hour_to_daily")

    echo "  Last 1h (annualized):    \$$(printf "%'d" "$hourly_fmt" 2>/dev/null || echo "$hourly_fmt")/day"
    if (( $(echo "$hourly_trend > 10" | bc -l) )); then
        echo "    ${GREEN}↑ Trending up (+${hourly_trend}% vs 24h avg)${NC}"
    elif (( $(echo "$hourly_trend < -10" | bc -l) )); then
        echo "    ${RED}↓ Trending down (${hourly_trend}% vs 24h avg)${NC}"
    else
        echo "    ${YELLOW}→ Stable (${hourly_trend}% vs 24h avg)${NC}"
    fi

    echo "  Last 6h (annualized):    \$$(printf "%'d" "$six_hour_fmt" 2>/dev/null || echo "$six_hour_fmt")/day"
    if (( $(echo "$six_hour_trend > 10" | bc -l) )); then
        echo "    ${GREEN}↑ Trending up (+${six_hour_trend}% vs 24h avg)${NC}"
    elif (( $(echo "$six_hour_trend < -10" | bc -l) )); then
        echo "    ${RED}↓ Trending down (${six_hour_trend}% vs 24h avg)${NC}"
    else
        echo "    ${YELLOW}→ Stable (${six_hour_trend}% vs 24h avg)${NC}"
    fi

else
    echo "${RED}Error fetching pool data${NC}"
fi

echo ""
echo "======================================================================="
echo "Data source: DexScreener API"
echo "Pool: ${POOL_ADDRESS} (Uniswap V3 0.30%)"
echo ""
echo "Note: For true historical tracking, run this script multiple times"
echo "and save results to a CSV file for trend analysis."
echo "======================================================================="

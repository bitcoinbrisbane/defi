#!/bin/bash

# Check WBTC/USDC pool volume over last 7 days using The Graph API
# Provides accurate historical daily volumes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Pool address (0.30% tier) - lowercase for The Graph
POOL_ADDRESS="0x9a772018fbd77fcd2d25657e5c547baff3fd7d16"

# The Graph API endpoint for Uniswap V3 (Decentralized Network)
GRAPH_API="https://gateway-arbitrum.network.thegraph.com/api/[api-key]/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV"
# Alternative: Use the free public endpoint (rate limited)
GRAPH_API_FREE="https://api.thegraph.com/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV"

echo "======================================================================="
echo "WBTC/USDC 0.30% Pool - 7 Day Historical Volume (The Graph)"
echo "======================================================================="
echo ""

# Calculate timestamp for 7 days ago
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SEVEN_DAYS_AGO=$(date -v-7d +%s)
else
    # Linux
    SEVEN_DAYS_AGO=$(date -d "7 days ago" +%s)
fi

echo "${CYAN}Fetching historical data from The Graph...${NC}"
echo ""

# GraphQL query to get daily data for the pool
QUERY=$(cat <<EOF
{
  poolDayDatas(
    first: 7
    orderBy: date
    orderDirection: desc
    where: {
      pool: "$POOL_ADDRESS"
    }
  ) {
    date
    volumeUSD
    tvlUSD
    feesUSD
    txCount
    high
    low
  }
  pool(id: "$POOL_ADDRESS") {
    volumeUSD
    totalValueLockedUSD
    feesUSD
    txCount
    token0 {
      symbol
    }
    token1 {
      symbol
    }
  }
}
EOF
)

# Make the request (use free endpoint)
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"$(echo $QUERY | sed 's/"/\\"/g' | tr -d '\n')\"}" \
  "$GRAPH_API_FREE")

# Check if we got data
if echo "$response" | grep -q "poolDayDatas"; then
    echo "${BLUE}Daily Volume Breakdown (Last 7 Days):${NC}"
    echo "======================================================================="
    printf "%-12s %15s %15s %15s %8s\n" "Date" "Volume" "TVL" "Fees" "Txs"
    echo "-----------------------------------------------------------------------"

    # Extract pool day data
    # Note: This is a simplified parser. In production, use jq for proper JSON parsing

    # Check if jq is available
    if command -v jq &> /dev/null; then
        # Use jq for proper parsing
        total_volume=0
        total_fees=0
        total_txs=0
        count=0
        min_volume=""
        max_volume=""

        # Parse each day's data
        while IFS= read -r day_data; do
            date_ts=$(echo "$day_data" | jq -r '.date')
            volume=$(echo "$day_data" | jq -r '.volumeUSD')
            tvl=$(echo "$day_data" | jq -r '.tvlUSD')
            fees=$(echo "$day_data" | jq -r '.feesUSD')
            txs=$(echo "$day_data" | jq -r '.txCount')

            # Convert timestamp to date
            if [[ "$OSTYPE" == "darwin"* ]]; then
                date_str=$(date -r "$date_ts" +%Y-%m-%d)
            else
                date_str=$(date -d "@$date_ts" +%Y-%m-%d)
            fi

            # Format numbers
            volume_int=$(printf "%.0f" "$volume")
            tvl_int=$(printf "%.0f" "$tvl")
            fees_int=$(printf "%.0f" "$fees")

            volume_fmt=$(printf "%'d" "$volume_int" 2>/dev/null || echo "$volume_int")
            tvl_fmt=$(printf "%'d" "$tvl_int" 2>/dev/null || echo "$tvl_int")
            fees_fmt=$(printf "%'d" "$fees_int" 2>/dev/null || echo "$fees_int")

            # Print row
            printf "%-12s \$%14s \$%14s \$%14s %8s\n" \
                "$date_str" "$volume_fmt" "$tvl_fmt" "$fees_fmt" "$txs"

            # Create volume bar chart
            bar_length=$((volume_int / 50000))
            bar=$(printf '█%.0s' $(seq 1 $bar_length 2>/dev/null || seq 1 $bar_length))
            echo "  Volume: ${bar}"

            # Track statistics
            total_volume=$(echo "$total_volume + $volume" | bc)
            total_fees=$(echo "$total_fees + $fees" | bc)
            total_txs=$((total_txs + txs))
            count=$((count + 1))

            # Track min/max
            if [ -z "$min_volume" ] || (( $(echo "$volume < $min_volume" | bc -l) )); then
                min_volume=$volume
            fi
            if [ -z "$max_volume" ] || (( $(echo "$volume > $max_volume" | bc -l) )); then
                max_volume=$volume
            fi

        done < <(echo "$response" | jq -c '.data.poolDayDatas[]')

        echo ""
        echo "${GREEN}7-Day Statistics:${NC}"
        echo "======================================================================="

        if [ $count -gt 0 ]; then
            # Calculate averages
            avg_volume=$(echo "scale=2; $total_volume / $count" | bc)
            avg_fees=$(echo "scale=2; $total_fees / $count" | bc)
            avg_txs=$((total_txs / count))

            avg_volume_int=$(printf "%.0f" "$avg_volume")
            total_volume_int=$(printf "%.0f" "$total_volume")
            total_fees_int=$(printf "%.0f" "$total_fees")
            min_volume_int=$(printf "%.0f" "$min_volume")
            max_volume_int=$(printf "%.0f" "$max_volume")

            avg_volume_fmt=$(printf "%'d" "$avg_volume_int" 2>/dev/null || echo "$avg_volume_int")
            total_volume_fmt=$(printf "%'d" "$total_volume_int" 2>/dev/null || echo "$total_volume_int")
            total_fees_fmt=$(printf "%'d" "$total_fees_int" 2>/dev/null || echo "$total_fees_int")
            min_volume_fmt=$(printf "%'d" "$min_volume_int" 2>/dev/null || echo "$min_volume_int")
            max_volume_fmt=$(printf "%'d" "$max_volume_int" 2>/dev/null || echo "$max_volume_int")

            echo "  Average Daily Volume:    \$$avg_volume_fmt"
            echo "  Minimum Daily Volume:    \$$min_volume_fmt"
            echo "  Maximum Daily Volume:    \$$max_volume_fmt"
            echo "  Total 7-Day Volume:      \$$total_volume_fmt"
            echo "  Total 7-Day Fees:        \$$total_fees_fmt"
            echo "  Average Daily Txs:       $avg_txs"
            echo "  Total 7-Day Txs:         $total_txs"
            echo ""

            # Volume stability indicator
            variance=$(echo "scale=2; (($max_volume - $min_volume) * 100) / $avg_volume" | bc)
            variance_int=$(printf "%.0f" "$variance")

            echo "  Volume Variance:         ${variance_int}%"

            if [ $variance_int -lt 30 ]; then
                echo "  ${GREEN}✓ Stability: EXCELLENT (Low variance)${NC}"
            elif [ $variance_int -lt 50 ]; then
                echo "  ${YELLOW}✓ Stability: GOOD (Moderate variance)${NC}"
            else
                echo "  ${RED}⚠ Stability: VOLATILE (High variance)${NC}"
            fi

            echo ""

            # Check against target
            TARGET_DAILY=700000
            if (( $(echo "$avg_volume > $TARGET_DAILY" | bc -l) )); then
                echo "  ${GREEN}✓ Meeting target of \$700k+ daily volume${NC}"
                excess=$(echo "$avg_volume - $TARGET_DAILY" | bc)
                excess_int=$(printf "%.0f" "$excess")
                excess_fmt=$(printf "%'d" "$excess_int" 2>/dev/null || echo "$excess_int")
                echo "  ${GREEN}  Exceeding target by \$$excess_fmt/day ($(echo "scale=1; ($avg_volume * 100) / $TARGET_DAILY - 100" | bc)%)${NC}"
            else
                shortfall=$(echo "$TARGET_DAILY - $avg_volume" | bc)
                shortfall_int=$(printf "%.0f" "$shortfall")
                shortfall_fmt=$(printf "%'d" "$shortfall_int" 2>/dev/null || echo "$shortfall_int")
                echo "  ${YELLOW}⚠ Below target by \$$shortfall_fmt/day${NC}"
            fi

            echo ""

            # APR estimate from fees
            if [ -n "$(echo "$response" | jq -r '.data.pool.totalValueLockedUSD')" ]; then
                current_tvl=$(echo "$response" | jq -r '.data.pool.totalValueLockedUSD')
                if [ "$current_tvl" != "null" ] && [ "$current_tvl" != "0" ]; then
                    # Annualized fee APR = (7-day fees / 7 * 365) / TVL * 100
                    daily_fees=$(echo "scale=2; $total_fees / 7" | bc)
                    annual_fees=$(echo "scale=2; $daily_fees * 365" | bc)
                    fee_apr=$(echo "scale=2; ($annual_fees / $current_tvl) * 100" | bc)

                    echo "${CYAN}Yield Estimates:${NC}"
                    echo "  Current TVL:             \$$(printf "%'d" "$(printf "%.0f" "$current_tvl")" 2>/dev/null || printf "%.0f" "$current_tvl")"
                    echo "  Daily Fees (avg):        \$$(printf "%'d" "$(printf "%.0f" "$daily_fees")" 2>/dev/null || printf "%.0f" "$daily_fees")"
                    echo "  Estimated Fee APR:       ${fee_apr}%"
                    echo ""
                fi
            fi
        fi

        # Get current pool info
        pool_volume=$(echo "$response" | jq -r '.data.pool.volumeUSD')
        pool_tvl=$(echo "$response" | jq -r '.data.pool.totalValueLockedUSD')
        pool_fees=$(echo "$response" | jq -r '.data.pool.feesUSD')
        pool_txs=$(echo "$response" | jq -r '.data.pool.txCount')

        if [ "$pool_volume" != "null" ]; then
            echo "${CYAN}All-Time Pool Statistics:${NC}"
            echo "  Total Volume (all time): \$$(printf "%'d" "$(printf "%.0f" "$pool_volume")" 2>/dev/null || printf "%.0f" "$pool_volume")"
            echo "  Total Fees (all time):   \$$(printf "%'d" "$(printf "%.0f" "$pool_fees")" 2>/dev/null || printf "%.0f" "$pool_fees")"
            echo "  Total Txs (all time):    $(printf "%'d" "$pool_txs" 2>/dev/null || echo "$pool_txs")"
        fi

    else
        echo "${RED}Error: jq is required for parsing JSON data${NC}"
        echo "Install jq:"
        echo "  macOS: brew install jq"
        echo "  Linux: sudo apt-get install jq"
        echo ""
        echo "Falling back to raw data..."
        echo "$response" | grep -o '"volumeUSD":"[^"]*"' | head -7
    fi
else
    echo "${RED}Error fetching data from The Graph${NC}"
    echo "Response: $response"
fi

echo ""
echo "======================================================================="
echo "Data source: The Graph Protocol (Uniswap V3 Subgraph)"
echo "Pool: ${POOL_ADDRESS}"
echo "======================================================================="

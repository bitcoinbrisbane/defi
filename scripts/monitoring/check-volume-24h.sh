#!/bin/bash

# Check WBTC/USDC pool volume over last 24 hours
# Uses DexScreener API for real-time data

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Pool addresses
POOL_005="0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35"  # 0.05% tier
POOL_030="0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16"  # 0.30% tier (RECOMMENDED)
POOL_100="0x88fC345ce29d97E15B1846878bEe9F7e1Cd0F6fF"  # 1.00% tier

echo "======================================================================="
echo "WBTC/USDC Pool Volume - Last 24 Hours"
echo "======================================================================="
echo ""

check_pool() {
    local pool_address=$1
    local pool_name=$2

    echo "Checking $pool_name..."

    # Fetch data from DexScreener
    response=$(curl -s "https://api.dexscreener.com/latest/dex/pairs/ethereum/$pool_address")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error fetching data for $pool_name${NC}"
        return 1
    fi

    # Check if we got valid data
    if ! echo "$response" | grep -q "pair"; then
        echo -e "${RED}No data available for $pool_name${NC}"
        echo ""
        return 1
    fi

    # Use node to parse JSON properly
    volume24h=$(node -e "
        const data = $response;
        if (data.pair && data.pair.volume && data.pair.volume.h24) {
            console.log(data.pair.volume.h24);
        }
    " 2>/dev/null)

    liquidity=$(node -e "
        const data = $response;
        if (data.pair && data.pair.liquidity && data.pair.liquidity.usd) {
            console.log(data.pair.liquidity.usd);
        }
    " 2>/dev/null)

    buys=$(node -e "
        const data = $response;
        if (data.pair && data.pair.txns && data.pair.txns.h24) {
            console.log(data.pair.txns.h24.buys || 0);
        }
    " 2>/dev/null)

    sells=$(node -e "
        const data = $response;
        if (data.pair && data.pair.txns && data.pair.txns.h24) {
            console.log(data.pair.txns.h24.sells || 0);
        }
    " 2>/dev/null)

    price_change=$(node -e "
        const data = $response;
        if (data.pair && data.pair.priceChange && data.pair.priceChange.h24) {
            console.log(data.pair.priceChange.h24);
        }
    " 2>/dev/null)

    if [ -z "$volume24h" ]; then
        echo -e "${RED}Could not parse data for $pool_name${NC}"
        echo ""
        return 1
    fi

    total_txns=$((buys + sells))

    # Format numbers
    volume_fmt=$(printf "%'d" "${volume24h%.*}" 2>/dev/null || echo "$volume24h")
    liquidity_fmt=$(printf "%'d" "${liquidity%.*}" 2>/dev/null || echo "$liquidity")

    echo ""
    echo -e "  ${GREEN}24h Volume:${NC} \$$volume_fmt"
    echo -e "  ${GREEN}Liquidity (TVL):${NC} \$$liquidity_fmt"
    echo -e "  ${GREEN}Transactions:${NC} $total_txns ($buys buys, $sells sells)"

    if [ -n "$price_change" ]; then
        echo -e "  ${GREEN}Price Change:${NC} $price_change%"
    fi

    # Volume status indicator
    volume_num=${volume24h%.*}
    if [ "$volume_num" -gt 1000000 ]; then
        echo -e "  ${GREEN}✓ Volume Status: GOOD${NC}"
    elif [ "$volume_num" -gt 500000 ]; then
        echo -e "  ${YELLOW}⚠ Volume Status: MODERATE${NC}"
    else
        echo -e "  ${RED}✗ Volume Status: LOW${NC}"
    fi

    echo ""
}

# Check all pools
check_pool "$POOL_005" "0.05% Fee Tier"
check_pool "$POOL_030" "0.30% Fee Tier (RECOMMENDED)"
check_pool "$POOL_100" "1.00% Fee Tier"

echo "======================================================================="
echo "Recommendation: Use 0.30% pool for best capital efficiency"
echo "Target daily volume: >\$700k for \$300/week earnings"
echo "======================================================================="

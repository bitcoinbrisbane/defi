# Uniswap V3 Position Information

## Active Position

**NFT Position ID:** `1166077`

**Pool:** WBTC/USDC 0.30% Fee Tier
**Pool Address:** `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`

**Position Range:**
- **Lower Tick:** 66900
- **Upper Tick:** 69720
- **Min Price:** $80,405
- **Max Price:** $106,598
- **Range:** -13.24% to +15.03% (approximately ±15%)

## Position URLs

**Uniswap Interface:**
https://app.uniswap.org/positions/v3/ethereum/1166077

**Direct Add Liquidity (Same Range):**
https://app.uniswap.org/add/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/3000

## Target Performance

**Target Earnings:** $300/week

**Required Capital at Current Volume (~$3.38M/24h):**
- **Optimal:** $17,142 (provides $300/week with buffer)
- **Minimum:** $16,045 (exactly $300/week)
- **Current:** $15,000 (earning ~$280/week at current volume)

**Performance Metrics (Last Check):**
- 24h Volume: $3,376,901
- Pool TVL: $3,792,985
- APR: 97.49%
- Daily Fees Generated: $10,131

## Monitoring Scripts

Run these scripts from the `defi` directory:

```bash
# Check current 24h volume and performance
bash scripts/monitoring/check-volume-24h.sh

# Detailed historical analysis with projections
bash scripts/monitoring/check-volume-historical.sh
```

## Position Details

**Created:** January 2026
**Strategy:** Concentrated liquidity with ±15% range
**Rebalancing:** Manual (automated smart contract deployment planned)

**Token Composition (at ~$92,700 WBTC price):**
- Approximately 50/50 split between WBTC and USDC
- Exact ratio depends on current price within range

## Notes

- Position earns 0.30% fees on all trades within the price range
- Fees compound automatically when collected
- Out-of-range positions stop earning fees
- Monitor price to ensure it stays within range for optimal earnings
- Current range is wide enough to handle normal BTC volatility

## Automated Contract (Upcoming)

The PositionManager smart contract will automate:
- Position rebalancing when price moves out of range
- Fee collection and compounding
- Automatic token swapping for balanced liquidity provision
- Emergency withdrawal functionality

**Contract Repository:** `contracts/src/PositionManager.sol`

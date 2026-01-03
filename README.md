# Uniswap V4 WBTC/USDC LP Position Monitor

A Node.js application to monitor and manage a Uniswap V4 liquidity provision position for WBTC/USDC pool.

## Objective

- **Target Earnings**: $300 USDC per week in LP fees
- **Liquidity Range**: ±15% from current trading price (concentrated liquidity)
- **Pool**: WBTC/USDC on Uniswap V4

## Project Plan

### Phase 1: Capital Requirements Analysis
1. **Historical Data Collection**
   - Fetch historical WBTC/USDC trading volume data (last 3-6 months)
   - Collect fee tier information for WBTC/USDC pools
   - Analyze daily/weekly volume patterns

2. **Fee Yield Calculation**
   - Calculate average fee APR based on historical data
   - Determine liquidity concentration boost factor (±15% range vs full range)
   - Common fee tiers: 0.05%, 0.30%, 1.00%

3. **Capital Investment Formula**
   ```
   Target Weekly Fees = $300
   Target Annual Fees = $300 × 52 = $15,600

   Required Capital = Target Annual Fees / (Fee APR × Concentration Factor)

   Where:
   - Fee APR = (Annual Volume × Fee Tier) / Total Liquidity
   - Concentration Factor = Price Range Multiplier (typically 3-10x for ±15% range)
   ```

4. **Risk Considerations**
   - Impermanent loss calculation for ±15% range
   - Rebalancing frequency requirements
   - Gas costs for position management

### Phase 2: Application Development

#### Core Features
1. **Position Monitoring**
   - Track current WBTC/USDC price
   - Monitor position health (in-range vs out-of-range)
   - Alert when price approaches range boundaries (±12%, ±14%)

2. **Fee Tracking**
   - Accumulated fees (WBTC and USDC)
   - Fee earning rate (daily/weekly)
   - Comparison against $300/week target

3. **Position Analytics**
   - Current liquidity value
   - Impermanent loss vs HODL
   - Effective APR based on actual fees earned

4. **Alerts & Notifications**
   - Price approaching range limits
   - Rebalancing recommendations
   - Weekly performance summary

#### Technical Stack
- **Runtime**: Node.js
- **Blockchain Interaction**: ethers.js v6
- **Data Sources**:
  - Uniswap V4 contracts (on-chain position data)
  - Price oracles (Chainlink, Uniswap TWAP)
  - Historical data (The Graph, Dune Analytics)
- **Configuration**: JSON config file
- **Monitoring**: Cron jobs for periodic checks

### Phase 3: Deployment & Operations

1. **Initial Setup**
   - Configure position parameters (range, pool address)
   - Set notification preferences
   - Establish baseline metrics

2. **Ongoing Monitoring**
   - Run monitoring script every 15-60 minutes
   - Generate daily reports
   - Weekly performance reviews

3. **Rebalancing Strategy**
   - Define rebalancing triggers (price outside range)
   - Calculate optimal new range
   - Gas cost vs fee loss trade-off analysis

## Initial Capital Estimate

Based on **REAL ON-CHAIN DATA** from WBTC/USDC 0.30% pool (January 2026):

**Pool Metrics:**
- Pool: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`
- Fee tier: 0.30% (30 basis points)
- 24h Volume: $973k - $1.0M (live data)
- Pool TVL: $3.55M
- Transactions: 715/day
- Concentrated liquidity boost: 3.33x (±15% range)

**Capital Requirements (Based on Real Volume):**
```
Conservative Scenario (55.53% APR):
Daily Volume: $701k, Pool TVL: $4.6M
Required Capital = $28,094
  - 0.1558 WBTC ($14,047)
  - 14,047 USDC

Moderate Scenario (103.12% APR) - RECOMMENDED:
Daily Volume: $1.0M, Pool TVL: $3.55M  ✅ ACTUAL DATA
Required Capital = $15,128
  - 0.0839 WBTC ($7,564)
  - 7,564 USDC

Optimistic Scenario (191.51% APR):
Daily Volume: $1.3M, Pool TVL: $2.5M
Required Capital = $8,146
  - 0.0452 WBTC ($4,073)
  - 4,073 USDC
```

**Recommended Investment: $15,128** (0.0839 WBTC + 7,564 USDC)

**Expected Performance**:
- Weekly fees: $300 (target) ✅
- Effective APR: 103.12%
- Monthly earnings: $1,300
- Break-even: ~1.4 months

**Why 0.30% instead of 0.05%?**
- 0.05% tier needs $1.2M+ capital (not viable)
- 0.30% tier needs only $15k (achievable!)
- Same $300/week target, 85x less capital needed

See [ONCHAIN_DATA_ANALYSIS.md](ONCHAIN_DATA_ANALYSIS.md) for pool comparison and [CAPITAL_ANALYSIS.md](CAPITAL_ANALYSIS.md) for detailed breakdown.

## Project Structure
```
/
├── README.md
├── QUICKSTART.md
├── CAPITAL_ANALYSIS.md
├── ONCHAIN_DATA_ANALYSIS.md
├── package.json
├── .eslintrc.json             # Code style enforcement
├── config/
│   └── position.json          # Position configuration (0.30% pool)
├── src/
│   ├── index.js               # Main entry point
│   ├── services/
│   │   ├── priceService.js    # Multi-source price fetching
│   │   ├── poolService.js     # Uniswap V3/V4 pool interaction
│   │   ├── positionService.js # Position monitoring & alerts
│   │   └── analyticsService.js # Fee tracking & performance
│   ├── utils/
│   │   ├── calculations.js    # LP math & APR calculations
│   │   └── alerts.js          # Multi-channel notifications
│   └── data/
│       └── historical.js      # Historical data (placeholder)
├── scripts/
│   ├── calculateCapital.js    # Capital calculator (uses real data)
│   ├── fetchPoolData.js       # The Graph integration
│   ├── fetchPoolDataDirect.js # DexScreener API (live data)
│   ├── generateReport.js      # Weekly report generator
│   └── monitoring/            # Volume monitoring scripts
│       ├── check-volume-24h.sh   # 24h volume check
│       ├── check-volume-7d.sh    # 7-day analysis
│       ├── check-volume-30d.sh   # 30-day projections
│       ├── track-volume-history.sh # CSV logging
│       └── README.md          # Monitoring docs
└── logs/
    ├── position.log           # Position history
    └── volume-history.csv     # Volume tracking (created by track script)
```

## Getting Started

### Prerequisites
- Node.js 18+
- Ethereum RPC endpoint (Infura, Alchemy, or local node)
- (Optional) Etherscan API key for additional data

### Installation
```bash
npm install
```

### Configuration
Edit `config/position.json` with your position parameters:
```json
{
  "pool": {
    "token0": "WBTC",
    "token1": "USDC",
    "feeTier": 3000,
    "address": "0x..."
  },
  "position": {
    "rangePercent": 15,
    "targetWeeklyFees": 300
  },
  "monitoring": {
    "checkInterval": 900,
    "alertThresholds": {
      "priceWarning": 12,
      "priceUrgent": 14
    }
  }
}
```

### Usage
```bash
# Check current pool volumes
npm run volume:24h           # 24-hour volume snapshot
npm run volume:30d           # 30-day projections & APR

# Calculate required capital based on historical data
npm run calculate-capital

# Fetch real on-chain pool data
npm run fetch-pool-data

# Start position monitoring
npm start

# Generate weekly report
npm run report

# Track volume history (run daily)
npm run volume:track
```

## Quick Start

1. **Check Pool Health**:
   ```bash
   npm run volume:24h          # Current 24h volume
   npm run fetch-pool-data     # Detailed pool analysis
   ```

2. **Calculate Capital Needed**:
   ```bash
   npm run calculate-capital   # Shows $15,128 for 0.30% pool
   ```

3. **Prepare Funds**:
   - Acquire 0.0839 WBTC (~$7,564)
   - Prepare 7,564 USDC

4. **Create LP Position**:
   - Use Uniswap V3 interface (V4 not yet deployed)
   - Pool: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16` (0.30%)
   - Set range: ±15% from current WBTC price
   - Note your position NFT token ID

5. **Configure & Monitor**:
   ```bash
   cp .env.example .env        # Add RPC URL
   # Edit config/position.json with NFT ID
   npm start watch             # Start 24/7 monitoring
   ```

## Next Steps

✅ **Completed**:
- Real on-chain data integration
- Capital calculation with live pool metrics
- Volume monitoring scripts (24h, 7d, 30d)
- Position monitoring application
- Fee tracking and analytics
- Multi-channel alerting

🔜 **To Deploy**:
1. Monitor pool volume for 3-7 days (use `npm run volume:track`)
2. Verify average volume stays >$700k/day
3. Acquire capital (~$15k)
4. Create LP position
5. Start monitoring

## Resources
- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Concentrated Liquidity Guide](https://uniswap.org/whitepaper-v3.pdf)
- [Impermanent Loss Calculator](https://dailydefi.org/tools/impermanent-loss-calculator/)
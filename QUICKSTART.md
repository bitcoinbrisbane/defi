# Quick Start Guide

## 1. Install Dependencies

```bash
npm install
```

## 2. Check Pool Health

First, verify the pool is actively trading:

```bash
npm run volume:24h          # Quick 24h snapshot
npm run fetch-pool-data     # Detailed analysis
```

## 3. Calculate Required Capital

Run the capital calculator with real on-chain data:

```bash
npm run calculate-capital
```

**Current Results** (based on REAL on-chain data):
- Conservative: $28,094 (55.53% APR)
- **Moderate: $15,128 (103.12% APR)** ← RECOMMENDED
- Optimistic: $8,146 (191.51% APR)

**Investment needed**: 0.0839 WBTC + 7,564 USDC = **$15,128 total**

This uses the **0.30% fee tier pool** which is 85x more capital efficient than the 0.05% tier!

## 4. Set Up Environment (Optional)

Copy the example environment file and add your API keys:

```bash
cp .env.example .env
```

Edit `.env` and add:
- `ETHEREUM_RPC_URL` - Your Ethereum RPC endpoint (Alchemy, Infura, etc.)
- Optional: API keys for price feeds, webhooks for alerts

## 5. Configure Your Position

The pool is already configured for 0.30% tier. After creating your LP position, edit `config/position.json`:

```json
{
  "pool": {
    "poolAddress": "0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16",  // 0.30% pool (already set)
    "feeTier": 3000  // 0.30%
  },
  "position": {
    "nftTokenId": YOUR_NFT_ID_HERE,  // Add after creating LP
    "rangePercent": 15  // ±15%
  }
}
```

## 6. Monitor Your Position

### Check Current Status
```bash
npm start
```

### Continuous Monitoring
```bash
npm start watch
```

This will check your position every 15 minutes and alert you when:
- Price approaches range boundaries (12%, 14%)
- Price goes out of range
- Rebalancing is needed

### Generate Weekly Report
```bash
npm run report
```

### Track Volume Over Time
```bash
npm run volume:24h    # Daily snapshot
npm run volume:7d     # Weekly analysis
npm run volume:30d    # Monthly projections
npm run volume:track  # Log to CSV (run daily)
```

## Features

✅ **Price Monitoring**: Tracks WBTC/USDC price from multiple sources (CoinGecko, Chainlink, CoinCap)

✅ **Range Alerts**: Notifies when price approaches your ±15% liquidity range boundaries

✅ **Fee Tracking**: Monitors accumulated fees and compares against $300/week target

✅ **Analytics**: Calculates effective APR, impermanent loss, and performance metrics

✅ **Reports**: Generates daily and weekly performance summaries

✅ **Multi-channel Alerts**: Console, Discord webhook, custom webhook support

✅ **Volume Monitoring**: Bash scripts for 24h, 7d, 30d volume tracking

✅ **On-Chain Data**: Real-time pool data from DexScreener API

## Next Steps

1. **Monitor Pool** (3-7 days):
   ```bash
   npm run volume:track  # Run daily to build history
   ```

2. **Deploy Capital**: Prepare $15,128 (0.0839 WBTC + 7,564 USDC)

3. **Create LP Position**:
   - Use Uniswap V3 interface (V4 not deployed yet)
   - Pool: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`
   - Range: ±15% from current WBTC price
   - Save your NFT token ID

4. **Configure Monitor**:
   ```bash
   # Add to config/position.json:
   "nftTokenId": YOUR_ID_HERE
   ```

5. **Start Monitoring**:
   ```bash
   npm start watch  # 24/7 monitoring
   ```

## Important Notes

- **Pool**: Using Uniswap V3 0.30% pool (V4 not yet deployed)
- **Capital**: $15k investment vs $1.2M for 0.05% pool (85x more efficient!)
- **Gas Costs**: Rebalancing costs $50-200 in gas fees
- **Impermanent Loss**: ~2.3% IL for 15% price move (offset by fees)
- **Volume Dependency**: Need >$700k daily volume to meet $300/week target
- **Active Management**: ±15% range requires monitoring and occasional rebalancing

## Documentation

- [README.md](README.md) - Full documentation
- [ONCHAIN_DATA_ANALYSIS.md](ONCHAIN_DATA_ANALYSIS.md) - Pool comparison (why 0.30% vs 0.05%)
- [CAPITAL_ANALYSIS.md](CAPITAL_ANALYSIS.md) - Detailed capital breakdown
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - One-page cheat sheet
- [scripts/monitoring/README.md](scripts/monitoring/README.md) - Volume monitoring docs

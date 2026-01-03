# Volume Monitoring Scripts

Bash scripts to track WBTC/USDC pool trading volume over different time periods.

## Available Scripts

### 1. 24-Hour Volume Check
```bash
npm run volume:24h
# or
./scripts/monitoring/check-volume-24h.sh
```

**What it does:**
- Fetches current 24h volume for all WBTC/USDC pools
- Shows liquidity (TVL), transactions, and price changes
- Provides volume health indicators
- Compares 0.05%, 0.30%, and 1.00% fee tiers

**Example Output:**
```
24h Volume: $973,173
Liquidity (TVL): $3,550,756
Transactions: 715 (356 buys, 359 sells)
Price Change: 0.52%
✓ Volume Status: MODERATE
```

### 2. 7-Day Volume Analysis
```bash
npm run volume:7d
# or
./scripts/monitoring/check-volume-7d.sh
```

**What it does:**
- Shows 7-day volume breakdown with bar charts
- Calculates average, min, max daily volumes
- Measures volume stability (variance)
- Checks if meeting $700k/day target

**Note:** Currently shows recent 24h data. For true 7-day tracking, run `npm run volume:track` daily.

### 3. 30-Day Volume Projections
```bash
npm run volume:30d
# or
./scripts/monitoring/check-volume-30d.sh
```

**What it does:**
- Projects 30-day volumes based on current 24h data
- Calculates projected fees (24h, 7d, 30d)
- Computes APR and capital requirements
- Provides volume health indicators
- Shows volume/TVL ratio

**Example Output:**
```
Projected 30-day volume: $29,195,190
Projected 30d fees: $87,585.57
Base APR (full-range): 30.25%
Effective APR (±15%): 100.73%
Required Capital: $15,490
```

### 4. Volume History Tracker
```bash
npm run volume:track
# or
./scripts/monitoring/track-volume-history.sh
```

**What it does:**
- Logs current volume data to `logs/volume-history.csv`
- Creates historical dataset for trend analysis
- Should be run daily (manually or via cron)

**CSV Format:**
```
date,timestamp,volume_24h,liquidity,txns_24h,price_change_24h
2026-01-04,1735948800,973173,3550756,715,0.52
```

## Automated Daily Tracking

To automatically track volume daily, add to your crontab:

```bash
# Open crontab
crontab -e

# Add this line (runs daily at 9 AM)
0 9 * * * cd /path/to/defi && npm run volume:track >> logs/cron.log 2>&1
```

## Viewing Historical Data

After running `volume:track` for several days:

```bash
# View all history
cat logs/volume-history.csv

# View last 30 days
tail -30 logs/volume-history.csv

# Formatted view
column -t -s, logs/volume-history.csv | less

# Calculate 30-day average (macOS)
awk -F, 'NR>1 {sum+=$3; count++} END {print "Avg:", sum/count}' logs/volume-history.csv
```

## Quick Reference

| Command | Purpose | Time Period |
|---------|---------|-------------|
| `npm run volume:24h` | Current snapshot | Last 24 hours |
| `npm run volume:7d` | Weekly analysis | 7 days (projected) |
| `npm run volume:30d` | Monthly projections | 30 days (projected) |
| `npm run volume:track` | Log to CSV | Point-in-time |

## Interpreting Results

### Volume Status
- **GOOD**: >$1M daily (excellent for earnings)
- **MODERATE**: $500k-$1M daily (acceptable)
- **LOW**: <$500k daily (may not meet targets)

### Volume/TVL Ratio
- **>0.25x**: Excellent (high trading activity)
- **0.15-0.25x**: Good (healthy activity)
- **<0.15x**: Low (may indicate low fees)

### APR Guidelines
- **>100%**: Excellent returns, aggressive LPing viable
- **50-100%**: Good returns, moderate capital needed
- **<50%**: Lower returns, large capital required

## Troubleshooting

**Script won't run:**
```bash
chmod +x scripts/monitoring/*.sh
```

**No data returned:**
- Check internet connection
- DexScreener API may be rate-limited
- Try again in a few minutes

**Colors not showing:**
- Normal in some terminals
- Try running directly: `./scripts/monitoring/check-volume-24h.sh`

## Integration with Main App

These scripts complement the main monitoring application:

```bash
# Check volumes
npm run volume:24h

# If volumes look good, calculate capital
npm run calculate-capital

# Start monitoring your position
npm start watch
```

## API Rate Limits

DexScreener API:
- Free tier: ~300 requests/5 minutes
- Running all scripts once = 3 requests
- Safe to run every 15+ minutes

## Future Enhancements

- [ ] Integration with The Graph for true historical data
- [ ] CSV analysis script (trends, averages, forecasts)
- [ ] Email/SMS alerts when volume drops
- [ ] Comparison with other DEXs (Curve, Balancer)
- [ ] Volume prediction using ML

## See Also

- [Main README](../../README.md)
- [On-Chain Data Analysis](../../ONCHAIN_DATA_ANALYSIS.md)
- [Capital Analysis](../../CAPITAL_ANALYSIS.md)

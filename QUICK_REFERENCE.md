# Quick Reference Card

## Capital Requirements (Based on Real Data)

### Recommended Investment: **$15,128**
```
0.0839 WBTC  ($7,564)
7,564 USDC   ($7,564)
```

**Pool**: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16` (0.30% tier)

**Expected Returns**:
- $300/week (target)
- $1,300/month
- $15,600/year
- 103.12% APR

**Why 0.30% pool?** 0.05% pool needs $1.2M+ (not viable!)

---

## Quick Commands

```bash
# Install
npm install

# Check pool volume
npm run volume:24h
npm run volume:30d

# Calculate required capital
npm run calculate-capital

# Fetch live pool data
npm run fetch-pool-data

# Check current status
npm start

# Start 24/7 monitoring
npm start watch

# Generate weekly report
npm run report

# Track volume history
npm run volume:track
```

---

## Position Configuration

**Pool**: WBTC/USDC 0.05% fee tier
**Range**: ±15% from current price
**Check Interval**: Every 15 minutes

**Alerts**:
- ⚠️  Warning: 12% from boundary
- 🚨 Urgent: 14% from boundary
- 🔴 Critical: Out of range

---

## Key Metrics

| Metric | Target | Alert Level |
|--------|--------|-------------|
| Weekly Fees | $300 | <$270 = warning |
| In-Range Time | >90% | <80% = review range |
| Effective APR | 19.67% | <15% = investigate |
| Rebalancing | <2/month | >4/month = widen range |

---

## Setup Checklist

- [ ] Run `npm install`
- [ ] Run `npm run calculate-capital`
- [ ] Copy `.env.example` to `.env`
- [ ] Add RPC URL to `.env`
- [ ] Acquire WBTC and USDC
- [ ] Create LP position on Uniswap V4
- [ ] Add NFT token ID to `config/position.json`
- [ ] Add pool address to config
- [ ] Test: `npm start`
- [ ] Deploy: `npm start watch`

---

## When to Rebalance

**Rebalance if**:
- Price exits ±15% range
- Out of range for >2 hours
- Missing >$50/day in fees

**Don't rebalance if**:
- Price near boundary but still in range
- Gas costs >$100
- Temporary price spike (wait 30-60 min)

---

## Troubleshooting

**No price data**:
```bash
# Check if RPC URL is set
echo $ETHEREUM_RPC_URL

# Test without RPC (uses public APIs)
npm start
```

**Position not found**:
- Verify NFT token ID in config
- Check pool address is correct
- Ensure RPC endpoint is working

**Alerts not working**:
- Check Discord webhook URL in `.env`
- Verify `enableAlerts: true` in config

---

## Important Numbers

- **Target**: $300/week
- **Capital**: $15,128
- **WBTC**: 0.0839
- **USDC**: $7,564
- **Range**: ±15%
- **Fee Tier**: 0.30% (30 bps)
- **Pool**: 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16
- **APR**: 103.12%
- **Break-even**: ~1.4 months

---

## Files to Know

- `README.md` - Full documentation
- `CAPITAL_ANALYSIS.md` - Detailed capital breakdown
- `QUICKSTART.md` - Setup guide
- `config/position.json` - Your position settings
- `.env` - API keys and secrets

---

## Support

**Calculator Issues**: Check `scripts/calculateCapital.js`
**Monitoring Issues**: Check `src/index.js`
**Price Feed Issues**: Check `src/services/priceService.js`

All services have error handling and fallbacks.
Check console output for detailed error messages.

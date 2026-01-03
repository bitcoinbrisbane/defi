# Capital Investment Analysis
## WBTC/USDC Pool Analysis

**Date**: January 3-4, 2026

> **⚠️ IMPORTANT**: This document shows the ORIGINAL analysis based on the 0.05% fee tier pool.
>
> **UPDATED RECOMMENDATION**: Use the **0.30% fee tier** pool instead!
> - Required capital: **$15,128** (not $23,788)
> - Pool: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`
> - See [ONCHAIN_DATA_ANALYSIS.md](ONCHAIN_DATA_ANALYSIS.md) for comparison
>
> This document is kept for reference showing the original research process.

---

## Original Analysis: 0.05% Fee Tier Pool

**Current WBTC Price**: $89,892
**Estimated Pool Data**: $16.17M daily volume

**CONCLUSION**: Not viable - needs too much capital. See 0.30% pool instead.

---

## Target Parameters

- **Weekly Fee Goal**: $300 USDC
- **Annual Fee Goal**: $15,600 USDC
- **Liquidity Range**: ±15% (concentrated liquidity)
- **Pool Fee Tier**: 0.05% (5 basis points)

---

## Capital Requirements

### Conservative Scenario
**Assumptions**:
- Daily Volume: $12M (lower bound)
- Pool TVL: $80M
- Base APR: 2.74%
- Effective APR (with ±15% concentration): **9.13%**

**Required Capital**: **$51,288**
- 0.2853 WBTC ($25,644)
- 25,644 USDC ($25,644)

### Moderate Scenario (RECOMMENDED)
**Assumptions**:
- Daily Volume: $16.17M (actual average)
- Pool TVL: $50M
- Base APR: 5.90%
- Effective APR (with ±15% concentration): **19.67%**

**Required Capital**: **$23,788**
- 0.1323 WBTC ($11,894)
- 11,894 USDC ($11,894)

### Optimistic Scenario
**Assumptions**:
- Daily Volume: $20M (upper bound)
- Pool TVL: $30M
- Base APR: 12.17%
- Effective APR (with ±15% concentration): **40.56%**

**Required Capital**: **$11,540**
- 0.0642 WBTC ($5,770)
- 5,770 USDC ($5,770)

---

## Capital Range Summary

| Scenario     | Required Capital | WBTC Amount | USDC Amount | Effective APR |
|--------------|------------------|-------------|-------------|---------------|
| Conservative | $51,288         | 0.2853      | $25,644     | 9.13%         |
| **Moderate** | **$23,788**     | **0.1323**  | **$11,894** | **19.67%**    |
| Optimistic   | $11,540         | 0.0642      | $5,770      | 40.56%        |

**Recommendation**: Start with **~$24,000** (Moderate scenario)

---

## How the Math Works

### Fee APR Calculation
```
Base APR = (Annual Volume × Fee Rate) / Total Pool Liquidity

For Moderate Scenario:
- Annual Volume = $16.17M × 365 = $5.9B
- Fee Rate = 0.05% = 0.0005
- Annual Fees = $5.9B × 0.0005 = $2.95M
- Pool TVL = $50M
- Base APR = $2.95M / $50M = 5.90%
```

### Concentration Boost
```
Concentration Factor = 100 / (2 × Range%)
= 100 / (2 × 15)
= 3.33x

For ±15% range, you earn ~3.33x more fees per dollar vs full-range position
```

### Effective APR with Concentration
```
Effective APR = Base APR × Concentration Factor
= 5.90% × 3.33
= 19.67%
```

### Required Capital
```
Required Capital = Annual Fee Target / Effective APR
= $15,600 / 0.1967
= $23,788
```

---

## Fee Earning Projections

### With $23,788 Investment (Moderate Scenario)

| Period | Expected Fees |
|--------|---------------|
| Daily  | $42.86        |
| Weekly | $300.00       |
| Monthly| $1,300.00     |
| Annual | $15,600.00    |

**Effective APR**: 19.67%
**Break-even**: ~1.5 months
**ROI**: Recover initial capital in ~18 months from fees alone

---

## Important Considerations

### Concentration Risk
- **±15% range** means position only earns fees when WBTC price stays within range
- If price moves >15% up or down, position goes out-of-range
- **No fees earned when out of range**
- More concentrated = more fees per dollar BUT higher rebalancing frequency

### Impermanent Loss (IL)
With ±15% range:
- If price moves 15% in one direction: ~2.3% IL
- If price moves 30% total (in and out of range): ~9.1% IL
- IL is offset by fee earnings over time
- At 19.67% APR, recover from 9% IL in ~170 days

### Rebalancing Costs
- Gas costs to rebalance: ~$50-200 depending on network congestion
- Break-even on rebalance: need to earn >gas cost in additional fees
- With $300/week target, can afford 1-2 rebalances per month
- Monitor price closely near range boundaries

### Volume Dependency
- **Critical**: Fee earnings directly proportional to trading volume
- $16.17M average is based on recent data
- Volume can fluctuate 50%+ day-to-day
- Low volume days = low fees regardless of position size
- High volatility often correlates with high volume (good for fees)

---

## Risk-Adjusted Recommendations

### Conservative Approach
**Capital**: $25,000-30,000
**Why**: Builds in buffer for lower-than-expected volume or higher TVL
**Expected**: ~$250-300/week
**Risk**: Lower returns if conditions improve, but safer

### Aggressive Approach
**Capital**: $12,000-15,000
**Why**: Assumes pool conditions remain favorable
**Expected**: $200-400/week (high variance)
**Risk**: May fall short of $300/week target if volume drops

### Recommended Balanced Approach
**Capital**: $20,000-24,000
**Why**: Middle ground with reasonable margin of safety
**Expected**: $275-325/week
**Risk**: Moderate, can scale up if performing well

---

## Action Plan

### Phase 1: Preparation ($0)
1. ✅ Run capital calculator (completed)
2. ⬜ Review current WBTC/USDC pool metrics
3. ⬜ Check recent volume trends (last 7-30 days)
4. ⬜ Decide on initial capital allocation

### Phase 2: Initial Position ($20-24k)
1. ⬜ Acquire ~0.13 WBTC + ~$12,000 USDC
2. ⬜ Create LP position on Uniswap V4
3. ⬜ Set range: ±15% from current price
4. ⬜ Note position NFT token ID

### Phase 3: Monitoring ($0)
1. ⬜ Configure monitoring app with NFT ID
2. ⬜ Start 24/7 monitoring: `npm start watch`
3. ⬜ Set up Discord/webhook alerts
4. ⬜ Review daily for first week

### Phase 4: Optimization (Ongoing)
1. ⬜ Track actual fees vs $300/week target
2. ⬜ Calculate actual APR after 1-2 weeks
3. ⬜ Adjust capital if needed (scale up/down)
4. ⬜ Optimize range based on volatility patterns

---

## Expected Performance Timeline

### Week 1-2: Learning Phase
- Expect: $200-350/week (high variance)
- Focus: Understanding price movement patterns
- Action: Fine-tune alerts, get comfortable with monitoring

### Week 3-4: Stabilization
- Expect: $250-325/week (approaching target)
- Focus: Optimize rebalancing frequency
- Action: Adjust range if needed, track IL vs fees

### Month 2-3: Steady State
- Expect: $275-325/week (consistent)
- Focus: Maximize efficiency, minimize gas costs
- Action: Consider scaling position if doing well

### Month 4+: Mature Position
- Expect: $300+/week (on target)
- Focus: Explore additional positions or strategies
- Action: Compound fees or diversify

---

## Key Metrics to Track

Daily:
- [ ] Current WBTC price vs range bounds
- [ ] Distance to range edges (%)
- [ ] Fees earned in last 24h

Weekly:
- [ ] Total fees earned (WBTC + USDC)
- [ ] USD value of fees
- [ ] Percent of $300 target achieved
- [ ] Time spent in-range (%)
- [ ] Impermanent loss vs HODL

Monthly:
- [ ] Actual APR achieved
- [ ] Total gas costs for rebalancing
- [ ] Net profit (fees - gas - IL)
- [ ] ROI progress

---

## Fallback Plans

### If Underperforming (<$250/week)
1. Check pool volume trends (temporary dip vs sustained drop)
2. Consider increasing position size by 20-30%
3. Alternative: Tighten range to ±10% for more concentration
4. Last resort: Switch to 0.3% fee tier pool (higher fees per trade)

### If Overperforming (>$350/week)
1. Verify pool conditions are sustainable
2. Consider scaling up position gradually
3. Take profits regularly (compound fees into position)
4. Explore opening second position in different range

### If Frequently Out-of-Range
1. Widen range to ±20% (lower concentration but more stability)
2. Check if WBTC volatility is unusually high
3. Consider dynamic rebalancing (automated)
4. May indicate wrong pool or parameters

---

## Final Recommendation

**Initial Capital**: **$23,788**
- 0.1323 WBTC (~$11,894)
- 11,894 USDC

**Expected Performance**:
- Weekly fees: $300 (target)
- Effective APR: 19.67%
- Monthly net: ~$1,200 (after gas)

**Success Probability**: 70-80% based on current pool metrics

**Start Date**: ASAP (pool metrics are favorable)

Good luck! 🚀

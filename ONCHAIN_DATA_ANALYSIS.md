# On-Chain Data Analysis - WBTC/USDC Pools
**Date**: January 4, 2026
**Source**: DexScreener API (Live 24h data)

---

## Pool Comparison

### 0.05% Fee Tier Pool ❌ NOT RECOMMENDED
**Pool Address**: `0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35`

**Current Metrics**:
- 24h Volume: $844,454
- TVL: $42,004,550
- Transactions: 111 per day
- Price Change: +0.30%

**Performance Analysis**:
- Base APR (full-range): **0.37%** ⚠️
- Effective APR (±15% concentrated): **1.22%** ❌
- **Required Capital**: **$1,275,566** 🚫

**Verdict**: ❌ **TOO MUCH CAPITAL REQUIRED**
- Need over $1.2M to earn $300/week
- Volume is too low ($844k vs your estimated $16.17M)
- Extremely inefficient for target goals

---

### 0.30% Fee Tier Pool ✅ RECOMMENDED
**Pool Address**: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`

**Current Metrics**:
- 24h Volume: $1,002,071
- TVL: $3,546,823
- Transactions: 736 per day
- Price Change: +0.62%

**Performance Analysis**:
- Base APR (full-range): **30.94%** ✅
- Effective APR (±15% concentrated): **103.12%** 🚀
- **Required Capital**: **$15,128** ✅

**Token Allocation** (50/50):
- **0.0841 WBTC** (~$7,564)
- **7,564 USDC**

**Expected Performance**:
- Daily Fees: $42.86
- Weekly Fees: $300.00 ✅ TARGET MET
- Monthly Fees: $1,299.00
- Annual Fees: $15,600.00
- Effective APR: 103.12%

**Verdict**: ✅ **PERFECT FOR YOUR GOALS**
- Achievable capital requirement (~$15k)
- High trading activity (736 txns/day)
- Excellent APR with concentration
- Much better than 0.05% tier

---

## Key Insights

### Volume Reality Check
Your initial estimate of $16.17M daily volume was based on **0.05% tier**.
However, that pool is **NOT suitable** for earning $300/week due to low fees.

**Actual Daily Volumes**:
- 0.05% tier: $844,454 (too low fees)
- 0.30% tier: $1,002,071 (PERFECT - 6x higher fee rate!)
- 0.05% tier would need $16.17M+ volume to match 0.30% tier earnings

### Why 0.30% is Better

| Metric | 0.05% Tier | 0.30% Tier | Winner |
|--------|------------|------------|--------|
| Volume | $844k | $1,002k | 0.30% |
| TVL | $42M | $3.5M | 0.05% (but doesn't matter) |
| Fee Rate | 0.05% | 0.30% | **0.30% (6x higher!)** |
| Base APR | 0.37% | 30.94% | **0.30% (83x better!)** |
| Effective APR | 1.22% | 103.12% | **0.30% (84x better!)** |
| Required Capital | $1.28M | **$15.1k** | **0.30% (85x less!)** |
| Daily Txns | 111 | 736 | **0.30% (6.6x more activity)** |

**Winner**: 🏆 **0.30% Fee Tier by a landslide!**

---

## Revised Capital Requirements

### For 0.30% Fee Tier Pool (RECOMMENDED)

**Conservative Scenario** (70% of current volume):
- Daily Volume: $701,450
- Required Capital: **$21,612**
- Effective APR: 72.2%

**Moderate Scenario** (current volume):
- Daily Volume: $1,002,071
- Required Capital: **$15,128** ✅
- Effective APR: 103.12%

**Optimistic Scenario** (130% of current volume):
- Daily Volume: $1,302,692
- Required Capital: **$11,637**
- Effective APR: 134.1%

---

## Updated Recommendation

### Invest in 0.30% Fee Tier Pool

**Required Investment**: **$15,128**
```
0.0841 WBTC  (~$7,564)
7,564 USDC   (~$7,564)
```

**Expected Returns**:
- Weekly: $300 (100% of target)
- Monthly: $1,299
- Annual: $15,600
- APR: 103.12%

**Why This is Excellent**:
1. ✅ Achievable capital (~$15k vs $1.2M for 0.05%)
2. ✅ High trading activity (736 txns/day)
3. ✅ Better fee capture (0.30% vs 0.05%)
4. ✅ Smaller TVL means your position has more impact
5. ✅ Higher APR means faster ROI

---

## Risk Assessment

### 0.30% Tier Advantages
- ✅ Less capital at risk ($15k vs $1.2M)
- ✅ More trading activity = more consistent fees
- ✅ 6x fee rate = 6x earnings per dollar of volume
- ✅ Higher APR = faster recovery from IL

### Considerations
- ⚠️ Slightly lower liquidity ($3.5M vs $42M)
- ⚠️ May have more price volatility (but that creates volume!)
- ⚠️ Higher fees might push some traders to 0.05% tier
- ✅ But none of this matters because APR is 84x better!

---

## Action Plan

### Immediate Next Steps

1. **Abandon 0.05% Tier Plan** ❌
   - Volume too low
   - Would need $1.2M+ capital
   - Not feasible for $300/week goal

2. **Focus on 0.30% Tier** ✅
   - Pool: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16`
   - Capital: **$15,128**
   - Allocation: **0.0841 WBTC + 7,564 USDC**

3. **Monitor Pool for 3-7 Days**
   - Run `npm run fetch-pool-data` daily
   - Verify volume stays above $700k/day
   - Check APR remains >80%

4. **Prepare Capital**
   - Acquire 0.0841 WBTC (~$7,564)
   - Prepare 7,564 USDC
   - Keep extra 10-20% for rebalancing

5. **Create LP Position**
   - Use Uniswap V3 interface (V4 not deployed yet)
   - Set range: ±15% from current WBTC price
   - Note NFT token ID

6. **Start Monitoring**
   - Add NFT ID to config
   - Run: `npm start watch`

---

## Updated Calculator

I'll update the capital calculator to use 0.30% tier with actual on-chain data:

**Old estimate** (0.05% tier, $16.17M volume assumption):
- Required: $23,788

**New reality** (0.30% tier, $1M actual volume):
- Required: **$15,128** ✅

**Savings**: $8,660 less capital needed!

---

## Comparison Table

| Pool | Volume | TVL | Fee Rate | APR | Capital Needed | Feasible? |
|------|--------|-----|----------|-----|----------------|-----------|
| 0.05% | $844k | $42M | 0.05% | 1.22% | $1.28M | ❌ NO |
| **0.30%** | **$1M** | **$3.5M** | **0.30%** | **103%** | **$15k** | **✅ YES** |
| 1.00% | N/A | N/A | 1.00% | ? | ? | ❓ Unknown |

---

## Final Verdict

🎯 **Use the 0.30% Fee Tier Pool**

**Investment**: $15,128 (0.0841 WBTC + 7,564 USDC)
**Expected Return**: $300/week (103% APR)
**Confidence**: High - based on real on-chain data

The 0.05% tier is a **trap** - you'd need nearly $1.3M to earn the same $300/week!

---

## Next Steps

1. ✅ Review this analysis
2. ⬜ Run `npm run fetch-pool-data` again tomorrow to confirm volume
3. ⬜ Acquire capital (~$15k)
4. ⬜ Create position in 0.30% pool
5. ⬜ Start monitoring

**Pool to use**: `0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16` (0.30% tier)

Good luck! 🚀

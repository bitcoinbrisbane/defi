import { ethers } from 'ethers';

// Use public RPC endpoint
const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com');

const POSITION_MANAGER = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';
const POOL_ADDRESS = '0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16';
const POSITION_ID = 1166077;

const POSITION_MANAGER_ABI = [
  'function positions(uint256 tokenId) external view returns (uint96 nonce, address operator, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)'
];

const POOL_ABI = [
  'function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)',
  'function liquidity() external view returns (uint128)',
  'function feeGrowthGlobal0X128() external view returns (uint256)',
  'function feeGrowthGlobal1X128() external view returns (uint256)'
];

async function main() {
  try {
    console.log('\n' + '='.repeat(70));
    console.log('FETCHING REAL ON-CHAIN DATA');
    console.log('Position NFT ID: ' + POSITION_ID);
    console.log('='.repeat(70));

    const positionManager = new ethers.Contract(POSITION_MANAGER, POSITION_MANAGER_ABI, provider);
    const pool = new ethers.Contract(POOL_ADDRESS, POOL_ABI, provider);

    console.log('\nQuerying blockchain...');

    const [position, slot0, poolLiquidity] = await Promise.all([
      positionManager.positions(POSITION_ID),
      pool.slot0(),
      pool.liquidity()
    ]);

    console.log('\n📊 YOUR POSITION:');
    console.log('  Token0 (WBTC):        ' + position.token0);
    console.log('  Token1 (USDC):        ' + position.token1);
    console.log('  Fee Tier:             ' + Number(position.fee) / 10000 + '%');
    console.log('  Tick Lower:           ' + Number(position.tickLower));
    console.log('  Tick Upper:           ' + Number(position.tickUpper));
    console.log('  Your Liquidity:       ' + position.liquidity.toString());

    console.log('\n🏊 POOL STATE:');
    console.log('  Current Tick:         ' + Number(slot0.tick));
    console.log('  Active Liquidity:     ' + poolLiquidity.toString());

    const inRange = Number(slot0.tick) >= Number(position.tickLower) && Number(slot0.tick) <= Number(position.tickUpper);
    console.log('  Position Status:      ' + (inRange ? '✅ IN RANGE' : '❌ OUT OF RANGE'));

    console.log('\n💰 UNCOLLECTED FEES:');
    const wbtcFees = ethers.formatUnits(position.tokensOwed0, 8);
    const usdcFees = ethers.formatUnits(position.tokensOwed1, 6);
    console.log('  WBTC Fees:            ' + wbtcFees + ' WBTC');
    console.log('  USDC Fees:            $' + parseFloat(usdcFees).toFixed(2));

    const wbtcPrice = 92468;
    const wbtcFeesUSD = parseFloat(wbtcFees) * wbtcPrice;
    const totalFeesUSD = wbtcFeesUSD + parseFloat(usdcFees);

    console.log('\n💵 TOTAL UNCOLLECTED (USD):');
    console.log('  WBTC:                 $' + wbtcFeesUSD.toFixed(2));
    console.log('  USDC:                 $' + parseFloat(usdcFees).toFixed(2));
    console.log('  TOTAL:                $' + totalFeesUSD.toFixed(2));

    console.log('\n📈 YOUR SHARE OF ACTIVE LIQUIDITY:');
    const yourShare = (Number(position.liquidity) / Number(poolLiquidity)) * 100;
    console.log('  Your Liquidity / Pool Active Liquidity');
    console.log('  = ' + position.liquidity.toString() + ' / ' + poolLiquidity.toString());
    console.log('  = ' + yourShare.toFixed(4) + '%');

    // Calculate expected fees based on actual share
    const volume24h = 4839064;
    const poolDailyFees = volume24h * 0.003;
    const yourExpectedDailyFees = poolDailyFees * (yourShare / 100);

    console.log('\n💡 EXPECTED FEES (based on real liquidity share):');
    console.log('  Pool 24h Volume:      $' + volume24h.toLocaleString());
    console.log('  Pool Daily Fees:      $' + poolDailyFees.toFixed(2));
    console.log('  Your Share:           ' + yourShare.toFixed(4) + '%');
    console.log('  Expected Daily Fees:  $' + yourExpectedDailyFees.toFixed(2));
    console.log('  Expected Weekly Fees: $' + (yourExpectedDailyFees * 7).toFixed(2));
    console.log('  Expected Annual Fees: $' + (yourExpectedDailyFees * 365).toFixed(2));
    console.log('  Effective APR:        ' + ((yourExpectedDailyFees * 365 / 10000) * 100).toFixed(2) + '%');

    console.log('\n' + '='.repeat(70));
    console.log('THE ISSUE: Active liquidity is ' + (100 / yourShare).toFixed(0) + 'x what calculators assumed!');
    console.log('='.repeat(70) + '\n');

  } catch (error) {
    console.error('Error:', error.message);
    if (error.message.includes('rate limit')) {
      console.log('\nTry again in a moment, or use your own RPC endpoint.');
    }
  }
}

main();

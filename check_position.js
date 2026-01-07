import { ethers } from 'ethers';

const POSITION_MANAGER_ABI = [
  'function positions(uint256 tokenId) external view returns (uint96 nonce, address operator, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)'
];

const POOL_ABI = [
  'function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)'
];

const RPC_URL = process.env.MAINNET_RPC_URL;
const POSITION_MANAGER = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';
const POOL_ADDRESS = '0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16';
const POSITION_ID = 1166077;

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const positionManager = new ethers.Contract(POSITION_MANAGER, POSITION_MANAGER_ABI, provider);
  const pool = new ethers.Contract(POOL_ADDRESS, POOL_ABI, provider);

  console.log('\n' + '='.repeat(70));
  console.log('FETCHING YOUR ACTUAL POSITION DATA FROM BLOCKCHAIN');
  console.log('Position NFT ID: ' + POSITION_ID);
  console.log('='.repeat(70));

  const position = await positionManager.positions(POSITION_ID);
  const slot0 = await pool.slot0();

  console.log('\n📊 Position Details:');
  console.log('  Token0 (WBTC):        ' + position.token0);
  console.log('  Token1 (USDC):        ' + position.token1);
  console.log('  Fee Tier:             ' + position.fee / 10000 + '%');
  console.log('  Tick Lower:           ' + position.tickLower);
  console.log('  Tick Upper:           ' + position.tickUpper);
  console.log('  Current Tick:         ' + slot0.tick);
  console.log('  Liquidity:            ' + position.liquidity.toString());

  console.log('\n💰 Uncollected Fees:');
  const wbtcFees = ethers.formatUnits(position.tokensOwed0, 8);
  const usdcFees = ethers.formatUnits(position.tokensOwed1, 6);
  console.log('  WBTC Fees:            ' + wbtcFees + ' WBTC');
  console.log('  USDC Fees:            $' + parseFloat(usdcFees).toFixed(2));

  // Estimate USD value of WBTC fees (approximate)
  const wbtcPrice = 92468; // Current price from DexScreener
  const wbtcFeesUSD = parseFloat(wbtcFees) * wbtcPrice;
  const totalFeesUSD = wbtcFeesUSD + parseFloat(usdcFees);
  
  console.log('\n💵 Total Uncollected Fees (USD):');
  console.log('  WBTC Fees:            $' + wbtcFeesUSD.toFixed(2));
  console.log('  USDC Fees:            $' + parseFloat(usdcFees).toFixed(2));
  console.log('  TOTAL:                $' + totalFeesUSD.toFixed(2));

  console.log('\n✅ Position Status:');
  if (slot0.tick >= position.tickLower && slot0.tick <= position.tickUpper) {
    console.log('  IN RANGE - Actively earning fees on every trade!');
  } else {
    console.log('  OUT OF RANGE - Not currently earning fees');
  }

  console.log('\n' + '='.repeat(70) + '\n');
}

main().catch(console.error);

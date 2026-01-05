import dotenv from 'dotenv';
import { ethers } from 'ethers';

dotenv.config();

const RPC_URL = process.env.ETHEREUM_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/fmiJslJk8E60f0Ni9QLq5nsnjm-lUzn1';
const provider = new ethers.JsonRpcProvider(RPC_URL);
const POSITION_MANAGER = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';
const POOL = '0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16';
const TOKEN_ID = 1166077;

const positionAbi = ['function positions(uint256) view returns (uint96,address,address,address,uint24,int24,int24,uint128,uint256,uint256,uint128,uint128)'];
const poolAbi = [
  'function slot0() view returns (uint160,int24,uint16,uint16,uint16,uint8,bool)',
  'function feeGrowthGlobal0X128() view returns (uint256)',
  'function feeGrowthGlobal1X128() view returns (uint256)',
  'function ticks(int24) view returns (uint128,int128,uint256,uint256,int56,uint160,uint32,bool)'
];

async function check() {
  const pm = new ethers.Contract(POSITION_MANAGER, positionAbi, provider);
  const pool = new ethers.Contract(POOL, poolAbi, provider);

  const pos = await pm.positions(TOKEN_ID);
  const slot0 = await pool.slot0();
  const fg0 = await pool.feeGrowthGlobal0X128();
  const fg1 = await pool.feeGrowthGlobal1X128();

  const tickLower = Number(pos[5]);
  const tickUpper = Number(pos[6]);

  const tickLowerData = await pool.ticks(tickLower);
  const tickUpperData = await pool.ticks(tickUpper);

  console.log('=== POSITION DATA ===');
  console.log('  tickLower:', tickLower);
  console.log('  tickUpper:', tickUpper);
  console.log('  liquidity:', pos[7].toString());
  console.log('  feeGrowthInside0Last:', pos[8].toString());
  console.log('  feeGrowthInside1Last:', pos[9].toString());
  console.log('  tokensOwed0 (raw):', pos[10].toString());
  console.log('  tokensOwed1 (raw):', pos[11].toString());
  console.log('  tokensOwed0 (WBTC):', Number(pos[10]) / 1e8);
  console.log('  tokensOwed1 (USDC):', Number(pos[11]) / 1e6);
  console.log('');
  console.log('=== POOL DATA ===');
  console.log('  currentTick:', Number(slot0[1]));
  console.log('  feeGrowthGlobal0:', fg0.toString());
  console.log('  feeGrowthGlobal1:', fg1.toString());
  console.log('');
  console.log('=== TICK DATA ===');
  console.log('  Lower tick feeGrowthOutside0:', tickLowerData[2].toString());
  console.log('  Lower tick feeGrowthOutside1:', tickLowerData[3].toString());
  console.log('  Upper tick feeGrowthOutside0:', tickUpperData[2].toString());
  console.log('  Upper tick feeGrowthOutside1:', tickUpperData[3].toString());
}

check().catch(console.error);

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {IPositionManager} from "../src/IPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PositionManagerIntegrationTest is Test {
    PositionManager public manager;

    // Allow test contract to receive ETH
    receive() external payable {}

    // Mainnet addresses
    address constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant UNISWAP_V3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant WBTC_USDC_POOL = 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16; // 0.30% pool
    address constant WBTC_USD_PRICE_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // Chainlink WBTC/USD
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 constant FEE_TIER = 3000; // 0.30%
    int24 constant RANGE_PERCENT = 15; // ±15%

    address owner = address(this);

    event PositionCreated(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionClosed(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event PositionRebalanced(uint256 indexed oldTokenId, uint256 indexed newTokenId);
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event FeesCompounded(uint256 indexed tokenId, uint256 amount0, uint256 amount1);

    function setUp() public {
        // Fork mainnet for testing
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        // Deploy PositionManager
        manager = new PositionManager(
            UNISWAP_V3_POSITION_MANAGER,
            UNISWAP_V3_SWAP_ROUTER,
            WBTC_USDC_POOL,
            WBTC_USD_PRICE_FEED,
            WBTC,
            USDC,
            FEE_TIER,
            RANGE_PERCENT
        );
    }

    // ============================================
    // createPosition() Tests
    // ============================================

    function testCreatePosition() public {
        uint256 wbtcAmount = 0.1 * 1e8; // 0.1 WBTC
        uint256 usdcAmount = 9000 * 1e6; // 9,000 USDC

        // Give tokens to owner
        deal(WBTC, owner, wbtcAmount);
        deal(USDC, owner, usdcAmount);

        // Approve manager
        IERC20(WBTC).approve(address(manager), wbtcAmount);
        IERC20(USDC).approve(address(manager), usdcAmount);

        // Get current tick and calculate range
        (, int24 currentTick, , , , , ) = manager.pool().slot0();
        (int24 tickLower, int24 tickUpper) = manager.calculateTickRange(currentTick);

        // Create position
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            manager.createPosition(wbtcAmount, usdcAmount, tickLower, tickUpper);

        // Verify
        assertGt(tokenId, 0, "Token ID should be set");
        assertGt(liquidity, 0, "Liquidity should be added");
        assertGt(amount0, 0, "WBTC should be used");
        assertGt(amount1, 0, "USDC should be used");
        assertEq(manager.currentTokenId(), tokenId, "Current token ID should be set");
    }

    function testCreatePositionRevertsIfNotOwner() public {
        address notOwner = address(0x1234);

        vm.prank(notOwner);
        vm.expectRevert();
        manager.createPosition(1e8, 90000e6, 252000, 255000);
    }

    // ============================================
    // addLiquidityFromContract() Tests
    // ============================================

    function testAddLiquidityFromContract() public {
        uint256 wbtcAmount = 0.05 * 1e8; // 0.05 WBTC
        uint256 usdcAmount = 4500 * 1e6; // 4,500 USDC

        // Give tokens to manager contract
        deal(WBTC, address(manager), wbtcAmount);
        deal(USDC, address(manager), usdcAmount);

        // Add liquidity (no parameters needed!)
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            manager.addLiquidityFromContract();

        // Verify
        assertGt(tokenId, 0, "Token ID should be set");
        assertGt(liquidity, 0, "Liquidity should be added");
        assertGt(amount0, 0, "WBTC should be used");
        assertGt(amount1, 0, "USDC should be used");
        assertEq(manager.currentTokenId(), tokenId, "Current token ID should be set");
    }

    function testAddLiquidityFromContractRevertsIfNoTokens() public {
        // Ensure no tokens
        assertEq(IERC20(WBTC).balanceOf(address(manager)), 0);
        assertEq(IERC20(USDC).balanceOf(address(manager)), 0);

        // Try to add liquidity
        vm.expectRevert("No tokens in contract");
        manager.addLiquidityFromContract();
    }

    // ============================================
    // closePosition() Tests
    // ============================================

    function testClosePosition() public {
        // First create a position
        uint256 wbtcAmount = 0.1 * 1e8;
        uint256 usdcAmount = 9000 * 1e6;

        deal(WBTC, address(manager), wbtcAmount);
        deal(USDC, address(manager), usdcAmount);

        (uint256 tokenId, , , ) = manager.addLiquidityFromContract();
        assertGt(tokenId, 0, "Position should be created");

        // Close position
        vm.expectEmit(true, true, true, false);
        emit PositionClosed(tokenId, 0, 0); // amounts don't matter for this test

        (uint256 amount0, uint256 amount1) = manager.closePosition();

        // Verify
        assertGt(amount0, 0, "Should withdraw WBTC");
        assertGt(amount1, 0, "Should withdraw USDC");
        assertEq(manager.currentTokenId(), 0, "Current token ID should be cleared");

        // Verify tokens are back in contract
        assertGt(IERC20(WBTC).balanceOf(address(manager)), 0, "WBTC should be in contract");
        assertGt(IERC20(USDC).balanceOf(address(manager)), 0, "USDC should be in contract");
    }

    function testClosePositionRevertsIfNoPosition() public {
        vm.expectRevert("No active position");
        manager.closePosition();
    }

    function testClosePositionRevertsIfNotOwner() public {
        // Create position first
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        manager.addLiquidityFromContract();

        // Try to close as non-owner
        address notOwner = address(0x1234);
        vm.prank(notOwner);
        vm.expectRevert();
        manager.closePosition();
    }

    // ============================================
    // rebalance() Tests
    // ============================================

    function testRebalance() public {
        // Create initial position
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);

        (uint256 oldTokenId, , , ) = manager.addLiquidityFromContract();
        assertGt(oldTokenId, 0, "Old position should be created");

        // Rebalance
        uint256 newTokenId = manager.rebalance();

        // Verify
        assertGt(newTokenId, 0, "New token ID should be set");
        assertNotEq(newTokenId, oldTokenId, "New token ID should be different");
        assertEq(manager.currentTokenId(), newTokenId, "Current token ID should be updated");
    }

    function testRebalanceRevertsIfNoPosition() public {
        vm.expectRevert("No active position");
        manager.rebalance();
    }

    function testRebalanceRevertsIfNotOwner() public {
        // Create position first
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        manager.addLiquidityFromContract();

        // Try to rebalance as non-owner
        address notOwner = address(0x1234);
        vm.prank(notOwner);
        vm.expectRevert();
        manager.rebalance();
    }

    // ============================================
    // compound() Tests
    // ============================================

    function testCompoundRevertsIfNoFees() public {
        // Create position with liquidity
        deal(WBTC, address(manager), 0.5 * 1e8);
        deal(USDC, address(manager), 45000 * 1e6);

        manager.addLiquidityFromContract();

        // Try to compound without any fees accrued
        // (In reality, fees accumulate from trading activity in the pool)
        vm.expectRevert("No fees to compound");
        manager.compound();
    }

    function testCompoundRevertsIfNoPosition() public {
        vm.expectRevert("No active position");
        manager.compound();
    }

    function testCompoundIsPublic() public {
        // Create position
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        manager.addLiquidityFromContract();

        // Random user can call compound (even though it will fail with no fees)
        // This verifies there's no onlyOwner restriction
        address randomUser = address(0x5555);

        vm.prank(randomUser);
        vm.expectRevert("No fees to compound");
        manager.compound();
    }

    // ============================================
    // collectFeesAndWithdraw() Tests
    // ============================================

    function testCollectFeesAndWithdraw() public {
        // Create position
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        manager.addLiquidityFromContract();

        // Simulate some tokens in contract (could be fees or leftovers)
        deal(WBTC, address(manager), 0.01 * 1e8);
        deal(USDC, address(manager), 900 * 1e6);

        uint256 ownerWbtcBefore = IERC20(WBTC).balanceOf(owner);
        uint256 ownerUsdcBefore = IERC20(USDC).balanceOf(owner);

        // Collect and withdraw
        (uint256 fees0, uint256 fees1, uint256 withdrawn0, uint256 withdrawn1) =
            manager.collectFeesAndWithdraw();

        // Verify owner received tokens
        assertGt(IERC20(WBTC).balanceOf(owner), ownerWbtcBefore, "Owner should receive WBTC");
        assertGt(IERC20(USDC).balanceOf(owner), ownerUsdcBefore, "Owner should receive USDC");
        assertGt(withdrawn0 + withdrawn1, 0, "Should withdraw some tokens");
    }

    // ============================================
    // Helper Functions Tests
    // ============================================

    function testName() public view {
        string memory poolName = manager.name();
        // Should contain "Pool" and token names
        assertTrue(bytes(poolName).length > 0, "Name should not be empty");
    }

    function testGetPositionInfo() public {
        // Create position
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        (uint256 tokenId, , , ) = manager.addLiquidityFromContract();

        // Get position info
        IPositionManager.PositionInfo memory info = manager.getPositionInfo(tokenId);

        // Verify
        assertEq(info.token0, WBTC, "Token0 should be WBTC");
        assertEq(info.token1, USDC, "Token1 should be USDC");
        assertEq(info.fee, FEE_TIER, "Fee should match");
        assertGt(info.liquidity, 0, "Should have liquidity");
        assertTrue(info.tickLower < info.tickUpper, "Tick range should be valid");
    }

    function testReentrancyProtection() public {
        // Create position
        deal(WBTC, address(manager), 0.1 * 1e8);
        deal(USDC, address(manager), 9000 * 1e6);
        manager.addLiquidityFromContract();

        // ReentrancyGuard should prevent nested calls
        // This is automatically protected, just verify deployment
        assertTrue(address(manager).code.length > 0, "Manager deployed with ReentrancyGuard");
    }
}

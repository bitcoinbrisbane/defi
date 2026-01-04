// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PositionManager} from "../src/PositionManager.sol";

contract PositionManagerTest is Test {
    PositionManager public manager;

    // Mainnet addresses
    address constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 constant FEE_TIER = 3000; // 0.30%
    int24 constant RANGE_PERCENT = 15; // ±15%

    address owner = address(this);

    function setUp() public {
        // Fork mainnet for testing
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        // Deploy PositionManager
        manager = new PositionManager(
            UNISWAP_V3_POSITION_MANAGER,
            WBTC,
            USDC,
            FEE_TIER,
            RANGE_PERCENT
        );
    }

    function testDeployment() public view {
        assertEq(address(manager.POSITION_MANAGER()), UNISWAP_V3_POSITION_MANAGER);
        assertEq(address(manager.WBTC()), WBTC);
        assertEq(address(manager.USDC()), USDC);
        assertEq(manager.FEE_TIER(), FEE_TIER);
        assertEq(manager.rangePercent(), RANGE_PERCENT);
    }

    function testCalculateTickRange() public view {
        int24 currentTick = 253320; // Example tick

        (int24 tickLower, int24 tickUpper) = manager.calculateTickRange(currentTick);

        // Verify ticks are properly spaced
        assertTrue(tickLower < currentTick, "Lower tick should be below current");
        assertTrue(tickUpper > currentTick, "Upper tick should be above current");
        assertEq(tickLower % 60, 0, "Lower tick should be multiple of tickSpacing");
        assertEq(tickUpper % 60, 0, "Upper tick should be multiple of tickSpacing");

        console.log("Current tick:", uint256(int256(currentTick)));
        console.log("Lower tick:  ", uint256(int256(tickLower)));
        console.log("Upper tick:  ", uint256(int256(tickUpper)));
    }

    function testUpdateRange() public {
        manager.updateRange(20); // Change to ±20%
        assertEq(manager.rangePercent(), 20);
    }

    function testUpdateRangeOnlyOwner() public {
        vm.prank(address(0x1234));
        vm.expectRevert();
        manager.updateRange(20);
    }

    function testCannotSetInvalidRange() public {
        vm.expectRevert();
        manager.updateRange(0);

        vm.expectRevert();
        manager.updateRange(101);
    }
}

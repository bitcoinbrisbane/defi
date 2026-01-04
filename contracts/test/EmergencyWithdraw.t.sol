// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EmergencyWithdrawTest is Test {
    PositionManager public manager;

    // Mainnet addresses
    address constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant WBTC_USDC_POOL = 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16; // 0.30% pool
    address constant WBTC_USD_PRICE_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // Chainlink WBTC/USD
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 constant FEE_TIER = 3000; // 0.30%
    int24 constant RANGE_PERCENT = 15; // ±15%

    address owner = address(this);
    address nonOwner = address(0x1234);

    // Whale addresses for tokens
    address constant WBTC_WHALE = 0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8; // Binance wallet
    address constant USDC_WHALE = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa; // USDC rich address

    event EmergencyWithdrawal(address indexed token, uint256 amount);

    function setUp() public {
        // Fork mainnet for testing
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        // Deploy PositionManager
        manager = new PositionManager(
            UNISWAP_V3_POSITION_MANAGER,
            WBTC_USDC_POOL,
            WBTC_USD_PRICE_FEED,
            WBTC,
            USDC,
            FEE_TIER,
            RANGE_PERCENT
        );
    }

    function testEmergencyWithdrawETH() public {
        // Send ETH to contract
        uint256 ethAmount = 1 ether;
        vm.deal(address(manager), ethAmount);

        // Check initial balance
        assertEq(address(manager).balance, ethAmount);

        uint256 ownerBalanceBefore = owner.balance;

        // Withdraw all assets
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(address(0), ethAmount);

        (uint256 ethWithdrawn, uint256 wbtcWithdrawn, uint256 usdcWithdrawn) = manager.emergencyWithdraw();

        // Verify balances
        assertEq(address(manager).balance, 0, "Contract should have no ETH");
        assertEq(owner.balance, ownerBalanceBefore + ethAmount, "Owner should receive ETH");
        assertEq(ethWithdrawn, ethAmount, "Should return ETH amount");
        assertEq(wbtcWithdrawn, 0, "No WBTC to withdraw");
        assertEq(usdcWithdrawn, 0, "No USDC to withdraw");
    }

    function testEmergencyWithdrawERC20() public {
        // Get USDC from whale
        uint256 usdcAmount = 10000 * 1e6; // 10,000 USDC (6 decimals)

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(address(manager), usdcAmount);

        // Check initial balance
        assertEq(IERC20(USDC).balanceOf(address(manager)), usdcAmount);

        uint256 ownerBalanceBefore = IERC20(USDC).balanceOf(owner);

        // Withdraw all assets
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(USDC, usdcAmount);

        (uint256 ethWithdrawn, uint256 wbtcWithdrawn, uint256 usdcWithdrawn) = manager.emergencyWithdraw();

        // Verify balances
        assertEq(IERC20(USDC).balanceOf(address(manager)), 0, "Contract should have no USDC");
        assertEq(
            IERC20(USDC).balanceOf(owner),
            ownerBalanceBefore + usdcAmount,
            "Owner should receive USDC"
        );
        assertEq(ethWithdrawn, 0, "No ETH to withdraw");
        assertEq(wbtcWithdrawn, 0, "No WBTC to withdraw");
        assertEq(usdcWithdrawn, usdcAmount, "Should return USDC amount");
    }

    function testEmergencyWithdrawWBTC() public {
        // Get WBTC from whale
        uint256 wbtcAmount = 1 * 1e8; // 1 WBTC (8 decimals)

        vm.prank(WBTC_WHALE);
        IERC20(WBTC).transfer(address(manager), wbtcAmount);

        // Check initial balance
        assertEq(IERC20(WBTC).balanceOf(address(manager)), wbtcAmount);

        uint256 ownerBalanceBefore = IERC20(WBTC).balanceOf(owner);

        // Withdraw all assets
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(WBTC, wbtcAmount);

        (uint256 ethWithdrawn, uint256 wbtcWithdrawn, uint256 usdcWithdrawn) = manager.emergencyWithdraw();

        // Verify balances
        assertEq(IERC20(WBTC).balanceOf(address(manager)), 0, "Contract should have no WBTC");
        assertEq(
            IERC20(WBTC).balanceOf(owner),
            ownerBalanceBefore + wbtcAmount,
            "Owner should receive WBTC"
        );
        assertEq(ethWithdrawn, 0, "No ETH to withdraw");
        assertEq(wbtcWithdrawn, wbtcAmount, "Should return WBTC amount");
        assertEq(usdcWithdrawn, 0, "No USDC to withdraw");
    }

    function testEmergencyWithdrawRevertsIfNotOwner() public {
        // Send some ETH to contract
        vm.deal(address(manager), 1 ether);

        // Try to withdraw as non-owner
        vm.prank(nonOwner);
        vm.expectRevert();
        manager.emergencyWithdraw();
    }

    function testEmergencyWithdrawRevertsIfNoAssets() public {
        // Ensure no assets in contract
        assertEq(address(manager).balance, 0);
        assertEq(IERC20(WBTC).balanceOf(address(manager)), 0);
        assertEq(IERC20(USDC).balanceOf(address(manager)), 0);

        // Try to withdraw
        vm.expectRevert("No assets to withdraw");
        manager.emergencyWithdraw();
    }

    function testEmergencyWithdrawMultipleTokens() public {
        // Send multiple tokens to contract
        uint256 ethAmount = 2 ether;
        uint256 usdcAmount = 5000 * 1e6; // 5,000 USDC
        uint256 wbtcAmount = 0.5 * 1e8; // 0.5 WBTC

        vm.deal(address(manager), ethAmount);

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(address(manager), usdcAmount);

        vm.prank(WBTC_WHALE);
        IERC20(WBTC).transfer(address(manager), wbtcAmount);

        // Withdraw all assets at once
        (uint256 ethWithdrawn, uint256 wbtcWithdrawn, uint256 usdcWithdrawn) = manager.emergencyWithdraw();

        // Verify all assets withdrawn
        assertEq(address(manager).balance, 0, "Contract should have no ETH");
        assertEq(IERC20(USDC).balanceOf(address(manager)), 0, "Contract should have no USDC");
        assertEq(IERC20(WBTC).balanceOf(address(manager)), 0, "Contract should have no WBTC");

        assertEq(ethWithdrawn, ethAmount, "Should return ETH amount");
        assertEq(wbtcWithdrawn, wbtcAmount, "Should return WBTC amount");
        assertEq(usdcWithdrawn, usdcAmount, "Should return USDC amount");

        assertEq(IERC20(USDC).balanceOf(owner), usdcAmount, "Owner should receive USDC");
        assertEq(IERC20(WBTC).balanceOf(owner), wbtcAmount, "Owner should receive WBTC");
    }

    function testEmergencyWithdrawEmitsEvent() public {
        uint256 ethAmount = 0.5 ether;
        vm.deal(address(manager), ethAmount);

        // Check event is emitted
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(address(0), ethAmount);

        manager.emergencyWithdraw();
    }

    // Fuzz test: withdraw varying amounts of ETH
    function testFuzzEmergencyWithdrawETH(uint96 amount) public {
        vm.assume(amount > 0);

        vm.deal(address(manager), amount);

        uint256 ownerBalanceBefore = owner.balance;
        (uint256 ethWithdrawn, , ) = manager.emergencyWithdraw();

        assertEq(address(manager).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + amount);
        assertEq(ethWithdrawn, amount);
    }

    // Test that contract can receive ETH (via receive function)
    function testContractCanReceiveETH() public {
        uint256 amount = 1 ether;

        (bool success, ) = address(manager).call{value: amount}("");
        assertTrue(success, "Contract should accept ETH");
        assertEq(address(manager).balance, amount);
    }
}

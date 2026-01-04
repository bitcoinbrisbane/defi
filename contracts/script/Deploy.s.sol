// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PositionManager} from "../src/PositionManager.sol";

contract DeployScript is Script {
    // Mainnet addresses
    address constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 constant FEE_TIER = 3000; // 0.30%
    int24 constant RANGE_PERCENT = 15; // ±15%

    function run() external returns (PositionManager) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        PositionManager manager = new PositionManager(
            UNISWAP_V3_POSITION_MANAGER,
            WBTC,
            USDC,
            FEE_TIER,
            RANGE_PERCENT
        );

        console.log("PositionManager deployed at:", address(manager));
        console.log("Owner:", manager.owner());
        console.log("Pool: WBTC/USDC");
        console.log("Fee Tier:", FEE_TIER, "(0.30%)");
        console.log("Range:", uint256(int256(RANGE_PERCENT)), "%");

        vm.stopBroadcast();

        return manager;
    }
}

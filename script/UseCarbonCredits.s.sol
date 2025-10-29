// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract UseCarbonCredits is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 enterpriseKey = vm.envUint("ENTERPRISE_PRIVATE_KEY");
        
        address enterprise = vm.addr(enterpriseKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("Starting carbon credits usage");
        console.log("User: %s", enterprise);
        
        uint256 useAmount = 0.001 ether;
        uint256 totalSupplyBefore = carbonSystem.totalSupply();
        
        uint256 balanceBefore = carbonSystem.balanceOf(enterprise);
        CarbonCreditSystem.CarbonAccount memory accBefore = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        console.log("Before - Balance: %s, Total used: %s", balanceBefore, accBefore.totalUsed);
        
        vm.startBroadcast(enterpriseKey);
        carbonSystem.useCarbonCredits(useAmount);
        vm.stopBroadcast();
        
        console.log("Carbon credits usage completed");
        console.log("Usage amount: %s", useAmount);
        
        uint256 balanceAfter = carbonSystem.balanceOf(enterprise);
        uint256 totalSupplyAfter = carbonSystem.totalSupply();
        CarbonCreditSystem.CarbonAccount memory accAfter = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        
        console.log("After - Balance: %s, Total used: %s", balanceAfter, accAfter.totalUsed);
        console.log("Actual decrease: %s", balanceBefore - balanceAfter);
        console.log("Total supply change: %s -> %s", totalSupplyBefore, totalSupplyAfter);
        console.log("Burned amount: %s", totalSupplyBefore - totalSupplyAfter);
    }
}
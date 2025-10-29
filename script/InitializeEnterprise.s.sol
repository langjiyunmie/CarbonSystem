// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract InitializeEnterprise is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 governmentKey = vm.envUint("GOVERNMENT_PRIVATE_KEY");
        uint256 enterpriseKey = vm.envUint("ENTERPRISE_PRIVATE_KEY");
        
        address enterprise = vm.addr(enterpriseKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("Starting enterprise initialization");
        console.log("Enterprise address: %s", enterprise);
        
        vm.startBroadcast(governmentKey);
        carbonSystem.initializeEnterprise(enterprise);
        vm.stopBroadcast();
        
        console.log("Enterprise initialization completed");
        
        CarbonCreditSystem.CarbonAccount memory acc = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        console.log("Enterprise status:");
        console.log("  Current balance: %s", acc.currentBalance);
        console.log("  Total purchased: %s", acc.totalPurchased);
        console.log("  Total used: %s", acc.totalUsed);
        console.log("  Active status: %s", acc.isActive);
    }
}
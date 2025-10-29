// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract CheckStatus is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 operatorKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        uint256 enterpriseKey = vm.envUint("ENTERPRISE_PRIVATE_KEY");
        
        address operator = vm.addr(operatorKey);
        address enterprise = vm.addr(enterpriseKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("System status check");
        console.log("Contract address: %s", carbonSystemAddress);
        
        CarbonCreditSystem.Operator memory op = carbonSystem.getOperatorInfo(operator);
        console.log("Operator (%s):", operator);
        console.log("  Staked amount: %s", op.stakedAmount);
        console.log("  Total carbon: %s", op.totalCarbon);
        console.log("  Reputation: %s", op.reputation);
        console.log("  Active status: %s", op.isActive);
        console.log("  Current balance: %s", carbonSystem.balanceOf(operator));
        
        CarbonCreditSystem.CarbonAccount memory acc = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        console.log("Enterprise (%s):", enterprise);
        console.log("  Current balance: %s", acc.currentBalance);
        console.log("  Total purchased: %s", acc.totalPurchased);
        console.log("  Total used: %s", acc.totalUsed);
        console.log("  Active status: %s", acc.isActive);
        console.log("  Wallet balance: %s", carbonSystem.balanceOf(enterprise));
        
        console.log("System information:");
        console.log("  Total supply: %s", carbonSystem.totalSupply());
        console.log("  Task counter: %s", carbonSystem.taskCounter());
        console.log("  Min stake amount: %s", carbonSystem.minStakeAmount());
        console.log("  Treasury address: %s", carbonSystem.treasury());
    }
}
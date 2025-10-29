// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract SellCarbonCredits is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 operatorKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        uint256 enterpriseKey = vm.envUint("ENTERPRISE_PRIVATE_KEY");
        
        address operator = vm.addr(operatorKey);
        address enterprise = vm.addr(enterpriseKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("Starting carbon credits sale");
        console.log("Seller: %s", operator);
        console.log("Buyer: %s", enterprise);
        
        uint256 sellAmount = 0.002 ether;
        
        uint256 operatorBalanceBefore = carbonSystem.balanceOf(operator);
        uint256 enterpriseBalanceBefore = carbonSystem.balanceOf(enterprise);
        console.log("Before - Operator: %s, Enterprise: %s", operatorBalanceBefore, enterpriseBalanceBefore);
        
        vm.startBroadcast(operatorKey);
        carbonSystem.sellCarbonCredit(enterprise, sellAmount);
        vm.stopBroadcast();
        
        console.log("Carbon credits sale completed");
        console.log("Sale amount: %s", sellAmount);
        
        uint256 operatorBalanceAfter = carbonSystem.balanceOf(operator);
        uint256 enterpriseBalanceAfter = carbonSystem.balanceOf(enterprise);
        console.log("After - Operator: %s, Enterprise: %s", operatorBalanceAfter, enterpriseBalanceAfter);
        console.log("Operator decrease: %s", operatorBalanceBefore - operatorBalanceAfter);
        console.log("Enterprise increase: %s", enterpriseBalanceAfter - enterpriseBalanceBefore);
        
        CarbonCreditSystem.CarbonAccount memory acc = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        console.log("Enterprise total purchased: %s", acc.totalPurchased);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract MintCarbonCredits is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 governmentKey = vm.envUint("GOVERNMENT_PRIVATE_KEY");
        uint256 operatorKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        
        address operator = vm.addr(operatorKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("Starting carbon credits minting");
        console.log("Recipient: %s", operator);
        
        uint256 mintAmount = 0.005 ether;
        uint256 taskId = 1;
        
        uint256 balanceBefore = carbonSystem.balanceOf(operator);
        console.log("Balance before: %s", balanceBefore);
        
        vm.startBroadcast(governmentKey);
        carbonSystem.mintCarbonCreditBasedOnDispatch(operator, mintAmount, taskId);
        vm.stopBroadcast();
        
        console.log("Carbon credits minting completed");
        console.log("Mint amount: %s", mintAmount);
        console.log("Task ID: %s", taskId);
        
        uint256 balanceAfter = carbonSystem.balanceOf(operator);
        console.log("Balance after: %s", balanceAfter);
        console.log("Actual increase: %s", balanceAfter - balanceBefore);
        
        CarbonCreditSystem.Operator memory op = carbonSystem.getOperatorInfo(operator);
        console.log("Operator total carbon: %s", op.totalCarbon);
    }
}
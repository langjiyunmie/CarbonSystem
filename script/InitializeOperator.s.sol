// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract InitializeOperator is Script {
    CarbonCreditSystem public carbonSystem;
    
    function run() external {
        // Read environment variables
        address carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
        uint256 governmentKey = vm.envUint("GOVERNMENT_PRIVATE_KEY");
        uint256 operatorKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        
        address operator = vm.addr(operatorKey);
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);
        
        console.log("Starting operator initialization");
        console.log("Operator address: %s", operator);
        
        // Execute initialization
        vm.startBroadcast(governmentKey);
        carbonSystem.initializeAndStakeOperator(operator);
        vm.stopBroadcast();
        
        console.log("Operator initialization completed");
        
        // Verify results
        CarbonCreditSystem.Operator memory op = carbonSystem.getOperatorInfo(operator);
        console.log("Operator status:");
        console.log("  Staked amount: %s", op.stakedAmount);
        console.log("  Total carbon: %s", op.totalCarbon);
        console.log("  Reputation: %s", op.reputation);
        console.log("  Active status: %s", op.isActive);
    }
}
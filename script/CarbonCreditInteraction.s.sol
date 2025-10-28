// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract CarbonCreditInteraction is Script {
    // 合约地址
    address public carbonSystemAddress;
    
    // 角色私钥
    uint256 public governmentPrivateKey;
    uint256 public operatorPrivateKey; 
    uint256 public enterprisePrivateKey;
    
    // 从私钥推导的地址
    address public government;
    address public operator;
    address public enterprise;
    
    CarbonCreditSystem public carbonSystem;

    function run() external {
        // 读取私钥并推导地址
        setupAccounts();
        
        console.log("=== Carbon Credit System Interaction ===");
        console.log("Contract: %s", carbonSystemAddress);
        console.log("Government: %s", government);
        console.log("Operator: %s", operator);
        console.log("Enterprise: %s", enterprise);

        // 验证合约存在
        require(carbonSystemAddress != address(0), "Carbon system address not set");

        // 加载合约实例
        carbonSystem = CarbonCreditSystem(carbonSystemAddress);

        // 执行交互流程
        executeInteraction();
    }

    function setupAccounts() internal {
        // 从环境变量读取私钥
        governmentPrivateKey = vm.envUint("GOVERNMENT_PRIVATE_KEY");
        operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        enterprisePrivateKey = vm.envUint("ENTERPRISE_PRIVATE_KEY");
        
        // 从私钥推导地址
        government = vm.addr(governmentPrivateKey);
        operator = vm.addr(operatorPrivateKey);
        enterprise = vm.addr(enterprisePrivateKey);
        
        // 读取合约地址
        carbonSystemAddress = vm.envAddress("CARBON_SYSTEM_ADDRESS");
    }

    function executeInteraction() internal {
        // 1. 政府初始化运营商
        console.log("\n--- Step 1: Government initializes operator ---");
        vm.startBroadcast(governmentPrivateKey);
        carbonSystem.initializeAndStakeOperator(operator);
        vm.stopBroadcast();
        console.log("Operator initialized and staked");

        // 2. 政府初始化企业
        console.log("\n--- Step 2: Government initializes enterprise ---");
        vm.startBroadcast(governmentPrivateKey);
        carbonSystem.initializeEnterprise(enterprise);
        vm.stopBroadcast();
        console.log("Enterprise initialized");

        // 3. 政府根据调度结果发放碳积分
        console.log("\n--- Step 3: Government mints carbon credits ---");
        vm.startBroadcast(governmentPrivateKey);
        carbonSystem.mintCarbonCreditBasedOnDispatch(operator, 0.005 ether, 1);
        vm.stopBroadcast();
        console.log("Carbon credits minted to operator");

        // 4. 运营商出售碳积分给企业
        console.log("\n--- Step 4: Operator sells carbon credits to enterprise ---");
        vm.startBroadcast(operatorPrivateKey);
        carbonSystem.sellCarbonCredit(enterprise, 0.002 ether);
        vm.stopBroadcast();
        console.log("Operator sold carbon credits to enterprise");

        // 5. 企业使用碳积分
        console.log("\n--- Step 5: Enterprise uses carbon credits ---");
        vm.startBroadcast(enterprisePrivateKey);
        carbonSystem.useCarbonCredits(0.001 ether);
        vm.stopBroadcast();
        console.log("Enterprise used carbon credits");

        // 6. 显示最终状态
        console.log("\n--- Final Status ---");
        showFinalStatus();
    }

    function showFinalStatus() internal view {
        // 运营商信息
        CarbonCreditSystem.Operator memory op = carbonSystem.getOperatorInfo(operator);
        console.log("Operator Info:");
        console.log("  Stake: %s", op.stakedAmount);
        console.log("  Total Carbon: %s", op.totalCarbon);
        console.log("  Reputation: %s", op.reputation);

        // 企业信息
        CarbonCreditSystem.CarbonAccount memory acc = carbonSystem.getEnterpriseCarbonAccount(enterprise);
        console.log("Enterprise Info:");
        console.log("  Balance: %s", acc.currentBalance);
        console.log("  Purchased: %s", acc.totalPurchased);
        console.log("  Used: %s", acc.totalUsed);

        // 余额信息
        console.log("Balances:");
        console.log("  Government: %s", carbonSystem.balanceOf(government));
        console.log("  Operator: %s", carbonSystem.balanceOf(operator));
        console.log("  Enterprise: %s", carbonSystem.balanceOf(enterprise));
        console.log("  Total Supply: %s", carbonSystem.totalSupply());
    }
}
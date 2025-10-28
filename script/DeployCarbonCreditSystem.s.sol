// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonCreditSystem.sol";

contract DeployCarbonCreditSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying to Sepolia with address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 使用很小的数值
        CarbonCreditSystem carbonSystem = new CarbonCreditSystem(0.001 ether, deployer);
        
        vm.stopBroadcast();
        
        console.log("CarbonCreditSystem deployed to:", address(carbonSystem));
        console.log("Min stake amount: 0.001 ETH");
    }
}
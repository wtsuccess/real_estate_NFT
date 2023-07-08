//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Property.sol";

contract MyProperty is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);
        string memory baseUri = "https://blablabla";
        Property property = new Property(baseUri);
        vm.stopBroadcast();
    }
}
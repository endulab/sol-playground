// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// The contract is required to inherit from Initializable
contract UpgradeableTransparentV1 is Initializable {
    uint256 public counter;
    
    function increment() public {
        counter++;
    }

    function initialize(uint256 counterValue) public initializer() {
        counter = counterValue;
    }
}

contract UpgradeableTransparentV2 is Initializable {
    uint256 public counter;
    // keep the order, only append new states!
    uint256 public newCounter;
    
    function increment() public {
        counter++;
    }

    function incrementNew() public {
        newCounter++;
    }

    // In further upgrades use reinitializer instead of initializer modifier
    function initialize() public reinitializer(2) {
    }
}

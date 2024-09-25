// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// The UUPS contract is required to inherit from UUPSUpgradeable and upgradeable versions of OpenZeppelin contracts.
contract UpgradeableV1 is UUPSUpgradeable, OwnableUpgradeable {
    uint256 public counter;
    
    // Prevent from non-proxy execution
    function increment() onlyProxy() public {
        counter++;
    }

    // Function from UUPSUpgradeable. Ownable or AccessControl can be used.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner() {
    }

    // Function from Initializable interface.
    // It will be used instead of constructor.
    function initialize(uint256 counterValue) public initializer() {
        // init every base contract
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        counter = counterValue;
    }
}

contract UpgradeableV2 is UUPSUpgradeable, OwnableUpgradeable {
    uint256 public counter;
    // keep the order, only append new states!
    uint256 public newCounter;
    
    function increment() public onlyProxy() {
        counter++;
    }

    function incrementNew() public onlyProxy() {
        newCounter++;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner() {
    }

    // In further upgrades use reinitializer instead of initializer modifier
    function initialize() public reinitializer(2) {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
}

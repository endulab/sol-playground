// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * This smart contract implements a simple eternal storage pattern.
 * It contains upgradeable mechanism.
 */
contract EternalStorage is Ownable {

    address public latestVersion;

    mapping(bytes32 => uint) uintStorage;
    mapping(bytes32 => address) addressStorage;

    error NotLatestVersion();
    error InvalidNewLatestVersion();

    modifier onlyLatestVersion() {
        if (msg.sender != latestVersion) {
            revert NotLatestVersion();
        }
        _;
    }

    constructor() Ownable(msg.sender) {
    }

    function upgradeLatestVersion(address _latestVersion) onlyOwner() external {
        if (_latestVersion == address(0)) {
            revert InvalidNewLatestVersion();
        }
        latestVersion = _latestVersion;
    }

    function getUint(bytes32 id) external view returns (uint) {
        return uintStorage[id];
    }

    function setUint(bytes32 id, uint value) external onlyLatestVersion() {
        uintStorage[id] = value;
    }

    function getAddress(bytes32 id) external view returns (address) {
        return addressStorage[id];
    }

    function setAddress(bytes32 id, address value) external onlyLatestVersion() {
        addressStorage[id] = value;
    }
}


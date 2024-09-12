// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {EternalStorage} from "./EternalStorage.sol";

library EternalUserLib {
    function setUserBalance(address _eternalStorage, uint _balance) external {
        EternalStorage(_eternalStorage).setUint(keccak256("user.balance"), _balance);
    }

    function getUserBalance(address _eternalStorage) external view returns (uint) {
        return EternalStorage(_eternalStorage).getUint(keccak256("user.balance"));
    }

    function setUserAddress(address _eternalStorage, address _address) external {
        EternalStorage(_eternalStorage).setAddress(keccak256("user.address"), _address);
    }

    function getUserAddress(address _eternalStorage) external view returns (address) {
        return EternalStorage(_eternalStorage).getAddress(keccak256("user.address"));
    }
}


contract EternalUser {

    using EternalUserLib for address;
    address immutable eternalStorage;
    
    constructor(address _eternalStorage) {
        eternalStorage = _eternalStorage;
    }

    function setUserAddress(address _userAddress) public {
        eternalStorage.setUserAddress(_userAddress);
    }

    function getUserAddress() public view returns (address) {
        return eternalStorage.getUserAddress();
    }

    function setUserBalance(uint _userBalance) public {
        eternalStorage.setUserBalance(_userBalance);
    }

    function getUserBalance() public view returns (uint) {
        return eternalStorage.getUserBalance();
    }
}

contract EternalUserV2 is EternalUser {
    // this is new version of contract
    constructor(address _eternalStorage) EternalUser(_eternalStorage) {
    }
}


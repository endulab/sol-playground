// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {EternalStorage} from "../../src/eternal/EternalStorage.sol";
import {EternalUser, EternalUserV2} from "../../src/eternal/EternalUser.sol";

contract EternalStorageTest is Test {
    
    EternalStorage public eternalStorage;
    EternalUser public eternalUser;
    EternalUserV2 public eternalUserV2;

    address userAddr = makeAddr("user");
    address userAddr2 = makeAddr("user2");
    
    function setUp() public {
        eternalStorage = new EternalStorage();
        eternalUser = new EternalUser(address(eternalStorage));
        eternalUserV2 = new EternalUserV2(address(eternalStorage));
        eternalStorage.upgradeLatestVersion(address(eternalUser));
    }

    function test_eternalStorage() public {
        eternalUser.setUserAddress(userAddr);
        eternalUser.setUserBalance(2 ether);

        assertEq(eternalUser.getUserAddress(), userAddr);
        assertEq(eternalUser.getUserBalance(), 2 ether);

        assertEq(eternalUserV2.getUserAddress(), userAddr);
        assertEq(eternalUserV2.getUserBalance(), 2 ether);

        vm.expectRevert();
        eternalUserV2.setUserAddress(userAddr2);

        eternalStorage.upgradeLatestVersion(address(eternalUserV2));
        eternalUserV2.setUserAddress(userAddr2);
        eternalUserV2.setUserBalance(4 wei);

        assertEq(eternalUserV2.getUserAddress(), userAddr2);
        assertEq(eternalUserV2.getUserBalance(), 4 wei);

        assertEq(eternalUser.getUserAddress(), userAddr2);
        assertEq(eternalUser.getUserBalance(), 4 wei);

        vm.expectRevert();
        eternalUser.setUserAddress(userAddr);
    }

}

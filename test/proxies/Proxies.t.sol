// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {UpgradeableV1, UpgradeableV2} from "../../src/proxies/UpgradeableContracts.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {UpgradeableTransparentV1, UpgradeableTransparentV2} from "../../src/proxies/UpgradeableContractsTransparent.sol";

contract ProxiesTest is Test {

    function test_uupsProxy() public {

        UpgradeableV1 upgradeableV1 = new UpgradeableV1();

        // proxy will call initialize function instantly. We do not want to leave contract uninitialized
        ERC1967Proxy proxy = new ERC1967Proxy(address(upgradeableV1), abi.encodeWithSignature("initialize(uint256)", 5));

        UpgradeableV1 proxyInstance = UpgradeableV1(address(proxy));
        assertEq(proxyInstance.counter(), 5);
        proxyInstance.increment();
        proxyInstance.increment();
        assertEq(proxyInstance.counter(), 7);

        // let's create a new contract, we do not like the old one
        UpgradeableV2 newContract = new UpgradeableV2();

        // upgrade logic contract
        proxyInstance.upgradeToAndCall(address(newContract), abi.encodeWithSignature("initialize()", 5));

        UpgradeableV2 proxyInstance2 = UpgradeableV2(address(proxy));

        assertEq(proxyInstance2.counter(), 7);
        assertEq(proxyInstance2.newCounter(), 0);

        proxyInstance2.increment();
        proxyInstance2.incrementNew();

        assertEq(proxyInstance2.counter(), 8);
        assertEq(proxyInstance2.newCounter(), 1);

    }

    function test_transparentProxy() public {
        
        UpgradeableTransparentV1 contractV1 = new UpgradeableTransparentV1();

        // proxy admin for managing transparent proxy
        address proxyAdminOwner = makeAddr("proxyAdminOwner");
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(contractV1),
                                            proxyAdminOwner,
                                            abi.encodeWithSignature("initialize(uint256)", 5));


        // ProxyAdmin is deployed in TransparentUpgradeableProxy constructor.
        // It's address is emitted with AdminChanged. In test cheatcode can be used.
        bytes32 adminSlot = vm.load(address(proxy), ERC1967Utils.ADMIN_SLOT);
        address proxyAdminAddress = address(uint160(uint256(adminSlot)));

        UpgradeableTransparentV1 proxyInstance = UpgradeableTransparentV1(address(proxy));

        assertEq(proxyInstance.counter(), 5);
        proxyInstance.increment();
        proxyInstance.increment();
        assertEq(proxyInstance.counter(), 7);

        // let's create a new contract, we do not like the old one
        UpgradeableTransparentV2 newContract = new UpgradeableTransparentV2();

        // proxy admin owner can upgrade via proxyAdmin contract
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(newContract), abi.encodeWithSignature("initialize()"));
    
        UpgradeableTransparentV2 proxyInstance2 = UpgradeableTransparentV2(address(proxy));

        assertEq(proxyInstance2.counter(), 7);
        assertEq(proxyInstance2.newCounter(), 0);

        proxyInstance2.increment();
        proxyInstance2.incrementNew();

        assertEq(proxyInstance2.counter(), 8);
        assertEq(proxyInstance2.newCounter(), 1);
    }
}

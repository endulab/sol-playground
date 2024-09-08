// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    address public addrOwner1 = makeAddr("owner1");
    address public addrOwner2 = makeAddr("owner2");
    address public addrOwner3 = makeAddr("owner3");
    address public addrOther = makeAddr("other");

    address public addrReceiver1 = makeAddr("receiver1");
    address public addrReceiver2 = makeAddr("receiver2");

    MultiSigWallet public sharedGoodWallet;

    event TransactionSubmitted(uint256 indexed transactionId, address indexed to, uint256 amount);
    event TransactionApproved(uint256 indexed transactionId);
    event TransactionExecuted(uint256 indexed transactionId);

    constructor() {
        vm.deal(addrOwner2, 2 ether);
        vm.deal(addrOwner3, 3 ether);
        vm.deal(addrOther, 5 ether);

        sharedGoodWallet = createGoodWallet();
    }

    function beforeTestSetup(
        bytes4 testSelector
    ) public pure returns (bytes[] memory beforeTestCalldata) {
        if (testSelector == this.test_approveNonExistentTransaction.selector ||
            testSelector == this.test_approveTransactionByNonOwner.selector ||
            testSelector == this.test_approveTransaction.selector) {
            beforeTestCalldata = new bytes[](1);
            beforeTestCalldata[0] = abi.encodePacked(this.test_submitTransactionByOwners.selector);
        } else if (testSelector == this.test_executeTransaction.selector) {
            beforeTestCalldata = new bytes[](2);
            beforeTestCalldata[0] = abi.encodePacked(this.test_submitTransactionByOwners.selector);
            beforeTestCalldata[1] = abi.encodePacked(this.test_approveTransaction.selector);
        }
    }

    function createGoodWallet() public returns (MultiSigWallet) {
        address[] memory owners = new address[](3);
        owners[0] = addrOwner1;
        owners[1] = addrOwner2;
        owners[2] = addrOwner3;
        return new MultiSigWallet(owners, 2);
    }

    function test_emptyOwnersInConstructor() public {
        address[] memory emptyOwners;
        vm.expectRevert();
        new MultiSigWallet(emptyOwners, 2);
    }

    function test_incorrectRequiredApprovalsNumberInConstructor() public {
        address[] memory owners = new address[](3);
        owners[0] = addrOwner1;
        owners[1] = addrOwner2;
        owners[2] = addrOwner3;
        vm.expectRevert();
        new MultiSigWallet(owners, 0);
        vm.expectRevert();
        new MultiSigWallet(owners, 4);
    }

    function test_zeroAddressInConstructor() public {
        address[] memory ownersWithZero = new address[](3);
        ownersWithZero[0] = addrOwner1;
        ownersWithZero[1] = address(0);
        ownersWithZero[2] = addrOwner3;
        vm.expectRevert();
        new MultiSigWallet(ownersWithZero, 3);
    }

    function test_submitTransactionByNonOwner() public {
        // non-owner submission - failed
        MultiSigWallet goodWallet = createGoodWallet();
        vm.prank(addrOther);
        vm.expectRevert();
        goodWallet.submitTransaction{value: 1.5 ether}(addrReceiver1);
    }

    function test_submitTransactionByOwners() public {
        // submit 1st transaction
        vm.prank(addrOwner2);
        vm.expectEmit();
        emit TransactionSubmitted(0, addrReceiver1, 1.5 ether);
        uint firstTransactionId = sharedGoodWallet.submitTransaction{value: 1.5 ether}(addrReceiver1);
        assertEq(firstTransactionId, 0);
        
        // submit 2nd transaction
        vm.prank(addrOwner3);
        vm.expectEmit();
        emit TransactionSubmitted(1, addrReceiver2, 1.2 ether);
        uint secondTransactionId = sharedGoodWallet.submitTransaction{value: 1.2 ether}(addrReceiver2);
        assertEq(secondTransactionId, 1);

        // check the contract balance
        assertEq(address(sharedGoodWallet).balance, 2.7 ether);
    }

    function test_approveNonExistentTransaction() public {
        vm.prank(addrOwner2);
        vm.expectRevert();
        sharedGoodWallet.approveTransaction(5);
    }

    function test_approveTransactionByNonOwner() public {
        vm.prank(addrOther);
        vm.expectRevert();
        sharedGoodWallet.approveTransaction(0);
    }

    function test_approveTransaction() public {
        vm.startPrank(addrOwner1);
        // approve 1st transaction by 1 owner only
        sharedGoodWallet.approveTransaction(0);

        // approve transaction again
        vm.expectRevert();
        sharedGoodWallet.approveTransaction(0);
        assertEq(sharedGoodWallet.isTransactionFullyApproved(0), false);

        // approve 2nd transaction by all
        sharedGoodWallet.approveTransaction(1);
        vm.stopPrank();
        assertEq(sharedGoodWallet.isTransactionFullyApproved(1), false);
        vm.prank(addrOwner2);
        sharedGoodWallet.approveTransaction(1);
        assertEq(sharedGoodWallet.isTransactionFullyApproved(1), true);
        vm.prank(addrOwner3);
        sharedGoodWallet.approveTransaction(1);
        assertEq(sharedGoodWallet.isTransactionFullyApproved(1), true);
    }

    function test_executeTransaction() public {
        // try to execute fully approved transaction by non-owner
        vm.prank(addrOther);
        vm.expectRevert();
        sharedGoodWallet.executeTransaction(1);

        // try to execute not fully approved transaction
        vm.startPrank(addrOwner3);
        vm.expectRevert();
        sharedGoodWallet.executeTransaction(0);

        // try to execute fully approved transaction by owner
        sharedGoodWallet.executeTransaction(1);

        // 2nd execution
        vm.expectRevert();
        sharedGoodWallet.executeTransaction(1);

        // check receiver balance
        assertEq(addrReceiver2.balance, 1.2 ether);
    }
}

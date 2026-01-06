// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Agreements} from "../../src/agreements/Agreements.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestTokenErc20 is ERC20 {
    constructor() ERC20("TestToken20", "TTT-20") {
        _mint(msg.sender, 10 ether);
    }
}

contract AgreementsTest is Test {

    TestTokenErc20 public erc20;

    Agreements public agreements;

    address buyerAddr = makeAddr("buyer");
    address sellerAddr = makeAddr("seller");
    address arbitratorAddr = makeAddr("arbitrator");
    address otherAddr = makeAddr("other");

    event AgreementSetWithETH(address indexed buyer, uint256 amount);
    event AgreementSetWithERC20(address indexed buyer, address indexed erc20Address, uint256 amount);
    event AgreementCompleted();
    event DisputeRaisedBy(address indexed account);

    function setUp() public {

        vm.deal(buyerAddr, 5 ether);
        vm.deal(otherAddr, 5 ether);

        erc20 = new TestTokenErc20();
        require(erc20.transfer(buyerAddr, 5 ether));
        require(erc20.transfer(otherAddr, 5 ether));

        agreements = new Agreements(arbitratorAddr, buyerAddr, sellerAddr);
    }
    
    function test_setWithEth() public {
        
        // other user
        vm.prank(otherAddr);
        vm.expectRevert();
        agreements.setAgreementEth{value: 2.5 ether}();

        vm.startPrank(buyerAddr);
        vm.expectRevert();
        agreements.setAgreementEth(); // 0 eth

        vm.expectRevert();
        agreements.setAgreementEth{value: 100 ether}(); // too much

        vm.expectEmit();
        emit AgreementSetWithETH(buyerAddr, 2.5 ether);
        agreements.setAgreementEth{value: 2.5 ether}();
        vm.stopPrank();
    }

    function test_completionWithEth() public {
        vm.startPrank(buyerAddr);
        
        // completion before set
        vm.expectRevert();
        agreements.completeAgreement();
        
        agreements.setAgreementEth{value: 2.5 ether}();

        // completion too early
        vm.expectRevert();
        agreements.completeAgreement();

        assertEq(sellerAddr.balance, 0 ether);

        vm.warp(60*60*2); // 2hours
        vm.expectEmit();
        emit AgreementCompleted();
        agreements.completeAgreement();

        assertEq(sellerAddr.balance, 2.5 ether);

        vm.stopPrank();
    }

    function test_setWithERC20() public {
        // other user
        vm.prank(otherAddr);
        vm.expectRevert();
        agreements.setAgreementERC20(address(erc20), 2.5 ether);

        vm.startPrank(buyerAddr);
        vm.expectRevert();
        agreements.setAgreementERC20(address(erc20), 0); // 0 erc

        vm.expectRevert();
        agreements.setAgreementERC20(address(erc20), 100 ether); // too much erc

        // set ERC20 allowance to transfer token
        erc20.approve(address(agreements), 2.5 ether);
        vm.expectEmit();
        emit AgreementSetWithERC20(buyerAddr, address(erc20), 2.5 ether);
        agreements.setAgreementERC20(address(erc20), 2.5 ether);
        vm.stopPrank();
    }

    function test_completionWithERC20() public {
        vm.startPrank(buyerAddr);
        
        // completion before set
        vm.expectRevert();
        agreements.completeAgreement();
        
        // set ERC20 allowance to transfer token
        erc20.approve(address(agreements), 2.5 ether);
        agreements.setAgreementERC20(address(erc20), 2.5 ether);

        // completion too early
        vm.expectRevert();
        agreements.completeAgreement();

        assertEq(erc20.balanceOf(sellerAddr), 0 ether);

        vm.warp(60*60*2); // 2hours
        agreements.completeAgreement();

        assertEq(erc20.balanceOf(sellerAddr), 2.5 ether);

        vm.stopPrank();
    }

    function test_disputeEth() public {

        vm.prank(buyerAddr);
        agreements.setAgreementEth{value: 2.5 ether}();

        // not autorised dispute
        vm.prank(otherAddr);
        vm.expectRevert();
        agreements.raiseDispute();

        vm.startPrank(sellerAddr);
        vm.expectEmit();
        emit DisputeRaisedBy(sellerAddr);
        agreements.raiseDispute();

        vm.warp(60*60*2); // 2hours
        // try complete disputed
        vm.expectRevert();
        agreements.completeAgreement();

        // unauthorized dispute resolving
        vm.expectRevert();
        agreements.resolveDispute(true);
        vm.stopPrank();

        assertEq(sellerAddr.balance, 0);

        vm.prank(arbitratorAddr);
        agreements.resolveDispute(false);

        assertEq(sellerAddr.balance, 2.5 ether);
    }

    function test_disputeERC20() public {
        
        vm.startPrank(buyerAddr);
        // set ERC20 allowance to transfer token
        erc20.approve(address(agreements), 2.5 ether);
        agreements.setAgreementERC20(address(erc20), 2.5 ether);
        
        agreements.raiseDispute();
        vm.stopPrank();

        assertEq(erc20.balanceOf(buyerAddr), 2.5 ether);

        vm.prank(arbitratorAddr);
        agreements.resolveDispute(true);

        assertEq(erc20.balanceOf(buyerAddr), 5 ether);
        assertEq(erc20.balanceOf(sellerAddr), 0);
    }

    function test_wrongStates() public {

        vm.prank(arbitratorAddr);
        vm.expectRevert();
        agreements.resolveDispute(true);

        vm.startPrank(buyerAddr);
        vm.expectRevert();
        agreements.completeAgreement();

        vm.expectRevert();
        agreements.raiseDispute();
        vm.stopPrank();
    }

}

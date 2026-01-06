// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Vault} from "../../src/vault/Vault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestTokenErc20 is ERC20 {
    constructor() ERC20("TestToken20", "TTT-20") {
        _mint(msg.sender, 10 ether);
    }
}

contract TestTokenErc721 is ERC721 {
    constructor() ERC721("TestToken721", "TTT-721") {
        _mint(msg.sender, 0);
        _mint(msg.sender, 1);
        _mint(msg.sender, 2);
    }
}

contract VaultTest is Test {

    TestTokenErc20 public erc20;
    TestTokenErc721 public erc721;

    Vault public vault;

    address richAddr = makeAddr("rich");
    address poorAddr = makeAddr("poor");

    uint[] goodTokenIds;
    uint[] badTokenIds;
    uint[] emptyTokenIds;

    event DepositEth(address indexed sender, uint value);
    event WithdrawEth(address indexed sender, uint value);
    event DepositERC20(address indexed sender, address indexed erc20Address, uint value);
    event WithdrawERC20(address indexed sender, address indexed erc20Address, uint value);
    event DepositERC721(address indexed sender, address indexed erc721Address, uint tokenId);
    event WithdrawERC721(address indexed sender, address indexed erc721Address, uint tokenId);

    function setUp() public {

        vm.deal(richAddr, 5 ether);
        erc20 = new TestTokenErc20();
        require(erc20.transfer(richAddr, 5 ether));

        erc721 = new TestTokenErc721();
        erc721.transferFrom(address(this), richAddr, 0);
        erc721.transferFrom(address(this), richAddr, 1);
        erc721.transferFrom(address(this), richAddr, 2);

        goodTokenIds.push(0);
        goodTokenIds.push(1);
        goodTokenIds.push(2);

        badTokenIds.push(0);
        badTokenIds.push(1);
        badTokenIds.push(20);

        vault = new Vault();
    }
    
    function test_Eth() public {
        // deposit 0 eth
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.depositEth{value: 0}();

        // deposit
        vm.expectEmit();
        emit DepositEth(richAddr, 2 ether);
        vault.depositEth{value: 2 ether}();
        assertEq(richAddr.balance, 3 ether);
        assertEq(address(vault).balance, 2 ether);
        vm.stopPrank();

        // withdraw with different account
        vm.prank(poorAddr);
        vm.expectRevert();
        vault.withdrawEth(1 ether);

        // withdraw  0
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.withdrawEth(0);

        // withdraw  more than has
        vm.expectRevert();
        vault.withdrawEth(3 ether);

        // withdraw small amount
        vm.expectEmit();
        emit WithdrawEth(richAddr, 1 ether);
        vault.withdrawEth(1 ether);
        assertEq(richAddr.balance, 4 ether);

        // withdraw the rest
        vm.expectEmit();
        emit WithdrawEth(richAddr, 1 ether);
        vault.withdrawEth(1 ether);
        assertEq(richAddr.balance, 5 ether);

        assertEq(address(vault).balance, 0);

        vm.stopPrank();
    }

    function test_ERC20() public {
        // deposit 0 erc20
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.depositERC20(address(erc20), 0);

        // set ERC20 allowance to transfer token
        erc20.approve(address(vault), 2 ether);
        // deposit
        vm.expectEmit();
        emit DepositERC20(richAddr, address(erc20), 2 ether);
        vault.depositERC20(address(erc20), 2 ether);
        assertEq(erc20.balanceOf(richAddr), 3 ether);
        assertEq(erc20.balanceOf(address(vault)), 2 ether);
        vm.stopPrank();

        // withdraw with different account
        vm.prank(poorAddr);
        vm.expectRevert();
        vault.withdrawERC20(address(erc20), 1 ether);

        // withdraw  0
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.withdrawERC20(address(erc20), 0);

        // withdraw  more than has
        vm.expectRevert();
        vault.withdrawERC20(address(erc20), 3 ether);

        // withdraw small amount
        vm.expectEmit();
        emit WithdrawERC20(richAddr, address(erc20), 1 ether);
        vault.withdrawERC20(address(erc20), 1 ether);
        assertEq(erc20.balanceOf(richAddr), 4 ether);

        // withdraw the rest
        vm.expectEmit();
        emit WithdrawERC20(richAddr, address(erc20), 1 ether);
        vault.withdrawERC20(address(erc20), 1 ether);
        assertEq(erc20.balanceOf(richAddr), 5 ether);

        assertEq(erc20.balanceOf(address(vault)), 0);

        vm.stopPrank();
    }

    function test_ERC721() public {
        // deposit no erc721 tokens
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.depositERC721(address(erc721), emptyTokenIds);

        // set ERC721 allowance to transfer token
        erc721.approve(address(vault), 0);
        erc721.approve(address(vault), 1);
        erc721.approve(address(vault), 2);
        // deposit
        vault.depositERC721(address(erc721), goodTokenIds);
        assertEq(erc721.balanceOf(richAddr), 0);
        assertEq(erc721.balanceOf(address(vault)), 3);
        vm.stopPrank();

        // withdraw with different account
        vm.prank(poorAddr);
        vm.expectRevert();
        vault.withdrawERC721(address(erc721), goodTokenIds);

        // withdraw  nothing
        vm.startPrank(richAddr);
        vm.expectRevert();
        vault.withdrawERC721(address(erc721), emptyTokenIds);

        // withdraw different tokens
        vm.expectRevert();
        vault.withdrawERC721(address(erc721), badTokenIds);

        // withdraw all tokens
        vault.withdrawERC721(address(erc721), goodTokenIds);
        
        assertEq(erc721.balanceOf(richAddr), 3);
        assertEq(erc721.balanceOf(address(vault)), 0);

        vm.stopPrank();
    }

}

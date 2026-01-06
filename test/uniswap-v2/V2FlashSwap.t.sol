// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@uniswap/v2-periphery/interfaces/IERC20.sol";

import {UniswapV2FlashSwap} from "../../src/uniswap-v2/V2FlashSwap.sol";

contract UniswapV2FlashSwapTest is Test {

    address constant DAI_ADDR = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant DAI_WETH_PAIR_ADDR = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;

    IERC20 constant DAI = IERC20(DAI_ADDR);

    UniswapV2FlashSwap private flashSwap;

    address user = makeAddr("user");


    function setUp() public {
        flashSwap = new UniswapV2FlashSwap(DAI_WETH_PAIR_ADDR);

        deal(DAI_ADDR, user, 1000000 * 1e18);
        vm.prank(user);
        DAI.approve(address(flashSwap), type(uint256).max);
    }

    function test_flashSwap() public {
        uint256 dai0 = DAI.balanceOf(DAI_WETH_PAIR_ADDR);
        vm.prank(user);
        flashSwap.flashSwap(DAI_ADDR, 1e6 * 1e18);
        uint256 dai1 = DAI.balanceOf(DAI_WETH_PAIR_ADDR);

        console2.log("dai0: ", dai0);
        console2.log("dai1: ", dai1);
        console2.log("dai1 - dai0: ", dai1-dai0);

        assertGe(dai1, dai0);
    }

}

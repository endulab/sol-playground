// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {IERC20} from "@uniswap/v2-periphery/interfaces/IERC20.sol";
import {IWETH} from "@uniswap/v2-periphery/interfaces/IWETH.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestTokenErc20 is ERC20 {
    constructor() ERC20("TestToken20", "TTT-20") {
        _mint(msg.sender, 10 ether);
    }
}

contract UniswapV2Swap is Test {

    address constant DAI_ADDR = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant MKR_ADDR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant FACTORY_ADDR = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IERC20 constant DAI = IERC20(DAI_ADDR);
    IERC20 constant MKR = IERC20(MKR_ADDR);
    IWETH constant WETH = IWETH(WETH_ADDR);

    IUniswapV2Router02 constant ROUTER = IUniswapV2Router02(ROUTER_ADDR);

    IUniswapV2Factory constant FACTORY = IUniswapV2Factory(FACTORY_ADDR);

    address user = makeAddr("user");

    function setUp() public {

        vm.deal(user, 100 * 1e18);
        vm.startPrank(user);
        WETH.deposit{value: 100 * 1e18}();
        IERC20(WETH_ADDR).approve(ROUTER_ADDR, type(uint256).max);
        vm.stopPrank();

        deal(DAI_ADDR, user, 1000000 * 1e18);
        vm.startPrank(user);
        DAI.approve(ROUTER_ADDR, type(uint256).max);
        vm.stopPrank();
    }
    
    function test_Swap1() public {

        uint256 amountOut = 1e15;
        uint256 amountInMax = 1e18;

        address[] memory path = new address[](3);
        path[0] = WETH_ADDR;
        path[1] = DAI_ADDR;
        path[2] = MKR_ADDR;

        vm.prank(user);
        uint[] memory amounts = ROUTER.swapTokensForExactTokens(amountOut, amountInMax, path, user, block.timestamp);
        console.log("WETH: ",amounts[0]);
        console.log("DAI: ",amounts[1]);
        console.log("MKR: ",amounts[2]);
        assertGe(MKR.balanceOf(user), amountOut);
    }

    function test_Swap2() public {

        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1;

        address[] memory path = new address[](3);
        path[0] = WETH_ADDR;
        path[1] = DAI_ADDR;
        path[2] = MKR_ADDR;

        vm.prank(user);
        uint[] memory amounts = ROUTER.swapExactTokensForTokens(amountIn, amountOutMin, path, user, block.timestamp);
        console.log("WETH: ",amounts[0]);
        console.log("DAI: ",amounts[1]);
        console.log("MKR: ",amounts[2]);
        assertGe(MKR.balanceOf(user), amountOutMin);
    }

    function test_Factory() public {
        TestTokenErc20 myErc20 = new TestTokenErc20();

        address pair = FACTORY.createPair(WETH_ADDR, address(myErc20));

        address token0Addr = IUniswapV2Pair(pair).token0();
        address token1Addr = IUniswapV2Pair(pair).token1();

        if (address(myErc20) < WETH_ADDR) {
            assertEq(token0Addr, address(myErc20));
            assertEq(token1Addr, WETH_ADDR);
        } else {
            assertEq(token0Addr, WETH_ADDR);
            assertEq(token1Addr, address(myErc20));
        }
    }

    function test_Liquidity() public {
        
        vm.startPrank(user);
        (uint amount0, uint amount1, uint liquidity) =
            ROUTER.addLiquidity(WETH_ADDR, DAI_ADDR, 100 * 1e18, 1000000 * 1e18, 1, 1, user, block.timestamp);
        console.log("WETH: ",amount0);
        console.log("DAI: ",amount1);
        console.log("liquidity: ",liquidity);
        address pairAddress = FACTORY.getPair(WETH_ADDR, DAI_ADDR);
        assertGt(IUniswapV2Pair(pairAddress).balanceOf(user), 0);

        IUniswapV2Pair(pairAddress).approve(ROUTER_ADDR, liquidity);

        (uint amountA, uint amountB) = ROUTER.removeLiquidity(WETH_ADDR, DAI_ADDR, liquidity, 1, 1, user, block.timestamp);
        console.log("AmountA: ",amountA);
        console.log("AmountB: ",amountB);
        vm.stopPrank();
        assertEq(IUniswapV2Pair(pairAddress).balanceOf(user), 0);
    }
}

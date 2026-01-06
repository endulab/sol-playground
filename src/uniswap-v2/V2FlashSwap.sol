// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IERC20} from "@uniswap/v2-periphery/interfaces/IERC20.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

contract UniswapV2FlashSwap {

    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    error UniswapV2FlashSwap_IncorrectTokenAddress();
    error UniswapV2FlashSwap_WrongFlashLoanCaller();
    error UniswapV2FlashSwap_WrongFlashSender();
    error UniswapV2FlashSwap_TransferError(uint256 amount);

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function flashSwap(address token, uint256 amount) external {
        if (token != token0 && token != token1) {
            revert UniswapV2FlashSwap_IncorrectTokenAddress();
        }

        (uint256 amount0Out, uint256 amount1Out) = (token == token0) ? (amount, uint256(0)) : (uint256(0), amount);

        bytes memory data = abi.encode(token, msg.sender);
        
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (msg.sender != address(pair)) {
            // only pair contract can call this function
            revert UniswapV2FlashSwap_WrongFlashLoanCaller();
        }
        if (sender != address(this)) {
            // only this contract can be a sender
            revert UniswapV2FlashSwap_WrongFlashSender();
        }

        (address token, address caller) = abi.decode(data, (address, address));
        uint256 borrowedAmount = amount0 == uint256(0) ? amount1 : amount0;
        
        // fee == borrowedAmount * 3 / 997 + 1
        uint256 fee = borrowedAmount*3/997+1;
        uint256 amountToRepay = borrowedAmount + fee;

        // get flash swap fee from caller
        bool success = IERC20(token).transferFrom(caller, address(this), fee);
        if (!success) {
            revert UniswapV2FlashSwap_TransferError(fee);
        }
        // repay uniswap v2 pair
        success = IERC20(token).transfer(address(pair), amountToRepay);
        if (!success) {
            revert UniswapV2FlashSwap_TransferError(amountToRepay);
        }
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouter {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);
}

contract Aggregator {
    IRouter public immutable uniswap;
    IRouter public immutable sushi;

    constructor(address _uniswap, address _sushi) {
        uniswap = IRouter(_uniswap);
        sushi = IRouter(_sushi);
    }

    function getBestQuote(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 bestOut, string memory bestDex)
    {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256 u = uniswap.getAmountsOut(amountIn, path)[1];
        uint256 s = sushi.getAmountsOut(amountIn, path)[1];

        if (u >= s) return (u, "uniswap");
        return (s, "sushiswap");
    }
}

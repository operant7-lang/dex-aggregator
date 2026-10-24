// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IRouter {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract Aggregator {
    IRouter public immutable uniswap;
    IRouter public immutable sushi;

    constructor(address _uniswap, address _sushi) {
        uniswap = IRouter(_uniswap);
        sushi = IRouter(_sushi);
    }

    function _best(address[] memory path, uint256 amountIn)
        internal view returns (uint256 bestOut, IRouter bestRouter, string memory bestDex)
    {
        uint256 u = uniswap.getAmountsOut(amountIn, path)[1];
        uint256 s = sushi.getAmountsOut(amountIn, path)[1];

        if (u >= s) return (u, uniswap, "uniswap");
        return (s, sushi, "sushiswap");
    }

    function getBestQuote(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 bestOut, string memory bestDex)
    {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        (bestOut, , bestDex) = _best(path, amountIn);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        (, IRouter router, ) = _best(path, amountIn);

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");
        require(IERC20(tokenIn).approve(address(router), amountIn), "approve failed");

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn, minOut, path, msg.sender, deadline
        );
        return amounts[1];
    }
}

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
    address public immutable weth;

    struct Route {
        IRouter router;
        address[] path;
        uint256 out;
        uint8 dexId; // 0 = uniswap, 1 = sushiswap
    }

    constructor(address _uniswap, address _sushi, address _weth) {
        uniswap = IRouter(_uniswap);
        sushi = IRouter(_sushi);
        weth = _weth;
    }

    // Returns 0 if the pool doesn't exist instead of reverting
    function _quote(IRouter router, address[] memory path, uint256 amountIn)
        internal view returns (uint256)
    {
        try router.getAmountsOut(amountIn, path) returns (uint256[] memory a) {
            return a[a.length - 1];
        } catch {
            return 0;
        }
    }

    function _consider(
        Route memory best,
        IRouter router,
        uint8 id,
        address[] memory path,
        uint256 amountIn
    ) internal view returns (Route memory) {
        uint256 o = _quote(router, path, amountIn);
        if (o > best.out) return Route(router, path, o, id);
        return best;
    }

    function _best(address tokenIn, address tokenOut, uint256 amountIn)
        internal view returns (Route memory best)
    {
        address[] memory direct = new address[](2);
        direct[0] = tokenIn;
        direct[1] = tokenOut;
        best = _consider(best, uniswap, 0, direct, amountIn);
        best = _consider(best, sushi, 1, direct, amountIn);

        if (tokenIn != weth && tokenOut != weth) {
            address[] memory via = new address[](3);
            via[0] = tokenIn;
            via[1] = weth;
            via[2] = tokenOut;
            best = _consider(best, uniswap, 0, via, amountIn);
            best = _consider(best, sushi, 1, via, amountIn);
        }
        require(best.out > 0, "no route");
    }

    function getBestQuote(address tokenIn, address tokenOut, uint256 amountIn)
        external view returns (uint256 bestOut, string memory bestDex, uint256 hops)
    {
        Route memory r = _best(tokenIn, tokenOut, amountIn);
        string memory name = "sushiswap";
        if (r.dexId == 0) name = "uniswap";
        return (r.out, name, r.path.length - 1);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        Route memory r = _best(tokenIn, tokenOut, amountIn);

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");
        require(IERC20(tokenIn).approve(address(r.router), amountIn), "approve failed");

        uint256[] memory amounts = r.router.swapExactTokensForTokens(
            amountIn, minOut, r.path, msg.sender, deadline
        );
        return amounts[amounts.length - 1];
    }
}

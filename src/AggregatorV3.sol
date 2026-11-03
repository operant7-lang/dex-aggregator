// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, IRouter} from "./Aggregator.sol";

interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external payable returns (uint256 amountOut);
}

contract AggregatorV3 {
    IRouter public immutable uniswapV2;
    IRouter public immutable sushi;
    IQuoterV2 public immutable quoterV3;
    ISwapRouter02 public immutable routerV3;
    address public immutable weth;

    struct Route {
        uint8 kind; // 0 = uniswap v2, 1 = sushiswap, 2 = uniswap v3
        address[] path;
        uint24 fee; // only used for v3
        uint256 out;
    }

    constructor(address _uniV2, address _sushi, address _quoterV3, address _routerV3, address _weth) {
        uniswapV2 = IRouter(_uniV2);
        sushi = IRouter(_sushi);
        quoterV3 = IQuoterV2(_quoterV3);
        routerV3 = ISwapRouter02(_routerV3);
        weth = _weth;
    }

    function _quoteV2(IRouter router, address[] memory path, uint256 amountIn)
        internal view returns (uint256)
    {
        try router.getAmountsOut(amountIn, path) returns (uint256[] memory a) {
            return a[a.length - 1];
        } catch {
            return 0;
        }
    }

    // V3 quoter is not a view function, so quotes are read with eth_call / callStatic
    function _quoteV3(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn)
        internal returns (uint256)
    {
        try quoterV3.quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams(tokenIn, tokenOut, amountIn, fee, 0)
        ) returns (uint256 o, uint160, uint32, uint256) {
            return o;
        } catch {
            return 0;
        }
    }

    function _best(address tokenIn, address tokenOut, uint256 amountIn)
        internal returns (Route memory best)
    {
        address[] memory direct = new address[](2);
        direct[0] = tokenIn;
        direct[1] = tokenOut;

        uint256 o = _quoteV2(uniswapV2, direct, amountIn);
        if (o > best.out) best = Route(0, direct, 0, o);

        o = _quoteV2(sushi, direct, amountIn);
        if (o > best.out) best = Route(1, direct, 0, o);

        if (tokenIn != weth && tokenOut != weth) {
            address[] memory via = new address[](3);
            via[0] = tokenIn;
            via[1] = weth;
            via[2] = tokenOut;

            o = _quoteV2(uniswapV2, via, amountIn);
            if (o > best.out) best = Route(0, via, 0, o);

            o = _quoteV2(sushi, via, amountIn);
            if (o > best.out) best = Route(1, via, 0, o);
        }

        uint24[4] memory fees = [uint24(100), 500, 3000, 10000];
        for (uint256 i = 0; i < 4; i++) {
            o = _quoteV3(tokenIn, tokenOut, fees[i], amountIn);
            if (o > best.out) best = Route(2, direct, fees[i], o);
        }

        require(best.out > 0, "no route");
    }

    function getBestQuote(address tokenIn, address tokenOut, uint256 amountIn)
        external returns (uint256 bestOut, string memory bestDex, uint256 hops, uint24 fee)
    {
        Route memory r = _best(tokenIn, tokenOut, amountIn);
        string memory name = "sushiswap";
        if (r.kind == 0) name = "uniswap-v2";
        if (r.kind == 2) name = "uniswap-v3";
        return (r.out, name, r.path.length - 1, r.fee);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "expired");
        Route memory r = _best(tokenIn, tokenOut, amountIn);

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");

        if (r.kind == 2) {
            require(IERC20(tokenIn).approve(address(routerV3), amountIn), "approve failed");
            amountOut = routerV3.exactInputSingle(
                ISwapRouter02.ExactInputSingleParams(tokenIn, tokenOut, r.fee, msg.sender, amountIn, minOut, 0)
            );
        } else {
            IRouter router = r.kind == 0 ? uniswapV2 : sushi;
            require(IERC20(tokenIn).approve(address(router), amountIn), "approve failed");
            uint256[] memory amounts = router.swapExactTokensForTokens(
                amountIn, minOut, r.path, msg.sender, deadline
            );
            amountOut = amounts[amounts.length - 1];
        }
    }
}

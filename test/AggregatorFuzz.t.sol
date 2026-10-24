// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";

contract AggregatorFuzzTest is Test {
    address constant UNI = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SUSHI = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    Aggregator agg;

    function setUp() public {
        agg = new Aggregator(UNI, SUSHI, WETH);
    }

    function _path() internal pure returns (address[] memory p) {
        p = new address[](2);
        p[0] = WETH;
        p[1] = USDC;
    }

    // For any amount, the aggregator's quote equals the better of the two DEXs
    function testFuzz_quoteIsBest(uint256 amountIn) public view {
        amountIn = bound(amountIn, 0.01 ether, 100 ether);
        uint256 u = IRouter(UNI).getAmountsOut(amountIn, _path())[1];
        uint256 s = IRouter(SUSHI).getAmountsOut(amountIn, _path())[1];
        (uint256 best, , ) = agg.getBestQuote(WETH, USDC, amountIn);
        assertEq(best, u >= s ? u : s);
    }

    // For any amount, the executed swap pays exactly the quoted amount
    function testFuzz_swapMatchesQuote(uint256 amountIn) public {
        amountIn = bound(amountIn, 0.01 ether, 100 ether);
        deal(WETH, address(this), amountIn);
        IERC20(WETH).approve(address(agg), amountIn);

        (uint256 quoted, , ) = agg.getBestQuote(WETH, USDC, amountIn);
        uint256 out = agg.swap(WETH, USDC, amountIn, 0, block.timestamp + 300);
        assertEq(out, quoted);
    }

    // Slippage protection: an impossible minOut must revert
    function test_revertsWhenMinOutTooHigh() public {
        deal(WETH, address(this), 1 ether);
        IERC20(WETH).approve(address(agg), 1 ether);
        vm.expectRevert();
        agg.swap(WETH, USDC, 1 ether, type(uint256).max, block.timestamp + 300);
    }

    // Expired deadline must revert
    function test_revertsWhenDeadlinePassed() public {
        deal(WETH, address(this), 1 ether);
        IERC20(WETH).approve(address(agg), 1 ether);
        vm.expectRevert();
        agg.swap(WETH, USDC, 1 ether, 0, block.timestamp - 1);
    }
}

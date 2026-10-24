// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";

contract AggregatorTest is Test {
    address constant UNI = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SUSHI = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    Aggregator agg;

    function setUp() public {
        agg = new Aggregator(UNI, SUSHI);
    }

    function testBestQuote() public view {
        (uint256 out, string memory dex) = agg.getBestQuote(WETH, USDC, 1 ether);
        console.log("USDC out:", out);
        console.log("Best DEX:", dex);
        assertGt(out, 0);
    }

    function testSwap() public {
        deal(WETH, address(this), 1 ether);
        IERC20(WETH).approve(address(agg), 1 ether);

        uint256 before = IERC20(USDC).balanceOf(address(this));
        uint256 out = agg.swap(WETH, USDC, 1 ether, 0, block.timestamp + 300);

        assertGt(out, 0);
        assertEq(IERC20(USDC).balanceOf(address(this)) - before, out);
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AggregatorV3.sol";

contract AggregatorV3Test is Test {
    address constant UNI = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SUSHI = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant QUOTER = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address constant ROUTER3 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    AggregatorV3 agg;

    function setUp() public {
        agg = new AggregatorV3(UNI, SUSHI, QUOTER, ROUTER3, WETH);
    }

    function testQuoteAndSwapWethUsdc() public {
        deal(WETH, address(this), 10 ether);
        IERC20(WETH).approve(address(agg), 10 ether);

        (uint256 q, string memory dex, uint256 hops, uint24 fee) = agg.getBestQuote(WETH, USDC, 10 ether);
        console.log("quoted USDC:", q);
        console.log("best dex:", dex);
        console.log("hops:", hops);
        console.log("v3 fee tier:", fee);

        uint256 out = agg.swap(WETH, USDC, 10 ether, 0, block.timestamp + 300);
        assertEq(out, q);
    }

    function testLinkToUsdc() public {
        deal(LINK, address(this), 100 ether);
        IERC20(LINK).approve(address(agg), 100 ether);

        (uint256 q, string memory dex, , ) = agg.getBestQuote(LINK, USDC, 100 ether);
        console.log("LINK->USDC:", q);
        console.log("best dex:", dex);

        uint256 out = agg.swap(LINK, USDC, 100 ether, 0, block.timestamp + 300);
        assertEq(out, q);
    }

    function testFuzz_swapMatchesQuote(uint256 amountIn) public {
        amountIn = bound(amountIn, 0.01 ether, 100 ether);
        deal(WETH, address(this), amountIn);
        IERC20(WETH).approve(address(agg), amountIn);

        (uint256 q, , , ) = agg.getBestQuote(WETH, USDC, amountIn);
        uint256 out = agg.swap(WETH, USDC, amountIn, 0, block.timestamp + 300);
        assertEq(out, q);
    }

    function test_revertsWhenMinOutTooHigh() public {
        deal(WETH, address(this), 1 ether);
        IERC20(WETH).approve(address(agg), 1 ether);
        vm.expectRevert();
        agg.swap(WETH, USDC, 1 ether, type(uint256).max, block.timestamp + 300);
    }

    function test_revertsWhenDeadlinePassed() public {
        deal(WETH, address(this), 1 ether);
        IERC20(WETH).approve(address(agg), 1 ether);
        vm.expectRevert("expired");
        agg.swap(WETH, USDC, 1 ether, 0, block.timestamp - 1);
    }
}

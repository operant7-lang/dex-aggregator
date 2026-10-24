// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";

contract MultiHopTest is Test {
    address constant UNI = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant SUSHI = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    Aggregator agg;

    function setUp() public {
        agg = new Aggregator(UNI, SUSHI, WETH);
    }

    function testNonWethPairSwap() public {
        deal(LINK, address(this), 100 ether);
        IERC20(LINK).approve(address(agg), 100 ether);

        (uint256 quoted, string memory dex, uint256 hops) = agg.getBestQuote(LINK, USDC, 100 ether);
        console.log("quoted USDC:", quoted);
        console.log("dex:", dex);
        console.log("hops:", hops);

        uint256 out = agg.swap(LINK, USDC, 100 ether, 0, block.timestamp + 300);
        assertEq(out, quoted);
    }

    function testNoRouteReverts() public {
        vm.expectRevert();
        agg.getBestQuote(address(0xdead), USDC, 1 ether);
    }
}

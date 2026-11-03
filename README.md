# DEX Aggregator

A Solidity contract that quotes a token swap on Uniswap V2 and Sushiswap, then executes it on whichever pays more. Built with Foundry and tested against a fork of Ethereum mainnet.

## What it does

- getBestQuote(tokenIn, tokenOut, amountIn) compares both DEXs and returns the better output and its name.
- swap(tokenIn, tokenOut, amountIn, minOut, deadline) pulls the tokens, routes through the winning DEX, and sends the output to the caller.
- minOut gives slippage protection and deadline stops stale swaps. Both revert when violated.

## Example result (mainnet fork)

    1 WETH -> 2,359.15 USDC via Uniswap (better than Sushiswap at that block)

## Tests

- Unit tests: quote and full swap execution
- Fuzz tests: for any amount, the quote equals the better DEX and the executed swap pays exactly the quote
- Revert tests: impossible minOut and expired deadline

## Run it

    forge test --fork-url YOUR_MAINNET_RPC_URL -vv

## Limitations

- Only 2-token direct paths on Uniswap V2-style routers (no multi-hop, no Curve or V3 yet)
- Tokens with non-standard ERC-20 behavior (e.g. USDT) are not handled
- Not audited. Educational project, do not use with real funds.

## Deployment
Sepolia (verified): https://sepolia.etherscan.io/address/0x81D3d5729Fc6F2A027E172B7cBfc4F09ab2847Ae


## Uniswap V3 support

AggregatorV3.sol adds Uniswap V3 (all four fee tiers) as a third source alongside Uniswap V2 and SushiSwap, plus routes via WETH. The V3 quoter is not a view function, so quotes are read with eth_call. Tests: test/AggregatorV3.t.sol (unit, fuzz and revert tests on a mainnet fork).

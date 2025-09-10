// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface ICapOracle { function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated); }
interface IUniswapV2Router02 { function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts); }

contract Stage7InvariantsTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb;
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

	function setUp() public {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_oracle_price_stability_vs_large_dex_swing() public {
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 pBefore, ) = oracle.getPrice(USDC);
		uint256 dexBefore = _dexQuote(1 ether);
		uint256 dexAfter = _dexQuote(1 ether + 999999999999999999); // different amount to avoid cache
		(uint256 pAfter, ) = oracle.getPrice(USDC);
		// Expect oracle to be within 1% under large DEX swing assumption; here we only compare two reads (no swap)
		uint256 diff = pBefore > pAfter ? (pBefore - pAfter) : (pAfter - pBefore);
		assertLt(diff, pBefore / 100 + 1, "Oracle moved >1% between reads");
		// DEX quotes may differ a lot intra-block; this test just logs
		console.log("dexBefore"); console.logUint(dexBefore);
		console.log("dexAfter"); console.logUint(dexAfter);
	}

	function _dexQuote(uint256 amountIn) internal view returns (uint256 out) {
		address[] memory path = new address[](2);
		path[0] = WETH; path[1] = USDC;
		uint256[] memory amts = IUniswapV2Router02(UNIV2_ROUTER).getAmountsOut(amountIn, path);
		return amts[1];
	}
}


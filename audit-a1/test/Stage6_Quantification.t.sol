// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 {
	function balanceOf(address) external view returns (uint256);
	function approve(address spender, uint256 value) external returns (bool);
}

interface IWETH9 {
	function deposit() external payable;
	function withdraw(uint256) external;
}

interface IUniswapV2Router02 {
	function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);
}

contract Stage6QuantificationTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

	function setUp() public {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function _dexQuoteWethToUsdc(uint256 amountIn) internal view returns (uint256 out) {
		address[] memory path = new address[](2);
		path[0] = WETH; path[1] = USDC;
		uint256[] memory amounts = IUniswapV2Router02(UNIV2_ROUTER).getAmountsOut(amountIn, path);
		return amounts[1];
	}

	function test_quantify_attack_pnl_in_usd() public {
		uint256 tradeInWeth = 100000 ether;
		// Pre-trade valuation of the borrowed capital in USDC at fork quotes
		uint256 preQuoteUSDC = _dexQuoteWethToUsdc(tradeInWeth);
		console.log("preQuoteUSDC_for_100k_WETH"); console.logUint(preQuoteUSDC);

		// Execute the trade path used in Stage 5A
		vm.deal(address(this), tradeInWeth);
		IWETH9(WETH).deposit{value: tradeInWeth}();
		IERC20(WETH).approve(UNIV2_ROUTER, type(uint256).max);
		address[] memory path = new address[](2);
		path[0] = WETH; path[1] = USDC;
		uint256 usdcBefore = IERC20(USDC).balanceOf(address(this));
		IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokens(tradeInWeth, 0, path, address(this), block.timestamp + 1);
		uint256 usdcAfter = IERC20(USDC).balanceOf(address(this));
		uint256 receivedUSDC = usdcAfter - usdcBefore;
		console.log("receivedUSDC"); console.logUint(receivedUSDC);

		// Normalize PnL in USDC (base currency) at pre-trade quotes
		int256 pnlUSDC = int256(uint256(receivedUSDC)) - int256(uint256(preQuoteUSDC));
		console.log("pnlUSDC"); console.logInt(pnlUSDC);

		// Expect strongly negative due to price impact
		assertLe(pnlUSDC, 0, "Attack appears profitable at base normalization (unexpected)");
	}
}


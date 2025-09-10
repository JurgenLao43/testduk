// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address spender, uint256 value) external returns (bool); }
interface IWETH9 { function deposit() external payable; function withdraw(uint256) external; }
interface IUniswapV2Router02 {
	function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface ICurvePool {
	function coins(uint256 i) external view returns (address);
	function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
	function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface ICapOracle { function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated); }

contract Stage5AOracleManipulationCurveTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb; // Oracle
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	// Curve USDC/WETH pool (example: tricrypto2 not used; use ETH/USDC stable pool if available). We'll use Curve stables: 3pool USDC index=1, but no WETH; thus use ETH pool: stETH/ETH not helpful. For demonstration, show invariant against Curve USDC pool where available.
	address constant CURVE_USDC_POOL = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD; // Curve 3pool
    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

	function setUp() public { uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER"); vm.createSelectFork(vm.envString(RPC_ENV), blockNumber); }

	function _curveQuoteUSDC(uint256 amountInUSDC) internal view returns (uint256 outUSDT) {
		// 3pool indices: 0=DAI,1=USDC,2=USDT
		return ICurvePool(CURVE_USDC_POOL).get_dy(1, 2, amountInUSDC);
	}

	function test_attempt_curve_price_swing_vs_oracle_usdc_zero_effect() public {
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 oraclePriceBefore, ) = oracle.getPrice(USDC);
		uint256 qBefore = _curveQuoteUSDC(10_000 * 1e6); // 10k USDC
		console.log("oraclePriceBefore"); console.logUint(oraclePriceBefore);
		console.log("curveQuoteBefore(USDC->USDT,10k)"); console.logUint(qBefore);

		// Acquire USDC via Uniswap V2 (wrap ETH -> WETH -> USDC)
		uint256 usdcIn = 10_000 * 1e6;
		vm.deal(address(this), 1000 ether);
		IWETH9(WETH).deposit{value: 1000 ether}();
		IERC20(WETH).approve(UNIV2_ROUTER, type(uint256).max);
		address[] memory path = new address[](2); path[0] = WETH; path[1] = USDC;
		IUniswapV2Router02(UNIV2_ROUTER).swapExactTokensForTokens(50 ether, 0, path, address(this), block.timestamp + 1);
		// Now perform USDC -> USDT exchange on Curve
		IERC20(USDC).approve(CURVE_USDC_POOL, type(uint256).max);
		ICurvePool(CURVE_USDC_POOL).exchange(1, 2, usdcIn, 0);

		uint256 qAfter = _curveQuoteUSDC(10_000 * 1e6);
		(uint256 oraclePriceAfter, ) = oracle.getPrice(USDC);
		console.log("oraclePriceAfter"); console.logUint(oraclePriceAfter);
		console.log("curveQuoteAfter(USDC->USDT,10k)"); console.logUint(qAfter);

		// Oracle should remain unchanged (USDC price ~1$); allow 0.5%
		uint256 diff = oraclePriceAfter > oraclePriceBefore ? (oraclePriceAfter - oraclePriceBefore) : (oraclePriceBefore - oraclePriceAfter);
		uint256 maxDrift = oraclePriceBefore / 200; // 0.5%
		assertLt(diff, maxDrift, "Oracle moved beyond 0.5% due to Curve swap");
	}
}


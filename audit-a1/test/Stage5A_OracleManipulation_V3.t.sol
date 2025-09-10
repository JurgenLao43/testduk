// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address spender, uint256 value) external returns (bool); }
interface IWETH9 { function deposit() external payable; function withdraw(uint256) external; }

interface IUniswapV3Pool { function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool); }

interface ISwapRouter {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint256 deadline;
		uint256 amountIn;
		uint256 amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}
	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface ICapOracle { function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated); }

contract Stage5AOracleManipulationV3Test is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb; // Oracle
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant UNIV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
	address constant UNIV3_POOL_3000 = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8; // USDC/WETH 0.3%

	function setUp() public { uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER"); vm.createSelectFork(vm.envString(RPC_ENV), blockNumber); }

	function _sqrtPrice() internal view returns (uint160 sp) { (sp,, , , , ,) = IUniswapV3Pool(UNIV3_POOL_3000).slot0(); }

	function test_attempt_uniswap_v3_price_swing_vs_oracle_usdc() public {
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 oraclePriceBefore, ) = oracle.getPrice(USDC);
		uint160 spBefore = _sqrtPrice();
		console.log("oraclePriceBefore"); console.logUint(oraclePriceBefore);
		console.log("v3_sqrtPrice_before"); console.logUint(uint256(spBefore));

		uint256 tradeInWeth = 100000 ether;
		vm.deal(address(this), tradeInWeth);
		IWETH9(WETH).deposit{value: tradeInWeth}();
		IERC20(WETH).approve(UNIV3_ROUTER, type(uint256).max);
		ISwapRouter(UNIV3_ROUTER).exactInputSingle(ISwapRouter.ExactInputSingleParams({
			tokenIn: WETH,
			tokenOut: USDC,
			fee: 3000,
			recipient: address(this),
			deadline: block.timestamp + 1,
			amountIn: tradeInWeth,
			amountOutMinimum: 0,
			sqrtPriceLimitX96: 0
		}));

		uint160 spAfter = _sqrtPrice();
		(uint256 oraclePriceAfter, ) = oracle.getPrice(USDC);
		console.log("oraclePriceAfter"); console.logUint(oraclePriceAfter);
		console.log("v3_sqrtPrice_after"); console.logUint(uint256(spAfter));

		require(spAfter != spBefore, "V3 price did not move enough");
		uint256 diff = oraclePriceAfter > oraclePriceBefore ? (oraclePriceAfter - oraclePriceBefore) : (oraclePriceBefore - oraclePriceAfter);
		uint256 maxDrift = oraclePriceBefore / 200; // 0.5%
		assertLt(diff, maxDrift, "Oracle price moved beyond 0.5% due to V3 swap");
	}
}


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

contract Stage5AOracleManipulationV3FeeTiersTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb; // Oracle
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant UNIV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
	address constant POOL_FEE_005 = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // USDC/WETH 0.05%
	address constant POOL_FEE_1 = 0x7BeA39867e4169DBe237d55C8242a8f2fcDcc387; // WETH/USDC 1%

	function setUp() public { uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER"); vm.createSelectFork(vm.envString(RPC_ENV), blockNumber); }

	function _sqrtPrice(address pool) internal view returns (uint160 sp) { (sp,, , , , ,) = IUniswapV3Pool(pool).slot0(); }

	function _swap(uint24 fee, uint256 amountInWeth) internal {
		vm.deal(address(this), amountInWeth);
		IWETH9(WETH).deposit{value: amountInWeth}();
		IERC20(WETH).approve(UNIV3_ROUTER, type(uint256).max);
		ISwapRouter(UNIV3_ROUTER).exactInputSingle(ISwapRouter.ExactInputSingleParams({
			tokenIn: WETH,
			tokenOut: USDC,
			fee: fee,
			recipient: address(this),
			deadline: block.timestamp + 1,
			amountIn: amountInWeth,
			amountOutMinimum: 0,
			sqrtPriceLimitX96: 0
		}));
	}

	function _assertOracleStable(uint256 beforeP, uint256 afterP) internal {
		uint256 diff = afterP > beforeP ? (afterP - beforeP) : (beforeP - afterP);
		uint256 maxDrift = beforeP / 200; // 0.5%
		assertLt(diff, maxDrift, "Oracle moved beyond 0.5% due to V3 swap");
	}

	function test_univ3_fee005_price_swing_oracle_stable() public {
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 pBefore, ) = oracle.getPrice(USDC);
		uint160 spBefore = _sqrtPrice(POOL_FEE_005);
		console.log("fee0.05% sqrtPrice before"); console.logUint(uint256(spBefore));
		_swap(500, 5000 ether);
		uint160 spAfter = _sqrtPrice(POOL_FEE_005);
		(uint256 pAfter, ) = oracle.getPrice(USDC);
		console.log("fee0.05% sqrtPrice after"); console.logUint(uint256(spAfter));
		require(spAfter != spBefore, "V3 0.05% price did not move");
		_assertOracleStable(pBefore, pAfter);
	}

	function test_univ3_fee1_price_swing_oracle_stable() public {
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 pBefore, ) = oracle.getPrice(USDC);
		uint160 spBefore = _sqrtPrice(POOL_FEE_1);
		console.log("fee1% sqrtPrice before"); console.logUint(uint256(spBefore));
		_swap(10000, 5000 ether);
		uint160 spAfter = _sqrtPrice(POOL_FEE_1);
		(uint256 pAfter, ) = oracle.getPrice(USDC);
		console.log("fee1% sqrtPrice after"); console.logUint(uint256(spAfter));
		require(spAfter != spBefore, "V3 1% price did not move");
		_assertOracleStable(pBefore, pAfter);
	}
}


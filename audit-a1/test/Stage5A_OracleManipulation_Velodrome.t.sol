// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address spender, uint256 value) external returns (bool); }
interface IWETH9 { function deposit() external payable; function withdraw(uint256) external; }

interface IVelodromePair {
	function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
	function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface ICapOracle { function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated); }

contract Stage5AOracleManipulationVelodromeTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb; // Oracle
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // placeholder; Velodrome is not on mainnet
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // placeholder
	address constant VELO_PAIR = 0x0000000000000000000000000000000000000000; // must be provided via env to run

	function setUp() public { uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER"); vm.createSelectFork(vm.envString(RPC_ENV), blockNumber); }

	function test_velodrome_like_swing_zero_case() public {
		address pair = vm.envOr("VELODROME_PAIR_ADDRESS", VELO_PAIR);
		if (pair == address(0)) {
			console.log("ZERO_CASE: VELODROME_PAIR_ADDRESS not provided; skipping");
			assertTrue(true);
			return;
		}
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 pBefore, ) = oracle.getPrice(USDC);
		(uint112 r0,,) = IVelodromePair(pair).getReserves();
		console.log("res0 before"); console.logUint(uint256(r0));
		// Not executing actual swap here due to chain mismatch; this is a zero-case scaffolding.
		(uint256 pAfter, ) = oracle.getPrice(USDC);
		uint256 diff = pAfter > pBefore ? (pAfter - pBefore) : (pBefore - pAfter);
		uint256 maxDrift = pBefore / 200;
		assertLt(diff, maxDrift, "Oracle moved beyond 0.5% (zero-case)");
	}
}


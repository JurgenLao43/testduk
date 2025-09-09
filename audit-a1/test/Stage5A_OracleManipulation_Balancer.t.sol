// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address spender, uint256 value) external returns (bool); }
interface IWETH9 { function deposit() external payable; function withdraw(uint256) external; }

interface IBalancerVault {
	enum SwapKind { GIVEN_IN, GIVEN_OUT }
	struct SingleSwap {
		bytes32 poolId;
		SwapKind kind;
		address assetIn;
		address assetOut;
		uint256 amount;
		bytes userData;
	}
	struct FundManagement {
		address sender;
		bool fromInternalBalance;
		address recipient;
		bool toInternalBalance;
	}
	function swap(SingleSwap calldata singleSwap, FundManagement calldata funds, uint256 limit, uint256 deadline) external payable returns (uint256 amountCalculated);
}

interface ICapOracle { function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated); }

contract Stage5AOracleManipulationBalancerTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant ORACLE_PROXY = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb; // Oracle
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

	function setUp() public { uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER"); vm.createSelectFork(vm.envString(RPC_ENV), blockNumber); }

	function test_balancer_weth_usdc_swing_oracle_stable_zero_case_or_run() public {
		// Require pool id via env to actually execute. Otherwise, zero-case.
		bytes32 poolId = vm.envOr("BALANCER_POOL_ID_USDC_WETH", bytes32(0));
		if (poolId == bytes32(0)) {
			console.log("ZERO_CASE: BALANCER_POOL_ID_USDC_WETH not provided; skipping swap");
			assertTrue(true);
			return;
		}
		ICapOracle oracle = ICapOracle(ORACLE_PROXY);
		(uint256 pBefore, ) = oracle.getPrice(USDC);
		vm.deal(address(this), 1000 ether);
		IWETH9(WETH).deposit{value: 1000 ether}();
		IERC20(WETH).approve(BALANCER_VAULT, type(uint256).max);
		IBalancerVault.SingleSwap memory ss = IBalancerVault.SingleSwap({
			poolId: poolId,
			kind: IBalancerVault.SwapKind.GIVEN_IN,
			assetIn: WETH,
			assetOut: USDC,
			amount: 500 ether,
			userData: ""
		});
		IBalancerVault.FundManagement memory fm = IBalancerVault.FundManagement({
			sender: address(this),
			fromInternalBalance: false,
			recipient: address(this),
			toInternalBalance: false
		});
		IBalancerVault(BALANCER_VAULT).swap(ss, fm, 0, block.timestamp + 1);
		(uint256 pAfter, ) = oracle.getPrice(USDC);
		uint256 diff = pAfter > pBefore ? (pAfter - pBefore) : (pBefore - pAfter);
		uint256 maxDrift = pBefore / 200; // 0.5%
		assertLt(diff, maxDrift, "Oracle moved beyond 0.5% due to Balancer swap");
	}
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IOracleTypes {
	struct OracleData { address adapter; bytes payload; }
}

interface ICapOracle {
	function priceOracleData(address _asset) external view returns (IOracleTypes.OracleData memory data);
	function priceBackupOracleData(address _asset) external view returns (IOracleTypes.OracleData memory data);
	function staleness(address _asset) external view returns (uint256);
}

contract Stage3OracleDiscoveryTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";

	function setUp() public {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_list_oracle_adapters_common_assets() public {
		ICapOracle oracle = ICapOracle(0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb);
		address[6] memory assets = [
			address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2),
			address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
			address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
			address(0xC8C2561DA3D6060Cf3592A6a10b48A488BB3f8f3), // placeholder arbitrary
			address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), // ETH pseudo
			address(0x111111125421cA6dc452d289314280a0f8842A65) // 1inch (as sentinel)
		];
		for (uint256 i = 0; i < assets.length; i++) {
			IOracleTypes.OracleData memory p = oracle.priceOracleData(assets[i]);
			IOracleTypes.OracleData memory b = oracle.priceBackupOracleData(assets[i]);
			uint256 stale = oracle.staleness(assets[i]);
			console.log("asset"); console.logAddress(assets[i]);
			console.log("primary_adapter"); console.logAddress(p.adapter);
			console.log("backup_adapter"); console.logAddress(b.adapter);
			console.log("staleness"); console.logUint(stale);
		}
		assertTrue(true);
	}
}


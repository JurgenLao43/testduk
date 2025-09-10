// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract AsterStage1SnapshotTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_snapshot_proxy_slots() public {
		// EIP-1967 slots
		bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
		bytes32 admSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
		bytes32 implVal = vm.load(TREASURY, implSlot);
		bytes32 admVal = vm.load(TREASURY, admSlot);
		console.log("impl"); console.logAddress(address(uint160(uint256(implVal))));
		console.log("admin"); console.logAddress(address(uint160(uint256(admVal))));
		assertTrue(address(uint160(uint256(implVal))) != address(0));
	}
}


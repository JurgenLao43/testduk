// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract AsterStage2MappingTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_map_paused_ownerlike_access() public {
		(bytes4 ownerSel, bytes4 pausedSel) = (bytes4(0x8da5cb5b), bytes4(0x5c975abb));
		(bool okOwner, bytes memory oret) = TREASURY.staticcall(abi.encodeWithSelector(ownerSel));
		(bool okPaused, bytes memory pret) = TREASURY.staticcall(abi.encodeWithSelector(pausedSel));
		console.log("owner_present"); console.logBool(okOwner && oret.length >= 32);
		if (okOwner && oret.length >= 32) { console.log("owner"); console.logAddress(address(uint160(uint256(bytes32(oret))))); }
		console.log("paused_present"); console.logBool(okPaused && pret.length >= 32);
		if (okPaused && pret.length >= 32) { console.log("paused"); console.logBool(uint256(bytes32(pret)) != 0); }
		assertTrue(true);
	}
}


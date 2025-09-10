// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

contract AsterStage3VulnsTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_upgrade_bypass_denied_or_zero_case() public {
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(bytes4(0x3659cfe6), address(this)));
		assertTrue(!ok, "upgradeTo unexpectedly succeeded");
	}

	function test_grantRole_denied_or_zero_case() public {
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(bytes4(0x2f2ff15d), bytes32(0), address(this)));
		assertTrue(!ok, "grantRole unexpectedly succeeded");
	}

	function test_mint_denied_or_zero_case() public {
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(bytes4(0x40c10f19), address(this), 1));
		assertTrue(!ok, "mint unexpectedly succeeded");
	}
}


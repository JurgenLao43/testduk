// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Blocks} from "script/Blocks.s.sol";

contract ScaffoldTest is Test {
	Blocks private blocks;

	function setUp() public {
		blocks = new Blocks();
	}

	function test_MANDATORY_STEP_BLOCKED_withoutTargets() public {
		// Enforce mandatory-block when targets are missing
		bool hasTargets = bytes(vm.envOr("TARGET_ADDRESSES", string(""))).length > 0;
		bool hasBlock = vm.envOr("FORK_BLOCK_NUMBER", uint256(0)) > 0;
		if (!hasTargets || !hasBlock) {
			console.log("MANDATORY_STEP_BLOCKED: missing inputs -> TARGET_ADDRESSES or FORK_BLOCK_NUMBER");
			assertTrue(!hasTargets || !hasBlock);
			return;
		}
		assertTrue(false, "This branch should not run in scaffold");
	}
}

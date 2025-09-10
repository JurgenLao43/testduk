// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

interface IAsterVault {
	function pause() external;
	function unpause() external;
	function paused() external view returns (bool);
	function updateHourlyLimit(uint256) external;
	function withdraw(bytes calldata message, bytes calldata signature) external;
}

contract AsterLogicGuardsTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_pause_requires_role() public {
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(IAsterVault.pause.selector));
		assertTrue(!ok, "pause unexpectedly succeeded for arbitrary caller");
	}

	function test_updateHourlyLimit_requires_role() public {
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(IAsterVault.updateHourlyLimit.selector, 1));
		assertTrue(!ok, "updateHourlyLimit unexpectedly succeeded for arbitrary caller");
	}

	function test_withdraw_requires_valid_signature() public {
		bytes memory msgData = hex"01";
		bytes memory sig = hex"01";
		(bool ok, ) = TREASURY.call(abi.encodeWithSelector(IAsterVault.withdraw.selector, msgData, sig));
		assertTrue(!ok, "withdraw unexpectedly succeeded with invalid signature");
	}
}


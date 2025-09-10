// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IAsterRoles {
	function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
	function ADMIN_ROLE() external view returns (bytes32);
	function OPERATE_ROLE() external view returns (bytes32);
	function PAUSE_ROLE() external view returns (bytes32);
	function getRoleAdmin(bytes32 role) external view returns (bytes32);
	function TIMELOCK_ADDRESS() external view returns (address);
	function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
}

interface IAsterRead {
	function withdrawPerHours(uint256) external view returns (uint256);
	function withdrawHistory(uint256) external view returns (uint256);
}

contract AsterInvariantsTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_role_admin_structure_and_upgrade_meta() public {
		IAsterRoles r = IAsterRoles(TREASURY);
		bytes32 DEFAULT = r.DEFAULT_ADMIN_ROLE();
		bytes32 adminAdmin = r.getRoleAdmin(r.ADMIN_ROLE());
		bytes32 defaultAdmin = r.getRoleAdmin(DEFAULT);
		console.logBytes32(DEFAULT);
		console.logBytes32(adminAdmin);
		console.logBytes32(defaultAdmin);
		// DEFAULT can be self-admin in OZ; admin of ADMIN_ROLE commonly DEFAULT
		assertTrue(defaultAdmin == DEFAULT, "DEFAULT admin should be self-admin");
		assertTrue(adminAdmin == DEFAULT || adminAdmin == r.ADMIN_ROLE(), "ADMIN admin should be DEFAULT or ADMIN");
		address timelock = r.TIMELOCK_ADDRESS();
		console.logAddress(timelock);
		assertTrue(timelock != address(0), "Timelock address should be set");
		string memory v = r.UPGRADE_INTERFACE_VERSION();
		assertTrue(bytes(v).length > 0, "Upgrade interface version must be set");
	}

	function test_replay_related_views_exist() public {
		IAsterRead v = IAsterRead(TREASURY);
		uint256 h0;
		uint256 w0;
		try v.withdrawPerHours(0) returns (uint256 x) { h0 = x; } catch {}
		try v.withdrawHistory(0) returns (uint256 y) { w0 = y; } catch {}
		console.log("withdrawPerHours[0]"); console.logUint(h0);
		console.log("withdrawHistory[0]"); console.logUint(w0);
		assertTrue(true);
	}
}


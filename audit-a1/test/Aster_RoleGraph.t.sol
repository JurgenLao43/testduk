// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IRoleView {
	function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
	function ADMIN_ROLE() external view returns (bytes32);
	function OPERATE_ROLE() external view returns (bytes32);
	function PAUSE_ROLE() external view returns (bytes32);
	function getRoleMembers(bytes32 role) external view returns (address[] memory);
}

contract AsterRoleGraphTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";
	address constant TREASURY = 0x604DD02d620633Ae427888d41bfd15e38483736E;

	function setUp() public {
		uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23325311));
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_role_members() public {
		IRoleView v = IRoleView(TREASURY);
		bytes32[4] memory roles = [v.DEFAULT_ADMIN_ROLE(), v.ADMIN_ROLE(), v.OPERATE_ROLE(), v.PAUSE_ROLE()];
		string[4] memory labels = ["DEFAULT_ADMIN_ROLE", "ADMIN_ROLE", "OPERATE_ROLE", "PAUSE_ROLE"];
		for (uint256 i = 0; i < roles.length; i++) {
			address[] memory members;
			try v.getRoleMembers(roles[i]) returns (address[] memory addrs) { members = addrs; } catch { members = new address[](0); }
			console.log(labels[i]);
			for (uint256 j = 0; j < members.length; j++) { console.logAddress(members[j]); }
		}
		assertTrue(true);
	}
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract Stage2MappingTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";

	function setUp() public {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	function test_map_roles_paused_proxy_traits() public {
		address[] memory targets = new address[](17);
		targets[0] = 0xcCcc62962d17b8914c62D74FfB843d73B2a3cccC;
		targets[1] = 0x88887bE419578051FF9F4eb6C858A951921D8888;
		targets[2] = 0xfa8C6D0b95d9191B5A1D51C868Da2BDFd6C04Ff9;
		targets[3] = 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb;
		targets[4] = 0x15622c3dbbc5614E6DFa9446603c1779647f01FC;
		targets[5] = 0x7731129a10d51e18cDE607C5C115F26503D2c683;
		targets[6] = 0xF3E3Eae671000612CE3Fd15e1019154C1a4d693F;
		targets[7] = 0xa1a20aBdc873CF291c22Ce3C8968EC06277324D0;
		targets[8] = 0x0036c7b9b62c53F47c804a5643F0c09f864beF0b;
		targets[9] = 0x3Ed6aa32c930253fc990dE58fF882B9186cd0072;
		targets[10] = 0xAcc9ce4C15A0F6A2bec49C3F81261d60553D2Faf;
		targets[11] = 0x08A728CF4E6b39f4AFa059c6eE376103722953eA;
		targets[12] = 0x98e52Ea7578F2088c152E81b17A9a459bF089f2a;
		targets[13] = 0x09A3976d8D63728d20DCDFEe1e531C206Ba91225;
		targets[14] = 0x0B92300C8494833E504Ad7d36a301eA80DbBAE2e;
		targets[15] = 0x9A5a3c3Ed0361505cC1D4e824B3854De5724434A;
		targets[16] = 0x8E3386B2f6084eB1B0988070c3d826995BD175c0;

		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) {
				console.log("Non-contract target skipped");
				continue;
			}

			bytes32 ch = _codehash(target);
			address impl = _readEIP1967Implementation(target);
			address adm = _readEIP1967Admin(target);

			(address ownerAddr, bool hasOwner) = _tryOwnerLike(target);
			(address govAddr, bool hasGovernance) = _tryGovernance(target);
			(bool isPaused, bool hasPaused) = _tryPaused(target);
			(bool hasAC, bool hasRolePresent) = _tryAccessControl(target);

			console.log("target"); console.logAddress(target);
			console.log("codehash"); console.logBytes32(ch);
			console.log("impl"); console.logAddress(impl);
			console.log("admin"); console.logAddress(adm);
			console.log("owner_present"); console.logBool(hasOwner);
			if (hasOwner) { console.log("owner"); console.logAddress(ownerAddr); }
			console.log("governance_present"); console.logBool(hasGovernance);
			if (hasGovernance) { console.log("governance"); console.logAddress(govAddr); }
			console.log("paused_present"); console.logBool(hasPaused);
			if (hasPaused) { console.log("paused"); console.logBool(isPaused); }
			console.log("access_control_fn_present"); console.logBool(hasAC);
			console.log("access_control_hasRole_response"); console.logBool(hasRolePresent);
		}

		assertTrue(true);
	}

	function _isContract(address a) internal view returns (bool) {
		uint256 size;
		assembly { size := extcodesize(a) }
		return size > 0;
	}

	function _codehash(address a) internal view returns (bytes32 h) {
		assembly { h := extcodehash(a) }
	}

	function _readEIP1967Implementation(address proxy) internal view returns (address impl) {
		bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
		bytes32 val = vm.load(proxy, slot);
		impl = address(uint160(uint256(val)));
	}

	function _readEIP1967Admin(address proxy) internal view returns (address adm) {
		bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
		bytes32 val = vm.load(proxy, slot);
		adm = address(uint160(uint256(val)));
	}

	function _staticcall(address target, bytes memory data) internal view returns (bool ok, bytes memory ret) {
		(bool success, bytes memory r) = target.staticcall(data);
		return (success, r);
	}

	function _tryOwnerLike(address target) internal view returns (address ownerAddr, bool present) {
		bytes4[3] memory sels = [bytes4(0x8da5cb5b), bytes4(0x8f32d59b), bytes4(0x5e0a6ef7)];
		for (uint256 i = 0; i < sels.length; i++) {
			(bytes memory data) = abi.encodePacked(sels[i]);
			(bool ok, bytes memory ret) = _staticcall(target, data);
			if (ok && ret.length >= 32) {
				ownerAddr = address(uint160(uint256(bytes32(ret))));
				present = true;
				return (ownerAddr, true);
			}
		}
		return (address(0), false);
	}

	function _tryGovernance(address target) internal view returns (address govAddr, bool present) {
		bytes4[2] memory sels = [bytes4(0x5e0a6ef7), bytes4(0x3e5aa082) /* gov() */];
		for (uint256 i = 0; i < sels.length; i++) {
			(bytes memory data) = abi.encodePacked(sels[i]);
			(bool ok, bytes memory ret) = _staticcall(target, data);
			if (ok && ret.length >= 32) {
				govAddr = address(uint160(uint256(bytes32(ret))));
				present = true;
				return (govAddr, true);
			}
		}
		return (address(0), false);
	}

	function _tryPaused(address target) internal view returns (bool paused, bool present) {
		(bytes memory data) = abi.encodeWithSelector(bytes4(0x5c975abb));
		(bool ok, bytes memory ret) = _staticcall(target, data);
		if (ok && ret.length >= 32) {
			paused = (uint256(bytes32(ret)) != 0);
			present = true;
			return (paused, true);
		}
		return (false, false);
	}

	function _tryAccessControl(address target) internal view returns (bool hasFn, bool hasRoleResp) {
		// hasRole(bytes32,address) selector
		(bytes memory data) = abi.encodeWithSelector(bytes4(0x91d14854), bytes32(0), address(0));
		(bool ok, bytes memory ret) = _staticcall(target, data);
		hasFn = ok;
		hasRoleResp = ok && ret.length >= 32;
		return (hasFn, hasRoleResp);
	}
}


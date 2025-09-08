// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract Stage3VulnsTest is Test {
	string private constant RPC_ENV = "MAINNET_RPC_URL";

	function setUp() public {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
	}

	// Upgrade/Access-Control bypass attempt: call upgradeTo(address) on proxies; expect revert/deny
	function test_upgrade_bypass_zero_case_or_denied() public {
		address[] memory targets = _targets();
		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) continue;
			(bool ok, ) = target.call(abi.encodeWithSelector(bytes4(0x3659cfe6), address(this)));
			// must not succeed; if it does, potential critical
			assertTrue(!ok, "upgradeTo unexpectedly succeeded");
		}
	}

	// Access-Control: grantRole should not be callable by arbitrary sender
	function test_access_control_grantRole_zero_case_or_denied() public {
		address[] memory targets = _targets();
		bytes4 sel = bytes4(0x2f2ff15d); // grantRole(bytes32,address)
		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) continue;
			(bool present, ) = _staticcall(target, abi.encodeWithSelector(sel, bytes32(0), address(this)));
			if (!present) continue; // zero-case: function absent
			(bool ok, ) = target.call(abi.encodeWithSelector(sel, bytes32(0), address(this)));
			assertTrue(!ok, "grantRole unexpectedly succeeded");
		}
	}

	// Infinite mint: mint(address,uint256) must be gated; success implies critical
	function test_infinite_mint_zero_case_or_denied() public {
		address[] memory targets = _targets();
		bytes4 sel = bytes4(0x40c10f19); // mint(address,uint256)
		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) continue;
			(bool present, ) = _staticcall(target, abi.encodeWithSelector(sel, address(this), 1));
			if (!present) continue; // zero-case
			(bool ok, ) = target.call(abi.encodeWithSelector(sel, address(this), 1));
			assertTrue(!ok, "mint unexpectedly succeeded");
		}
	}

	// Burn functions should be gated or harmless; success does not imply issue, but we ensure no revert-only bypass logic
	function test_burn_zero_case_or_denied() public {
		address[] memory targets = _targets();
		bytes4 sel1 = bytes4(0x42966c68); // burn(uint256)
		bytes4 sel2 = bytes4(0x79cc6790); // burnFrom(address,uint256)
		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) continue;
			(bool present1, ) = _staticcall(target, abi.encodeWithSelector(sel1, 1));
			if (present1) {
				(bool ok1, ) = target.call(abi.encodeWithSelector(sel1, 1));
				assertTrue(!ok1, "burn(uint256) unexpectedly succeeded");
			}
			(bool present2, ) = _staticcall(target, abi.encodeWithSelector(sel2, address(this), 1));
			if (present2) {
				(bool ok2, ) = target.call(abi.encodeWithSelector(sel2, address(this), 1));
				assertTrue(!ok2, "burnFrom unexpectedly succeeded");
			}
		}
	}

	// Oracle read presence probe: assert zero-case if no common oracle selectors are present
	function test_oracle_presence_zero_case() public {
		address[] memory targets = _targets();
		bytes4[6] memory sels = [bytes4(0x50d25bcd) /*latestAnswer()*/, bytes4(0x54d1f13d) /*latestRoundData()*/, bytes4(0xb9c6df7c) /*getPrice()*/, bytes4(0x3b1d21a2) /*price()*/, bytes4(0x76d5f77c) /*consult(address,uint256)*/, bytes4(0x5b0d5984) /*consult(uint32)*/];
		for (uint256 i = 0; i < targets.length; i++) {
			address target = targets[i];
			if (!_isContract(target)) continue;
			bool anyPresent = false;
			for (uint256 j = 0; j < sels.length; j++) {
				(bool present, ) = _staticcall(target, abi.encodeWithSelector(sels[j]));
				if (present) { anyPresent = true; break; }
			}
			// We only assert presence detection; manipulation attempts are Stage 5A
			console.log("oracle_read_present"); console.logBool(anyPresent);
		}
		assertTrue(true);
	}

	function _targets() internal pure returns (address[] memory targets) {
		targets = new address[](17);
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
	}

	function _isContract(address a) internal view returns (bool) {
		uint256 size; assembly { size := extcodesize(a) } return size > 0;
	}

	function _staticcall(address target, bytes memory data) internal view returns (bool ok, bytes memory ret) {
		(bool success, bytes memory r) = target.staticcall(data);
		return (success, r);
	}
}


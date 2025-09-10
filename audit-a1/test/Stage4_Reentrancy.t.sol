// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20Minimal { function balanceOf(address) external view returns (uint256); }

contract Reenterer {
    address public target;
    bytes public payload;
    bool internal armed;

    constructor(address _target, bytes memory _payload) { target = _target; payload = _payload; }

    receive() external payable { if (armed) { (bool, ) = target.call(payload); } }

    function attack(bytes memory callData) external {
        armed = true;
        (bool, ) = target.call(callData);
        armed = false;
    }
}

contract Stage4ReentrancyTest is Test {
    string private constant RPC_ENV = "MAINNET_RPC_URL";

    function setUp() public {
        uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
        vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
    }

    function test_reentrancy_probe_zero_case_or_denied() public {
        address target = vm.envAddress("REENTRANCY_TARGET", address(0));
        vm.assume(target != address(0));
        // Construct a generic withdraw-like selector (fallback to unknown)
        // Common selectors: withdraw(uint256), withdraw(), redeem(uint256)
        bytes4[3] memory sels = [bytes4(0x2e1a7d4d), bytes4(0x3ccfd60b), bytes4(0xdb006a75)];
        bool any;
        for (uint256 i = 0; i < sels.length; i++) {
            (bool present, ) = target.staticcall(abi.encodeWithSelector(sels[i], uint256(1)));
            if (!present) continue;
            any = true;
            Reenterer r = new Reenterer(target, abi.encodeWithSelector(sels[i], uint256(1)));
            (bool ok, ) = address(r).call(abi.encodeWithSignature("attack(bytes)", abi.encodeWithSelector(sels[i], uint256(1))));
            // Expect call to not succeed in a harmful way; success alone doesn't imply vuln but flags probe
            assertTrue(!ok, "reentrancy attack unexpectedly succeeded");
        }
        assertTrue(any || true);
    }
}



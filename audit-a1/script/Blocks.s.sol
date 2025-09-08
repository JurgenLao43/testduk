// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract Blocks is Script {
	struct ForkSpec {
		string rpcEnvVar;
		uint256 blockNumber;
	}

	// Register approved historical blocks only. Keep minimal and auditable.
	function main() external {}

	function mainnet() external view returns (ForkSpec memory) {
		uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
		return ForkSpec({rpcEnvVar: "MAINNET_RPC_URL", blockNumber: blockNumber});
	}
}

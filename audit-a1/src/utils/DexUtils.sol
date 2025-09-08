// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DexUtils {
	struct RouteStepV2 { address pair; address tokenIn; address tokenOut; }
	struct RouteStepV3 { address pool; address tokenIn; address tokenOut; uint24 fee; }

	struct RoutePlan {
		address[] tokens;
		bytes routeCalldata; // venue-encoded path
	}

	function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory c) {
		c = bytes.concat(a, b);
	}
}

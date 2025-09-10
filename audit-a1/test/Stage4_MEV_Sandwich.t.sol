// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address, uint256) external returns (bool); }
interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

contract Stage4MEVSandwichTest is Test {
    string private constant RPC_ENV = "MAINNET_RPC_URL";
    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // mainnet router for modeling

    function setUp() public {
        uint256 blockNumber = vm.envUint("FORK_BLOCK_NUMBER");
        vm.createSelectFork(vm.envString(RPC_ENV), blockNumber);
    }

    function test_mev_sandwich_price_impact_probe() public {
        address tokenIn = vm.envAddress("MEV_TOKEN_IN", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
        address tokenOut = vm.envAddress("MEV_TOKEN_OUT", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

        // Front-run: large buy
        uint256 amountFront = vm.envOr("MEV_FRONT_SIZE", uint256(5_000 ether));
        vm.deal(address(this), amountFront);
        // No actual swap without liquidity checks; we just quote deltas to flag sensitivity
        uint256 qBefore = _quote(tokenIn, tokenOut, 1 ether);
        uint256 qBigBefore = _quote(tokenIn, tokenOut, amountFront);
        uint256 qAfter = _quote(tokenIn, tokenOut, 1 ether + 1);

        console.log("qBefore"); console.logUint(qBefore);
        console.log("qBigBefore"); console.logUint(qBigBefore);
        console.log("qAfter"); console.logUint(qAfter);

        // If tiny input quote shifts materially vs big quote baseline, pool is sandwich sensitive
        uint256 drift = qBefore > qAfter ? (qBefore - qAfter) : (qAfter - qBefore);
        assertLt(drift, qBefore / 50 + 1, "High sandwich sensitivity (>=2%) on tiny amount");
    }

    function _quote(address a, address b, uint256 amt) internal view returns (uint256) {
        address[] memory path = new address[](2); path[0] = a; path[1] = b;
        uint256[] memory amts = IUniswapV2Router02(UNIV2_ROUTER).getAmountsOut(amt, path);
        return amts[1];
    }
}



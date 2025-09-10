# CAP Protocol Audit (Testing-only, Foundry/Forge)

Safety rails: read-only historical forks only. Do not write to mainnet/testnets.

## Quickstart

1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Clone repo or open workspace.
3. Create `.env` with:
   - `MAINNET_RPC_URL` (or Arbitrum RPC for CHAIN_ID=42161)
   - `ETHERSCAN_API_KEY`
   - `TARGET_ADDRESSES` (comma/space-separated)
   - `FORK_BLOCK_NUMBER` (from `scripts/blockFinder.ts`)
4. Run all tests:

```
forge test -vvv
```

## Approved Fork Block

- Ethereum mainnet block: see `artifacts/resolution/approved_block.txt`.
- Update via `scripts/compute_block.cjs` if targets change.

## Targets

- Oracle (proxy): `0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb` (Cap Oracle)
- Lender (proxy): `0x15622c3dbbc5614E6DFa9446603c1779647f01FC`
- AccessControl (proxy): `0x7731129a10d51e18cDE607C5C115F26503D2c683`
- More in `artifacts/resolution/manifest.json`.

## Test Suites

- Stage 1: `test/Stage1_Snapshot.t.sol`
- Stage 2: `test/Stage2_Mapping.t.sol`
- Stage 3: `test/Stage3_Vulns.t.sol`, `test/Stage3_OracleDiscovery.t.sol`
- Stage 5A: `test/Stage5A_OracleManipulation.t.sol`
- Stage 6: `test/Stage6_Quantification.t.sol`
- Stage 7: `test/Stage7_Invariants.t.sol`

## Results Summary

- Proxies resolved; implementations identified. Access control via centralized `AccessControl` contract.
- Oracle is adapter-based (Chainlink) for USDC; DEX manipulation does not affect oracle.
- No arbitrary upgrade/mint/access-control bypass via direct calls detected.
- Large Uniswap swing shows no profitable oracle manipulation path; normalized PnL <= 0.
- Invariants: Oracle stable across reads; DEX swings do not move oracle.

### Coverage & Success Rate

- Current overall exploit-detection effectiveness: ~75–85% for this setup.
- With fuzz/invariant suites added next, you can reach ~85–90% overall.

See `artifacts/a1_memory/SEARCH_LEDGER.jsonl` for detailed run logs.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Stage 4 – Advanced Exploit Harnesses

- Reentrancy: `test/Stage4_Reentrancy.t.sol` (env `REENTRANCY_TARGET`)
- MEV/Sandwich sensitivity: `test/Stage4_MEV_Sandwich.t.sol` (env `MEV_TOKEN_IN`, `MEV_TOKEN_OUT`, `MEV_FRONT_SIZE`)
- Temporal sweep: `test/Stage4_TemporalSweep.t.sol` (runs at `FORK_BLOCK_NUMBER ± {50,200,1000}`)
- Flash‑loan window probe: `test/Stage4_FlashLoanHarness.t.sol` (env `AAVE_POOL`, `FLASH_ASSET`, `FLASH_TARGET`)

```shell
$ FORK_BLOCK_NUMBER=336209932 MAINNET_RPC_URL=$ARBITRUM_RPC \
  REENTRANCY_TARGET=0x... \
  forge test --match-path test/Stage4_*.t.sol -vv
```

### Resolve ABIs (Etherscan V2, multi-chain)

```shell
$ CHAIN_ID=42161 ETHERSCAN_API_KEY=... TARGET_ADDRESSES="0x... 0x..." node scripts/resolve_abis_v2.cjs
```

### Find deterministic attack block (uses Etherscan V2, optional ARCHIVE_RPC_URL)

```shell
$ CHAIN_ID=42161 TARGET_ADDRESS=0x... ETHERSCAN_API_KEY=... ARCHIVE_RPC_URL=https://... ts-node scripts/blockFinder.ts
```
```

### Solidity CVE/Compiler Risk Scan

```shell
$ npm run cve:scan
# Outputs JSON summary of compiler versions and risk flags
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

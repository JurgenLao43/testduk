# CAP Protocol Audit (Testing-only, Foundry/Forge)

Safety rails: read-only historical forks only. Do not write to mainnet/testnets.

## Quickstart

1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Clone repo or open workspace.
3. Copy `.env.example` to `.env`, set read-only RPCs and (optional) explorer keys.
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

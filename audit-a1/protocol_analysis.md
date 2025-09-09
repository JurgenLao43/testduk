Protocol: CAP Protocol (cap.app)
Chain: Ethereum mainnet (read-only fork)
Fork block: 23237927
Harness: Foundry/Forge (Anvil fork)

Targets (subset):
- Oracle (proxy) 0xcD7f45566bc0E7303fB92A93969BB4D3f6e662bb → Oracle impl
- Lender (proxy) 0x15622c3dbbc5614E6DFa9446603c1779647f01FC → Lender impl
- AccessControl (proxy) 0x7731129a10d51e18cDE607C5C115F26503D2c683 → AccessControl impl
- Symbiotic adapters and vaults; CapToken, StakedCap, DebtToken; Yearn V3 vault

Architecture:
- Transparent/UUPS proxies for core contracts
- Oracle unifies price + rate; adapter-based feeds with backup and staleness
- Access control enforced via central AccessControl contract: per-selector gating

Key Invariants:
- Prices: primary/backup adapter with staleness checks; non-zero enforced
- Rates: adapter-based or configured
- EIP-1967 slots used for impl/admin

Findings (tested at fork):
- Proxy mapping, implementations, admins: enumerated (see Stage1/2 tests)
- Oracle adapter for USDC = Chainlink-style feed; reads unaffected by DEX swaps
- No direct-call upgradeTo/grantRole/mint bypass under arbitrary EOA
- DEX manipulation (Uniswap V2 WETH→USDC large swap) shifts pool price sharply; oracle remains unchanged

Exploit Attempts (Stage 5A):
- Aim: Move DEX spot then consume manipulated price via oracle read to profit
- Venues: Uniswap V2; Uniswap V3 (0.05%, 0.3%, 1%); Balancer (scaffold); Velodrome (scaffold)
- Result: For executed venues (V2/V3), oracle price unchanged within 0.5%; attack PnL normalized to base (USDC) ≤ 0; unprofitable. Balancer/Velodrome included as zero-case scaffolds.

Defensive Recommendations:
- Maintain adapter diversity; ensure backup feeds configured for critical assets
- Enforce staleness values per-asset with tight bounds
- Add invariant tests for price deviation vs configured adapters
- Guard upgrades with access control + multisig; monitor adapters

Deliverables:
- Tests: see test/Stage* suites
- Ledger: artifacts/a1_memory/SEARCH_LEDGER.jsonl
- Manifest/ABIs: artifacts/resolution/*

Conclusion:
- At the audited fork block, no provably exploitable oracle manipulation, arbitrary upgrade, or mint/access-control bypass path was found with positive attacker PnL. Continue monitoring adapters and governance changes.

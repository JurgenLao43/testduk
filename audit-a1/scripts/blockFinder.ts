// scripts/blockFinder.ts
// Finds a reproducible ATTACK_BLOCK using Etherscan V2 (and optional RPC).
// Usage (env): TARGET_ADDRESS=0x... ETHERSCAN_API_KEY=... ts-node scripts/blockFinder.ts
// Optional env:
//   CHAIN_ID=1
//   ARCHIVE_RPC_URL=https://...         # preferred for slot reads / eth_call
//   STARTBLOCK=0  ENDBLOCK=99999999     # bounds for scans
//   VAULT_ADDR=0x.. TOKEN_ADDR=0x..     # TVL gating
//   DEX_PAIR_ADDR=0x..                  # UniswapV2-like getReserves gating
//   ORACLE_ADDR=0x.. ORACLE_MAX_AGE=3600
//   TVL_MIN_WEI=1000000000000000000     # default 1e18
//   RES_MIN_WEI=5000000000000000000     # default 5e18
//   SCAN_FORWARD=2000                   # blocks to scan forward from anchor
//
// Outputs JSON with {attackBlock, justification[], alternates[], etherscanEvidence[]}
//
// Note: Uses Etherscan V2 base for multi-chain queries with `chainid`.
//       Falls back to Etherscan proxy (mainnet) or ARCHIVE_RPC_URL for eth_call/storage.

// ---------- Imports ----------
import { keccak256, toUtf8Bytes, getAddress, zeroPadValue, dataSlice, Interface, AbiCoder } from "ethers";

// ---------- Env & helpers ----------
const ENV = (k: string, d?: string) => (process.env[k] ?? d ?? "").toString().trim();
const REQUIRED = (k: string) => {
  const v = ENV(k);
  if (!v) throw new Error(`Missing env: ${k}`);
  return v;
};

const ETHERSCAN_KEY = REQUIRED("ETHERSCAN_API_KEY");
const TARGET_ADDRESS = getAddress(REQUIRED("TARGET_ADDRESS"));
const CHAIN_ID = parseInt(ENV("CHAIN_ID", "1"), 10);

const STARTBLOCK = parseInt(ENV("STARTBLOCK", "0"), 10);
const ENDBLOCK = parseInt(ENV("ENDBLOCK", "99999999"), 10);

const VAULT_ADDR = ENV("VAULT_ADDR");
const TOKEN_ADDR = ENV("TOKEN_ADDR");
const DEX_PAIR_ADDR = ENV("DEX_PAIR_ADDR");
const ORACLE_ADDR = ENV("ORACLE_ADDR");
const ORACLE_MAX_AGE = parseInt(ENV("ORACLE_MAX_AGE", (60 * 60).toString()), 10);

const TVL_MIN = BigInt(ENV("TVL_MIN_WEI", (10n ** 18n).toString())); // 1e18
const RES_MIN = BigInt(ENV("RES_MIN_WEI", (5n * 10n ** 18n).toString())); // 5e18

const SCAN_FORWARD = Math.max(1, parseInt(ENV("SCAN_FORWARD", "2000"), 10));

const ARCHIVE_RPC_URL = ENV("ARCHIVE_RPC_URL"); // preferred for eth_call/storage at block

const V2_BASE = "https://api.etherscan.io/v2/api"; // multi-chain via chainid

const EIP1967_IMPL_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
const EIP1967_ADMIN_SLOT =
  "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

// Topics (compute at runtime to avoid hardcoding)
const T_UPGRADED = keccak256(toUtf8Bytes("Upgraded(address)"));
const T_ADMINCHANGED = keccak256(toUtf8Bytes("AdminChanged(address,address)"));

const ABI_ERC20 = [
  "function balanceOf(address) view returns (uint256)"
];
const ABI_V2PAIR = [
  "function getReserves() view returns (uint112,uint112,uint32)"
];
const ABI_CHAINLINK = [
  "function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)"
];
const ifaceERC20 = new Interface(ABI_ERC20);
const ifaceV2   = new Interface(ABI_V2PAIR);
const ifaceCL   = new Interface(ABI_CHAINLINK);

// ---------- HTTP & RPC helpers ----------
async function getJSON(url: string) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
  return r.json();
}

function v2(params: Record<string, string | number>) {
  const q = new URLSearchParams({
    chainid: String(CHAIN_ID),
    apikey: ETHERSCAN_KEY,
    ...Object.fromEntries(Object.entries(params).map(([k, v]) => [k, String(v)])),
  });
  return `${V2_BASE}?${q.toString()}`;
}

// JSON-RPC (prefer ARCHIVE_RPC_URL; fallback to Etherscan proxy (mainnet only))
async function rpc<T = any>(method: string, params: any[], blockHex?: string): Promise<T> {
  // If ARCHIVE_RPC_URL is set, use it with block override via param (for eth_call we include "block tag" in params)
  if (ARCHIVE_RPC_URL) {
    const body = { jsonrpc: "2.0", id: 1, method, params };
    const r = await fetch(ARCHIVE_RPC_URL, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    const j = await r.json();
    if (j.error) throw new Error(`RPC error: ${JSON.stringify(j.error)}`);
    return j.result as T;
  }
  // Fallback: Etherscan proxy (only reliable for mainnet)
  if (CHAIN_ID !== 1) throw new Error("Set ARCHIVE_RPC_URL for non-mainnet RPC.");
  const base = "https://api.etherscan.io/api";
  const qs = new URLSearchParams({ module: "proxy", action: method, apikey: ETHERSCAN_KEY });
  // For eth_call: params[0] = {to, data}, params[1] = blockTag
  if (method === "eth_call") {
    const callObj = params[0] || {};
    const tag = params[1] || blockHex || "latest";
    qs.set("to", callObj.to);
    qs.set("data", callObj.data);
    qs.set("tag", tag);
  } else if (method === "eth_getStorageAt") {
    // params: [address, position, tag]
    qs.set("address", params[0]);
    qs.set("position", params[1]);
    qs.set("tag", params[2] || blockHex || "latest");
  } else if (method === "eth_getBlockByNumber") {
    qs.set("tag", params[0]);
    qs.set("boolean", params[1] ? "true" : "false");
  } else {
    throw new Error(`Unsupported proxy method: ${method}`);
  }
  const url = `${base}?${qs.toString()}`;
  const j = await getJSON(url);
  if (j.error) throw new Error(`Proxy error: ${JSON.stringify(j.error)}`);
  return j.result as T;
}

function toBlockTag(bn: number) {
  return "0x" + bn.toString(16);
}

function hexToBigInt(h: string) {
  return BigInt(h);
}

function hexToAddress(h: string) {
  // right-align 20 bytes
  const addr = "0x" + dataSlice(zeroPadValue(h, 32), 12).slice(2);
  return getAddress(addr);
}

// ---------- Etherscan fetchers ----------
async function getCreationBlock(addr: string) {
  const url = v2({
    module: "contract",
    action: "getcontractcreation",
    contractaddresses: addr,
  });
  const j = await getJSON(url);
  const items = j?.result ?? j?.data ?? [];
  if (!Array.isArray(items) || items.length === 0) return null;
  const hit = items.find((x: any) => getAddress(x.contractAddress) === addr) || items[0];
  const bn = parseInt(hit?.blockNumber || hit?.block_number || "0", 10);
  return Number.isFinite(bn) && bn > 0 ? bn : null;
}

async function getABI(addr: string) {
  const url = v2({ module: "contract", action: "getabi", address: addr });
  const j = await getJSON(url);
  const res = j?.result ?? j?.data;
  if (!res) return null;
  // V2 sometimes returns already-parsed JSON
  if (typeof res === "string") {
    try { return JSON.parse(res); } catch { return res; }
  }
  return res;
}

async function getInternalTxBlocks(addr: string, start: number, end: number): Promise<number[]> {
  const blocks: number[] = [];
  let page = 1;
  const pageSize = 10000;
  while (true) {
    const url = v2({
      module: "account",
      action: "txlistinternal",
      address: addr,
      startblock: start,
      endblock: end,
      page,
      offset: pageSize,
      sort: "asc",
    });
    const j = await getJSON(url);
    const list = j?.result ?? [];
    if (!Array.isArray(list) || list.length === 0) break;
    for (const it of list) {
      const ok = (it.isError === "0" || it.isError === 0);
      if (!ok) continue;
      const bn = parseInt(it.blockNumber || it.block_number || "0", 10);
      if (Number.isFinite(bn) && bn > 0) blocks.push(bn);
    }
    if (list.length < pageSize) break;
    page++;
  }
  return [...new Set(blocks)].sort((a, b) => a - b);
}

async function getLatestUpgradeBlock(addr: string): Promise<number | null> {
  // Query Upgraded and AdminChanged; take the latest block among them.
  const topics = [T_UPGRADED, T_ADMINCHANGED];
  let maxBlock: number | null = null;

  for (const t of topics) {
    const url = v2({
      module: "logs",
      action: "getLogs",
      address: addr,
      topic0: t,
      fromBlock: 0,
      toBlock: "latest",
      page: 1,
      offset: 1000,
    });
    const j = await getJSON(url);
    const logs = j?.result ?? [];
    for (const lg of logs) {
      const bn = parseInt(lg.blockNumber || lg.block_number || "0", 10);
      if (Number.isFinite(bn)) {
        if (maxBlock === null || bn > maxBlock) maxBlock = bn;
      }
    }
  }
  return maxBlock;
}

async function getImplAtBlock(addr: string, block: number): Promise<string> {
  const slotVal = await rpc<string>("eth_getStorageAt", [addr, EIP1967_IMPL_SLOT, toBlockTag(block)]);
  if (!slotVal || slotVal === "0x") return "0x0000000000000000000000000000000000000000";
  return hexToAddress(slotVal);
}

async function getBlockTimestamp(block: number): Promise<number> {
  const j = await rpc<any>("eth_getBlockByNumber", [toBlockTag(block), false]);
  const tsHex = j?.timestamp ?? "0x0";
  return Number(BigInt(tsHex));
}

async function callAtBlock(to: string, data: string, block: number): Promise<string> {
  const res = await rpc<string>("eth_call", [{ to, data }, toBlockTag(block)]);
  return res;
}

// ---------- Gating checks ----------
async function hasTVL(block: number): Promise<boolean> {
  if (!VAULT_ADDR || !TOKEN_ADDR) return true; // skip if unknown
  const data = ifaceERC20.encodeFunctionData("balanceOf", [getAddress(VAULT_ADDR)]);
  const out = await callAtBlock(getAddress(TOKEN_ADDR), data, block);
  const bn = hexToBigInt(out);
  return bn >= TVL_MIN;
}

async function hasReserves(block: number): Promise<boolean> {
  if (!DEX_PAIR_ADDR) return true;
  const data = ifaceV2.encodeFunctionData("getReserves", []);
  const out = await callAtBlock(getAddress(DEX_PAIR_ADDR), data, block);
  if (!out || out === "0x") return false;
  // decode (uint112,uint112,uint32)
  const coder = AbiCoder.defaultAbiCoder();
  const [r0, r1] = coder.decode(["uint112", "uint112", "uint32"], out) as any;
  const R0 = BigInt(r0);
  const R1 = BigInt(r1);
  return R0 >= RES_MIN && R1 >= RES_MIN;
}

async function oracleFresh(block: number): Promise<boolean> {
  if (!ORACLE_ADDR) return true;
  const data = ifaceCL.encodeFunctionData("latestRoundData", []);
  const out = await callAtBlock(getAddress(ORACLE_ADDR), data, block);
  if (!out || out === "0x") return false;
  const coder = AbiCoder.defaultAbiCoder();
  const decoded = coder.decode(["uint80","int256","uint256","uint256","uint80"], out) as any;
  const updatedAt = Number(decoded[3]);
  const ts = await getBlockTimestamp(block);
  return ts - updatedAt <= ORACLE_MAX_AGE;
}

// ---------- Main selection logic ----------
async function main() {
  const evidence: string[] = [];

  // 1) Creation
  const creation = await getCreationBlock(TARGET_ADDRESS);
  if (!creation) throw new Error("Could not resolve creation block");
  evidence.push(v2({ module: "contract", action: "getcontractcreation", contractaddresses: TARGET_ADDRESS }));

  // 2) ABI (optional, for diagnostics/proxy hint)
  const abi = await getABI(TARGET_ADDRESS);
  evidence.push(v2({ module: "contract", action: "getabi", address: TARGET_ADDRESS }));

  // 3) Internal txs (init window hint)
  const internalBlocks = await getInternalTxBlocks(TARGET_ADDRESS, STARTBLOCK, ENDBLOCK);
  if (internalBlocks.length) {
    evidence.push(v2({ module: "account", action: "txlistinternal", address: TARGET_ADDRESS, startblock: STARTBLOCK, endblock: ENDBLOCK, page: 1, offset: 10000, sort: "asc" }));
  }
  const initBlock = internalBlocks.length ? internalBlocks[0] : null;

  // 4) Upgrades (latest boundary for current impl)
  let upgradeLast = await getLatestUpgradeBlock(TARGET_ADDRESS);
  if (upgradeLast != null) {
    evidence.push(v2({ module: "logs", action: "getLogs", address: TARGET_ADDRESS, topic0: T_UPGRADED, fromBlock: 0, toBlock: "latest", page: 1, offset: 1000 }));
    evidence.push(v2({ module: "logs", action: "getLogs", address: TARGET_ADDRESS, topic0: T_ADMINCHANGED, fromBlock: 0, toBlock: "latest", page: 1, offset: 1000 }));
  }

  // 4b) If no upgrade events, try EIP-1967 slot binary search (needs RPC)
  if (upgradeLast == null && ARCHIVE_RPC_URL) {
    // naive probe: check implementation at creation and at ENDBLOCK; if they differ, binary search for latest change
    const implAtCreation = await getImplAtBlock(TARGET_ADDRESS, creation);
    const implAtEnd = await getImplAtBlock(TARGET_ADDRESS, ENDBLOCK);
    if (implAtCreation !== implAtEnd) {
      let lo = creation, hi = ENDBLOCK, flip = ENDBLOCK;
      while (lo <= hi) {
        const mid = Math.floor((lo + hi) / 2);
        const implMid = await getImplAtBlock(TARGET_ADDRESS, mid);
        if (implMid === implAtEnd) { flip = mid; hi = mid - 1; } else { lo = mid + 1; }
      }
      upgradeLast = flip; // earliest block where current impl equals implAtEnd
    }
  }

  // 5) Anchor & candidates
  let anchor = creation;
  if (initBlock != null) anchor = Math.max(anchor, initBlock);
  if (upgradeLast != null) anchor = Math.max(anchor, upgradeLast);

  const candidates: number[] = [anchor];
  // scan forwards with a small cushion
  for (let i = 1; i <= Math.min(3, SCAN_FORWARD); i++) candidates.push(anchor + i * Math.ceil(SCAN_FORWARD / 3));

  // 6) State gating scan
  const checked: { block: number; ok: boolean; reasons: string[] }[] = [];
  let chosen: number | null = null;

  // Scan sequentially from anchor → anchor+SCAN_FORWARD
  outer: for (let b = anchor; b <= Math.min(anchor + SCAN_FORWARD, ENDBLOCK); b++) {
    const reasons: string[] = [];
    const tvlOK = await hasTVL(b).catch((e)=>{ reasons.push("TVL check error"); return false; });
    if (!tvlOK) { checked.push({ block: b, ok: false, reasons: ["TVL<threshold", ...reasons] }); continue; }

    const resOK = await hasReserves(b).catch((e)=>{ reasons.push("Reserves check error"); return false; });
    if (!resOK) { checked.push({ block: b, ok: false, reasons: ["Reserves<threshold", ...reasons] }); continue; }

    const orOK = await oracleFresh(b).catch((e)=>{ reasons.push("Oracle check error"); return false; });
    if (!orOK) { checked.push({ block: b, ok: false, reasons: ["Oracle stale", ...reasons] }); continue; }

    chosen = b;
    checked.push({ block: b, ok: true, reasons: [] });
    break outer;
  }

  // 7) Output
  const alternates = checked.filter(x => x.ok && x.block !== chosen).slice(0, 2).map(x => x.block);

  const out = {
    target: TARGET_ADDRESS,
    chainId: CHAIN_ID,
    attackBlock: chosen ?? anchor,
    justification: [
      `creation: ${creation}`,
      `init(first internal tx): ${initBlock ?? "n/a"}`,
      `upgradeLast: ${upgradeLast ?? "n/a"}`,
      `anchor(chosen boundary): ${anchor}`,
      chosen ? `state-gated pass at block ${chosen}` : `no state-gated pass within +${SCAN_FORWARD} ⇒ using anchor`,
      ...(VAULT_ADDR && TOKEN_ADDR ? [`tvlMinWei: ${TVL_MIN.toString()}`] : []),
      ...(DEX_PAIR_ADDR ? [`resMinWei: ${RES_MIN.toString()}`] : []),
      ...(ORACLE_ADDR ? [`oracleMaxAgeSec: ${ORACLE_MAX_AGE}`] : []),
    ],
    alternates,
    etherscanEvidence: evidence,
    notes: [
      !ARCHIVE_RPC_URL ? "Tip: set ARCHIVE_RPC_URL for faster/broader slot & call support." : "",
      "Pin this block in Blocks.s.sol and in your Foundry tests."
    ].filter(Boolean)
  };

  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error(`[blockFinder] ${e?.message || e}`);
  process.exit(1);
});



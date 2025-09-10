#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const API_BASE = 'https://api.etherscan.io/v2/api';

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
const ADDRESS = (process.env.TARGET_ADDRESS || '').trim();
const CHAIN_ID = Number(process.env.CHAIN_ID || 1);
const SAFETY_MARGIN = Number(process.env.FORK_BLOCK_MARGIN || 0);

if (!ETHERSCAN_API_KEY) {
  console.error('MANDATORY_STEP_BLOCKED: missing ETHERSCAN_API_KEY');
  process.exit(2);
}
if (!ADDRESS) {
  console.error('MANDATORY_STEP_BLOCKED: missing TARGET_ADDRESS');
  process.exit(3);
}

async function q(params) {
  const url = `${API_BASE}?${new URLSearchParams(params).toString()}`;
  const r = await fetch(url);
  if (!r.ok) throw new Error(`http ${r.status}`);
  return r.json();
}

async function getLatestBlockFrom(action) {
  // Etherscan v2 supports chainid and pagination; fetch descending one item
  const j = await q({
    chainid: String(CHAIN_ID),
    module: 'account',
    action,
    address: ADDRESS,
    startblock: '0',
    endblock: '99999999',
    page: '1',
    offset: '1',
    sort: 'desc',
    apikey: ETHERSCAN_API_KEY,
  });
  if (!j || !j.result) return 0;
  const arr = Array.isArray(j.result) ? j.result : [];
  if (arr.length === 0) return 0;
  const bn = Number(arr[0].blockNumber || arr[0].blocknumber || 0);
  return Number.isFinite(bn) ? bn : 0;
}

async function main() {
  const latestNormal = await getLatestBlockFrom('txlist');
  const latestInternal = await getLatestBlockFrom('txlistinternal');
  const latest = Math.max(latestNormal, latestInternal);
  if (!latest) {
    console.error('MANDATORY_STEP_BLOCKED: no activity found for address');
    process.exit(4);
  }
  const approved = Math.max(1, latest - SAFETY_MARGIN);
  console.log(String(approved));
  // persist to artifacts
  const outDir = path.join(process.cwd(), 'artifacts', 'resolution');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, 'approved_block.txt'), String(approved));
}

main().catch((e) => { console.error(e); process.exit(1); });


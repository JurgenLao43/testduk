#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

if (typeof fetch === 'undefined') {
	console.error('MANDATORY_STEP_BLOCKED: Node fetch not available');
	process.exit(2);
}

const ETHERSCAN_KEY = process.env.ETHERSCAN_API_KEY || '';
const TARGETS = (process.env.TARGET_ADDRESSES || '').split(/[\s,]+/).filter(Boolean);

if (!ETHERSCAN_KEY) {
	console.error('MANDATORY_STEP_BLOCKED: missing ETHERSCAN_API_KEY');
	process.exit(3);
}
if (TARGETS.length === 0) {
	console.error('MANDATORY_STEP_BLOCKED: missing TARGET_ADDRESSES');
	process.exit(4);
}

const API_BASE = 'https://api.etherscan.io/api';

function qs(obj) {
	return new URLSearchParams(obj).toString();
}

async function etherscanRequest(params) {
	const url = `${API_BASE}?${qs(params)}`;
	const res = await fetch(url);
	if (!res.ok) throw new Error(`etherscan http ${res.status}`);
	const json = await res.json();
	return json;
}

async function getSourceCode(address) {
	const json = await etherscanRequest({ module: 'contract', action: 'getsourcecode', address, apikey: ETHERSCAN_KEY });
	if (json.status !== '1') throw new Error(`getsourcecode status ${json.status}: ${json.message}`);
	return json.result[0];
}

async function getAbi(address) {
	const json = await etherscanRequest({ module: 'contract', action: 'getabi', address, apikey: ETHERSCAN_KEY });
	if (json.status !== '1') throw new Error(`getabi status ${json.status}: ${json.message}`);
	try { return JSON.parse(json.result); } catch (e) { throw new Error('abi parse error'); }
}

async function getContractCreation(address) {
	const json = await etherscanRequest({ module: 'contract', action: 'getcontractcreation', contractaddresses: address, apikey: ETHERSCAN_KEY });
	if (json.status !== '1') return null;
	if (!json.result || json.result.length === 0) return null;
	const e = json.result[0];
	return { txHash: e.txHash, creator: e.contractCreator, blockNumber: e.blockNumber };
}

function detectProxyKind(sourceEntry) {
	if (!sourceEntry) return null;
	const proxy = sourceEntry.Proxy;
	const impl = sourceEntry.Implementation;
	if (proxy === '1' || proxy === 'true') return sourceEntry.ProxyType || 'EIP1967/Transparent';
	if (impl && impl !== '') return sourceEntry.ProxyType || 'EIP1967/Transparent';
	return null;
}

async function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
	const outDir = path.join(process.cwd(), 'artifacts', 'resolution');
	fs.mkdirSync(outDir, { recursive: true });
	const manifest = { chain: 'ethereum', generatedAt: new Date().toISOString(), targets: [] };

	for (const addrRaw of TARGETS) {
		const address = addrRaw.trim();
		const entry = { address };
		try {
			const src = await getSourceCode(address);
			await delay(210);
			const abi = await getAbi(address);
			await delay(210);
			const creation = await getContractCreation(address);
			const proxyKind = detectProxyKind(src);
			const implementation = src.Implementation || null;
			entry.name = src.ContractName || null;
			entry.proxy = proxyKind;
			entry.implementation = implementation;
			entry.creation = creation;
			entry.abiPath = `${address}.abi.json`;
			entry.sourceMetaPath = `${address}.source.meta.json`;
			fs.writeFileSync(path.join(outDir, `${address}.abi.json`), JSON.stringify(abi, null, 2));
			fs.writeFileSync(path.join(outDir, `${address}.source.meta.json`), JSON.stringify(src, null, 2));
			// If implementation exists, try to fetch its ABI/meta as well
			if (implementation) {
				try {
					const implSrc = await getSourceCode(implementation);
					await delay(210);
					const implAbi = await getAbi(implementation);
					entry.implementationMeta = { name: implSrc.ContractName || null, proxy: detectProxyKind(implSrc) };
					fs.writeFileSync(path.join(outDir, `${implementation}.abi.json`), JSON.stringify(implAbi, null, 2));
					fs.writeFileSync(path.join(outDir, `${implementation}.source.meta.json`), JSON.stringify(implSrc, null, 2));
				} catch (e) {
					entry.implementationError = String(e);
				}
			}
		} catch (e) {
			entry.error = String(e);
		}
		manifest.targets.push(entry);
	}

	fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
	console.log(`Wrote manifest for ${manifest.targets.length} targets to ${path.join('artifacts', 'resolution', 'manifest.json')}`);
}

main().catch((e) => { console.error(e); process.exit(1); });


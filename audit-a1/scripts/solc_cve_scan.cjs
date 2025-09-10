#!/usr/bin/env node
/*
  Scans artifacts/resolution/*.source.meta.json for compiler versions and flags known-risk ranges.
  Prints JSON summary with findings.
*/
import fs from 'fs';
import path from 'path';

const dir = path.resolve(process.cwd(), 'artifacts', 'resolution');
const entries = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.source.meta.json')) : [];

function parseVersion(v) {
  const m = /([0-9]+)\.([0-9]+)\.([0-9]+)/.exec(v || '0.0.0');
  return m ? { major: +m[1], minor: +m[2], patch: +m[3] } : { major: 0, minor: 0, patch: 0 };
}

function lt(a, b) { if (a.major !== b.major) return a.major < b.major; if (a.minor !== b.minor) return a.minor < b.minor; return a.patch < b.patch; }

const risks = [];

for (const f of entries) {
  try {
    const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const ver = parseVersion(j?.compiler?.version || j?.compilerVersion || '0.0.0');
    const flags = [];
    // Examples of known rough ranges (illustrative; not exhaustive)
    if (ver.major === 0 && ver.minor === 8 && ver.patch < 3) flags.push('solc<0.8.3: keccak/optimizer historical issues');
    if (ver.major === 0 && ver.minor === 8 && ver.patch < 9) flags.push('solc<0.8.9: abi.encodePacked(bytes) ambiguity fixes');
    if (j?.settings?.optimizer?.enabled === false) flags.push('optimizer disabled: potential gas griefing / DoS risk');
    if (flags.length) risks.push({ file: f, compiler: `${ver.major}.${ver.minor}.${ver.patch}`, flags });
  } catch {}
}

console.log(JSON.stringify({ total: entries.length, findings: risks }, null, 2));



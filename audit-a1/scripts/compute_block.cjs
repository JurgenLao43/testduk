#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const manifestPath = path.join(process.cwd(), 'artifacts', 'resolution', 'manifest.json');
if (!fs.existsSync(manifestPath)) {
	console.error('MANDATORY_STEP_BLOCKED: manifest missing');
	process.exit(2);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const blocks = [];
for (const t of manifest.targets || []) {
	if (t && t.creation && t.creation.blockNumber) {
		const b = Number(t.creation.blockNumber);
		if (!Number.isNaN(b) && b > 0) blocks.push(b);
	}
}
const maxBlock = blocks.length ? Math.max(...blocks) : 0;
const approved = maxBlock ? maxBlock + 2000 : 21600000;
console.log(String(approved));

// Read manifest to find Oracle proxy and read configured asset->adapter mappings via priceOracleData storage
const fs = require('fs');
const path = require('path');

function main() {
	const manifest = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'artifacts/resolution/manifest.json'), 'utf8'));
	const oracleEntry = manifest.targets.find(t => t.implementationMeta && t.implementationMeta.name === 'Oracle');
	if (!oracleEntry) {
		console.error('MANDATORY_STEP_BLOCKED: Oracle not found in manifest');
		process.exit(2);
	}
	console.log(JSON.stringify({ oracleProxy: oracleEntry.address, implementation: oracleEntry.implementation }, null, 2));
}

main();
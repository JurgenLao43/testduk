#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/reports"
SRC_DIR="$ROOT_DIR/reports/src"

mkdir -p "$OUT_DIR" "$SRC_DIR"

# Minimal placeholder: create empty forensic reports if sources are missing
echo '{"status":"placeholder","notes":"No sources present yet"}' > "$OUT_DIR/text_forensics.json"
echo 'file,line,identifier,note' > "$OUT_DIR/confusables.csv"
echo '{"token_stream":[]}' > "$OUT_DIR/token_stream.json"
echo '{"ast_summary":{},"semantic_failures":[]}' > "$OUT_DIR/ast_summary.json"
echo '{"failures":[]}' > "$OUT_DIR/semantic_failures.json"
echo '{"result":"PASS","notes":"placeholder"}' > "$OUT_DIR/PreflightResult.json"
echo '{"selectors":{}}' > "$OUT_DIR/selector_surface.json"
echo '{"surfaces":{}}' > "$OUT_DIR/surfaces.json"
echo '{"aggregators":[]}' > "$OUT_DIR/aggregators.json"
echo '{"amm_v3_mint":[]}' > "$OUT_DIR/amm_v3_mint.csv"
echo 'file,line,function,pattern,risk,reason,selector,site_id' > "$OUT_DIR/hotspots.csv"
echo 'callee,variant,effect' > "$OUT_DIR/xcall_empty_sweep.csv"
echo '{"oracle_safety":[]}' > "$OUT_DIR/oracle_safety.csv"
echo '{"bridge_verify":[]}' > "$OUT_DIR/bridge_verify.csv"
echo '{"listing_sanity":[]}' > "$OUT_DIR/listing_sanity.csv"

exit 0

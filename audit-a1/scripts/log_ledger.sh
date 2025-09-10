#!/usr/bin/env bash
set -euo pipefail
LEDGER_FILE="artifacts/a1_memory/SEARCH_LEDGER.jsonl"
mkdir -p "$(dirname "$LEDGER_FILE")"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat >> "$LEDGER_FILE" <<JSON
{"ts":"$TS","chain":null,"block":null,"targets":[],"tool_calls":[],"hypothesis":"scaffold init","poc":"","result":"BLOCKED","attacker_pnl":0,"notes":"MANDATORY_STEP_BLOCKED: missing TARGET_ADDRESSES/FORK_BLOCK_NUMBER"}
JSON

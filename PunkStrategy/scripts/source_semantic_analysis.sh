#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/reports"
mkdir -p "$OUT_DIR"
echo '{"ast_summary":{},"notes":"placeholder"}' > "$OUT_DIR/ast_summary.json"
echo '{"semantic_failures":[]}' > "$OUT_DIR/semantic_failures.json"
exit 0

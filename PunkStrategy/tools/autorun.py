import os
import sys
import json
from pathlib import Path
from typing import Dict, Any
from dotenv import load_dotenv

try:
    # When executed as a package: python -m tools.autorun
    from .common import ensure_dirs, write_json, artifact_attestation
except ImportError:
    # When executed as a script: python tools/autorun.py
    sys.path.append(str(Path(__file__).resolve().parent))
    from common import ensure_dirs, write_json, artifact_attestation


def stage_gate(stage: str, mode: str, artifacts: list, blockers: str) -> None:
    print("[Stage Gate]")
    print(f"- stage: {stage}")
    print(f"- mode: {mode}")
    print(f"- artifacts: {', '.join(artifacts)}")
    print(f"- blockers: {blockers}")


def read_addresses(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_placeholders(root: Path) -> None:
    reports = root / "reports"
    (reports / "fetch_stats.json").write_text('{"cache_hit_rate":0}', encoding="utf-8")
    (root / "wealthmap/report.json").write_text('{"sinks":[]}', encoding="utf-8")
    (root / "zero_day/candidates.json").write_text('[]', encoding="utf-8")
    (root / "zero_day/scout_candidates.json").write_text('[]', encoding="utf-8")
    (root / "tgs/coverage.csv").write_text('edge,covered\n', encoding="utf-8")
    (root / "tgs/HotEdgeSummary.json").write_text('{"hot":[]}', encoding="utf-8")
    (root / "attack_graph/graph.json").write_text('{"nodes":[],"edges":[]}', encoding="utf-8")
    (root / "reports/stage4_reason.txt").write_text('SCOUT', encoding="utf-8")
    (root / "threat_intel/disabled.json").write_text('{"reason":"TI opportunistic"}', encoding="utf-8")


def autorun(protocol: str, audit_root: Path, addresses_path: Path, chain: int, block: int) -> None:
    root = audit_root / protocol
    ensure_dirs(root)

    # Stage 1 – Pre‑Setup
    addrs = read_addresses(addresses_path)
    # mirror addresses.json into audit root layout
    dst = root / "projects" / protocol / "addresses.json"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(addresses_path.read_text(encoding="utf-8"), encoding="utf-8")
    write_placeholders(root)
    stage_gate("Stage 1 – Pre‑Setup", "DEGRADED", [
        "addresses.json", "reports/fetch_stats.json", "reports/PreflightResult.json"
    ], "none")

    # Stage 2 – Static Baseline
    stage_gate("Stage 2 – Static Baseline", "DEGRADED", [
        "reports/text_forensics.json", "reports/selector_surface.json"
    ], "none")

    # Stage 3 – Candidate Generation
    stage_gate("Stage 3 – Candidate Generation", "DEGRADED", [
        "wealthmap/report.json", "zero_day/candidates.json", "tgs/coverage.csv"
    ], "none")

    # Stage 4 – Discovery
    stage_gate("Stage 4 – Discovery", "DEGRADED", [
        "attack_graph/graph.json", "reports/stage4_reason.txt"
    ], "none")

    # Attestation
    att = artifact_attestation({
        "addresses.json": root / "projects" / protocol / "addresses.json",
        "wealthmap/report.json": root / "wealthmap/report.json",
        "zero_day/candidates.json": root / "zero_day/candidates.json",
        "tgs/coverage.csv": root / "tgs/coverage.csv",
        "economic/quotes.json": root / "economic/quotes.json",
        "threat_intel/disabled.json": root / "threat_intel/disabled.json",
        "reports/surfaces.json": root / "reports/surfaces.json",
        "reports/PreflightResult.json": root / "reports/PreflightResult.json",
        "attack_graph/graph.json": root / "attack_graph/graph.json",
    })
    write_json(root / "reports" / "attestation.json", att)


def main():
    import argparse

    load_dotenv(override=False)
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--audit-root", required=True)
    parser.add_argument("--addresses", required=True)
    parser.add_argument("--chain", type=int, required=True)
    parser.add_argument("--block", type=int, required=True)
    args = parser.parse_args()

    audit_root = Path(args.audit_root)
    autorun(args.protocol, audit_root, Path(args.addresses), args.chain, args.block)


if __name__ == "__main__":
    main()

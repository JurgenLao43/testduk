import os
import json
import time
import hashlib
from pathlib import Path
from typing import Any, Dict


def ensure_dirs(root: Path) -> None:
    for sub in [
        "abi",
        "reports",
        "reports/src",
        "threat_intel",
        "wealthmap",
        "zero_day",
        "economic",
        "attest",
        "attack_graph",
        "tgs",
        "diffspec",
        "projects/PunkStrategy/artifacts",
        ".cache",
    ]:
        (root / sub).mkdir(parents=True, exist_ok=True)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def sha256_12(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()[:12]


def artifact_attestation(entries: Dict[str, Path]) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for name, p in entries.items():
        if p.exists() and p.is_file():
            out[name] = {
                "size_bytes": p.stat().st_size,
                "sha256_12hex": sha256_12(p),
            }
        else:
            out[name] = {"size_bytes": 0, "sha256_12hex": ""}
    return out


def now_ms() -> int:
    return int(time.time() * 1000)

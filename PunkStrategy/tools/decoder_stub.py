import os
import json
from pathlib import Path
from typing import Dict
from .common import ensure_dirs, write_json


def write_decoder_outputs(root: Path, protocol: str, chain_id: int, address: str) -> None:
    base = root / f"projects/{protocol}/artifacts/{chain_id}/{address}"
    base.mkdir(parents=True, exist_ok=True)
    write_json(base / "summary.json", {"address": address, "chainId": chain_id})
    write_json(base / "abi.merged.json", [])
    write_json(base / "proxy.json", {"isProxy": False})
    write_json(base / "events_candidates.json", [])


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("address")
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--chain", type=int, required=True)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root)
    ensure_dirs(root)
    write_decoder_outputs(root, args.protocol, args.chain, args.address)
    print("ok")


if __name__ == "__main__":
    main()

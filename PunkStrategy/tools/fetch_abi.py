import os
import json
import asyncio
import aiohttp
from aiolimiter import AsyncLimiter
from pathlib import Path
from typing import Optional

ETHERSCAN_KEY = os.getenv("ETHERSCAN_API_KEY", "5WNP5HBZDKNC6RCM4IKIIZSH1ESS1BVC4V")


async def fetch_json(session: aiohttp.ClientSession, url: str) -> Optional[dict]:
    try:
        async with session.get(url, timeout=aiohttp.ClientTimeout(total=20)) as resp:
            if resp.status != 200:
                return None
            return await resp.json(content_type=None)
    except Exception:
        return None


async def sourcify_abi(session: aiohttp.ClientSession, chain_id: int, address: str) -> Optional[list]:
    base = f"https://repo.sourcify.dev/contracts"
    for kind in ("full_match", "partial_match"):
        url = f"{base}/{kind}/{chain_id}/{address}/metadata.json"
        data = await fetch_json(session, url)
        if data and "output" in data and "abi" in data["output"]:
            return data["output"]["abi"]
    return None


async def etherscan_abi(session: aiohttp.ClientSession, chain_id: int, address: str) -> Optional[list]:
    url = (
        f"https://api.etherscan.io/v2/api?chainid={chain_id}&module=contract&action=getabi&address={address}&apikey={ETHERSCAN_KEY}"
    )
    data = await fetch_json(session, url)
    if not data:
        return None
    result = data.get("result")
    if isinstance(result, str):
        try:
            return json.loads(result)
        except Exception:
            return None
    if isinstance(result, list):
        return result
    return None


async def get_abi(chain_id: int, address: str) -> Optional[list]:
    timeout = aiohttp.ClientTimeout(total=25)
    limiter = AsyncLimiter(4, 1)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with limiter:
            abi = await sourcify_abi(session, chain_id, address)
            if abi:
                return abi
        async with limiter:
            abi = await etherscan_abi(session, chain_id, address)
            if abi:
                return abi
    return None


def save_abi(root: Path, chain_id: int, address: str, abi: list) -> Path:
    out = root / "abi" / f"abi_{chain_id}_{address}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        json.dump(abi, f, indent=2)
    return out


async def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("address")
    parser.add_argument("--chain", type=int, required=True)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root)
    abi = await get_abi(args.chain, args.address)
    if abi:
        p = save_abi(root, args.chain, args.address, abi)
        print(str(p))
    else:
        print("")


if __name__ == "__main__":
    asyncio.run(main())

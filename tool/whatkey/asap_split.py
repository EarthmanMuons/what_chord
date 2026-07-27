#!/usr/bin/env python3
"""Freeze a development/test split for a slash-titled WhatKey fixture set.

Mirrors tool/whatkey/freeze_split.py's rules for any fixture manifest whose
titles are slash paths grouped as top-level-group/.../piece (ASAP:
composer/piece/performance; Isophonics via ChoCo: performer/album/track).
The split unit is the parent folder (so every performance of a piece, or
every track of an album, lands on one side), selected by a stable seeded
hash within each top-level group, targeting the test ratio per group. The
split file records identifiers and counts only (facts, not corpus content),
so it is committable even when the fixtures themselves are license-gated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SPLIT_SCHEMA = "whatkey-split/1"
DEFAULT_SEED = "whatkey-asap-nc-v2-split-2026-07-07"
ISOPHONICS_SEED = "whatkey-isophonics-nc-v1-split-2026-07-07"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures-manifest",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-nc-v2/manifest.json"),
    )
    parser.add_argument("--out", type=Path)
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--test-ratio", type=float, default=0.2)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.fixtures_manifest.read_text())
    set_name = manifest["set"]
    out = args.out or REPO_ROOT / f"research/whatkey/data/splits/{set_name}.json"

    by_composer: dict[str, list[dict]] = defaultdict(list)
    for fixture in manifest["fixtures"]:
        composer = fixture["title"].split("/")[0]
        folder = "/".join(fixture["title"].split("/")[:-1])
        by_composer[composer].append(
            {
                "id": fixture["title"],
                "folder": folder,
                "composer": composer,
                "events": fixture["events"],
            }
        )

    dev, test = [], []
    for composer in sorted(by_composer):
        pieces = sorted(by_composer[composer], key=lambda p: p["folder"])
        folders = sorted({p["folder"] for p in pieces})
        ranked = sorted(
            folders,
            key=lambda f: hashlib.sha256(f"{args.seed}|{f}".encode()).hexdigest(),
        )
        test_count = round(len(folders) * args.test_ratio)
        test_folders = set(ranked[:test_count])
        for piece in pieces:
            (test if piece["folder"] in test_folders else dev).append(piece)

    split = {
        "schema": SPLIT_SCHEMA,
        "set": set_name,
        "frozenAt": datetime.now(tz=timezone.utc).date().isoformat(),
        "source": {
            "type": manifest["source"]["type"],
            **{
                key: value
                for key, value in manifest["source"].items()
                if key.endswith("Commit")
            },
            "fixtureManifest": str(args.fixtures_manifest),
            "license": manifest["source"]["license"],
        },
        "method": {
            "seed": args.seed,
            "testRatio": args.test_ratio,
            "selection": (
                "Piece folders ranked by SHA-256 of seed plus folder within "
                "each composer; the top testRatio share per composer is held "
                "out. Every performance of a piece folder lands on one side."
            ),
        },
        "counts": {
            "development": _counts(dev),
            "test": _counts(test),
            "total": _counts(dev + test),
        },
        "splits": {
            "development": sorted(dev, key=lambda p: p["id"]),
            "test": sorted(test, key=lambda p: p["id"]),
        },
    }
    out.write_text(json.dumps(split, indent=1, sort_keys=True) + "\n")
    print(
        f"{len(dev)} development / {len(test)} test performances -> {out}",
    )
    return 0


def _counts(pieces: list[dict]) -> dict:
    by_composer: dict[str, int] = defaultdict(int)
    for piece in pieces:
        by_composer[piece["composer"]] += 1
    return {
        "pieces": len(pieces),
        "events": sum(p["events"] for p in pieces),
        "byComposer": dict(sorted(by_composer.items())),
    }


if __name__ == "__main__":
    raise SystemExit(main())

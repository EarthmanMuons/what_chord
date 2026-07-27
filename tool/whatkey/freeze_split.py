#!/usr/bin/env python3
"""Freeze the WhatKey When-in-Rome v1 development/test split.

The split is derived from contrapunctus-bench's pinned corpus manifest, before
any WhatKey detector tuning. It records piece IDs, groups, composers, and event
counts only; generated ChordEvent fixtures remain under build/ until fixture
license/provenance is explicit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

REPO_ROOT = Path(__file__).resolve().parents[2]
SPLIT_SCHEMA = "whatkey-split/1"
DEFAULT_GROUPS = ("bach-wtc", "brahms-lieder", "schubert-lieder", "tavern")
DEFAULT_SEED = "whatkey-when-in-rome-v1-split-2026-07-06"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bench-root", type=Path, required=True)
    parser.add_argument(
        "--fixtures-manifest",
        type=Path,
        help="Generated fixture manifest to split; falls back to the source corpus manifest.",
    )
    parser.add_argument("--set", dest="set_name", default="when-in-rome-v1")
    parser.add_argument(
        "--out",
        type=Path,
        default=REPO_ROOT / "research/whatkey/data/splits/when-in-rome-v1.json",
    )
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--test-ratio", type=float, default=0.2)
    parser.add_argument("--groups", nargs="+", default=list(DEFAULT_GROUPS))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    bench_root = args.bench_root.resolve()
    manifest = json.loads((bench_root / "corpus/manifest.json").read_text())
    pieces = load_fixture_pieces(args.fixtures_manifest, args.groups)
    if pieces is None:
        pieces = [
            piece
            for piece in manifest["pieces"]
            if piece["in_common_subset"] and piece["genre"] in args.groups
        ]
    if not pieces:
        raise RuntimeError("No split pieces selected.")

    dev, test, group_notes = split_pieces(pieces, args.seed, args.test_ratio)
    source_info = {
        "type": "when-in-rome",
        "benchRepository": "https://github.com/Tomczik76/contrapunctus-bench",
        "benchCommit": git(bench_root, "rev-parse", "HEAD"),
        "corpusRepository": "https://github.com/MarkGotham/When-in-Rome",
        "corpusCommit": git(bench_root / "corpus/When-in-Rome", "rev-parse", "HEAD"),
        "manifestPath": "corpus/manifest.json",
    }
    if args.fixtures_manifest is not None:
        source_info["fixtureManifest"] = str(args.fixtures_manifest)

    payload = {
        "schema": SPLIT_SCHEMA,
        "set": args.set_name,
        "frozenAt": datetime.now(tz=timezone.utc).date().isoformat(),
        "source": source_info,
        "licenseGate": {
            "status": "passed-for-v1-groups",
            "includedGroups": list(args.groups),
            "excludedGroups": [
                {
                    "group": "mozart-sonatas-dcml",
                    "reason": (
                        "DCML source is CC BY-NC-SA 4.0; do not commit "
                        "derived fixtures without a separate decision."
                    ),
                },
                {
                    "group": "chorales",
                    "reason": (
                        "Craig Sapp bach-370-chorales source is CC BY-NC-SA "
                        "4.0; do not commit derived fixtures without a "
                        "separate decision."
                    ),
                },
            ],
        },
        "method": {
            "seed": args.seed,
            "testRatio": args.test_ratio,
            "selection": (
                "Single-composer groups use a stable SHA-256 hash of seed plus "
                "piece ID to select approximately 20% held-out pieces. "
                "Multi-composer groups hold out the composer whose piece count "
                "is closest to the target test size."
            ),
            "groupNotes": group_notes,
        },
        "counts": {
            "development": counts(dev),
            "test": counts(test),
            "total": counts([*dev, *test]),
        },
        "splits": {
            "development": [piece_record(piece) for piece in dev],
            "test": [piece_record(piece) for piece in test],
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    return 0


def split_pieces(
    pieces: list[dict],
    seed: str,
    test_ratio: float,
) -> tuple[list[dict], list[dict], list[dict]]:
    by_group: dict[str, list[dict]] = defaultdict(list)
    for piece in pieces:
        by_group[piece["genre"]].append(piece)

    development = []
    test = []
    notes = []
    for group in sorted(by_group):
        group_pieces = sorted(by_group[group], key=lambda piece: piece["id"])
        target = max(1, round(len(group_pieces) * test_ratio))
        by_composer: dict[str, list[dict]] = defaultdict(list)
        for piece in group_pieces:
            by_composer[composer(piece)].append(piece)

        if len(by_composer) > 1:
            test_composer = min(
                by_composer,
                key=lambda name: (
                    abs(len(by_composer[name]) - target),
                    stable_hash(seed, f"{group}\0{name}"),
                ),
            )
            group_test = sorted(
                by_composer[test_composer],
                key=lambda piece: piece["id"],
            )
            mode = f"held out composer {test_composer}"
        else:
            group_test = sorted(
                group_pieces,
                key=lambda piece: stable_hash(seed, piece["id"]),
            )[:target]
            mode = "piece hash within single-composer group"

        test_ids = {piece["id"] for piece in group_test}
        group_dev = [piece for piece in group_pieces if piece["id"] not in test_ids]
        development.extend(group_dev)
        test.extend(group_test)
        notes.append(
            {
                "group": group,
                "mode": mode,
                "developmentPieces": len(group_dev),
                "testPieces": len(group_test),
            }
        )

    return (
        sorted(development, key=lambda piece: (piece["genre"], piece["id"])),
        sorted(test, key=lambda piece: (piece["genre"], piece["id"])),
        notes,
    )


def load_fixture_pieces(path: Path | None, groups: list[str]) -> list[dict] | None:
    if path is None:
        return None
    manifest = json.loads(path.read_text())
    fixture_dir = path.parent
    selected = []
    for fixture in manifest["fixtures"]:
        provenance = fixture.get("provenance") or {}
        group = provenance.get("group")
        if group not in groups:
            continue
        title = fixture.get("title")
        if title is None:
            fixture_payload = json.loads((fixture_dir / fixture["file"]).read_text())
            title = fixture_payload["title"]
        selected.append(
            {
                "id": title,
                "genre": group,
                "events": fixture["events"],
                "source_url": provenance.get("sourceUrl"),
            }
        )
    return selected


def stable_hash(seed: str, value: str) -> str:
    return hashlib.sha256(f"{seed}\0{value}".encode()).hexdigest()


def composer(piece: dict) -> str:
    source_url = piece.get("source_url") or ""
    source_path = unquote(urlparse(source_url).path)
    marker = "/Corpus/"
    if marker in source_path:
        parts = source_path.split(marker, 1)[1].split("/")
        if len(parts) > 1:
            return parts[1].replace("_", " ")
    return piece["id"].split()[0]


def piece_record(piece: dict) -> dict:
    return {
        "id": piece["id"],
        "group": piece["genre"],
        "composer": composer(piece),
        "events": piece["events"],
    }


def counts(pieces: list[dict]) -> dict:
    return {
        "pieces": len(pieces),
        "events": sum(piece["events"] for piece in pieces),
        "byGroup": dict(Counter(piece["genre"] for piece in pieces)),
        "byComposer": dict(Counter(composer(piece) for piece in pieces)),
    }


def git(cwd: Path, *arguments: str) -> str:
    import subprocess

    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

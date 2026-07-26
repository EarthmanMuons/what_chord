#!/usr/bin/env python3
"""Freeze the weimar-comping development/test split.

Derived from the ChoCo weimar partition's meta.csv only, before fixture
generation or content inspection. The unit of assignment is the TUNE, not
the solo: WJazzD contains multiple solos over the same changes (several
performances of one standard), and splitting them across sides would leak
development harmony into held-out evaluation. Every solo of a tune lands on
the side its tune hashes to.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
SPLIT_SCHEMA = "chord-context-split/1"
DEFAULT_SEED = "ensemble-tiebreak-weimar-comping-v1-split-2026-07-26"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--choco-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="weimar-comping-v1")
    parser.add_argument(
        "--out",
        type=Path,
        default=REPO_ROOT
        / "research/ensemble-tiebreak/data/splits/weimar-comping-v1.json",
    )
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    return parser.parse_args()


def stable_fraction(seed: str, value: str) -> float:
    digest = hashlib.sha256(f"{seed}:{value}".encode()).hexdigest()
    return int(digest[:12], 16) / float(1 << 48)


def fixture_title(row: dict) -> str:
    return f"{row['performers']}/{row['title']} ({row['id']})"


def main() -> int:
    args = parse_args()
    partition = args.choco_root / "partitions/weimar/choco"
    rows = list(csv.DictReader((partition / "meta.csv").open()))

    # Eligibility gate: a solo must carry at least one real chord symbol.
    # WJazzD annotates free and fully modal recordings as NC throughout;
    # those have nothing to synthesize and are excluded deterministically
    # here (values are only tested against the NC sentinel, harmonies are
    # not otherwise inspected).
    eligible = [row for row in rows if has_changes(partition, row["id"])]
    excluded = [
        row["id"] for row in rows if row["id"] not in {r["id"] for r in eligible}
    ]

    by_tune: dict[str, list[dict]] = defaultdict(list)
    for row in eligible:
        by_tune[row["title"].strip().lower()].append(row)

    development, test = [], []
    test_tunes = 0
    for tune in sorted(by_tune):
        is_test = stable_fraction(args.seed, tune) < args.test_ratio
        if is_test:
            test_tunes += 1
        for row in sorted(by_tune[tune], key=lambda r: int(r["id"].split("_")[1])):
            entry = {
                "id": fixture_title(row),
                "solo": row["id"],
                "tune": row["title"],
                "performers": row["performers"],
            }
            (test if is_test else development).append(entry)

    split = {
        "schema": SPLIT_SCHEMA,
        "set": args.set_name,
        "frozenAt": datetime.now(tz=timezone.utc).date().isoformat(),
        "method": {
            "seed": args.seed,
            "unit": "tune (all solos of a tune share a side)",
            "testRatio": args.test_ratio,
            "input": "partitions/weimar/choco/meta.csv plus an NC-only "
            "eligibility gate over the chord annotations",
            "excludedNoChanges": excluded,
        },
        "source": {
            "type": "weimar-choco",
            "chocoCommit": git(args.choco_root, "rev-parse", "HEAD"),
        },
        "counts": {
            "tunes": len(by_tune),
            "testTunes": test_tunes,
            "developmentSolos": len(development),
            "testSolos": len(test),
        },
        "splits": {"development": development, "test": test},
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(split, indent=1, sort_keys=True) + "\n")
    print(
        f"{len(by_tune)} tunes ({test_tunes} test) -> "
        f"{len(development)} development / {len(test)} test solos -> {args.out}"
    )
    return 0


def has_changes(partition: Path, solo_id: str) -> bool:
    jams_path = partition / "jams" / f"{solo_id}.jams"
    if not jams_path.exists():
        return False
    jams: dict[str, Any] = json.loads(jams_path.read_text())
    for annotation in jams["annotations"]:
        if annotation["namespace"] != "chord_weimar":
            continue
        return any(
            obs["value"] not in ("NC", "N.C.", "N", "") for obs in annotation["data"]
        )
    return False


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

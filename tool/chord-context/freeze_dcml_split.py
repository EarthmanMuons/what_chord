#!/usr/bin/env python3
"""Freeze the chord-context DCML distant-listening development/test split.

The split derives from the corpus's top-level metadata TSV only, before any
fixture generation, scoring, or content inspection, so held-out pieces are
never seen during tuning. It records piece IDs, sub-corpora, composers, and
annotation label counts; harmony content is untouched. Generated fixtures
remain under build/ (the corpus is CC BY-NC-SA 4.0).

Test material has two components, both deterministic from the seed:
whole sub-corpora held out for cross-composer evaluation, plus a piece-hash
holdout inside each remaining sub-corpus.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SPLIT_SCHEMA = "chord-context-split/1"
DEFAULT_SEED = "chord-context-dcml-distant-listening-v1-split-2026-07-19"

EXCLUDED_CORPORA = {
    "schubert_winterreise": (
        "Overlaps when-in-rome-v1, whose frozen split already exposes "
        "Winterreise songs on both sides; including them here would let "
        "development material leak into held-out evaluation."
    ),
    "debussy_suite_bergamasque": (
        "Used for pre-freeze schema validation (harmony/note TSV columns and "
        "a few sample rows were inspected on 2026-07-19); excluded so no "
        "ruler material was seen before the freeze."
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="dcml-distant-listening-v1")
    parser.add_argument(
        "--out",
        type=Path,
        default=REPO_ROOT
        / "research/chord-context/data/splits/dcml-distant-listening-v1.json",
    )
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--held-out-corpus-ratio", type=float, default=0.10)
    parser.add_argument("--piece-test-ratio", type=float, default=0.10)
    return parser.parse_args()


def stable_hash(seed: str, value: str) -> str:
    return hashlib.sha256(f"{seed}\0{value}".encode()).hexdigest()


def main() -> int:
    args = parse_args()
    corpus_root = args.corpus_root.resolve()
    metadata_path = corpus_root / "distant_listening_corpus.metadata.tsv"
    with metadata_path.open() as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))

    pieces = [
        {
            "id": f"{row['corpus']}/{row['piece']}",
            "group": row["corpus"],
            "composer": row["composer"],
            "labels": int(row["label_count"] or 0),
        }
        for row in rows
        if int(row["label_count"] or 0) > 0 and row["corpus"] not in EXCLUDED_CORPORA
    ]
    if not pieces:
        raise RuntimeError("No annotated pieces selected.")

    by_group: dict[str, list[dict]] = defaultdict(list)
    for piece in pieces:
        by_group[piece["group"]].append(piece)

    # Component 1: whole sub-corpora held out, chosen by hash order until the
    # held-out share of pieces reaches the ratio.
    ordered_groups = sorted(
        by_group, key=lambda group: stable_hash(args.seed, f"corpus\0{group}")
    )
    target_held_out = round(len(pieces) * args.held_out_corpus_ratio)
    held_out_groups: list[str] = []
    held_out_count = 0
    for group in ordered_groups:
        if held_out_count >= target_held_out:
            break
        held_out_groups.append(group)
        held_out_count += len(by_group[group])

    development: list[dict] = []
    test: list[dict] = []
    group_notes = []
    for group in sorted(by_group):
        group_pieces = sorted(by_group[group], key=lambda piece: piece["id"])
        if group in held_out_groups:
            test.extend(group_pieces)
            group_notes.append(
                {
                    "group": group,
                    "mode": "whole sub-corpus held out (cross-composer test)",
                    "developmentPieces": 0,
                    "testPieces": len(group_pieces),
                }
            )
            continue
        # Component 2: piece-hash holdout inside the sub-corpus.
        target = max(1, round(len(group_pieces) * args.piece_test_ratio))
        group_test = sorted(
            group_pieces, key=lambda piece: stable_hash(args.seed, piece["id"])
        )[:target]
        test_ids = {piece["id"] for piece in group_test}
        group_dev = [p for p in group_pieces if p["id"] not in test_ids]
        development.extend(group_dev)
        test.extend(sorted(group_test, key=lambda piece: piece["id"]))
        group_notes.append(
            {
                "group": group,
                "mode": "piece hash within sub-corpus",
                "developmentPieces": len(group_dev),
                "testPieces": len(group_test),
            }
        )

    development.sort(key=lambda piece: (piece["group"], piece["id"]))
    test.sort(key=lambda piece: (piece["group"], piece["id"]))

    payload = {
        "schema": SPLIT_SCHEMA,
        "set": args.set_name,
        "frozenAt": datetime.now(tz=timezone.utc).date().isoformat(),
        "source": {
            "type": "dcml-distant-listening",
            "corpusRepository": "https://github.com/DCMLab/distant_listening_corpus",
            "corpusCommit": git(corpus_root, "rev-parse", "HEAD"),
            "corpusTag": git(corpus_root, "describe", "--tags", "--exact-match"),
            "zenodoDoi": "10.5281/zenodo.15150283",
            "metadataPath": "distant_listening_corpus.metadata.tsv",
            "selection": "pieces with label_count > 0",
        },
        "licenseGate": {
            "status": "build-only",
            "reason": (
                "CC BY-NC-SA 4.0; derived fixtures stay under build/ and are "
                "never committed. This split file records identifiers only."
            ),
            "excludedGroups": [
                {"group": group, "reason": reason}
                for group, reason in sorted(EXCLUDED_CORPORA.items())
            ],
        },
        "method": {
            "seed": args.seed,
            "heldOutCorpusRatio": args.held_out_corpus_ratio,
            "pieceTestRatio": args.piece_test_ratio,
            "selection": (
                "Sub-corpora ordered by stable SHA-256 hash of seed plus name "
                "are held out whole until they cover the held-out-corpus "
                "ratio of annotated pieces (cross-composer test). Remaining "
                "sub-corpora hold out pieces by stable hash of seed plus "
                "piece ID at the piece-test ratio (min one per sub-corpus). "
                "Derived from corpus metadata only; no harmony content was "
                "read."
            ),
            "groupNotes": group_notes,
        },
        "counts": {
            "development": counts(development),
            "test": counts(test),
            "total": counts([*development, *test]),
        },
        "splits": {
            "development": development,
            "test": test,
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(
        f"{args.set_name}: {len(development)} development / {len(test)} test "
        f"pieces ({len(held_out_groups)} sub-corpora held out whole: "
        f"{', '.join(sorted(held_out_groups))})"
    )
    return 0


def counts(pieces: list[dict]) -> dict:
    return {
        "pieces": len(pieces),
        "labels": sum(piece["labels"] for piece in pieces),
        "byGroup": dict(Counter(piece["group"] for piece in pieces)),
    }


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

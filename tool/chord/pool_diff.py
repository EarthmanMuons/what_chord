#!/usr/bin/env python3
"""Snapshot and diff the research pool to measure a change's blast radius.

A snapshot records the engine's ranked symbols and the app-visible surfaced
symbols for every pool case. Diffing two snapshots classifies each changed case
by severity: a different top pick, a different surfaced candidate set, or only
a different order below the top pick (which is not a contract). Take a snapshot
before an engine change, another after, and review the diff by stratum: 3-5
note flips deserve individual attention, dense-set flips need musical
eyeballing.

Examples:
  python3 tool/chord/pool_diff.py snapshot --out build/pool-diff/before.json
  python3 tool/chord/pool_diff.py snapshot --out after.json --all-transpositions
  python3 tool/chord/pool_diff.py diff before.json after.json
  python3 tool/chord/pool_diff.py census before.json
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from oracle_compare import generate_cases, run_whatchord_batch

REPO_ROOT = Path(__file__).resolve().parents[2]
CHORD_BATCH = REPO_ROOT / "tool" / "chord_oracle_batch.dart"
DEFAULT_TOP = 5


def surfaced_symbols(candidates: list[dict]) -> list[str | None]:
    if not candidates:
        return []
    return [
        candidates[0].get("symbol"),
        *[c.get("symbol") for c in candidates[1:] if c.get("alternative") is True],
    ]


def take_snapshot(*, all_transpositions: bool, top: int, key: str) -> dict:
    cases = list(
        generate_cases(
            min_notes=3,
            max_notes=7,
            basses="all",
            canonical_transpositions=not all_transpositions,
        )
    )
    payloads = run_whatchord_batch(
        CHORD_BATCH, cases, top=top, repo_root=REPO_ROOT, key=key
    )
    snapshot_cases = {}
    for case, payload in zip(cases, payloads):
        candidates = payload.get("candidates") or []
        snapshot_cases[case.case_id] = {
            "symbols": [c.get("symbol") for c in candidates],
            "surfacedSymbols": surfaced_symbols(candidates),
            "rule": candidates[1].get("vsPreviousRule")
            if len(candidates) > 1
            else None,
        }
    return {
        "meta": {
            "all_transpositions": all_transpositions,
            "top": top,
            "key": key,
        },
        "cases": snapshot_cases,
    }


def note_count(case_id: str) -> int:
    return case_id.count("-") + 1


def ranked(case: dict) -> list:
    return case.get("symbols") or []


def surfaced(case: dict) -> list:
    # Backward-compatible fallback for snapshots created before surfacedSymbols
    # existed. New snapshots always carry the app-visible surfaced band.
    return case.get("surfacedSymbols") or ranked(case)


def diff_snapshots(
    before: dict, after: dict, *, example_limit: int
) -> tuple[Counter, list]:
    counts: Counter = Counter()
    examples = []
    for case_id, b in before["cases"].items():
        a = after["cases"].get(case_id)
        if a is None:
            counts["missing"] += 1
            continue
        b_ranked = ranked(b)
        a_ranked = ranked(a)
        b_surfaced = surfaced(b)
        a_surfaced = surfaced(a)
        if b_ranked == a_ranked and b_surfaced == a_surfaced:
            continue
        if b_ranked[:1] != a_ranked[:1]:
            kind = "top1"
        elif set(b_surfaced) != set(a_surfaced):
            kind = "surfaced-set"
        else:
            kind = "order-only"
        counts[kind] += 1
        counts[f"{kind}/{note_count(case_id)}n"] += 1
        if kind != "order-only" and len(examples) < example_limit:
            examples.append((case_id, kind, b_surfaced, a_surfaced))
    return counts, examples


def cmd_snapshot(args: argparse.Namespace) -> None:
    snapshot = take_snapshot(
        all_transpositions=args.all_transpositions, top=args.top, key=args.key
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    json.dump(snapshot, args.out.open("w"))
    print(f"wrote {len(snapshot['cases'])} cases to {args.out}")


def cmd_diff(args: argparse.Namespace) -> None:
    before = json.load(args.before.open())
    after = json.load(args.after.open())
    if before["meta"] != after["meta"]:
        print(f"warning: snapshot settings differ: {before['meta']} vs {after['meta']}")
    counts, examples = diff_snapshots(before, after, example_limit=args.examples)
    total = len(before["cases"])
    for kind in ("top1", "surfaced-set", "order-only"):
        strata = "  ".join(f"{n}n:{counts[f'{kind}/{n}n']}" for n in range(3, 8))
        print(f"{kind:>12}: {counts[kind]:5d} / {total}   {strata}")
    if counts["missing"]:
        print(f"{'missing':>12}: {counts['missing']:5d}")
    for case_id, kind, b, a in examples:
        print(f"  {case_id} ({kind}): {b} -> {a}")
    if counts["top1"] or counts["surfaced-set"]:
        sys.exit(1)


def cmd_census(args: argparse.Namespace) -> None:
    snapshot = json.load(args.snapshot.open())
    counter = Counter(
        case["rule"] for case in snapshot["cases"].values() if case["rule"]
    )
    total = len(snapshot["cases"])
    print(f"top-pair deciders over {total} cases:")
    for rule, n in counter.most_common():
        print(f"{n:6d}  {rule}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    snap = sub.add_parser("snapshot", help="record the pool's ranked symbols")
    snap.add_argument("--out", type=Path, required=True)
    snap.add_argument("--all-transpositions", action="store_true")
    snap.add_argument("--top", type=int, default=DEFAULT_TOP)
    snap.add_argument("--key", default="C:maj")
    snap.set_defaults(func=cmd_snapshot)

    diff = sub.add_parser("diff", help="compare two snapshots by severity")
    diff.add_argument("before", type=Path)
    diff.add_argument("after", type=Path)
    diff.add_argument("--examples", type=int, default=20)
    diff.set_defaults(func=cmd_diff)

    census = sub.add_parser("census", help="count which rule decides each top pair")
    census.add_argument("snapshot", type=Path)
    census.set_defaults(func=cmd_census)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

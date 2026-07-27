#!/usr/bin/env python3
"""Paired per-piece comparison of two WhatKey harness reports.

Implements the protocol's reporting rules (research/whatkey/PROTOCOL.md):
paired per-piece differences, the Wilcoxon signed-rank test (normal
approximation with tie correction and continuity correction), and a
seeded-bootstrap CI95 of the mean difference. Pieces are paired by title;
pieces where either run has no claimed labeled events are excluded and
counted.

Accuracy comparisons are only meaningful alongside coverage, which is printed
for both runs; for a coverage-matched test, compare floor-zero runs or use
--restrict-to when generating the reports.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

DEFAULT_SEED = "whatkey-compare-v1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path, help="report.json of run A")
    parser.add_argument("baseline", type=Path, help="report.json of run B")
    parser.add_argument(
        "--metric",
        default="exactOnClaimed",
        choices=["exactOnClaimed", "mirexOnClaimed", "coverage"],
    )
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--bootstrap", type=int, default=10000)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    a_report = json.loads(args.candidate.read_text())
    b_report = json.loads(args.baseline.read_text())

    a_pieces = {piece["title"]: piece for piece in a_report["perPiece"]}
    b_pieces = {piece["title"]: piece for piece in b_report["perPiece"]}
    shared = sorted(a_pieces.keys() & b_pieces.keys())
    if not shared:
        print("No shared pieces between reports.", file=sys.stderr)
        return 1

    def usable(piece: dict) -> bool:
        if args.metric == "coverage":
            return True
        return piece["labeledClaimed"] > 0

    deltas = []
    excluded = 0
    for title in shared:
        a_piece, b_piece = a_pieces[title], b_pieces[title]
        if not (usable(a_piece) and usable(b_piece)):
            excluded += 1
            continue
        deltas.append((title, a_piece[args.metric] - b_piece[args.metric]))

    values = [delta for _, delta in deltas]
    wins = sum(1 for v in values if v > 1e-9)
    losses = sum(1 for v in values if v < -1e-9)
    ties = len(values) - wins - losses
    mean_delta = sum(values) / len(values)
    p_value = wilcoxon_signed_rank(values)
    ci_low, ci_high = bootstrap_ci(values, args.bootstrap, args.seed)

    def name(report: dict) -> str:
        return report["detector"]["name"]

    print(f"Paired per-piece comparison on {args.metric}")
    print(f"  A (candidate): {name(a_report)}  {args.candidate}")
    print(f"  B (baseline):  {name(b_report)}  {args.baseline}")
    print(
        f"  pieces: {len(values)} paired"
        f" ({excluded} excluded without claims), of {len(shared)} shared"
    )
    print(
        f"  coverage (mean per piece): "
        f"A {a_report['summary']['coverage']['meanPerPiece']:.2f}  "
        f"B {b_report['summary']['coverage']['meanPerPiece']:.2f}"
    )
    print(f"  A-B mean delta: {mean_delta:+.4f}  CI95 [{ci_low:+.4f}, {ci_high:+.4f}]")
    print(f"  wins/losses/ties: {wins}/{losses}/{ties}")
    if p_value is None:
        print("  Wilcoxon: not applicable (all differences are zero)")
    else:
        print(f"  Wilcoxon signed-rank p (two-sided): {p_value:.4f}")
    return 0


def wilcoxon_signed_rank(values: list[float]) -> float | None:
    """Two-sided p via the normal approximation with tie and continuity
    corrections. Zero differences are dropped (the standard Wilcoxon
    treatment)."""
    nonzero = [v for v in values if abs(v) > 1e-12]
    if not nonzero:
        return None
    ranked = sorted(nonzero, key=abs)
    # Average ranks across ties in |delta|.
    ranks: list[float] = [0.0] * len(ranked)
    index = 0
    while index < len(ranked):
        end = index
        while end + 1 < len(ranked) and math.isclose(
            abs(ranked[end + 1]), abs(ranked[index]), rel_tol=0, abs_tol=1e-12
        ):
            end += 1
        average = (index + end) / 2 + 1
        for position in range(index, end + 1):
            ranks[position] = average
        index = end + 1

    w_plus = sum(rank for value, rank in zip(ranked, ranks) if value > 0)
    n = len(ranked)
    mean = n * (n + 1) / 4
    variance = n * (n + 1) * (2 * n + 1) / 24
    # Tie correction over groups of equal |delta|.
    index = 0
    while index < len(ranked):
        end = index
        while end + 1 < len(ranked) and math.isclose(
            abs(ranked[end + 1]), abs(ranked[index]), rel_tol=0, abs_tol=1e-12
        ):
            end += 1
        t = end - index + 1
        if t > 1:
            variance -= (t**3 - t) / 48
        index = end + 1
    if variance <= 0:
        return None
    z = (w_plus - mean - math.copysign(0.5, w_plus - mean)) / math.sqrt(variance)
    return math.erfc(abs(z) / math.sqrt(2))


def bootstrap_ci(values: list[float], resamples: int, seed: str) -> tuple[float, float]:
    rng = random.Random(seed)
    n = len(values)
    means = sorted(
        sum(rng.choice(values) for _ in range(n)) / n for _ in range(resamples)
    )
    low = means[max(0, int(0.025 * resamples) - 1)]
    high = means[min(resamples - 1, int(0.975 * resamples))]
    return low, high


if __name__ == "__main__":
    raise SystemExit(main())

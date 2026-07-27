"""Paired per-piece comparison for a chord-context lever0 A/B report.

Reads a report.json from tool/chord-context/lever0_eval.dart and applies the
protocol's reporting rules to the closed-vs-base (and oracle-vs-base) arms:
per-piece mean deltas, Wilcoxon signed-rank, and a seeded-bootstrap CI95,
reusing the statistics implementations from tool/whatkey/compare.py.

Usage:
  python tool/chord-context/lever0_compare.py build/chord-context/lever0/dcml-dev/report.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "whatkey"))
from compare import bootstrap_ci, wilcoxon_signed_rank

DEFAULT_SEED = "chord-context-lever0-compare-v1"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument(
        "--arm",
        default="closed",
        help="Arm name present in the report's perPiece entries.",
    )
    parser.add_argument(
        "--baseline-arm",
        default="base",
        help="Arm to pair against within the same report.",
    )
    parser.add_argument(
        "--baseline-report",
        type=Path,
        help="Compare this report's arm against another report's same arm "
        "(paired by piece) instead of against its own base arm.",
    )
    parser.add_argument("--bootstrap", type=int, default=10000)
    parser.add_argument("--seed", default=DEFAULT_SEED)
    args = parser.parse_args()

    report = json.loads(args.report.read_text())
    if args.baseline_report is not None:
        baseline = json.loads(args.baseline_report.read_text())
        b_pieces = {piece["id"]: piece for piece in baseline["perPiece"]}
        values = [
            piece[args.arm] - b_pieces[piece["id"]][args.arm]
            for piece in report["perPiece"]
            if piece["id"] in b_pieces
            and piece.get(args.arm) is not None
            and b_pieces[piece["id"]].get(args.arm) is not None
        ]
        against = f"{args.baseline_report} ({args.arm})"
    else:
        baseline_arm = args.baseline_arm
        values = [
            piece[args.arm] - piece[baseline_arm]
            for piece in report["perPiece"]
            if piece.get(args.arm) is not None and piece.get(baseline_arm) is not None
        ]
        against = f"own {baseline_arm} arm"
    wins = sum(1 for v in values if v > 1e-9)
    losses = sum(1 for v in values if v < -1e-9)
    ties = len(values) - wins - losses
    mean_delta = sum(values) / len(values)
    p_value = wilcoxon_signed_rank(values)
    ci_low, ci_high = bootstrap_ci(values, args.bootstrap, args.seed)

    pooled = report["pooled"]
    print(f"lever0 paired comparison ({args.arm} vs {against}): {report['set']}")
    print(f"  pieces: {len(values)}  pooled n: {pooled['n']}")

    def pooled_num(key):
        value = pooled.get(key)
        return value if isinstance(value, (int, float)) else None

    coverage = pooled_num("claimCoverage")
    pooled_a = pooled_num(args.arm)
    pooled_b = pooled_num(args.baseline_arm) or pooled_num("base")
    if pooled_a is not None and pooled_b is not None:
        print(
            f"  pooled: baseline {pooled_b:.4f}  {args.arm} {pooled_a:.4f}"
            + (f"  claim coverage {coverage:.3f}" if coverage is not None else "")
        )
    print(
        f"  per-piece mean delta: {mean_delta:+.4f}"
        f"  CI95 [{ci_low:+.4f}, {ci_high:+.4f}]"
    )
    print(f"  wins/losses/ties: {wins}/{losses}/{ties}")
    if p_value is None:
        print("  Wilcoxon: not applicable (all differences are zero)")
    else:
        print(f"  Wilcoxon signed-rank p (two-sided): {p_value:.2e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

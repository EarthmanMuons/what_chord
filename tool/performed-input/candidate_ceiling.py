#!/usr/bin/env python3
"""Re-ranking ceiling: how much disagreement time an alternative would fix.

The pricing hypothesis (log 2026-07-27-10): the ranker absorbs extra tones
into bigger chord names where naming the base chord and leaving a tone
unexplained would match the analyst. Fixture events carry the surfaced
near-tie alternatives with explanation costs, so the ceiling of any pricing
change is measurable offline: for every exact-tier disagreement segment
(after boundary tolerance), does some surfaced alternative match the analyst
exactly, at what cost gap behind the winner, and is it the base-reading
shape (alternative chord tones a subset of the winner's)?

Shares are of disagreement time; cost gaps are time-weighted. The ceiling is
relative to surfaced near-ties only (what the app can already flip to), a
lower bound on full re-ranking. Reads build/ fixtures; writes a JSON report.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from identity_score import REPO_ROOT, analyst_chord, app_chord, tiers

REPORT_SCHEMA = "performed-input-candidate-ceiling/1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2"),
    )
    parser.add_argument(
        "--split-file",
        type=Path,
        default=REPO_ROOT / "research/performed-input/data/splits/asap-wir-nc-v2.json",
    )
    parser.add_argument(
        "--split", choices=("development", "test"), default="development"
    )
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def weighted_quantile(pairs: list[tuple[float, float]], q: float) -> float:
    """Quantile of values weighted by time; pairs are (value, weight)."""
    if not pairs:
        return 0.0
    ordered = sorted(pairs)
    target = q * sum(weight for _, weight in ordered)
    run = 0.0
    for value, weight in ordered:
        run += weight
        if run >= target:
            return value
    return ordered[-1][0]


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())

    displayed = disagree = added = 0.0
    flip = flip_added = flip_base = 0.0
    gaps: list[tuple[float, float]] = []
    for entry in split["splits"][args.split]:
        name = entry["id"].split("/")[-1]
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        timeline = fixture["harmony"]
        starts = [t["timestampMs"] for t in timeline]
        end_ms = max(
            (e["timestampMs"] + e["durationMs"] for e in fixture["events"]),
            default=starts[-1] if starts else 0,
        )
        ends = starts[1:] + [max(end_ms, starts[-1] if starts else 0)]
        for event in fixture["events"]:
            candidates = event.get("candidates") or []
            if not candidates:
                continue
            top = candidates[0]
            ev_lo = event["timestampMs"]
            ev_hi = ev_lo + event["durationMs"]
            pcs = frozenset(i for i in range(12) if event["pcMask"] >> i & 1)
            for index, (span_start, span_end) in enumerate(zip(starts, ends)):
                lo, hi = max(ev_lo, span_start), min(ev_hi, span_end)
                if hi <= lo:
                    continue
                span = timeline[index]
                chord = analyst_chord(span["figure"], span["key"])
                if chord[0] is None:
                    continue
                weight = hi - lo
                displayed += weight
                exact = tiers(top, chord)[0]
                tolerance = span.get("beatMs", 0)
                if not exact and index > 0 and lo - span_start < tolerance:
                    neighbor = timeline[index - 1]
                    exact = tiers(
                        top, analyst_chord(neighbor["figure"], neighbor["key"])
                    )[0]
                if (
                    not exact
                    and index + 1 < len(timeline)
                    and span_end - hi < tolerance
                ):
                    neighbor = timeline[index + 1]
                    exact = tiers(
                        top, analyst_chord(neighbor["figure"], neighbor["key"])
                    )[0]
                if exact:
                    continue
                disagree += weight
                in_added = chord[0] <= pcs and bool(pcs - chord[0])
                if in_added:
                    added += weight
                winner = None
                for alternative in candidates[1:]:
                    if tiers(alternative, chord)[0]:
                        winner = alternative
                        break
                if winner is None:
                    continue
                flip += weight
                if in_added:
                    flip_added += weight
                gaps.append((winner["cost"] - top["cost"], weight))
                top_members = app_chord(top)[0]
                if app_chord(winner)[0] < top_members:
                    flip_base += weight

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "displayedMs": round(displayed),
        "disagreementMs": round(disagree),
        "flippable": {
            "shareOfDisagreement": flip / disagree if disagree else 0.0,
            "shareOfDisplayed": flip / displayed if displayed else 0.0,
            "withinAddedToneShare": flip_added / added if added else 0.0,
            "baseReadingShareOfFlippable": flip_base / flip if flip else 0.0,
            "costGap": {
                "median": weighted_quantile(gaps, 0.5),
                "p90": weighted_quantile(gaps, 0.9),
            },
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    f = report["flippable"]
    print(
        f"{args.split}: analyst chord among surfaced alternatives on "
        f"{f['shareOfDisagreement']:.3f} of disagreement time "
        f"({f['shareOfDisplayed']:.3f} of displayed; "
        f"{f['withinAddedToneShare']:.3f} of added-tone time)"
    )
    print(
        f"  base-reading shape {f['baseReadingShareOfFlippable']:.3f} of "
        f"flippable; cost gap median {f['costGap']['median']:.3f}, "
        f"p90 {f['costGap']['p90']:.3f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

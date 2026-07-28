#!/usr/bin/env python3
"""Census of exact-tier disagreement time on a performed-input arm.

For every displayed time segment failing the exact tier (after boundary
tolerance, mirroring identity_score.py), classifies the disagreement on two
axes and reports time-weighted shares:

  content axis: were the analyst chord's tones sounding in the voicing?
    playable  every analyst chord tone is in the event's pitch classes;
              the engine had the full chord in hand and named something
              else (engine-actionable)
    partial   analyst root sounding but not every chord tone; naming a
              sub-chord of the label is defensible surface behavior
    absent    analyst root not sounding: the label is functional harmony
              the player was not literally voicing (not engine-actionable)

  naming axis (relationship of the app's chord to the analyst's):
    rootHit      same root, different quality family
    appSubset    app chord tones are a strict subset of the analyst's
    appSuperset  analyst chord tones are a strict subset of the app's
    overlapping  at least two shared tones, neither containment
    unrelated    fewer than two shared tones

Prints the crossed matrix and the heaviest samples from the playable bucket
for qualitative reading. Reads build/ fixtures; writes a JSON report.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from identity_score import REPO_ROOT, analyst_chord, app_chord, tiers

REPORT_SCHEMA = "performed-input-error-census/1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2-armBC"),
    )
    parser.add_argument(
        "--split-file",
        type=Path,
        default=REPO_ROOT / "research/performed-input/data/splits/asap-wir-nc-v2.json",
    )
    parser.add_argument(
        "--split", choices=("development", "test"), default="development"
    )
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def event_pcs(event: dict) -> frozenset[int]:
    return frozenset(i for i in range(12) if event["pcMask"] >> i & 1)


def content_bucket(pcs: frozenset[int], chord: tuple) -> str:
    members, root = chord[0], chord[1]
    if members <= pcs:
        return "playable"
    if root in pcs:
        return "partial"
    return "absent"


def naming_bucket(candidate: dict, chord: tuple) -> str:
    a_members, a_root = chord[0], chord[1]
    members, root, _ = app_chord(candidate)
    if root == a_root:
        return "rootHit"
    if members < a_members:
        return "appSubset"
    if a_members < members:
        return "appSuperset"
    if len(members & a_members) >= 2:
        return "overlapping"
    return "unrelated"


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())

    matrix: dict[tuple[str, str], float] = defaultdict(float)
    samples: list[tuple] = []
    displayed = disagree = 0.0
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
            candidate = (event.get("candidates") or [None])[0]
            if candidate is None:
                continue
            ev_start = event["timestampMs"]
            ev_end = ev_start + event["durationMs"]
            pcs = event_pcs(event)
            for index, (span_start, span_end) in enumerate(zip(starts, ends)):
                lo, hi = max(ev_start, span_start), min(ev_end, span_end)
                if hi <= lo:
                    continue
                span = timeline[index]
                chord = analyst_chord(span["figure"], span["key"])
                if chord[0] is None:
                    continue
                weight = hi - lo
                displayed += weight
                exact = tiers(candidate, chord)[0]
                tolerance = span.get("beatMs", 0)
                if not exact:
                    if index > 0 and lo - span_start < tolerance:
                        neighbor = timeline[index - 1]
                        exact = tiers(
                            candidate,
                            analyst_chord(neighbor["figure"], neighbor["key"]),
                        )[0]
                    if (
                        not exact
                        and index + 1 < len(timeline)
                        and span_end - hi < tolerance
                    ):
                        neighbor = timeline[index + 1]
                        exact = tiers(
                            candidate,
                            analyst_chord(neighbor["figure"], neighbor["key"]),
                        )[0]
                if exact:
                    continue
                disagree += weight
                buckets = (content_bucket(pcs, chord), naming_bucket(candidate, chord))
                matrix[buckets] += weight
                if buckets[0] == "playable":
                    samples.append(
                        (
                            weight,
                            name,
                            span["measure"],
                            span["figure"],
                            span["key"],
                            sorted(chord[0]),
                            candidate["rootPc"],
                            candidate["quality"],
                            sorted(pcs),
                        )
                    )

    content_order = ("playable", "partial", "absent")
    naming_order = ("rootHit", "appSubset", "appSuperset", "overlapping", "unrelated")
    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "displayedMs": round(displayed),
        "disagreementMs": round(disagree),
        "disagreementShare": disagree / displayed if displayed else 0.0,
        "matrixShareOfDisagreement": {
            f"{content}/{naming}": matrix[(content, naming)] / disagree
            for content in content_order
            for naming in naming_order
            if matrix[(content, naming)]
        },
        "contentShares": {
            content: sum(matrix[(content, n)] for n in naming_order) / disagree
            for content in content_order
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    print(
        f"{args.split}: disagreement {report['disagreementShare']:.3f} of "
        f"displayed time ({round(disagree / 1000)}s of {round(displayed / 1000)}s)"
    )
    print(f"{'':>12}" + "".join(f"{n:>12}" for n in naming_order))
    for content in content_order:
        row = "".join(f"{matrix[(content, n)] / disagree:>12.3f}" for n in naming_order)
        share = report["contentShares"][content]
        print(f"{content:>12}{row}   total {share:.3f}")
    print(f"\nheaviest playable-bucket samples (top {args.samples} by time):")
    for weight, name, measure, figure, key, expected, root, quality, pcs in sorted(
        samples, reverse=True
    )[: args.samples]:
        print(
            f"  {weight / 1000:5.1f}s {name} m{measure} {figure} in {key} "
            f"exp={expected} app=({root},{quality}) pcs={pcs}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

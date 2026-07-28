#!/usr/bin/env python3
"""Alignment-quality probe for ASAP x When in Rome harmony-labeled fixtures.

For each fixture in a harmony-labeled set (asap_wir_extract.py, v2+), reports:

  - timeline sanity: monotone timestamps, span and distinct-figure counts
  - agreement between the two independent key paths (measure-map localKey
    vs harmony-span key), which differ only at mid-measure key changes
  - analyst chord content vs performed content: music21 RomanNumeral
    (figure, key) pitch classes against each event's pcMask (mean chord-tone
    overlap, strict containment, root presence, figure parse failures)
  - shift response: mean overlap when every harmony label is displaced by a
    global measure offset in [-2, +2]. A healthy alignment peaks sharply at
    0; a peak elsewhere means the downbeat-map offset calibration failed for
    that movement, and a flat row means the alignment is unusable.

Reads build/ fixtures only; writes nothing.
"""

from __future__ import annotations

import argparse
import bisect
import json
from itertools import pairwise
from pathlib import Path

from music21 import key as m21key
from music21 import roman

SHIFTS = (-2, -1, 0, 1, 2)

_cache: dict[tuple, object] = {}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--set-dir",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2"),
    )
    parser.add_argument(
        "movements",
        nargs="*",
        help="Fixture names (default: every fixture in the set).",
    )
    parser.add_argument(
        "--worst",
        type=int,
        default=0,
        help="Also list the N lowest-overlap events per movement.",
    )
    parser.add_argument(
        "--windows",
        type=int,
        default=1,
        help="Also report the shift response per time window (N windows), "
        "distinguishing uniform shallowness (texture) from sectional drift "
        "(piecewise misalignment, e.g. repeat-convention mismatches).",
    )
    return parser.parse_args()


def analyst_chord(figure: str, wire: str):
    """(expected pitch-class set, root pc) or (None, None) on parse failure."""
    ck = (figure, wire)
    if ck not in _cache:
        try:
            tonic, mode = wire.split(":")
            tonic = tonic.replace("b", "-")
            scale = m21key.Key(tonic.lower() if mode == "min" else tonic)
            rn = roman.RomanNumeral(figure, scale)
            _cache[ck] = (
                frozenset(p.pitchClass for p in rn.pitches),
                rn.root().pitchClass,
            )
        except Exception:  # noqa: BLE001 -- music21 raises many parse types
            _cache[ck] = (None, None)
    return _cache[ck]


def event_pcs(event: dict) -> frozenset[int]:
    return frozenset(i for i in range(12) if event["pcMask"] >> i & 1)


def shift_response(
    fixture: dict, events: list[dict] | None = None
) -> list[float | None]:
    spans = sorted(
        {(e["measure"], e["beat"], e["key"], e["figure"]) for e in fixture["harmony"]}
    )
    positions = [(s[0], s[1]) for s in spans]
    response = []
    for shift in SHIFTS:
        overlaps = []
        for event in events if events is not None else fixture["events"]:
            harmony = event["labels"].get("harmony")
            if not harmony:
                continue
            at = (
                bisect.bisect_right(
                    positions, (harmony["measure"] + shift, harmony["beat"])
                )
                - 1
            )
            _, _, key, figure = spans[max(at, 0)]
            expected, _ = analyst_chord(figure, key)
            if expected is None:
                continue
            got = event_pcs(event)
            overlaps.append(len(got & expected) / len(got) if got else 1.0)
        response.append(sum(overlaps) / len(overlaps) if overlaps else None)
    return response


def inspect(name: str, fixture: dict, worst_n: int, windows: int = 1) -> None:
    timeline = fixture["harmony"]
    events = fixture["events"]
    times = [entry["timestampMs"] for entry in timeline]
    monotone = all(a <= b for a, b in pairwise(times))
    figures = {(entry["key"], entry["figure"]) for entry in timeline}

    labeled = key_agree = subset = root_hit = parse_fail = 0
    overlaps: list[float] = []
    worst: list[tuple] = []
    for event in events:
        harmony = event["labels"].get("harmony")
        if not harmony:
            continue
        labeled += 1
        if harmony["key"] == event["labels"]["localKey"]:
            key_agree += 1
        expected, root = analyst_chord(harmony["figure"], harmony["key"])
        if expected is None:
            parse_fail += 1
            continue
        got = event_pcs(event)
        overlap = len(got & expected) / len(got) if got else 1.0
        overlaps.append(overlap)
        if got <= expected:
            subset += 1
        if root in got:
            root_hit += 1
        worst.append((overlap, event["labels"]["measure"], harmony, sorted(got)))

    print(
        f"== {name}: {len(events)} events, {len(timeline)} timeline entries, "
        f"{len(figures)} distinct (key,figure), monotone={monotone}"
    )
    print(
        f"   harmony label on {labeled}/{len(events)} events; "
        f"localKey==harmony.key {key_agree}/{labeled}; "
        f"figure parse failures {parse_fail}"
    )
    if overlaps:
        n = len(overlaps)
        print(
            f"   chord-tone overlap mean {sum(overlaps) / n:.3f}; "
            f"event pcs subset-of-chord {subset}/{n} ({subset / n:.1%}); "
            f"root present {root_hit}/{n} ({root_hit / n:.1%})"
        )
    response = shift_response(fixture)
    cells = (
        f"{shift:+d}: {value:.3f}" if value is not None else f"{shift:+d}: n/a"
        for shift, value in zip(SHIFTS, response)
    )
    print("   shift response  " + "  ".join(cells))
    if windows > 1:
        labeled_events = [e for e in events if e["labels"].get("harmony")]
        for index in range(windows):
            chunk = labeled_events[
                index * len(labeled_events) // windows : (index + 1)
                * len(labeled_events)
                // windows
            ]
            if not chunk:
                continue
            row = shift_response(fixture, chunk)
            best = max(
                (value, shift) for shift, value in zip(SHIFTS, row) if value is not None
            )[1]
            cells = "  ".join(
                f"{shift:+d}: {value:.3f}" if value is not None else f"{shift:+d}: n/a"
                for shift, value in zip(SHIFTS, row)
            )
            flag = "" if best == 0 else f"   <-- peaks at {best:+d}"
            span = f"m{chunk[0]['labels']['measure']}-{chunk[-1]['labels']['measure']}"
            print(f"   window {index + 1}/{windows} ({span}): {cells}{flag}")
    for overlap, measure, harmony, got in sorted(worst, key=lambda w: w[0])[:worst_n]:
        expected, _ = analyst_chord(harmony["figure"], harmony["key"])
        print(
            f"   LOW {overlap:.2f} evMeasure={measure} "
            f"span=m{harmony['measure']} b{harmony['beat']} "
            f"{harmony['figure']} in {harmony['key']} "
            f"got={got} exp={sorted(expected)}"
        )
    print()


def main() -> int:
    args = parse_args()
    names = args.movements or sorted(
        p.stem for p in args.set_dir.glob("*.json") if p.stem != "manifest"
    )
    for name in names:
        fixture = json.loads((args.set_dir / f"{name}.json").read_text())
        inspect(name, fixture, args.worst, args.windows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

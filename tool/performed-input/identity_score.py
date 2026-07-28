#!/usr/bin/env python3
"""Score displayed chord identity against analyst harmony on performed input.

The frozen ruler (research/performed-input/PROTOCOL.md, log 2026-07-27-04):
time-weighted agreement over the union of event display intervals
([timestampMs, +durationMs]) intersected with the analyst harmony timeline,
scored between the app's top-ranked candidate and the analyst chord at three
tiers:

  exact   root pitch class and quality family both match (headline)
  root    root pitch class matches
  members chord-tone pitch-class sets match regardless of root

Quality family is (third, fifth, seventh) classified from the chord-member
interval set above the root, identically on both sides. Augmented-sixth
figures score by member set at every tier (the app legitimately names them as
enharmonic dominants). Within one interpolated beat (beatMs) of an analyst
span boundary, agreement with either neighboring span counts. Coverage is the
displayed share of analyst-labeled time; tiers are reported on displayed time
only, mirroring the coverage/accuracy-on-claimed pairing of the whatkey
harness.

Reads build/ fixtures; writes a JSON report. License-gated inputs stay under
build/ (research/whatkey/data/NOTICE.md).
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from music21 import key as m21key
from music21 import roman

REPO_ROOT = Path(__file__).resolve().parents[2]
REPORT_SCHEMA = "performed-input-identity/1"

QUALITY_INTERVALS = {
    "major": (0, 4, 7),
    "minor": (0, 3, 7),
    "diminished": (0, 3, 6),
    "augmented": (0, 4, 8),
    "power": (0, 7),
    "majorFlat5": (0, 4, 6),
    "sus2": (0, 2, 7),
    "sus4": (0, 5, 7),
    "sus2sus4": (0, 2, 5, 7),
    "major6": (0, 4, 7, 9),
    "minor6": (0, 3, 7, 9),
    "dominant7": (0, 4, 7, 10),
    "major7": (0, 4, 7, 11),
    "minor7": (0, 3, 7, 10),
    "minorMajor7": (0, 3, 7, 11),
    "diminished7": (0, 3, 6, 9),
    "halfDiminished7": (0, 3, 6, 10),
    "dominant7sus4": (0, 5, 7, 10),
    "dominant7sus2": (0, 2, 7, 10),
    "major7sus4": (0, 5, 7, 11),
    "major7sus2": (0, 2, 7, 11),
    "dominant7Sharp5": (0, 4, 8, 10),
    "dominant7Flat5": (0, 4, 6, 10),
    "major7Sharp5": (0, 4, 8, 11),
    "major7Flat5": (0, 4, 6, 11),
}

EXTENSION_INTERVALS = {
    "nine": 2, "add9": 2, "flat9": 1, "addFlat9": 1, "sharp9": 3,
    "addSharp9": 3, "eleven": 5, "add11": 5, "sharp11": 6,
    "thirteen": 9, "flat13": 8,
}  # fmt: skip

AUG6_MARKERS = ("It", "Ger", "Fr")

_analyst_cache: dict[tuple, tuple] = {}


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
    parser.add_argument(
        "--arm",
        default="A0",
        help="Attribution arm label recorded in the report (data lineage is "
        "the fixture set; A0 = app segmentation, neutral context).",
    )
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def family(members: frozenset[int]) -> tuple[str, str, str]:
    """(third, fifth, seventh) classified from intervals above the root."""
    third = (
        "major"
        if 4 in members
        else "minor"
        if 3 in members
        else "sus"
        if 2 in members or 5 in members
        else "none"
    )
    fifth = (
        "perfect"
        if 7 in members
        else "diminished"
        if 6 in members
        else "augmented"
        if 8 in members
        else "none"
    )
    if 10 in members:
        seventh = "minor"
    elif 11 in members:
        seventh = "major"
    elif 9 in members and third == "minor" and fifth == "diminished":
        seventh = "diminished"
    else:
        seventh = "none"
    return (third, fifth, seventh)


def analyst_chord(figure: str, wire: str) -> tuple:
    """(member pcs, root pc, family, is_aug6) or (None, ...) on parse failure."""
    ck = (figure, wire)
    if ck not in _analyst_cache:
        try:
            tonic, mode = wire.split(":")
            tonic = tonic.replace("b", "-")
            scale = m21key.Key(tonic.lower() if mode == "min" else tonic)
            rn = roman.RomanNumeral(figure, scale)
            members = frozenset(p.pitchClass for p in rn.pitches)
            root = rn.root().pitchClass
            intervals = frozenset((pc - root) % 12 for pc in members)
            is_aug6 = any(marker in figure for marker in AUG6_MARKERS)
            _analyst_cache[ck] = (members, root, family(intervals), is_aug6)
        except Exception:  # noqa: BLE001 -- music21 raises many parse types
            _analyst_cache[ck] = (None, None, None, False)
    return _analyst_cache[ck]


def app_chord(candidate: dict) -> tuple:
    """(member pcs, root pc, family) from the app's named identity."""
    root = candidate["rootPc"]
    intervals = set(QUALITY_INTERVALS[candidate["quality"]])
    intervals.update(
        EXTENSION_INTERVALS[ext]
        for ext in candidate["extensions"]
        if ext in EXTENSION_INTERVALS
    )
    members = frozenset((root + i) % 12 for i in intervals)
    return members, root, family(frozenset(QUALITY_INTERVALS[candidate["quality"]]))


def tiers(candidate: dict, span_chord: tuple) -> tuple[bool, bool, bool]:
    """(exact, root, members) agreement between app candidate and span."""
    a_members, a_root, a_family, is_aug6 = span_chord
    if a_members is None:
        return False, False, False
    members, root, fam = app_chord(candidate)
    member_match = members == a_members
    if is_aug6:
        return member_match, member_match, member_match
    return (
        root == a_root and fam == a_family,
        root == a_root,
        member_match,
    )


def score_fixture(fixture: dict) -> dict:
    timeline = fixture["harmony"]
    events = fixture["events"]
    end_ms = max(
        (e["timestampMs"] + e["durationMs"] for e in events),
        default=timeline[-1]["timestampMs"] if timeline else 0,
    )
    starts = [entry["timestampMs"] for entry in timeline]
    ends = starts[1:] + [max(end_ms, starts[-1] if starts else 0)]

    analyst_ms = sum(max(e - s, 0) for s, e in zip(starts, ends))
    displayed = exact = root = members = aug6_ms = unparsed_ms = 0.0
    for event in events:
        candidate = (event.get("candidates") or [None])[0]
        if candidate is None:
            continue
        ev_start = event["timestampMs"]
        ev_end = ev_start + event["durationMs"]
        for index, (span_start, span_end) in enumerate(zip(starts, ends)):
            lo, hi = max(ev_start, span_start), min(ev_end, span_end)
            if hi <= lo:
                continue
            entry = timeline[index]
            chord = analyst_chord(entry["figure"], entry["key"])
            if chord[0] is None:
                unparsed_ms += hi - lo
                continue
            verdicts = tiers(candidate, chord)
            tolerance = entry.get("beatMs", 0)
            if not verdicts[0]:
                neighbors = []
                if index > 0 and lo - span_start < tolerance:
                    neighbors.append(timeline[index - 1])
                if index + 1 < len(timeline) and span_end - hi < tolerance:
                    neighbors.append(timeline[index + 1])
                for neighbor in neighbors:
                    other = analyst_chord(neighbor["figure"], neighbor["key"])
                    alt = tiers(candidate, other)
                    verdicts = tuple(a or b for a, b in zip(verdicts, alt))
            weight = hi - lo
            displayed += weight
            exact += weight * verdicts[0]
            root += weight * verdicts[1]
            members += weight * verdicts[2]
            if chord[3]:
                aug6_ms += weight

    return {
        "id": fixture["id"],
        "title": fixture["title"],
        "analystMs": round(analyst_ms),
        "displayedMs": round(displayed),
        "coverage": displayed / analyst_ms if analyst_ms else 0.0,
        "exact": exact / displayed if displayed else 0.0,
        "root": root / displayed if displayed else 0.0,
        "members": members / displayed if displayed else 0.0,
        "aug6Share": aug6_ms / displayed if displayed else 0.0,
        "unparsedMs": round(unparsed_ms),
    }


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())
    rows = []
    for entry in split["splits"][args.split]:
        name = entry["id"].split("/")[-1]
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        rows.append(score_fixture(fixture))

    def mean(field: str) -> float:
        return sum(r[field] for r in rows) / len(rows) if rows else 0.0

    total_displayed = sum(r["displayedMs"] for r in rows)

    def pooled(field: str) -> float:
        if not total_displayed:
            return 0.0
        return sum(r[field] * r["displayedMs"] for r in rows) / total_displayed

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "arm": args.arm,
        "fixtures": str(args.fixtures),
        "splitFile": str(args.split_file),
        "split": args.split,
        "protocol": "research/performed-input/PROTOCOL.md",
        "summary": {
            "pieces": len(rows),
            "meanPerPiece": {
                field: mean(field) for field in ("coverage", "exact", "root", "members")
            },
            "pooledOnDisplayed": {
                field: pooled(field) for field in ("exact", "root", "members")
            },
        },
        "perPiece": sorted(rows, key=lambda r: r["id"]),
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    s = report["summary"]
    print(
        f"{args.split} ({len(rows)} pieces, arm {args.arm}): "
        f"coverage {s['meanPerPiece']['coverage']:.3f}, "
        f"exact {s['meanPerPiece']['exact']:.3f}, "
        f"root {s['meanPerPiece']['root']:.3f}, "
        f"members {s['meanPerPiece']['members']:.3f} (mean per piece) -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

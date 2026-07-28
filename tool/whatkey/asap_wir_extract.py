#!/usr/bin/env python3
"""Emit mode-resolved WhatKey fixtures: ASAP performances with When in Rome keys.

The overlap corpus: ASAP's performed Beethoven piano sonatas, labeled with
When in Rome's analyst local keys (tonic AND mode, tonicization-scale)
transferred through ASAP's performance-to-score downbeat alignment. This is
the only set with real key ground truth on performed input, closing the
mode-accuracy blind spot (log entry 2026-07-07-17) and enabling the
controlled same-input timescale comparison (identical performances, analyst
labels, both emission-memory configurations).

Pipeline per performance: pedal-aware sounding snapshots replayed through the
real capture path (reusing tool/whatkey/asap_extract.py), then each event is
labeled with the analyst key of the score measure active at its start
(performance downbeat -> downbeats_score_map -> measure -> RomanText key).

For the performed-input identity benchmark (research/performed-input/), each
fixture also carries the analyst harmony: the full RomanText chord-span
timeline projected into performance time (downbeats anchor measures; beats
interpolate linearly inside a measure), plus a per-event convenience label of
the span active at the event start. Conversion of (key, figure) to expected
chord content is a scoring-time decision and does not happen here.

LICENSE GATE: ASAP is CC BY-NC-SA 4.0 and the When in Rome Beethoven-sonata
analyses are not in our license-verified group set; fixtures stay under
build/ and this tool refuses to write inside research/.
"""

from __future__ import annotations

import argparse
import bisect
import json
import re
import sys
from datetime import datetime, timezone
from itertools import pairwise
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "chord"))
import asap_extract as asap_x
from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    DEFAULT_ANALYSIS_PROFILE,
    fixture_hashes,
)
from wir_alignment_probe import analyst_chord

REPO_ROOT = asap_x.REPO_ROOT

# Arm A1 key-behavior presets: detector evidence half-life in seconds.
LIVE_KEY_HALF_LIFE_SECONDS = {"stable": 30, "balanced": 4, "reactive": 1}

# Beethoven sonata number -> When in Rome opus folder prefix.
SONATA_OPUS = {
    1: "Op002_No1", 2: "Op002_No2", 3: "Op002_No3", 4: "Op007",
    5: "Op010_No1", 6: "Op010_No2", 7: "Op010_No3", 8: "Op013",
    9: "Op014_No1", 10: "Op014_No2", 11: "Op022", 12: "Op026",
    13: "Op027_No1", 14: "Op027_No2", 15: "Op028", 16: "Op031_No1",
    17: "Op031_No2", 18: "Op031_No3", 19: "Op049_No1", 20: "Op049_No2",
    21: "Op053", 22: "Op054", 23: "Op057", 24: "Op078", 25: "Op079",
    26: "Op081a", 27: "Op090", 28: "Op101", 29: "Op106", 30: "Op109",
    31: "Op110", 32: "Op111",
}  # fmt: skip


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asap-root", type=Path, required=True)
    parser.add_argument("--bench-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="asap-wir-nc-v2")
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-fixtures"))
    parser.add_argument("--context", default="C:maj")
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
        help="Chord-ranking policy used before capture segmentation.",
    )
    parser.add_argument(
        "--arm",
        choices=("A0", "B", "C", "BC", "A1"),
        default="A0",
        help="Attribution arm (research/performed-input/PROTOCOL.md): A0 = "
        "app segmentation, neutral context; B = annotated analyst key as "
        "context; C = annotation-boundary segmentation; BC = both; A1 = "
        "live inferred-key context (requires --behavior). Arms other than "
        "A0 append -arm<X> to the set name.",
    )
    parser.add_argument(
        "--behavior",
        choices=sorted(LIVE_KEY_HALF_LIFE_SECONDS),
        help="Arm A1 key-behavior preset; sets the detector half-life.",
    )
    parser.add_argument(
        "--span-note-threshold",
        type=float,
        default=0.25,
        help="Arm C: a note enters a span's voicing when it sounds at least "
        "this fraction of the span.",
    )
    parser.add_argument(
        "--emit-frames",
        action="store_true",
        help="Also write per-snapshot display-label change points to "
        "<set>/frames/<name>.json (performed-input avenue 2). Fixture "
        "files stay byte-identical, so frozen split hashes hold.",
    )
    parser.add_argument(
        "--pedal-demotion",
        choices=("off", "transient", "attack"),
        default="off",
        help="Pedal-blur prototype (performed-input log 2026-07-27-10): drop "
        "sustained-only notes with sub-200ms presses (transient), or "
        "additionally once fresh attacks land after their release (attack). "
        "Appends -pd-<rule> to the set name.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if (args.arm == "A1") != (args.behavior is not None):
        raise SystemExit("--arm A1 and --behavior go together.")
    if args.arm == "A1":
        args.set_name = f"{args.set_name}-armA1-{args.behavior}"
    elif args.arm != "A0":
        args.set_name = f"{args.set_name}-arm{args.arm}"
    if args.pedal_demotion != "off":
        args.set_name = f"{args.set_name}-pd-{args.pedal_demotion}"
    if (REPO_ROOT / "research") in args.out.resolve().parents:
        raise SystemExit("License-gated fixtures: build/ only.")

    sys.path.insert(0, str(args.bench_root.resolve() / "harness"))
    import music21_comparison as cbench
    import when_in_rome_benchmark as wir

    annotations = json.loads((args.asap_root / "asap_annotations.json").read_text())
    corpus = (
        args.bench_root
        / "corpus/When-in-Rome/Corpus/Piano_Sonatas/Beethoven,_Ludwig_van"
    )

    # One performance per overlapping sonata movement.
    selected: dict[str, str] = {}
    for perf_path in sorted(annotations):
        parts = perf_path.split("/")
        if parts[0] != "Beethoven" or parts[1] != "Piano_Sonatas":
            continue
        selected.setdefault(parts[2], perf_path)

    fixtures = []
    pieces = []
    seen_movements: set[tuple[int, int]] = set()
    for folder, perf_path in sorted(selected.items()):
        match = re.match(r"^(\d+)-(\d+)", folder)
        if not match:
            continue
        sonata, movement = int(match.group(1)), int(match.group(2))
        if (sonata, movement) in seen_movements:
            continue
        seen_movements.add((sonata, movement))
        opus = SONATA_OPUS.get(sonata)
        if opus is None:
            continue
        matches = sorted(corpus.glob(f"{opus}*/{movement}/analysis.txt"))
        if not matches:
            continue
        keys_by_measure = analyst_keys_by_measure(matches[0], cbench, wir)
        if not keys_by_measure:
            continue
        harmony_spans = analyst_harmony_spans(matches[0], cbench, wir)

        perf = annotations[perf_path]
        if not isinstance(perf.get("downbeats_score_map"), list) or not perf.get(
            "score_and_performance_aligned", False
        ):
            print(f"{perf_path}: no usable alignment, skipped", file=sys.stderr)
            continue
        downbeats = perf["performance_downbeats"]
        # Map entries are usually ints; spans like "63-64" take their first
        # measure. The base is inconsistent across pieces (some start at 0,
        # some at 1). Anchor an offset guess by matching the map's last
        # measure to the analysis's, then calibrate by content: the offset
        # near the anchor whose analyst chords best match the sounding
        # pitch classes (performed-input log 2026-07-27-02: last-measure
        # matching alone mislabeled 8 of 36 movements, including -1 offsets
        # it could not represent).
        raw_measures = [int(str(m).split("-")[0]) for m in perf["downbeats_score_map"]]
        last_analysis_measure = max(keys_by_measure)
        anchor = min(
            (0, 1), key=lambda d: abs(raw_measures[-1] + d - last_analysis_measure)
        )
        snapshots = asap_x.sounding_snapshots(
            args.asap_root / perf_path,
            provenance=args.pedal_demotion != "off",
        )
        offset, curve = calibrate_offset(
            harmony_spans, downbeats, raw_measures, snapshots, anchor
        )
        measures = [m + offset for m in raw_measures]
        timeline = harmony_timeline(harmony_spans, downbeats, measures)
        pieces.append(
            {
                "id": f"{args.set_name}/{folder}",
                "title": perf_path.removesuffix(".mid"),
                "snapshots": snapshots,
                "downbeats": downbeats,
                "measures": measures,
                "keys": keys_by_measure,
                "harmonySpans": harmony_spans,
                "timeline": timeline,
                "replayExtras": arm_extras(args, timeline, snapshots),
            }
        )
        curve_text = "  ".join(
            f"{candidate:+d}: {score:.3f}" for candidate, score in sorted(curve.items())
        )
        print(
            f"{perf_path}: {len(snapshots)} snapshots, "
            f"{len(keys_by_measure)} keyed measures, opens in "
            f"{key_at(keys_by_measure, 1)}, offset {offset:+d} "
            f"(anchor {anchor:+d}; {curve_text})",
            file=sys.stderr,
        )

    replayed = asap_x.replay(
        pieces,
        args.context,
        200,
        args.analysis_profile,
    )

    set_dir = args.out / args.set_name
    set_dir.mkdir(parents=True, exist_ok=True)
    for piece in pieces:
        events = replayed[piece["id"]]["events"]
        if args.emit_frames:
            frames_dir = set_dir / "frames"
            frames_dir.mkdir(parents=True, exist_ok=True)
            name = piece["id"].split("/")[-1]
            (frames_dir / f"{name}.json").write_text(
                json.dumps(
                    {
                        "id": piece["id"],
                        "frames": replayed[piece["id"]]["frames"],
                    },
                    indent=2,
                    sort_keys=True,
                )
                + "\n"
            )
        timeline = piece["timeline"]
        timeline_times = [entry["timestampMs"] for entry in timeline]
        for event in events:
            time_s = event["timestampMs"] / 1000
            index = bisect.bisect_right(piece["downbeats"], time_s) - 1
            measure = piece["measures"][max(index, 0)]
            event["labels"] = {
                "localKey": key_at(piece["keys"], measure),
                "measure": measure,
            }
            if timeline:
                at = bisect.bisect_right(timeline_times, event["timestampMs"]) - 1
                entry = timeline[max(at, 0)]
                event["labels"]["harmony"] = {
                    field: entry[field]
                    for field in ("key", "figure", "measure", "beat")
                }
        fixture = {
            "schema": asap_x.FIXTURE_SCHEMA,
            "id": piece["id"],
            "title": piece["title"],
            "labels": {
                "source": "asap+when-in-rome",
                "modeResolved": True,
                "arm": args.arm,
            },
            "harmony": timeline,
            "events": events,
        }
        name = piece["id"].split("/")[-1]
        (set_dir / f"{name}.json").write_text(
            json.dumps(fixture, indent=2, sort_keys=True) + "\n"
        )
        fixtures.append(
            {
                "id": piece["id"],
                "title": piece["title"],
                "file": f"{name}.json",
                "events": len(events),
            }
        )

    files = [entry["file"] for entry in fixtures]
    hashes, content_hash = fixture_hashes(set_dir, files)
    for entry in fixtures:
        entry["sha256"] = hashes[entry["file"]]

    manifest = {
        "schema": asap_x.MANIFEST_SCHEMA,
        "set": args.set_name,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": "python tool/whatkey/asap_wir_extract.py " + " ".join(sys.argv[1:]),
        "engineCommit": asap_x.git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            asap_x.git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/whatkey/asap_wir_extract.py",
            "arguments": sys.argv[1:],
        },
        "context": args.context,
        "analysisProfile": args.analysis_profile,
        "harmonyLabeled": True,
        "arm": args.arm,
        **(
            {"spanNoteThreshold": args.span_note_threshold}
            if args.arm in ("C", "BC")
            else {}
        ),
        **(
            {"pedalDemotion": args.pedal_demotion}
            if args.pedal_demotion != "off"
            else {}
        ),
        **({"behavior": args.behavior} if args.arm == "A1" else {}),
        "contentHash": {
            "algorithm": "sha256",
            "canonicalization": CANONICALIZATION,
            "value": content_hash,
        },
        "segmenterMinMs": 200,
        "source": {
            "type": "asap+when-in-rome",
            "asapCommit": asap_x.git(args.asap_root, "rev-parse", "HEAD"),
            "benchCommit": asap_x.git(args.bench_root, "rev-parse", "HEAD"),
            "license": (
                "NONCOMMERCIAL-GATED: ASAP is CC BY-NC-SA 4.0 and the "
                "When in Rome Beethoven-sonata analyses are outside the "
                "verified group set; local uncommitted experiments only"
            ),
        },
        "fixtures": fixtures,
    }
    (set_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    print(f"{len(fixtures)} fixtures -> {set_dir}", file=sys.stderr)
    return 0


def analyst_keys_by_measure(analysis_path: Path, cbench, wir) -> dict[int, str]:
    """RomanText -> the analyst key active at the start of each measure."""
    keys: dict[int, str] = {}
    current = None
    last_measure = 0
    for measure, beat, key, figure, time_sig in cbench.parse_rntxt(analysis_path):
        if current is not None:
            for m in range(last_measure, measure + 1):
                keys.setdefault(m, current)
        current = wir.key_to_wire(key)
        keys.setdefault(measure, keys.get(measure, current))
        if measure not in keys or beat <= 1:
            keys[measure] = current if beat <= 1 else keys[measure]
        last_measure = measure
    if current is not None:
        keys.setdefault(last_measure, current)
    return keys


def analyst_harmony_spans(analysis_path: Path, cbench, wir) -> list[dict]:
    """RomanText -> chord spans as (measure, beat, key, figure), score order.

    Beats are notated beat positions; `beats` is the measure's beat count
    (compound meters count dotted beats: 6/8 -> 2), used to interpolate a
    span's onset between performance downbeats.
    """
    spans = []
    for measure, beat, key, figure, time_sig in cbench.parse_rntxt(analysis_path):
        spans.append(
            {
                "measure": measure,
                "beat": beat,
                "key": wir.key_to_wire(key),
                "figure": figure,
                "beats": beat_count(time_sig),
            }
        )
    spans.sort(key=lambda s: (s["measure"], s["beat"]))
    return spans


def beat_count(time_sig: str) -> int:
    # When in Rome writes signatures like "slow 3/8" or "6/8"; unparseable
    # ones fall back to 4 (only the within-measure interpolation cares).
    match = re.search(r"(\d+)\s*/\s*\d+", time_sig)
    if not match:
        return 4
    numerator = int(match.group(1))
    if numerator > 3 and numerator % 3 == 0:
        return numerator // 3
    return numerator


def arm_extras(args: argparse.Namespace, timeline: list[dict], snapshots) -> dict:
    """replay_batch.dart request fields for the selected attribution arm."""
    extras: dict = {}
    if args.arm in ("B", "BC"):
        switches: list[dict] = []
        for entry in timeline:
            if not switches or switches[-1]["context"] != entry["key"]:
                switches.append(
                    {"timestampMs": entry["timestampMs"], "context": entry["key"]}
                )
        extras["contextTimeline"] = switches
    if args.arm in ("C", "BC"):
        boundaries: list[int] = []
        for entry in timeline:
            if not boundaries or entry["timestampMs"] > boundaries[-1]:
                boundaries.append(entry["timestampMs"])
        end = snapshots[-1]["timestampMs"] if snapshots else 0
        if boundaries and end > boundaries[-1]:
            boundaries.append(end)
        extras["spanBoundaries"] = boundaries
        extras["spanNoteThreshold"] = args.span_note_threshold
    if args.pedal_demotion != "off":
        extras["pedalDemotion"] = args.pedal_demotion
    if args.arm == "A1":
        extras["liveKeyHalfLifeSeconds"] = LIVE_KEY_HALF_LIFE_SECONDS[args.behavior]
    if args.emit_frames:
        extras["emitFrames"] = True
    return extras


def calibrate_offset(
    spans: list[dict],
    downbeats: list[float],
    raw_measures: list[int],
    snapshots: list[dict],
    anchor: int,
) -> tuple[int, dict[int, float]]:
    """Pick the downbeat-map measure offset by analyst-chord agreement.

    Scores each candidate offset within 2 of the last-measure anchor by the
    time-weighted overlap between sounding pitch classes and the analyst
    chord active at each snapshot. Correct alignments peak sharply (roughly
    0.7-0.9 against 0.4-0.6 off-peak, see wir_alignment_probe.py), so the
    argmax is effectively deterministic; verify regenerated sets with the
    probe regardless.
    """
    if not spans or not snapshots:
        return anchor, {}
    curve = {}
    for delta in range(-2, 3):
        candidate = anchor + delta
        timeline = harmony_timeline(
            spans, downbeats, [m + candidate for m in raw_measures]
        )
        curve[candidate] = snapshot_overlap(snapshots, timeline)
    return max(curve, key=lambda c: curve[c]), curve


def snapshot_overlap(snapshots: list[dict], timeline: list[dict]) -> float:
    """Time-weighted mean overlap of sounding pcs with the analyst chord."""
    times = [entry["timestampMs"] for entry in timeline]
    weighted = total = 0.0
    for current, following in pairwise(snapshots):
        pcs = {note % 12 for note in current["midiNotes"]}
        weight = following["timestampMs"] - current["timestampMs"]
        if not pcs or weight <= 0:
            continue
        at = bisect.bisect_right(times, current["timestampMs"]) - 1
        entry = timeline[max(at, 0)]
        expected, _ = analyst_chord(entry["figure"], entry["key"])
        if expected is None:
            continue
        weighted += weight * len(pcs & expected) / len(pcs)
        total += weight
    return weighted / total if total else 0.0


def harmony_timeline(
    spans: list[dict], downbeats: list[float], measures: list[int]
) -> list[dict]:
    """Project analyst chord spans into performance milliseconds.

    Each performance downbeat anchors the span active at its measure's start
    (carried from earlier measures when a chord sustains across the barline,
    which also keeps lookups correct across performed repeats), and spans
    starting mid-measure are placed by linear beat interpolation between
    downbeats. Entries keep the span's own (measure, beat) provenance.
    """
    if not spans:
        return []
    positions = [(s["measure"], s["beat"]) for s in spans]
    timeline = []
    interval_ms = 2000.0
    for index, downbeat in enumerate(downbeats):
        measure = measures[index]
        start_ms = downbeat * 1000
        if index + 1 < len(downbeats):
            interval_ms = downbeats[index + 1] * 1000 - start_ms
        at = bisect.bisect_right(positions, (measure, 1)) - 1
        active = spans[max(at, 0)]
        timeline.append(_timeline_entry(active, round(start_ms), interval_ms))
        lo = bisect.bisect_right(positions, (measure, 1))
        hi = bisect.bisect_right(positions, (measure, float("inf")))
        for span in spans[lo:hi]:
            fraction = min(max((span["beat"] - 1) / span["beats"], 0.0), 1.0)
            timeline.append(
                _timeline_entry(
                    span, round(start_ms + fraction * interval_ms), interval_ms
                )
            )
    return timeline


def _timeline_entry(span: dict, timestamp_ms: int, interval_ms: float) -> dict:
    return {
        "timestampMs": timestamp_ms,
        "measure": span["measure"],
        "beat": span["beat"],
        "beatMs": round(interval_ms / span["beats"]),
        "key": span["key"],
        "figure": span["figure"],
    }


def key_at(keys: dict[int, str], measure: int) -> str | None:
    if not keys:
        return None
    candidates = [m for m in keys if m <= measure]
    if not candidates:
        return keys[min(keys)]
    return keys[max(candidates)]


if __name__ == "__main__":
    raise SystemExit(main())

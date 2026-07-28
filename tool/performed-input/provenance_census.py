#!/usr/bin/env python3
"""Split added-tone disagreement time by note provenance (held vs pedal).

Log 2026-07-27-08 reframed the ornament-absorption bucket as possibly
melody-over-accompaniment rather than pedal blur. This census decides: for
every A0 disagreement segment where the full analyst chord was sounding plus
extra tones (the added-tone family: appSuperset and added-seventh rootHit
cases), it classifies each extra pitch class by how its notes were sounding
during the segment, straight from the raw ASAP MIDI:

  heldDwell      physically held for at least minDwellMs or half the segment
                 (a melodic or voiced tone; no timing filter reaches it)
  transientPress the key press itself was shorter than transientMs, with the
                 tone persisting only through the sustain pedal
  pedalCarry     pressed before the segment and sounding in it only through
                 the pedal (earlier harmony carried across the change)

Weights are segment time split evenly across that segment's extra pitch
classes. Reads build/ fixtures and the license-gated ASAP checkout; writes a
JSON report.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import mido
from identity_score import REPO_ROOT, analyst_chord, tiers

REPORT_SCHEMA = "performed-input-provenance-census/1"
PEDAL_CONTROLLER = 64


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2"),
    )
    parser.add_argument(
        "--asap-root",
        type=Path,
        default=Path("build/whatkey-corpora/asap-dataset"),
    )
    parser.add_argument(
        "--split-file",
        type=Path,
        default=REPO_ROOT / "research/performed-input/data/splits/asap-wir-nc-v2.json",
    )
    parser.add_argument(
        "--split", choices=("development", "test"), default="development"
    )
    parser.add_argument("--transient-ms", type=int, default=200)
    parser.add_argument("--min-dwell-ms", type=int, default=400)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def note_segments(midi_path: Path) -> list[dict]:
    """Per note instance: held [onMs, offMs] and pedal tail (offMs, sustEndMs].

    Mirrors asap_extract.sounding_snapshots: a release under the pedal
    sustains the note until the pedal lifts; re-pressing reclaims it.
    """
    segments: list[dict] = []
    open_press: dict[int, dict] = {}
    sustained: dict[int, dict] = {}
    pedal_down = False
    clock = 0.0
    for message in mido.MidiFile(midi_path):
        clock += message.time
        at = round(clock * 1000)
        if message.type == "note_on" and message.velocity > 0:
            if message.note in sustained:
                sustained.pop(message.note)["sustEndMs"] = at
            segment = {
                "note": message.note,
                "onMs": at,
                "offMs": None,
                "sustEndMs": None,
            }
            open_press[message.note] = segment
            segments.append(segment)
        elif message.type in ("note_off", "note_on"):
            segment = open_press.pop(message.note, None)
            if segment is None:
                continue
            segment["offMs"] = at
            if pedal_down:
                sustained[message.note] = segment
        elif message.type == "control_change" and message.control == PEDAL_CONTROLLER:
            now_down = message.value >= 64
            if pedal_down and not now_down:
                for segment in sustained.values():
                    segment["sustEndMs"] = at
                sustained.clear()
            pedal_down = now_down
    for segment in segments:
        if segment["offMs"] is None:
            segment["offMs"] = round(clock * 1000)
    return segments


def overlap(a_lo: int, a_hi: int, b_lo: int, b_hi: int) -> int:
    return max(0, min(a_hi, b_hi) - max(a_lo, b_lo))


def classify_pc(
    segments: list[dict],
    pc: int,
    lo: int,
    hi: int,
    transient_ms: int,
    min_dwell_ms: int,
) -> str | None:
    held_ms = sust_ms = 0
    shortest_press = None
    for segment in segments:
        if segment["note"] % 12 != pc:
            continue
        held = overlap(segment["onMs"], segment["offMs"], lo, hi)
        tail = (
            overlap(segment["offMs"], segment["sustEndMs"], lo, hi)
            if segment["sustEndMs"] is not None
            else 0
        )
        if held + tail <= 0:
            continue
        held_ms += held
        sust_ms += tail
        press = segment["offMs"] - segment["onMs"]
        if shortest_press is None or press < shortest_press:
            shortest_press = press
    if held_ms + sust_ms <= 0:
        return None
    if held_ms >= min_dwell_ms or held_ms >= (hi - lo) / 2:
        return "heldDwell"
    if held_ms == 0:
        return "pedalCarry"
    if shortest_press is not None and shortest_press < transient_ms:
        return "transientPress"
    return "heldDwell"


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())

    shares: dict[str, float] = defaultdict(float)
    added_time = displayed = disagree = 0.0
    for entry in split["splits"][args.split]:
        name = entry["id"].split("/")[-1]
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        segments = note_segments(args.asap_root / f"{fixture['title']}.mid")
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
                exact = tiers(candidate, chord)[0]
                tolerance = span.get("beatMs", 0)
                if not exact and index > 0 and lo - span_start < tolerance:
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
                members = chord[0]
                extra = pcs - members
                if not (members <= pcs) or not extra:
                    continue
                added_time += weight
                per_pc = weight / len(extra)
                for pc in sorted(extra):
                    bucket = classify_pc(
                        segments,
                        pc,
                        lo,
                        hi,
                        args.transient_ms,
                        args.min_dwell_ms,
                    )
                    shares[bucket or "untraced"] += per_pc

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "transientMs": args.transient_ms,
        "minDwellMs": args.min_dwell_ms,
        "displayedMs": round(displayed),
        "disagreementMs": round(disagree),
        "addedToneMs": round(added_time),
        "addedToneShareOfDisagreement": added_time / disagree if disagree else 0.0,
        "provenanceShares": {
            bucket: value / added_time for bucket, value in sorted(shares.items())
        }
        if added_time
        else {},
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    print(
        f"{args.split}: added-tone family {added_time / disagree:.3f} of "
        f"disagreement ({added_time / displayed:.3f} of displayed, "
        f"{added_time / 1000:.0f}s)"
    )
    for bucket, value in sorted(shares.items(), key=lambda x: -x[1]):
        print(f"  {bucket:>15}: {value / added_time:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

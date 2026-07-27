#!/usr/bin/env python3
"""Run external (music21) key baselines over WhatKey fixtures.

Rebuilds each fixture's event stream as a music21 score (chords with their
fixture durations) and runs music21's whole-piece key analyzers over it. The
output is a claims file per analyzer that tool/whatkey/harness.dart scores
with --claims-file, so external baselines go through exactly the same metric
code as our detectors.

These baselines are offline and non-abstaining: one global key per piece,
scored as a constant claim on every event. They anchor the accuracy metrics;
the streaming metrics are only compared between our own detectors (see
research/whatkey/PROTOCOL.md, Baselines).
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import music21
from music21 import chord, stream
from music21.analysis import discrete

ANALYZERS = {
    "krumhanslschmuckler": discrete.KrumhanslSchmuckler,
    "krumhanslkessler": discrete.KrumhanslKessler,
    "temperleykostkapayne": discrete.TemperleyKostkaPayne,
    "aardenessen": discrete.AardenEssen,
    "bellmanbudge": discrete.BellmanBudge,
    "simpleweights": discrete.SimpleWeights,
}
DEFAULT_ANALYZERS = ["krumhanslschmuckler", "temperleykostkapayne", "aardenessen"]
PC_NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--split-file", type=Path)
    parser.add_argument("--split", default="development")
    parser.add_argument(
        "--analyzers",
        nargs="+",
        default=DEFAULT_ANALYZERS,
        choices=sorted(ANALYZERS),
    )
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-baselines"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads((args.fixtures / "manifest.json").read_text())
    tempo_bpm = float(manifest.get("tempoBpm", 120.0))

    titles: set[str] | None = None
    if args.split_file:
        split = json.loads(args.split_file.read_text())
        titles = {piece["id"] for piece in split["splits"][args.split]}

    fixtures = []
    for entry in manifest["fixtures"]:
        if titles is not None and entry["title"] not in titles:
            continue
        fixtures.append(json.loads((args.fixtures / entry["file"]).read_text()))
    if not fixtures:
        print("No fixtures selected.", file=sys.stderr)
        return 1

    streams = {fixture["id"]: build_stream(fixture, tempo_bpm) for fixture in fixtures}

    out_dir = args.out / (
        f"{manifest['set']}-{args.split if args.split_file else 'all'}"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    for analyzer_name in args.analyzers:
        analyzer = ANALYZERS[analyzer_name]()
        claims = {}
        for fixture_id, score in streams.items():
            solution = analyzer.getSolution(score)
            claims[fixture_id] = {
                "global": f"{PC_NAMES[solution.tonic.pitchClass]}:"
                f"{'min' if solution.mode == 'minor' else 'maj'}"
            }
        payload = {
            "schema": "whatkey-claims/1",
            "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "command": "python tool/whatkey/external_baseline.py "
            + " ".join(sys.argv[1:]),
            "detector": {
                "name": f"music21-{analyzer_name}",
                "configuration": (
                    f"music21 {music21.__version__}, offline whole-piece, "
                    "constant claim per event, non-abstaining"
                ),
            },
            "fixtures": {
                "set": manifest["set"],
                "split": args.split if args.split_file else None,
            },
            "claims": claims,
        }
        path = out_dir / f"{analyzer_name}.claims.json"
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        print(f"{analyzer_name}: {len(claims)} pieces -> {path}", file=sys.stderr)
    return 0


def build_stream(fixture: dict, tempo_bpm: float) -> stream.Stream:
    beats_per_ms = tempo_bpm / 60000.0
    score = stream.Stream()
    for event in fixture["events"]:
        sounding = chord.Chord(event["midiNotes"])
        sounding.quarterLength = max(event["durationMs"] * beats_per_ms, 0.25)
        score.append(sounding)
    return score


if __name__ == "__main__":
    raise SystemExit(main())

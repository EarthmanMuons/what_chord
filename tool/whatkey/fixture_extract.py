#!/usr/bin/env python3
"""Emit labeled ChordEvent fixtures for the WhatKey harness (research/whatkey/).

Two sources:

  charts        Hand-authored chord charts (JSON) with per-chord key labels.
  when-in-rome  When-in-Rome pieces via the contrapunctus-bench checkout,
                reusing tool/chord/when_in_rome_benchmark.py's extraction.
                RomanText annotations supply the local key and figure labels.

Both run every event through the real engine (tool/whatkey/fixture_batch.dart)
under a fixed, neutral analysis context (default C:maj) so tonality-gated
ranking tie-breakers cannot leak ground-truth key knowledge into the recorded
candidates. Score offsets and chart beats become wall-clock times at a fixed
tempo recorded in the manifest.

When-in-Rome fixtures default to build/ output: verify the sub-corpus license
before committing anything derived from the corpus (see
research/whatkey/data/README.md).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from itertools import pairwise
from pathlib import Path
from statistics import median

from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    DEFAULT_ANALYSIS_PROFILE,
    fixture_hashes,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SCHEMA = "whatkey-fixture/1"
MANIFEST_SCHEMA = "whatkey-manifest/1"
NOTE_NAME = re.compile(r"^([A-Ga-g])([#b]*)(-?\d)$")
NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
VERIFIED_WHEN_IN_ROME_GROUPS = {
    "bach-wtc": {
        "fixtureLicense": "CC BY-SA 4.0",
        "scoreLicense": "CC BY-SA 4.0 (When-in-Rome)",
        "analysisLicense": "CC BY-SA 4.0 (When-in-Rome)",
    },
    "brahms-lieder": {
        "fixtureLicense": "CC BY-SA 4.0",
        "scoreLicense": "CC0 (OpenScore Lieder)",
        "analysisLicense": "CC BY-SA 4.0 (When-in-Rome)",
    },
    "schubert-lieder": {
        "fixtureLicense": "CC BY-SA 4.0",
        "scoreLicense": "CC0 (OpenScore Lieder)",
        "analysisLicense": "CC BY-SA 4.0 (When-in-Rome)",
    },
    "tavern": {
        "fixtureLicense": "CC BY-SA 4.0",
        "scoreLicense": "CC BY-SA 4.0 (TAVERN)",
        "analysisLicense": "CC BY-SA 4.0 (When-in-Rome/TAVERN conversion)",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", default="C:maj", help="Analysis context key")
    parser.add_argument("--tempo", type=float, default=120.0, help="Beats per minute")
    parser.add_argument("--set", dest="set_name", required=True)
    parser.add_argument("--out", type=Path, required=True, help="Fixture output root")
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
        help="Chord-ranking policy used to generate fixture observations.",
    )
    sub = parser.add_subparsers(dest="source", required=True)

    charts = sub.add_parser("charts", help="Hand-authored chord charts")
    charts.add_argument("--charts-dir", type=Path, required=True)

    wir = sub.add_parser("when-in-rome", help="When-in-Rome via contrapunctus-bench")
    wir.add_argument("--bench-root", type=Path, required=True)
    wir.add_argument("--groups", nargs="+")
    wir.add_argument("--max-pieces", type=int, default=0)
    wir.add_argument(
        "--allow-unverified-license",
        action="store_true",
        help=(
            "Allow non-v1 or license-unverified When-in-Rome groups for local "
            "build/ output."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.source == "charts":
        fixtures, source_info = load_charts(args)
    else:
        fixtures, source_info = load_when_in_rome(args)
    if not fixtures:
        print("No fixtures produced.", file=sys.stderr)
        return 1

    attach_candidates(fixtures, args.context, args.analysis_profile)

    set_dir = args.out / args.set_name
    set_dir.mkdir(parents=True, exist_ok=True)
    for fixture in fixtures:
        path = set_dir / f"{fixture['id'].split('/')[-1]}.json"
        path.write_text(json.dumps(fixture, indent=2, sort_keys=True) + "\n")

    files = [f"{fixture['id'].split('/')[-1]}.json" for fixture in fixtures]
    hashes, content_hash = fixture_hashes(set_dir, files)

    manifest = {
        "schema": MANIFEST_SCHEMA,
        "set": args.set_name,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "engineCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/whatkey/fixture_extract.py",
            "arguments": sys.argv[1:],
        },
        "context": args.context,
        "analysisProfile": args.analysis_profile,
        "contentHash": {
            "algorithm": "sha256",
            "canonicalization": CANONICALIZATION,
            "value": content_hash,
        },
        "tempoBpm": args.tempo,
        "source": source_info,
        "fixtures": [
            {
                "id": fixture["id"],
                "title": fixture["title"],
                "file": f"{fixture['id'].split('/')[-1]}.json",
                "sha256": hashes[f"{fixture['id'].split('/')[-1]}.json"],
                "events": len(fixture["events"]),
                "provenance": fixture.get("provenance"),
            }
            for fixture in fixtures
        ],
    }
    (set_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    print(f"{len(fixtures)} fixtures -> {set_dir}", file=sys.stderr)
    return 0


def load_charts(args: argparse.Namespace) -> tuple[list[dict], dict]:
    fixtures = []
    for chart_path in sorted(args.charts_dir.glob("*.json")):
        chart = json.loads(chart_path.read_text())
        tempo = float(chart.get("tempoBpm", args.tempo))
        beat_ms = 60000.0 / tempo
        events = []
        clock_ms = 0.0
        for index, entry in enumerate(chart["chords"]):
            midi_notes = parse_notes(entry["notes"])
            duration_ms = float(entry["beats"]) * beat_ms
            labels = {"localKey": entry.get("localKey")}
            for optional in ("figure", "acceptableKeys"):
                if optional in entry:
                    labels[optional] = entry[optional]
            events.append(event_dict(index, clock_ms, duration_ms, midi_notes, labels))
            clock_ms += duration_ms
        fixtures.append(
            {
                "schema": FIXTURE_SCHEMA,
                "id": f"{args.set_name}/{chart_path.stem}",
                "title": chart.get("title", chart_path.stem),
                "labels": chart.get("labels", {}),
                "events": events,
            }
        )
    source_info = {
        "type": "hand-authored",
        "chartsDir": str(args.charts_dir),
        "license": "Same as repository (original content)",
    }
    return fixtures, source_info


def load_when_in_rome(args: argparse.Namespace) -> tuple[list[dict], dict]:
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "chord"))
    import when_in_rome_benchmark as wir

    bench_root = args.bench_root.resolve()
    sys.path.insert(0, str(bench_root / "harness"))
    import music21_comparison as cbench  # type: ignore[import-not-found]

    manifest = json.loads((bench_root / "corpus/manifest.json").read_text())
    pieces = [
        piece
        for piece in manifest["pieces"]
        if piece["in_common_subset"]
        and (not args.groups or piece["genre"] in args.groups)
    ]
    unverified = sorted(
        {
            piece["genre"]
            for piece in pieces
            if piece["genre"] not in VERIFIED_WHEN_IN_ROME_GROUPS
        }
    )
    if unverified and not args.allow_unverified_license:
        raise RuntimeError(
            "When-in-Rome groups are not license-verified for committed "
            "WhatKey fixtures: "
            + ", ".join(unverified)
            + ". Use --allow-unverified-license only for local build/ output."
        )
    if args.max_pieces:
        pieces = pieces[: args.max_pieces]

    beat_ms = 60000.0 / args.tempo
    fixtures = []
    for piece in pieces:
        rows = wir.load_piece(bench_root, piece, cbench)
        if not rows:
            continue
        offsets = [row["offset"] for row in rows]
        gaps = [b - a for a, b in pairwise(offsets) if b > a]
        fallback = median(gaps) if gaps else 2.0
        events = []
        for index, row in enumerate(rows):
            gap = (
                offsets[index + 1] - offsets[index]
                if index + 1 < len(offsets)
                else fallback
            )
            if gap <= 0:
                gap = fallback
            midi_notes = sorted(int(token) for token in row["midiNotes"].split())
            labels = {"localKey": row["key"], "figure": row["figure"]}
            events.append(
                event_dict(
                    index,
                    row["offset"] * beat_ms,
                    gap * beat_ms,
                    midi_notes,
                    labels,
                )
            )
        fixtures.append(
            {
                "schema": FIXTURE_SCHEMA,
                "id": f"{args.set_name}/{piece['id'].replace('/', '-')}",
                "title": piece["id"],
                "labels": {"group": piece["genre"]},
                "provenance": when_in_rome_provenance(piece),
                "events": events,
            }
        )
        print(f"{piece['id']}: {len(events)} events", file=sys.stderr)

    source_info = {
        "type": "when-in-rome",
        "benchRoot": str(bench_root),
        "benchCommit": git(bench_root, "rev-parse", "HEAD"),
        "corpusCommit": git(bench_root / "corpus/When-in-Rome", "rev-parse", "HEAD"),
        "licenseVerified": not unverified,
        "license": when_in_rome_license_summary(unverified),
        "verifiedGroups": sorted(VERIFIED_WHEN_IN_ROME_GROUPS),
    }
    return fixtures, source_info


def when_in_rome_provenance(piece: dict) -> dict:
    license_info = VERIFIED_WHEN_IN_ROME_GROUPS.get(piece["genre"])
    if license_info is None:
        license_info = {
            "fixtureLicense": "UNVERIFIED",
            "scoreLicense": "UNVERIFIED",
            "analysisLicense": "UNVERIFIED",
        }
    return {
        "sourceCorpus": "When-in-Rome",
        "group": piece["genre"],
        "sourceUrl": piece["source_url"],
        **license_info,
    }


def when_in_rome_license_summary(unverified: list[str]) -> str:
    if unverified:
        return (
            "UNVERIFIED: check the When-in-Rome sub-corpus license before "
            "committing derived fixtures"
        )
    return (
        "Verified for WhatKey when-in-rome-v1 groups. Fixture artifacts are "
        "derived from When-in-Rome analyses and carry CC BY-SA 4.0 provenance; "
        "see research/whatkey/data/provenance/when-in-rome-v1.md."
    )


def event_dict(
    index: int,
    timestamp_ms: float,
    duration_ms: float,
    midi_notes: list[int],
    labels: dict,
) -> dict:
    return {
        "index": index,
        "timestampMs": round(timestamp_ms),
        "durationMs": round(duration_ms),
        "midiNotes": midi_notes,
        "pcMask": sum(1 << pc for pc in {note % 12 for note in midi_notes}),
        "bassPc": min(midi_notes) % 12,
        "noteCount": len(midi_notes),
        "labels": labels,
    }


def attach_candidates(
    fixtures: list[dict], context: str, analysis_profile: str
) -> None:
    requests = []
    for fixture in fixtures:
        for event in fixture["events"]:
            requests.append(
                {
                    "id": f"{fixture['id']}#{event['index']}",
                    "midiNotes": event["midiNotes"],
                    "context": context,
                    "analysisProfile": analysis_profile,
                }
            )
    payload = "".join(json.dumps(request) + "\n" for request in requests)
    process = subprocess.run(
        ["dart", "run", "tool/whatkey/fixture_batch.dart"],
        input=payload,
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr)
    results = {}
    for line in process.stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        result = json.loads(line)
        results[result["id"]] = result["candidates"]
    for fixture in fixtures:
        for event in fixture["events"]:
            event["candidates"] = results[f"{fixture['id']}#{event['index']}"]


def parse_notes(notes: str | list) -> list[int]:
    if isinstance(notes, list):
        return sorted(int(note) for note in notes)
    midi = []
    for token in notes.split():
        match = NOTE_NAME.match(token)
        if not match:
            raise ValueError(f"Unrecognized note token: {token!r}")
        letter, accidentals, octave = match.groups()
        pitch = NOTE_BASE[letter.upper()]
        pitch += accidentals.count("#") - accidentals.count("b")
        midi.append((int(octave) + 1) * 12 + pitch)
    return sorted(midi)


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

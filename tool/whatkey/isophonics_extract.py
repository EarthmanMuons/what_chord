#!/usr/bin/env python3
"""Emit WhatKey fixtures from the Isophonics corpus via ChoCo JAMS.

Isophonics (via ChoCo's normalized `isophonics` partition) provides Harte
chord segments and key annotations with tonic AND mode, including mid-song
key changes: the first corpus with real key labels on non-classical music.
This is the clean-pop corpus that breaks the noise/genre confound from log
entries 13-15: events are synthesized from annotation segments (like the
When in Rome path, no capture segmenter), with voicings rendered from the
Harte chord symbols.

Voicing synthesis: bass note in the octave below middle C (the annotated
bass degree, so inversions are honored), remaining chord pitch classes in
the octave above, mirroring the app's lookup-pad synthesis. Labels: the
key_mode segment active at the event start; plain major/minor keys become
`localKey`, anything else (modal annotations) becomes an unlabeled event.

LICENSE GATE: the Isophonics reference annotations are distributed for
research without an explicit redistribution license, and ChoCo is CC BY-SA
for its own transformations. Derived fixtures stay under build/ pending a
recorded decision; this tool refuses to write inside research/.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    DEFAULT_ANALYSIS_PROFILE,
    fixture_hashes,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SCHEMA = "whatkey-fixture/1"
MANIFEST_SCHEMA = "whatkey-manifest/1"

PC_NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")
NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# Harte shorthand -> intervals above root (semitones). Degree lists in
# parentheses extend or replace these.
SHORTHANDS = {
    "maj": (0, 4, 7),
    "min": (0, 3, 7),
    "dim": (0, 3, 6),
    "aug": (0, 4, 8),
    "maj7": (0, 4, 7, 11),
    "min7": (0, 3, 7, 10),
    "7": (0, 4, 7, 10),
    "dim7": (0, 3, 6, 9),
    "hdim7": (0, 3, 6, 10),
    "minmaj7": (0, 3, 7, 11),
    "maj6": (0, 4, 7, 9),
    "min6": (0, 3, 7, 9),
    "9": (0, 4, 7, 10, 2),
    "maj9": (0, 4, 7, 11, 2),
    "min9": (0, 3, 7, 10, 2),
    "11": (0, 4, 7, 10, 2, 5),
    "13": (0, 4, 7, 10, 2, 9),
    "sus2": (0, 2, 7),
    "sus4": (0, 5, 7),
    "": (0, 4, 7),
}

DEGREE_RE = re.compile(r"^(\*?)([#b]*)(\d+)$")
DEGREE_SEMITONES = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--choco-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="isophonics-nc-v1")
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-fixtures"))
    parser.add_argument("--context", default="C:maj")
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
        help="Chord-ranking policy used to generate fixture observations.",
    )
    parser.add_argument("--max-tracks", type=int, default=0, help="0 means all.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if (REPO_ROOT / "research") in args.out.resolve().parents:
        raise SystemExit(
            "Isophonics annotations lack an explicit redistribution license: "
            "derived fixtures are local-only and must not be written under "
            "research/."
        )

    partition = args.choco_root / "partitions/isophonics/choco"
    meta = {row["id"]: row for row in csv.DictReader((partition / "meta.csv").open())}

    fixtures = []
    skipped = 0
    track_ids = sorted(meta, key=lambda t: int(t.split("_")[1]))
    if args.max_tracks:
        track_ids = track_ids[: args.max_tracks]
    for track_id in track_ids:
        jams_path = partition / "jams" / f"{track_id}.jams"
        if not jams_path.exists():
            skipped += 1
            continue
        jams = json.loads(jams_path.read_text())
        events, key_segments = extract_events(jams)
        if not events or not key_segments:
            skipped += 1
            continue
        row = meta[track_id]
        fixtures.append(
            {
                "schema": FIXTURE_SCHEMA,
                "id": f"{args.set_name}/{track_id}",
                "title": f"{row['file_performer']}/{row['file_release']}/"
                f"{row['file_title']}",
                "labels": {"source": "isophonics", "performer": row["file_performer"]},
                "events": events,
            }
        )
    print(
        f"{len(fixtures)} tracks ({skipped} skipped for missing chords or keys)",
        file=sys.stderr,
    )

    attach_candidates(fixtures, args.context, args.analysis_profile)

    set_dir = args.out / args.set_name
    set_dir.mkdir(parents=True, exist_ok=True)
    for fixture in fixtures:
        name = fixture["id"].split("/")[-1]
        (set_dir / f"{name}.json").write_text(
            json.dumps(fixture, indent=2, sort_keys=True) + "\n"
        )
    files = [f"{fixture['id'].split('/')[-1]}.json" for fixture in fixtures]
    hashes, content_hash = fixture_hashes(set_dir, files)
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "set": args.set_name,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": "python tool/whatkey/isophonics_extract.py "
        + " ".join(sys.argv[1:]),
        "engineCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/whatkey/isophonics_extract.py",
            "arguments": sys.argv[1:],
        },
        "context": args.context,
        "analysisProfile": args.analysis_profile,
        "contentHash": {
            "algorithm": "sha256",
            "canonicalization": CANONICALIZATION,
            "value": content_hash,
        },
        "source": {
            "type": "isophonics-choco",
            "chocoRoot": str(args.choco_root),
            "chocoCommit": git(args.choco_root, "rev-parse", "HEAD"),
            "license": (
                "GATED: Isophonics reference annotations are research-"
                "distributed without an explicit redistribution license; "
                "local uncommitted experiments only "
                "(research/whatkey/data/NOTICE.md)"
            ),
        },
        "fixtures": [
            {
                "id": fixture["id"],
                "title": fixture["title"],
                "file": f"{fixture['id'].split('/')[-1]}.json",
                "sha256": hashes[f"{fixture['id'].split('/')[-1]}.json"],
                "events": len(fixture["events"]),
            }
            for fixture in fixtures
        ],
    }
    (set_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    print(f"{len(fixtures)} fixtures -> {set_dir}", file=sys.stderr)
    return 0


def extract_events(jams: dict) -> tuple[list[dict], list[tuple[float, str]]]:
    chords = []
    keys: list[tuple[float, str]] = []
    for annotation in jams["annotations"]:
        if annotation["namespace"] == "chord":
            chords = annotation["data"]
        elif annotation["namespace"] == "key_mode":
            keys = [(d["time"], d["value"]) for d in annotation["data"]]
    if not chords or not keys:
        return [], []

    events = []
    index = 0
    for datum in chords:
        midi_notes = harte_to_midi(datum["value"])
        if midi_notes is None or len(midi_notes) < 3:
            continue
        start_ms = round(datum["time"] * 1000)
        events.append(
            {
                "index": index,
                "timestampMs": start_ms,
                "durationMs": max(round(datum["duration"] * 1000), 1),
                "midiNotes": midi_notes,
                "pcMask": sum(1 << (n % 12) for n in set(midi_notes)),
                "bassPc": min(midi_notes) % 12,
                "noteCount": len(midi_notes),
                "labels": key_label_at(keys, datum["time"]),
            }
        )
        index += 1
    return events, keys


def key_label_at(keys: list[tuple[float, str]], time_s: float) -> dict:
    active = keys[0][1]
    for at, value in keys:
        if at <= time_s:
            active = value
    parsed = parse_key(active)
    if parsed is None:
        return {"localKey": None, "annotatedKey": active}
    return {"localKey": parsed}


def parse_key(value: str) -> str | None:
    """Isophonics key_mode: 'A', 'A:minor', 'Bb:major'; modal values pass
    through as unlabeled."""
    parts = value.split(":")
    tonic = note_pc(parts[0])
    if tonic is None:
        return None
    mode = parts[1] if len(parts) > 1 else "major"
    if mode == "major":
        return f"{PC_NAMES[tonic]}:maj"
    if mode == "minor":
        return f"{PC_NAMES[tonic]}:min"
    return None


def note_pc(name: str) -> int | None:
    if not name or name[0].upper() not in NOTE_PC:
        return None
    pc = NOTE_PC[name[0].upper()]
    for accidental in name[1:]:
        if accidental == "#":
            pc += 1
        elif accidental == "b":
            pc -= 1
        else:
            return None
    return pc % 12


def harte_to_midi(label: str) -> list[int] | None:
    """Harte chord label to a synthesized voicing: annotated bass in the
    octave below middle C, chord tones above. Returns None for N/X."""
    if label in ("N", "X"):
        return None
    body, _, bass_degree = label.partition("/")
    root_part, _, quality = body.partition(":")
    root = note_pc(root_part)
    if root is None:
        return None

    shorthand, _, degree_list = quality.partition("(")
    intervals = set(SHORTHANDS.get(shorthand, SHORTHANDS["maj"]))
    if degree_list:
        for token in degree_list.rstrip(")").split(","):
            parsed = parse_degree(token.strip())
            if parsed is None:
                continue
            removed, semitones = parsed
            if removed:
                intervals.discard(semitones)
            else:
                intervals.add(semitones)
    if not intervals:
        return None

    bass_interval = 0
    if bass_degree:
        parsed = parse_degree(bass_degree.strip())
        if parsed is not None and not parsed[0]:
            bass_interval = parsed[1]
            intervals.add(bass_interval)

    bass_pc = (root + bass_interval) % 12
    bass_midi = 48 + ((bass_pc - 48) % 12)  # 48..59
    uppers = sorted(
        60 + ((root + interval) % 12)
        for interval in intervals
        if (root + interval) % 12 != bass_pc
    )
    return [bass_midi, *uppers]


def parse_degree(token: str) -> tuple[bool, int] | None:
    match = DEGREE_RE.match(token)
    if not match:
        return None
    removed, accidentals, degree = match.groups()
    base = DEGREE_SEMITONES.get(((int(degree) - 1) % 7) + 1)
    if base is None:
        return None
    offset = accidentals.count("#") - accidentals.count("b")
    return bool(removed), (base + offset) % 12


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
        kept = []
        for event in fixture["events"]:
            candidates = results.get(f"{fixture['id']}#{event['index']}")
            if not candidates:
                continue
            event["candidates"] = candidates
            kept.append(event)
        for new_index, event in enumerate(kept):
            event["index"] = new_index
        fixture["events"] = kept


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

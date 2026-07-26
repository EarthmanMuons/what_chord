#!/usr/bin/env python3
"""Emit the jazz-comping fixture set from the Weimar Jazz Database via ChoCo.

WJazzD (ChoCo's `weimar` partition, namespace `chord_weimar`) provides the
underlying chord changes of 456 transcribed jazz solos with per-solo keys:
the first corpus for the ensemble-tiebreak initiative whose vocabulary is
the genre the ensemble mode is for (dominant/minor/major sevenths and their
colors throughout, against Isophonics' pop triads).

Emits two artifacts per run:

- a `whatkey-fixture/1` set (voicings synthesized like the Isophonics
  extractor: root or slash bass in the octave below middle C, chord tones
  above; candidates attached under a fixed neutral context so ground truth
  never leaks into rankings), and
- a `chord-context-labels/1` sidecar with the expected identity per event,
  parsed from the WJazzD symbol itself (the corpus ground truth), aligned
  to the fixture events after candidate attachment.

License: ChoCo redistributes the weimar partition under CC BY 4.0; derived
fixtures stay under build/ by convention, with attribution recorded in the
manifest.
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

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tool/whatkey"))

from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    fixture_hashes,
)

FIXTURE_SCHEMA = "whatkey-fixture/1"
MANIFEST_SCHEMA = "whatkey-manifest/1"
LABELS_SCHEMA = "chord-context-labels/1"

PC_NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")
NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
ROOT_RE = re.compile(r"^([A-G][#b]*)(.*)$")
TENSION_RE = re.compile(r"(9|11|13)([#b]?)")
TENSION_SEMITONES = {"9": 2, "9b": 1, "9#": 3, "11": 5, "11#": 6, "13": 9, "13b": 8}

# WJazzD quality grammar: triad prefix ('' major, '-' minor, '+' aug,
# 'o' dim, 'sus' suspension), optional seventh/sixth ('7' minor seventh,
# 'j7' major seventh, '6' sixth), then tension digits with TRAILING
# accidentals ('9b' is a flat nine). Specials: 'm7b5', 'o7', '69', 'alt'.
TRIADS = {
    "": ("major", (0, 4, 7)),
    "-": ("minor", (0, 3, 7)),
    "+": ("augmented", (0, 4, 8)),
    "o": ("diminished", (0, 3, 6)),
    "sus": ("sus4", (0, 5, 7)),
}
SEVENTH_QUALITY = {
    ("", "7"): "dominant7",
    ("-", "7"): "minor7",
    ("+", "7"): "dominant7Sharp5",
    ("sus", "7"): "dominant7sus4",
    ("", "j7"): "major7",
    ("-", "j7"): "minorMajor7",
    ("+", "j7"): "major7Sharp5",
    ("", "6"): "major6",
    ("-", "6"): "minor6",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--choco-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="weimar-comping-v1")
    parser.add_argument("--out", type=Path, default=Path("build/chord-context"))
    parser.add_argument("--context", default="C:maj")
    parser.add_argument(
        "--analysis-profile", choices=ANALYSIS_PROFILES, default="current"
    )
    parser.add_argument("--max-solos", type=int, default=0, help="0 means all.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    partition = args.choco_root / "partitions/weimar/choco"
    meta = {row["id"]: row for row in csv.DictReader((partition / "meta.csv").open())}

    fixtures = []
    labels_by_id: dict[str, list[dict]] = {}
    skipped = 0
    solo_ids = sorted(meta, key=lambda t: int(t.split("_")[1]))
    if args.max_solos:
        solo_ids = solo_ids[: args.max_solos]
    for solo_id in solo_ids:
        jams_path = partition / "jams" / f"{solo_id}.jams"
        if not jams_path.exists():
            skipped += 1
            continue
        jams = json.loads(jams_path.read_text())
        events = extract_events(jams)
        if not events:
            skipped += 1
            continue
        row = meta[solo_id]
        fixtures.append(
            {
                "schema": FIXTURE_SCHEMA,
                "id": f"{args.set_name}/{solo_id}",
                "title": fixture_title(row),
                "labels": {
                    "source": "weimar-jazz-database",
                    "performer": row["performers"],
                    "tune": row["title"],
                },
                "events": events,
            }
        )
    print(f"{len(fixtures)} solos ({skipped} skipped)", file=sys.stderr)

    attach_candidates(fixtures, args.context, args.analysis_profile)

    # Labels align to the events that survived candidate attachment; the
    # expected identity rides on each event dict until this point.
    category_counts: dict[str, int] = {}
    for fixture in fixtures:
        entries = []
        for event in fixture["events"]:
            expected = event.pop("_expected")
            category = event.pop("_category")
            entries.append(
                {
                    "index": event["index"],
                    "category": category,
                    "expected": expected,
                    "localKey": event["labels"]["localKey"],
                }
            )
            category_counts[category] = category_counts.get(category, 0) + 1
        labels_by_id[fixture["id"]] = entries
    print(f"label categories: {category_counts}", file=sys.stderr)

    set_dir = args.out / "fixtures" / args.set_name
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
        "command": "python tool/chord-context/weimar_extract.py "
        + " ".join(sys.argv[1:]),
        "engineCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/chord-context/weimar_extract.py",
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
            "type": "weimar-choco",
            "chocoRoot": str(args.choco_root),
            "chocoCommit": git(args.choco_root, "rev-parse", "HEAD"),
            "license": (
                "CC BY 4.0 via ChoCo (weimar partition is not among ChoCo's "
                "NC-SA carve-outs); attribution: Weimar Jazz Database "
                "(Jazzomat Research Project) via ChoCo"
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

    labels_dir = args.out / "labels"
    labels_dir.mkdir(parents=True, exist_ok=True)
    labels_doc = {
        "schema": LABELS_SCHEMA,
        "set": args.set_name,
        "fixtures": len(fixtures),
        "pieces": labels_by_id,
    }
    labels_path = labels_dir / f"{args.set_name}.labels.json"
    labels_path.write_text(json.dumps(labels_doc, indent=1, sort_keys=True) + "\n")
    print(f"{len(fixtures)} fixtures -> {set_dir}", file=sys.stderr)
    print(f"labels -> {labels_path}", file=sys.stderr)
    return 0


def fixture_title(row: dict) -> str:
    return f"{row['performers']}/{row['title']} ({row['id']})"


def extract_events(jams: dict) -> list[dict]:
    chords = []
    keys: list[tuple[float, str]] = []
    for annotation in jams["annotations"]:
        if annotation["namespace"] == "chord_weimar":
            chords = annotation["data"]
        elif annotation["namespace"] == "key_mode":
            keys = [(d["time"], d["value"]) for d in annotation["data"]]
    if not chords:
        return []

    events = []
    index = 0
    for datum in chords:
        parsed = parse_weimar_chord(datum["value"])
        if parsed is None:
            continue
        root, quality, intervals, bass_pc = parsed
        midi_notes = synthesize(root, intervals, bass_pc)
        if len(midi_notes) < 3:
            continue
        local_key = key_label_at(keys, datum["time"])
        category = "ok" if local_key is not None else "unlabeled-key"
        events.append(
            {
                "index": index,
                "timestampMs": round(datum["time"] * 1000),
                "durationMs": max(round(datum["duration"] * 1000), 1),
                "midiNotes": midi_notes,
                "pcMask": sum(1 << (n % 12) for n in set(midi_notes)),
                "bassPc": min(midi_notes) % 12,
                "noteCount": len(midi_notes),
                "labels": {"localKey": local_key},
                "_expected": {
                    "rootPc": root,
                    "quality": quality,
                    "bassPc": bass_pc,
                },
                "_category": category,
            }
        )
        index += 1
    return events


def key_label_at(keys: list[tuple[float, str]], time_s: float) -> str | None:
    """WJazzD key_mode: 'Bb-maj', 'F-min', bare tonics and modal values
    ('F-dor', 'Bb-blues', 'D-chrom') stay unlabeled."""
    if not keys:
        return None
    active = keys[0][1]
    for at, value in keys:
        if at <= time_s:
            active = value
    tonic_part, _, mode = active.partition("-")
    tonic = note_pc(tonic_part)
    if tonic is None or mode not in ("maj", "min"):
        return None
    return f"{PC_NAMES[tonic]}:{mode}"


def parse_weimar_chord(
    value: str,
) -> tuple[int, str, frozenset[int], int] | None:
    """WJazzD symbol to (rootPc, ChordQuality name, intervals, bassPc)."""
    if value in ("NC", "N.C.", "N", ""):
        return None
    body, _, bass_part = value.partition("/")
    match = ROOT_RE.match(body)
    if not match:
        return None
    root = note_pc(match.group(1))
    if root is None:
        return None
    suffix = match.group(2)

    special = {
        "m7b5": ("halfDiminished7", {0, 3, 6, 10}),
        "o7": ("diminished7", {0, 3, 6, 9}),
        "69": ("major6", {0, 4, 7, 9, 2}),
        "-69": ("minor6", {0, 3, 7, 9, 2}),
    }
    quality: str | None = None
    intervals: set[int] = set()
    if suffix in special:
        quality, base = special[suffix]
        intervals = set(base)
    else:
        triad = ""
        for prefix in ("sus", "-", "+", "o"):
            if suffix.startswith(prefix):
                triad = prefix
                suffix = suffix[len(prefix) :]
                break
        seventh = ""
        for marker in ("j7", "7", "6"):
            if suffix.startswith(marker):
                seventh = marker
                suffix = suffix[len(marker) :]
                break
        if triad not in TRIADS:
            return None
        base_quality, base_intervals = TRIADS[triad]
        intervals = set(base_intervals)
        if seventh:
            quality = SEVENTH_QUALITY.get((triad, seventh))
            if quality is None:
                return None
            intervals.add({"7": 10, "j7": 11, "6": 9}[seventh])
        else:
            quality = base_quality
        if suffix == "alt":
            intervals.update({1, 3, 8})
            suffix = ""
        for tension, accidental in TENSION_RE.findall(suffix):
            semitones = TENSION_SEMITONES.get(tension + accidental)
            if semitones is not None:
                intervals.add(semitones)
        leftover = TENSION_RE.sub("", suffix)
        if leftover:
            return None

    bass_pc = root
    if bass_part:
        parsed_bass = note_pc(bass_part)
        if parsed_bass is not None:
            bass_pc = parsed_bass
    return root, quality, frozenset((root + i) % 12 for i in intervals), bass_pc


def synthesize(root: int, pcs: frozenset[int], bass_pc: int) -> list[int]:
    """Bass in the octave below middle C, remaining tones above, mirroring
    the Isophonics extractor."""
    bass_midi = 48 + (bass_pc % 12)
    uppers = sorted(60 + pc for pc in pcs if pc != bass_pc % 12)
    return [bass_midi, *uppers]


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

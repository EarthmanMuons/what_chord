#!/usr/bin/env python3
"""Emit WhatKey fixtures from ASAP performed-piano MIDI (research/whatkey/).

Parses ASAP performance MIDI (mido) into pedal-aware sounding-set snapshots
and replays them through the real Phase 1 capture path
(tool/whatkey/replay_batch.dart: the app's analyzer plus the actual
ChordEventSegmenter), so fixture events reflect genuine capture behavior on
performed input, finger rolls and pedal blur included.

Labels come from ASAP's key-signature annotations, which by design do not
distinguish a major key from its relative minor. Events therefore carry
`localKey: null` with `acceptableKeys` = [signature major, relative minor]:
the ambiguity metrics (claims within the acceptable pair, abstention), plus
coverage, stability, and time-to-first-claim, are the meaningful scores on
this corpus; exact local-key accuracy is not available from these labels.

LICENSE GATE: ASAP is CC BY-NC-SA 4.0 (NonCommercial). Fixture sets derived
from it are for local, uncommitted experiments only; this tool refuses to
write inside research/. See research/whatkey/data/NOTICE.md.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import mido
from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    DEFAULT_ANALYSIS_PROFILE,
    fixture_hashes,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SCHEMA = "whatkey-fixture/1"
MANIFEST_SCHEMA = "whatkey-manifest/1"
PEDAL_CONTROLLER = 64


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asap-root", type=Path, required=True)
    parser.add_argument("--set", dest="set_name", default="asap-nc-v1")
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-fixtures"))
    parser.add_argument("--context", default="C:maj")
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
        help="Chord-ranking policy used before capture segmentation.",
    )
    parser.add_argument(
        "--max-performances",
        type=int,
        default=24,
        help="Cap on performances (one per piece folder, spread by composer).",
    )
    parser.add_argument("--composers", nargs="+", help="Only these composers.")
    parser.add_argument(
        "--segmenter-min-ms",
        type=int,
        default=200,
        help="Capture segmenter minimum/debounce duration (app default 200).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out_resolved = args.out.resolve()
    if (REPO_ROOT / "research") in out_resolved.parents:
        raise SystemExit(
            "ASAP is CC BY-NC-SA 4.0 (NonCommercial): derived fixtures are "
            "local-only and must not be written under research/."
        )

    annotations = json.loads((args.asap_root / "asap_annotations.json").read_text())
    performances = select_performances(annotations, args)
    print(f"Selected {len(performances)} performances", file=sys.stderr)

    pieces = []
    for perf_path, key_signatures in performances:
        snapshots = sounding_snapshots(args.asap_root / perf_path)
        pieces.append(
            {
                "id": f"{args.set_name}/{perf_path.replace('/', '-').removesuffix('.mid')}",
                "title": perf_path.removesuffix(".mid"),
                "snapshots": snapshots,
                "keySignatures": key_signatures,
            }
        )
        print(f"{perf_path}: {len(snapshots)} snapshots", file=sys.stderr)

    replayed = replay(
        pieces, args.context, args.segmenter_min_ms, args.analysis_profile
    )

    set_dir = args.out / args.set_name
    set_dir.mkdir(parents=True, exist_ok=True)
    fixtures_meta = []
    for piece in pieces:
        events = replayed[piece["id"]]
        for event in events:
            event["labels"] = labels_at(piece["keySignatures"], event["timestampMs"])
        fixture = {
            "schema": FIXTURE_SCHEMA,
            "id": piece["id"],
            "title": piece["title"],
            "labels": {"source": "asap", "modeUnknown": True},
            "events": events,
        }
        name = piece["id"].split("/")[-1]
        (set_dir / f"{name}.json").write_text(
            json.dumps(fixture, indent=2, sort_keys=True) + "\n"
        )
        fixtures_meta.append(
            {
                "id": piece["id"],
                "title": piece["title"],
                "file": f"{name}.json",
                "events": len(events),
            }
        )

    files = [entry["file"] for entry in fixtures_meta]
    hashes, content_hash = fixture_hashes(set_dir, files)
    for entry in fixtures_meta:
        entry["sha256"] = hashes[entry["file"]]

    manifest = {
        "schema": MANIFEST_SCHEMA,
        "set": args.set_name,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": "python tool/whatkey/asap_extract.py " + " ".join(sys.argv[1:]),
        "engineCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/whatkey/asap_extract.py",
            "arguments": sys.argv[1:],
        },
        "context": args.context,
        "analysisProfile": args.analysis_profile,
        "contentHash": {
            "algorithm": "sha256",
            "canonicalization": CANONICALIZATION,
            "value": content_hash,
        },
        "segmenterMinMs": args.segmenter_min_ms,
        "source": {
            "type": "asap",
            "asapRoot": str(args.asap_root),
            "asapCommit": git(args.asap_root, "rev-parse", "HEAD"),
            "license": (
                "NONCOMMERCIAL-GATED: ASAP is CC BY-NC-SA 4.0; local "
                "uncommitted experiments only (research/whatkey/data/NOTICE.md)"
            ),
            "captureReplay": "tool/whatkey/replay_batch.dart",
        },
        "fixtures": fixtures_meta,
    }
    (set_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    print(f"{len(fixtures_meta)} fixtures -> {set_dir}", file=sys.stderr)
    return 0


def select_performances(
    annotations: dict, args: argparse.Namespace
) -> list[tuple[str, dict]]:
    """One performance per piece folder, round-robin across composers."""
    by_composer: dict[str, dict[str, tuple[str, dict]]] = {}
    for perf_path in sorted(annotations):
        composer = perf_path.split("/")[0]
        if args.composers and composer not in args.composers:
            continue
        folder = "/".join(perf_path.split("/")[:-1])
        by_composer.setdefault(composer, {}).setdefault(
            folder, (perf_path, annotations[perf_path]["perf_key_signatures"])
        )

    selected: list[tuple[str, dict]] = []
    queues = {c: list(folders.values()) for c, folders in sorted(by_composer.items())}
    while queues and len(selected) < args.max_performances:
        for composer in sorted(queues):
            if len(selected) >= args.max_performances:
                break
            queue = queues[composer]
            selected.append(queue.pop(0))
            if not queue:
                del queues[composer]
    return selected


def sounding_snapshots(midi_path: Path) -> list[dict]:
    """Pedal-aware sounding sets at every change, timestamped in ms."""
    held: set[int] = set()
    sustained: set[int] = set()
    pedal_down = False
    snapshots: list[dict] = []
    last_emitted: frozenset[int] = frozenset()
    clock = 0.0

    def emit(at_ms: int) -> None:
        nonlocal last_emitted
        sounding = frozenset(held | sustained)
        if sounding == last_emitted:
            return
        if snapshots and snapshots[-1]["timestampMs"] == at_ms:
            snapshots[-1]["midiNotes"] = sorted(sounding)
        else:
            snapshots.append({"timestampMs": at_ms, "midiNotes": sorted(sounding)})
        last_emitted = sounding

    for message in mido.MidiFile(midi_path):
        clock += message.time
        at_ms = round(clock * 1000)
        if message.type == "note_on" and message.velocity > 0:
            held.add(message.note)
            sustained.discard(message.note)
        elif message.type in ("note_off", "note_on"):
            held.discard(message.note)
            if pedal_down:
                sustained.add(message.note)
        elif message.type == "control_change" and message.control == PEDAL_CONTROLLER:
            now_down = message.value >= 64
            if pedal_down and not now_down:
                sustained.clear()
            pedal_down = now_down
        else:
            continue
        emit(at_ms)
    return snapshots


def replay(
    pieces: list[dict],
    context: str,
    segmenter_min_ms: int,
    analysis_profile: str = DEFAULT_ANALYSIS_PROFILE,
) -> dict[str, list[dict]]:
    payload = "".join(
        json.dumps(
            {
                "id": p["id"],
                "context": context,
                "segmenterMinMs": segmenter_min_ms,
                "analysisProfile": analysis_profile,
                "snapshots": p["snapshots"],
            }
        )
        + "\n"
        for p in pieces
    )
    process = subprocess.run(
        ["dart", "run", "tool/whatkey/replay_batch.dart"],
        input=payload,
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr)
    out: dict[str, list[dict]] = {}
    for line in process.stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        result = json.loads(line)
        out[result["id"]] = result["events"]
    return out


PC_NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")


def labels_at(key_signatures: dict, timestamp_ms: int) -> dict:
    """Mode-unknown labels from the signature active at the event start."""
    active = None
    for time_s in sorted(key_signatures, key=float):
        if float(time_s) * 1000 <= timestamp_ms or active is None:
            active = key_signatures[time_s]
    tonic_pc, sharps = int(active[0]), int(active[1])
    relative_minor_pc = (tonic_pc + 9) % 12
    return {
        "localKey": None,
        "acceptableKeys": [
            f"{PC_NAMES[tonic_pc]}:maj",
            f"{PC_NAMES[relative_minor_pc]}:min",
        ],
        "keySignatureSharps": sharps,
    }


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())

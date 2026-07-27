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

REPO_ROOT = asap_x.REPO_ROOT

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
    parser.add_argument("--set", dest="set_name", default="asap-wir-nc-v1")
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-fixtures"))
    parser.add_argument("--context", default="C:maj")
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
        help="Chord-ranking policy used before capture segmentation.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
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

        perf = annotations[perf_path]
        if not isinstance(perf.get("downbeats_score_map"), list) or not perf.get(
            "score_and_performance_aligned", False
        ):
            print(f"{perf_path}: no usable alignment, skipped", file=sys.stderr)
            continue
        downbeats = perf["performance_downbeats"]
        # Map entries are usually ints; spans like "63-64" take their first
        # measure. The base is inconsistent across pieces (some start at 0,
        # some at 1), so calibrate an offset by matching the map's last
        # measure to the analysis's, tolerating small edition differences.
        measures = [int(str(m).split("-")[0]) for m in perf["downbeats_score_map"]]
        last_analysis_measure = max(keys_by_measure)
        offset = min(
            (0, 1), key=lambda d: abs(measures[-1] + d - last_analysis_measure)
        )
        measures = [m + offset for m in measures]
        snapshots = asap_x.sounding_snapshots(args.asap_root / perf_path)
        pieces.append(
            {
                "id": f"{args.set_name}/{folder}",
                "title": perf_path.removesuffix(".mid"),
                "snapshots": snapshots,
                "downbeats": downbeats,
                "measures": measures,
                "keys": keys_by_measure,
            }
        )
        print(
            f"{perf_path}: {len(snapshots)} snapshots, "
            f"{len(keys_by_measure)} keyed measures, opens in "
            f"{key_at(keys_by_measure, 1)}",
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
        events = replayed[piece["id"]]
        for event in events:
            time_s = event["timestampMs"] / 1000
            index = bisect.bisect_right(piece["downbeats"], time_s) - 1
            measure = piece["measures"][max(index, 0)]
            event["labels"] = {
                "localKey": key_at(piece["keys"], measure),
                "measure": measure,
            }
        fixture = {
            "schema": asap_x.FIXTURE_SCHEMA,
            "id": piece["id"],
            "title": piece["title"],
            "labels": {"source": "asap+when-in-rome", "modeResolved": True},
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


def key_at(keys: dict[int, str], measure: int) -> str | None:
    if not keys:
        return None
    candidates = [m for m in keys if m <= measure]
    if not candidates:
        return keys[min(keys)]
    return keys[max(candidates)]


if __name__ == "__main__":
    raise SystemExit(main())

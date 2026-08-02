#!/usr/bin/env python3
"""Polychord exposure census: how often observed voicings look like two
stacked sonorities.

Scoping instrumentation for research/polychord/ (PROTOCOL.md). Two detectors
run over whatkey-fixture event streams, which retain full octave layouts:

Registral: split the distinct sounding notes at each register gap of at least
--gap semitones (each swept value reported separately). Both stacks must match
the explicitly selected --profile. Every qualifying split is reported; the
census does not silently rank alternatives. Separate note instances on opposite
sides of a split may project to the same pitch class unless
--disallow-shared-pitch-classes is set. The recognized layer roots must differ;
two registers of the same rooted harmony are not two harmonic areas.

Pitch-class-only: ignore register and ask whether the sounded pitch classes can
be covered by an upper and lower template with the bass in the lower part.
Shared pitch classes require separate sounded note instances. This measures the
exposure of a register-blind candidate generator, and the cover count per firing
event measures its ambiguity.

Reports, per corpus: fired share of event mass and events for both detectors,
lower-template and root-interval distributions, the engine's current top-1
cost and extension load on fired events against the corpus baseline, and the
complete fired-event and per-piece evidence trail.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path

REPORT_SCHEMA = "polychord-split-census/3"

PC_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

TRIAD_TEMPLATES = {
    (0, 4, 7): "major",
    (0, 3, 7): "minor",
}

SEVENTH_TEMPLATES = {
    (0, 4, 7, 10): "dominant7",
    (0, 4, 7, 11): "major7",
    (0, 3, 7, 10): "minor7",
}

COMMON_CHORD_TEMPLATES = {**TRIAD_TEMPLATES, **SEVENTH_TEMPLATES}

LOWER_FRAGMENT_TEMPLATES = {
    (0, 7): "power",
    (0, 10): "seventhShell",
    (0, 4, 10): "seventhShellThird",
    (0, 7, 10): "seventhShellFifth",
}

TEMPLATE_PROFILES = {
    "bichord-triads": {
        "description": "complete major/minor triads in both layers",
        "upper": TRIAD_TEMPLATES,
        "lower": TRIAD_TEMPLATES,
    },
    "complete-common": {
        "description": "complete common triads or seventh chords in both layers",
        "upper": COMMON_CHORD_TEMPLATES,
        "lower": COMMON_CHORD_TEMPLATES,
    },
    "upper-structure-triads": {
        "description": (
            "major/minor upper triad over a complete common chord or lower fragment"
        ),
        "upper": TRIAD_TEMPLATES,
        "lower": {**COMMON_CHORD_TEMPLATES, **LOWER_FRAGMENT_TEMPLATES},
    },
    "upper-structure-common": {
        "description": (
            "complete common upper chord over a complete common chord or lower fragment"
        ),
        "upper": COMMON_CHORD_TEMPLATES,
        "lower": {**COMMON_CHORD_TEMPLATES, **LOWER_FRAGMENT_TEMPLATES},
    },
}

CHORD_SUFFIXES = {
    "major": "",
    "minor": "m",
    "dominant7": "7",
    "major7": "maj7",
    "minor7": "m7",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--split-file", type=Path)
    parser.add_argument("--split", default="development")
    parser.add_argument("--gaps", type=int, nargs="+", default=[3, 5, 7])
    parser.add_argument(
        "--profile",
        choices=sorted(TEMPLATE_PROFILES),
        required=True,
        help="Declared layer vocabulary; complete-common is the primary census profile",
    )
    parser.add_argument("--disallow-shared-pitch-classes", action="store_true")
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def fixture_paths(args: argparse.Namespace) -> list[Path]:
    if args.split_file is None:
        return sorted(args.fixtures.glob("*.json"))
    split = json.loads(args.split_file.read_text())
    names = [entry["id"].split("/")[-1] for entry in split["splits"][args.split]]
    return [args.fixtures / f"{name}.json" for name in names]


def fixture_files_hash(paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.name.encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def classify(
    pcs: frozenset[int], templates: dict[tuple, str]
) -> tuple[int, str] | None:
    for root in sorted(pcs):
        shape = tuple(sorted((pc - root) % 12 for pc in pcs))
        name = templates.get(shape)
        if name is not None:
            return root, name
    return None


def registral_splits(
    notes: list[int],
    min_gap: int,
    upper_templates: dict[tuple, str],
    lower_templates: dict[tuple, str],
    *,
    allow_shared_pitch_classes: bool,
) -> list[dict]:
    distinct = sorted(set(notes))
    splits = [
        (distinct[i + 1] - distinct[i], i)
        for i in range(len(distinct) - 1)
        if distinct[i + 1] - distinct[i] >= min_gap
    ]
    out = []
    for gap, i in sorted(splits, key=lambda s: (-s[0], s[1])):
        lower = frozenset(n % 12 for n in distinct[: i + 1])
        upper = frozenset(n % 12 for n in distinct[i + 1 :])
        if not allow_shared_pitch_classes and lower & upper:
            continue
        upper_match = classify(upper, upper_templates)
        lower_match = classify(lower, lower_templates)
        if upper_match is None or lower_match is None:
            continue
        if upper_match[0] == lower_match[0]:
            continue
        out.append(
            {
                "gap": gap,
                "lowerTopMidi": distinct[i],
                "upperBottomMidi": distinct[i + 1],
                "upperRoot": upper_match[0],
                "upperQuality": upper_match[1],
                "lowerRoot": lower_match[0],
                "lowerQuality": lower_match[1],
                "sharedPitchClasses": sorted(lower & upper),
            }
        )
    return out


def pc_covers(
    notes: list[int],
    bass_pc: int,
    upper_templates: dict[tuple, str],
    lower_templates: dict[tuple, str],
    *,
    allow_shared_pitch_classes: bool,
) -> list[dict]:
    pcs = frozenset(note % 12 for note in notes)
    pc_counts = {pc: sum(note % 12 == pc for note in notes) for pc in pcs}
    out = []
    upper_sizes = {len(shape) for shape in upper_templates}
    lower_sizes = {len(shape) for shape in lower_templates}
    for size in sorted(upper_sizes):
        for upper in combinations(sorted(pcs), size):
            upper_set = frozenset(upper)
            upper_match = classify(upper_set, upper_templates)
            if upper_match is None:
                continue
            for lower_size in sorted(lower_sizes):
                for lower in combinations(sorted(pcs), lower_size):
                    lower_set = frozenset(lower)
                    if bass_pc not in lower_set or upper_set | lower_set != pcs:
                        continue
                    shared = upper_set & lower_set
                    if shared and (
                        not allow_shared_pitch_classes
                        or any(pc_counts[pc] < 2 for pc in shared)
                    ):
                        continue
                    lower_match = classify(lower_set, lower_templates)
                    if lower_match is None:
                        continue
                    if upper_match[0] == lower_match[0]:
                        continue
                    out.append(
                        {
                            "upperRoot": upper_match[0],
                            "upperQuality": upper_match[1],
                            "lowerRoot": lower_match[0],
                            "lowerQuality": lower_match[1],
                            "sharedPitchClasses": sorted(shared),
                        }
                    )
    return out


def split_symbol(split: dict) -> str:
    upper = PC_NAMES[split["upperRoot"]] + CHORD_SUFFIXES[split["upperQuality"]]
    lower_quality = split["lowerQuality"]
    lower = PC_NAMES[split["lowerRoot"]]
    if lower_quality in CHORD_SUFFIXES:
        lower += CHORD_SUFFIXES[lower_quality]
    else:
        lower += f":{lower_quality}"
    return f"{upper}|{lower}"


def serialized_templates(templates: dict[tuple, str]) -> list[dict]:
    return [
        {"intervals": list(intervals), "quality": quality}
        for intervals, quality in templates.items()
    ]


def main() -> int:
    args = parse_args()
    gaps = sorted(args.gaps, reverse=True)
    profile = TEMPLATE_PROFILES[args.profile]
    upper_templates = profile["upper"]
    lower_templates = profile["lower"]
    allow_shared_pitch_classes = not args.disallow_shared_pitch_classes

    total_mass = 0.0
    total_events = 0
    baseline_cost = 0.0
    baseline_ext2 = 0.0
    by_gap = {
        gap: {
            "mass": 0.0,
            "events": 0,
            "cost": 0.0,
            "ext2": 0.0,
            "candidateMass": 0.0,
            "candidates": 0,
            "lower": defaultdict(float),
            "interval": defaultdict(float),
            "splitCounts": defaultdict(int),
            "fires": [],
            "perPiece": defaultdict(lambda: {"events": 0, "massMs": 0.0}),
        }
        for gap in gaps
    }
    pc_only = {
        "mass": 0.0,
        "events": 0,
        "candidates": 0,
        "coverCounts": defaultdict(int),
        "fires": [],
        "perPiece": defaultdict(lambda: {"events": 0, "massMs": 0.0}),
    }
    piece_mass: dict[str, float] = defaultdict(float)
    selected_fixture_paths = fixture_paths(args)

    for path in selected_fixture_paths:
        fixture = json.loads(path.read_text())
        piece = fixture.get("id", path.stem)
        for event in fixture.get("events", []):
            candidate = (event.get("candidates") or [None])[0]
            if candidate is None:
                continue
            mass = event["durationMs"]
            total_mass += mass
            total_events += 1
            piece_mass[piece] += mass
            cost = candidate.get("cost", 0.0)
            extensions = len(candidate.get("extensions") or [])
            baseline_cost += cost * mass
            baseline_ext2 += mass if extensions >= 2 else 0.0

            for gap in gaps:
                splits = registral_splits(
                    event["midiNotes"],
                    gap,
                    upper_templates,
                    lower_templates,
                    allow_shared_pitch_classes=allow_shared_pitch_classes,
                )
                if not splits:
                    continue
                bucket = by_gap[gap]
                bucket["mass"] += mass
                bucket["events"] += 1
                bucket["cost"] += cost * mass
                bucket["ext2"] += mass if extensions >= 2 else 0.0
                bucket["splitCounts"][len(splits)] += 1
                for split in splits:
                    bucket["candidateMass"] += mass
                    bucket["candidates"] += 1
                    bucket["lower"][split["lowerQuality"]] += mass
                    interval = (split["upperRoot"] - split["lowerRoot"]) % 12
                    bucket["interval"][f"{interval}_{split['upperQuality']}"] += mass
                per_piece = bucket["perPiece"][piece]
                per_piece["events"] += 1
                per_piece["massMs"] += mass
                bucket["fires"].append(
                    {
                        "mass": mass,
                        "piece": piece,
                        "eventIndex": event.get("index"),
                        "timestampMs": event.get("timestampMs"),
                        "midiNotes": event["midiNotes"],
                        "splits": [
                            {**split, "symbol": split_symbol(split)} for split in splits
                        ],
                        "currentTop1": {
                            "rootPc": candidate["rootPc"],
                            "quality": candidate["quality"],
                            "extensions": candidate.get("extensions") or [],
                            "cost": cost,
                        },
                    }
                )

            covers = pc_covers(
                event["midiNotes"],
                event["bassPc"],
                upper_templates,
                lower_templates,
                allow_shared_pitch_classes=allow_shared_pitch_classes,
            )
            if covers:
                pc_only["mass"] += mass
                pc_only["events"] += 1
                pc_only["candidates"] += len(covers)
                pc_only["coverCounts"][len(covers)] += 1
                pc_only["fires"].append(
                    {
                        "mass": mass,
                        "piece": piece,
                        "eventIndex": event.get("index"),
                        "timestampMs": event.get("timestampMs"),
                        "midiNotes": event["midiNotes"],
                        "covers": [
                            {**cover, "symbol": split_symbol(cover)} for cover in covers
                        ],
                        "currentTop1": {
                            "rootPc": candidate["rootPc"],
                            "quality": candidate["quality"],
                            "extensions": candidate.get("extensions") or [],
                            "cost": cost,
                        },
                    }
                )
                per_piece = pc_only["perPiece"][piece]
                per_piece["events"] += 1
                per_piece["massMs"] += mass

    def share(mass: float) -> float:
        return mass / total_mass if total_mass else 0.0

    manifest_path = args.fixtures / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    script_path = Path(__file__).resolve()

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "argv": sys.argv,
        "workingDirectory": str(Path.cwd()),
        "pythonVersion": sys.version.split()[0],
        "script": str(script_path),
        "scriptSha256": hashlib.sha256(script_path.read_bytes()).hexdigest(),
        "fixtures": str(args.fixtures),
        "fixtureFiles": len(selected_fixture_paths),
        "fixtureFilesHash": {
            "algorithm": "sha256",
            "canonicalization": "filename-null-file-sha256-v1",
            "value": fixture_files_hash(selected_fixture_paths),
        },
        "fixtureManifest": {
            key: manifest[key]
            for key in ("engineCommit", "analysisProfile", "contentHash")
            if key in manifest
        },
        "fixtureManifestSha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest()
        if manifest_path.exists()
        else None,
        "split": None if args.split_file is None else args.split,
        "splitFileSha256": None
        if args.split_file is None
        else hashlib.sha256(args.split_file.read_bytes()).hexdigest(),
        "templateProfile": {
            "name": args.profile,
            "description": profile["description"],
            "upper": serialized_templates(upper_templates),
            "lower": serialized_templates(lower_templates),
        },
        "sharedPitchClasses": (
            "separate-note-instances" if allow_shared_pitch_classes else "disallowed"
        ),
        "registralCandidatePolicy": "report-all-qualifying-splits",
        "layerRootPolicy": "different-roots-required",
        "totalEvents": total_events,
        "totalMassMs": total_mass,
        "baseline": {
            "meanCost": baseline_cost / total_mass if total_mass else None,
            "ext2MassShare": share(baseline_ext2),
        },
        "registral": {
            str(gap): {
                "firedMassShare": share(bucket["mass"]),
                "firedEvents": bucket["events"],
                "candidateCount": bucket["candidates"],
                "splitCounts": dict(sorted(bucket["splitCounts"].items())),
                "firedMeanCost": bucket["cost"] / bucket["mass"]
                if bucket["mass"]
                else None,
                "firedExt2MassShare": bucket["ext2"] / bucket["mass"]
                if bucket["mass"]
                else None,
                "lowerTemplates": dict(
                    sorted(
                        (
                            (k, v / bucket["candidateMass"])
                            for k, v in bucket["lower"].items()
                        ),
                        key=lambda x: -x[1],
                    )
                )
                if bucket["mass"]
                else {},
                "intervalQuality": dict(
                    sorted(
                        (
                            (k, v / bucket["candidateMass"])
                            for k, v in bucket["interval"].items()
                        ),
                        key=lambda x: -x[1],
                    )
                )
                if bucket["mass"]
                else {},
                "fires": sorted(bucket["fires"], key=lambda e: -e["mass"]),
                "perPiece": {
                    piece: stats for piece, stats in sorted(bucket["perPiece"].items())
                },
            }
            for gap, bucket in by_gap.items()
        },
        "pieceMassMs": dict(sorted(piece_mass.items())),
        "pcOnly": {
            "firedMassShare": share(pc_only["mass"]),
            "firedEvents": pc_only["events"],
            "candidateCount": pc_only["candidates"],
            "coverCounts": dict(sorted(pc_only["coverCounts"].items())),
            "fires": sorted(pc_only["fires"], key=lambda event: -event["mass"]),
            "perPiece": {
                piece: stats for piece, stats in sorted(pc_only["perPiece"].items())
            },
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    label = (
        args.fixtures.name
        if args.split_file is None
        else f"{args.fixtures.name}/{args.split}"
    )
    parts = "  ".join(
        f"g{gap}:{report['registral'][str(gap)]['firedMassShare']:.4f}" for gap in gaps
    )
    print(
        f"{label}: {total_events} events; registral fired mass {parts}; "
        f"pcOnly {report['pcOnly']['firedMassShare']:.4f} "
        f"({pc_only['events']} events)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

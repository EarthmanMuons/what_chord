#!/usr/bin/env python3
"""Generate the POP909 exposure-weight table for the oracle pool.

Walks all 909 songs' raw MIDI through the same pedal-aware sounding logic as
the fixture extraction and accumulates dwell milliseconds per canonical
(pc-set, bass) pool case for snapshots with 3-7 pitch classes. Engine-free
and replay-free: deterministic from the corpus checkout alone. Method choice
and its validation (0.929 distribution agreement with committed-event mass
on the sampled songs) are recorded in performed-input log 2026-07-28-04.

The output is aggregate statistics only (no corpus content), committable at
tool/chord/pop909_exposure_weights.json while the corpus itself stays under
build/ per the license gate (performed-input log 2026-07-28-01).

Usage:
  .venv/bin/python tool/chord/pop909_exposure.py
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tool" / "whatkey"))
import asap_extract as asap_x

SCHEMA = "pop909-exposure-weights/1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pop909-root",
        type=Path,
        default=REPO_ROOT / "build/whatkey-corpora/POP909-Dataset/POP909",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent / "pop909_exposure_weights.json",
    )
    return parser.parse_args()


def canonical_case(pcs: tuple[int, ...], bass_pc: int) -> str:
    rotations = {root: tuple(sorted((pc - root) % 12 for pc in pcs)) for root in pcs}
    canonical = min(rotations.values())
    root = min(r for r, rotation in rotations.items() if rotation == canonical)
    bass = (bass_pc - root) % 12
    return "-".join(str(pc) for pc in canonical) + f"_b{bass}"


def main() -> int:
    args = parse_args()
    mass: Counter[str] = Counter()
    total = outside = 0.0
    songs = 0
    for folder in sorted(
        p for p in args.pop909_root.iterdir() if p.is_dir() and p.name.isdigit()
    ):
        midi = folder / f"{folder.name}.mid"
        if not midi.exists():
            continue
        songs += 1
        snapshots = asap_x.sounding_snapshots(midi)
        for index, snapshot in enumerate(snapshots[:-1]):
            dwell = snapshots[index + 1]["timestampMs"] - snapshot["timestampMs"]
            if dwell <= 0:
                continue
            notes = snapshot["midiNotes"]
            pcs = tuple(sorted({note % 12 for note in notes}))
            total += dwell
            if not 3 <= len(pcs) <= 7:
                outside += dwell
                continue
            mass[canonical_case(pcs, min(notes) % 12)] += dwell

    pool_mass = sum(mass.values())
    table = {
        "schema": SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": {
            "type": "pop909",
            "pop909Commit": asap_x.git(args.pop909_root.parent, "rev-parse", "HEAD"),
            "method": (
                "raw snapshot dwell mass, pedal-aware sounding sets, 3-7 "
                "pitch classes, bass = lowest sounding note"
            ),
            "songs": songs,
        },
        "totalMs": round(total),
        "outsidePoolMs": round(outside),
        "weights": {
            case_id: {"massMs": ms, "share": ms / pool_mass}
            for case_id, ms in mass.most_common()
        },
    }
    args.out.write_text(json.dumps(table, indent=1, sort_keys=True) + "\n")
    print(
        f"{songs} songs, {total / 3.6e6:.1f}h sounding, "
        f"outside-pool {outside / total:.3f}, {len(mass)} cases -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

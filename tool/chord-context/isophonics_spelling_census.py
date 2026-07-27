"""Census of enharmonic spelling choices in the Isophonics annotations.

Reads the ChoCo Isophonics partition's JAMS (pinned checkout, see
tool/whatkey/prepare_data.py) and counts how human annotators of recorded
pop/rock spell the enharmonically ambiguous tonics and chord roots
(C#/Db, D#/Eb, F#/Gb, G#/Ab, A#/Bb, B/Cb), as audience-relevant evidence
for the cold-start key-side question (log entry 2026-07-20-09).

Reports, per ambiguous pitch class:
- key annotations: segments, duration, and distinct tracks per side;
- chord roots: labels, duration, and distinct tracks per side;
- chord-root sides conditioned on the ambient annotated key's side
  (sharp-side key vs flat-side key vs neutral), the contextual evidence.

Usage:
  python tool/chord-context/isophonics_spelling_census.py \
    --choco-root /private/tmp/choco-sparse
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
AMBIGUOUS = {1, 3, 6, 8, 10, 11}
SHARP_TONICS = {"C#", "D#", "F#", "G#", "A#", "B#", "E#"}
FLAT_TONICS = {"Db", "Eb", "Gb", "Ab", "Bb", "Cb", "Fb"}


def note_pc(name: str) -> int | None:
    if not name or name[0].upper() not in PC:
        return None
    pc = PC[name[0].upper()]
    for accidental in name[1:]:
        if accidental in "#s":
            pc += 1
        elif accidental in "bf":
            pc -= 1
        else:
            return None
    return pc % 12


def side(name: str) -> str:
    if name in SHARP_TONICS:
        return "sharp"
    if name in FLAT_TONICS:
        return "flat"
    return "natural"


def ambient_side(time_s: float, key_segments: list[tuple[float, float, str]]) -> str:
    for start, duration, tonic in key_segments:
        if start <= time_s < start + duration:
            return side(tonic)
    return "none"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--choco-root", type=Path, required=True)
    args = parser.parse_args()
    jams_dir = args.choco_root / "partitions/isophonics/choco/jams"
    files = sorted(jams_dir.glob("*.jams"))
    if not files:
        raise SystemExit(f"no JAMS under {jams_dir}")

    key_stats = defaultdict(lambda: defaultdict(lambda: [0, 0.0, set()]))
    root_stats = defaultdict(lambda: defaultdict(lambda: [0, 0.0, set()]))
    conditioned = defaultdict(Counter)
    unparsed = Counter()

    for path in files:
        jams = json.loads(path.read_text())
        track = path.stem
        key_segments: list[tuple[float, float, str]] = []
        chord_obs: list[tuple[float, float, str]] = []
        for annotation in jams["annotations"]:
            namespace = annotation["namespace"]
            for obs in annotation["data"]:
                value = obs["value"]
                if not isinstance(value, str):
                    continue
                start = float(obs.get("time") or 0)
                duration = float(obs.get("duration") or 0)
                if namespace.startswith("key"):
                    tonic = value.split(":")[0].split("/")[0].strip()
                    if note_pc(tonic) is not None:
                        key_segments.append((start, duration, tonic))
                elif namespace.startswith("chord"):
                    root = value.split(":")[0].split("/")[0].strip()
                    if root in ("N", "X", ""):
                        continue
                    if note_pc(root) is None:
                        unparsed[value] += 1
                        continue
                    chord_obs.append((start, duration, root))

        for start, duration, tonic in key_segments:
            pc = note_pc(tonic)
            if pc in AMBIGUOUS:
                entry = key_stats[pc][tonic]
                entry[0] += 1
                entry[1] += duration
                entry[2].add(track)

        for start, duration, root in chord_obs:
            pc = note_pc(root)
            if pc in AMBIGUOUS:
                entry = root_stats[pc][root]
                entry[0] += 1
                entry[1] += duration
                entry[2].add(track)
                conditioned[(pc, ambient_side(start, key_segments))][side(root)] += 1

    print(f"{len(files)} tracks")
    print("\nKEY annotations on ambiguous tonics:")
    for pc in sorted(key_stats):
        for tonic, (count, duration, tracks) in sorted(key_stats[pc].items()):
            print(
                f"  pc{pc:>2} {tonic:<3} segments={count:<4} "
                f"duration={duration:8.0f}s tracks={len(tracks)}"
            )
    print("\nCHORD roots on ambiguous pitch classes:")
    for pc in sorted(root_stats):
        for root, (count, duration, tracks) in sorted(root_stats[pc].items()):
            print(
                f"  pc{pc:>2} {root:<3} labels={count:<5} "
                f"duration={duration:8.0f}s tracks={len(tracks)}"
            )
    print("\nCHORD-root side conditioned on ambient key side:")
    for (pc, ambient), sides in sorted(conditioned.items()):
        total = sum(sides.values())
        detail = "  ".join(f"{s}={n}" for s, n in sorted(sides.items()))
        print(f"  pc{pc:>2} in {ambient:<7} key: {detail}  (n={total})")
    if unparsed:
        print("\nunparsed chord values:", unparsed.most_common(5))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

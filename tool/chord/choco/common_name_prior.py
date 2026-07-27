#!/usr/bin/env python3
"""Generate WhatChord common-name prior data from ChoCo chord-body counts.

Usage:
  python3 tool/chord/choco/common_name_prior.py build/choco-stats/choco_chord_bodies.csv
  python3 tool/chord/choco/common_name_prior.py /path/to/choco --jams-version converted
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from chord_label_stats import choco_jams_files, iter_chord_observations, parse_label

OUTPUT_PATH = Path("packages/whatchord/lib/analysis/choco_common_name_prior.dart")

QUALITY_BASES = [
    ("major", {"3"}, {"5"}),
    ("majorFlat5", {"3", "b5"}, set()),
    ("minor", {"b3"}, {"5"}),
    ("minorSharp5", {"b3", "#5"}, set()),
    ("diminished", {"b3", "b5"}, set()),
    ("augmented", {"3", "#5"}, set()),
    ("sus2", {"2", "5"}, set()),
    ("sus4", {"4", "5"}, set()),
    ("major6", {"3", "6"}, {"5"}),
    ("minor6", {"b3", "6"}, {"5"}),
    ("dominant7", {"3", "b7"}, {"5"}),
    ("dominant7sus2", {"2", "b7"}, {"5"}),
    ("dominant7sus4", {"4", "b7"}, {"5"}),
    ("dominant7Flat5", {"3", "b5", "b7"}, set()),
    ("dominant7Sharp5", {"3", "#5", "b7"}, set()),
    ("major7", {"3", "7"}, {"5"}),
    ("major7sus2", {"2", "7"}, {"5"}),
    ("major7sus4", {"4", "7"}, {"5"}),
    ("major7Flat5", {"3", "b5", "7"}, set()),
    ("major7Sharp5", {"3", "#5", "7"}, set()),
    ("minor7", {"b3", "b7"}, {"5"}),
    ("minor7Sharp5", {"b3", "#5", "b7"}, set()),
    ("minorMajor7", {"b3", "7"}, {"5"}),
    ("halfDiminished7", {"b3", "b5", "b7"}, set()),
    ("diminished7", {"b3", "b5", "bb7"}, set()),
]

SEVENTH_QUALITIES = {
    "dominant7",
    "dominant7sus2",
    "dominant7sus4",
    "dominant7Flat5",
    "dominant7Sharp5",
    "major7",
    "major7sus2",
    "major7sus4",
    "major7Flat5",
    "major7Sharp5",
    "minor7",
    "minor7Sharp5",
    "minorMajor7",
    "halfDiminished7",
    "diminished7",
}

SIXTH_QUALITIES = {"major6", "minor6"}

EXTENSION_ORDER = [
    "flat9",
    "addFlat9",
    "nine",
    "sharp9",
    "addSharp9",
    "eleven",
    "sharp11",
    "flat13",
    "thirteen",
    "add9",
    "add11",
    "add13",
]

DEGREE_INTERVALS = {
    "b9": 1,
    "9": 2,
    "#9": 3,
    "11": 5,
    "#11": 6,
    "b13": 8,
    "13": 9,
}


@dataclass(frozen=True)
class PriorSignature:
    quality: str
    extensions: tuple[str, ...]

    @property
    def key(self) -> str:
        if not self.extensions:
            return self.quality
        return f"{self.quality}|{','.join(self.extensions)}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        type=Path,
        help="ChoCo root directory or an existing choco_chord_bodies.csv report",
    )
    parser.add_argument(
        "--jams-version",
        choices=["converted", "original"],
        default="converted",
    )
    parser.add_argument("--out", type=Path, default=OUTPUT_PATH)
    args = parser.parse_args()

    counts: Counter[PriorSignature] = Counter()
    skipped = 0

    for degrees, observation_count in iter_degree_rows(args.source, args.jams_version):
        signature = signature_from_degrees(degrees)
        if signature is None:
            skipped += observation_count
            continue
        counts[signature] += observation_count

    if not counts:
        print(f"No supported chord signatures found in {args.source}", file=sys.stderr)
        return 2

    write_dart(args.out, counts)

    print(f"Common-name signatures: {len(counts)}")
    print(f"Supported observations: {sum(counts.values())}")
    print(f"Skipped observations: {skipped}")
    print(f"Wrote {args.out}")
    return 0


def iter_degree_rows(source: Path, jams_version: str):
    if source.is_file():
        with source.open(newline="", encoding="utf-8") as file:
            reader = csv.DictReader(file)
            for row in reader:
                if row.get("class") != "supported":
                    continue
                yield (
                    frozenset((row.get("degrees") or "").split()),
                    int(row["observations"]),
                )
        return

    files = choco_jams_files(source, jams_version)
    if not files:
        print(f"No JAMS files found under {source}", file=sys.stderr)
        return

    for jams_path in files:
        for label, _duration, _corpus, _partition, _jam_type in iter_chord_observations(
            jams_path
        ):
            parsed = parse_label(label)
            if parsed is None or parsed.label_class != "supported":
                continue
            yield parsed.degrees, 1


def signature_from_degrees(degrees: frozenset[str]) -> PriorSignature | None:
    normalized = normalize_degrees(set(degrees))
    matches: list[tuple[int, PriorSignature]] = []

    for quality, required, optional in QUALITY_BASES:
        if not required.issubset(normalized):
            continue

        base = required | optional
        extras = normalized - base
        extensions = extensions_from_extras(extras, quality)
        if extensions is None:
            continue

        # Prefer the most specific base that explains the most tones before
        # falling back to the declaration order, which mirrors analyzer quality
        # vocabulary rather than corpus surface spelling.
        matches.append((len(base & normalized), PriorSignature(quality, extensions)))

    if not matches:
        return None

    matches.sort(key=lambda item: item[0], reverse=True)
    return matches[0][1]


def normalize_degrees(degrees: set[str]) -> set[str]:
    normalized = {degree for degree in degrees if degree != "1"}
    has_third = "3" in normalized or "b3" in normalized
    if "2" in normalized and has_third:
        normalized.remove("2")
        normalized.add("9")
    if "4" in normalized and has_third:
        normalized.remove("4")
        normalized.add("11")
    if "#4" in normalized and has_third:
        normalized.remove("#4")
        normalized.add("#11")
    return normalized


def extensions_from_extras(extras: set[str], quality: str) -> tuple[str, ...] | None:
    if not extras <= set(DEGREE_INTERVALS):
        return None

    has7 = quality in SEVENTH_QUALITIES
    has6_anchor = quality in SIXTH_QUALITIES
    by_interval = {DEGREE_INTERVALS[degree] for degree in extras}
    extensions: set[str] = set()

    if 1 in by_interval:
        extensions.add("flat9" if has7 or has6_anchor else "addFlat9")
    if 3 in by_interval:
        extensions.add("sharp9" if has7 or quality != "minor" else "addSharp9")
    if 6 in by_interval:
        extensions.add("sharp11")
    if 8 in by_interval:
        extensions.add("flat13")

    has9 = 2 in by_interval
    has11 = 5 in by_interval
    has13 = 9 in by_interval
    if has9:
        extensions.add("nine" if has7 else "add9")
    if has11:
        extensions.add("eleven" if has7 and has9 else "add11")
    if has13:
        extensions.add("thirteen" if has7 and has9 else "add13")

    return tuple(sorted(extensions, key=EXTENSION_ORDER.index))


def write_dart(path: Path, counts: Counter[PriorSignature]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = sorted(
        counts,
        key=lambda signature: (-counts[signature], signature.key),
    )

    with path.open("w", encoding="utf-8") as file:
        file.write(
            "// Generated by tool/chord/choco/common_name_prior.py.\n"
            "// ChoCo-derived chord common-name prior counts. Do not edit by hand.\n\n"
            "const chocoCommonNamePriorObservationCounts = <String, int>{\n"
        )
        for signature in rows:
            file.write(f"  '{signature.key}': {counts[signature]},\n")
        file.write("};\n\n")


if __name__ == "__main__":
    raise SystemExit(main())

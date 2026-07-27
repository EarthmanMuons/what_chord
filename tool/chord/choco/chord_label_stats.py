#!/usr/bin/env python3
"""Summarize ChoCo/JAMS chord-label frequencies against WhatChord support.

Usage:
  python3 tool/chord/choco/chord_label_stats.py /path/to/choco
  python3 tool/chord/choco/chord_label_stats.py /path/to/choco --jams-version original
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

NO_CHORD_LABELS = {"", "N", "X"}
ROOT_RE = re.compile(r"^[A-G](?:#{1,2}|b{1,2})?")

HARTE_SHORTHANDS = {
    "__explicit__": set(),
    "maj": {"3", "5"},
    "": {"3", "5"},
    "min": {"b3", "5"},
    "dim": {"b3", "b5"},
    "aug": {"3", "#5"},
    "sus2": {"2", "5"},
    "sus4": {"4", "5"},
    "6": {"3", "5", "6"},
    "maj6": {"3", "5", "6"},
    "min6": {"b3", "5", "6"},
    "7": {"3", "5", "b7"},
    "maj7": {"3", "5", "7"},
    "min7": {"b3", "5", "b7"},
    "dim7": {"b3", "b5", "bb7"},
    "hdim": {"b3", "b5", "b7"},
    "hdim7": {"b3", "b5", "b7"},
    "minmaj7": {"b3", "5", "7"},
    "9": {"3", "5", "b7", "9"},
    "maj9": {"3", "5", "7", "9"},
    "min9": {"b3", "5", "b7", "9"},
    "11": {"3", "5", "b7", "9", "11"},
    "maj11": {"3", "5", "7", "9", "11"},
    "min11": {"b3", "5", "b7", "9", "11"},
    "13": {"3", "5", "b7", "9", "13"},
    "maj13": {"3", "5", "7", "9", "13"},
    "min13": {"b3", "5", "b7", "9", "13"},
}

# WhatChord's current core templates, expressed in Harte degree tokens.
# Each tuple is (required degrees, optional degrees). Perfect fifths are
# optional where the analyzer template makes them omittable.
WHATCHORD_BASES = {
    "major": ({"3"}, {"5"}),
    "minor": ({"b3"}, {"5"}),
    "minorSharp5": ({"b3", "#5"}, set()),
    "diminished": ({"b3", "b5"}, set()),
    "augmented": ({"3", "#5"}, set()),
    "sus2": ({"2", "5"}, set()),
    "sus4": ({"4", "5"}, set()),
    "major6": ({"3", "6"}, {"5"}),
    "minor6": ({"b3", "6"}, {"5"}),
    "dominant7": ({"3", "b7"}, {"5"}),
    "dominant7sus2": ({"2", "b7"}, {"5"}),
    "dominant7sus4": ({"4", "b7"}, {"5"}),
    "dominant7Flat5": ({"3", "b5", "b7"}, set()),
    "dominant7Sharp5": ({"3", "#5", "b7"}, set()),
    "major7": ({"3", "7"}, {"5"}),
    "major7sus2": ({"2", "7"}, {"5"}),
    "major7sus4": ({"4", "7"}, {"5"}),
    "major7Flat5": ({"3", "b5", "7"}, set()),
    "major7Sharp5": ({"3", "#5", "7"}, set()),
    "minor7": ({"b3", "b7"}, {"5"}),
    "minor7Sharp5": ({"b3", "#5", "b7"}, set()),
    "minorMajor7": ({"b3", "7"}, {"5"}),
    "halfDiminished7": ({"b3", "b5", "b7"}, set()),
    "diminished7": ({"b3", "b5", "bb7"}, set()),
}

WHATCHORD_EXTENSIONS = {"b9", "9", "#9", "11", "#11", "b13", "13"}


@dataclass(frozen=True)
class ParsedLabel:
    label_class: str
    body: str
    degrees: frozenset[str]
    bass_degree: str | None


def parse_label(label: str) -> ParsedLabel | None:
    label = label.strip()
    if label in NO_CHORD_LABELS:
        return None

    match = ROOT_RE.match(label)
    if match is None:
        return ParsedLabel("parse-error", label, frozenset(), None)

    rest = label[match.end() :]
    if rest.startswith(":"):
        rest = rest[1:]
    else:
        rest = "maj" + rest

    body, bass = split_bass(rest)
    shorthand, additions = split_body(body)
    degrees = set(HARTE_SHORTHANDS.get(shorthand, set()))
    apply_degree_modifications(degrees, additions)

    body_key = body or "maj"
    return ParsedLabel(classify(degrees), body_key, frozenset(degrees), bass)


def split_bass(rest: str) -> tuple[str, str | None]:
    depth = 0
    for i, char in enumerate(rest):
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "/" and depth == 0:
            return rest[:i], rest[i + 1 :]
    return rest, None


def split_body(body: str) -> tuple[str, list[str]]:
    if body.startswith("("):
        end = body.rfind(")")
        return "__explicit__", split_degrees(body[1:end])

    if "(" not in body:
        return body or "maj", []

    start = body.find("(")
    end = body.rfind(")")
    shorthand = body[:start] or "maj"
    additions = split_degrees(body[start + 1 : end])
    return shorthand, additions


def split_degrees(degrees: str) -> list[str]:
    if not degrees:
        return []
    return [degree.strip() for degree in degrees.split(",") if degree.strip()]


def apply_degree_modifications(degrees: set[str], modifications: list[str]) -> None:
    for degree in modifications:
        if degree.startswith("*"):
            degrees.discard(degree[1:])
        elif degree in ("b5", "#5"):
            degrees.discard("5")
            degrees.add(degree)
        else:
            degrees.add(degree)


def classify(degrees: set[str]) -> str:
    normalized = normalize_degrees(degrees)
    for required, optional in WHATCHORD_BASES.values():
        explained = required | optional
        if (
            required.issubset(normalized)
            and normalized - explained <= WHATCHORD_EXTENSIONS
        ):
            return "supported"
    return "unsupported"


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


def choco_jams_files(choco_root: Path, jams_version: str) -> list[Path]:
    jams_dir = "jams-converted" if jams_version == "converted" else "jams"
    return sorted((choco_root / "partitions").glob(f"*/choco/{jams_dir}/*.jams"))


def iter_chord_observations(jams_path: Path):
    with jams_path.open(encoding="utf-8") as file:
        jam = json.load(file)

    corpus = None
    partition = jams_path.parts[-4]
    jam_type = jam.get("sandbox", {}).get("type", "")
    for annotation in jam.get("annotations", []):
        if annotation.get("namespace") not in {"chord", "chord_harte"}:
            continue
        metadata = annotation.get("annotation_metadata", {})
        corpus = metadata.get("corpus") or corpus or partition
        for observation in annotation.get("data", []):
            value = observation.get("value")
            if isinstance(value, str):
                yield (
                    value,
                    float(observation.get("duration") or 0),
                    corpus,
                    partition,
                    jam_type,
                )


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = list(rows[0].keys()) if rows else []
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("choco_root", type=Path)
    parser.add_argument(
        "--jams-version",
        choices=["converted", "original"],
        default="converted",
    )
    parser.add_argument("--out-dir", type=Path, default=Path("build/choco-stats"))
    parser.add_argument("--top", type=int, default=40)
    args = parser.parse_args()

    files = choco_jams_files(args.choco_root, args.jams_version)
    if not files:
        print(f"No JAMS files found under {args.choco_root}", file=sys.stderr)
        return 2

    label_counts: Counter[str] = Counter()
    label_durations: Counter[str] = Counter()
    body_counts: Counter[str] = Counter()
    body_durations: Counter[str] = Counter()
    body_classes: dict[str, str] = {}
    body_degrees: dict[str, str] = {}
    partition_counts: dict[str, Counter[str]] = defaultdict(Counter)
    parse_errors: Counter[str] = Counter()
    observations = 0

    for jams_path in files:
        for label, duration, _corpus, partition, _jam_type in iter_chord_observations(
            jams_path
        ):
            parsed = parse_label(label)
            if parsed is None:
                continue
            observations += 1
            label_counts[label] += 1
            label_durations[label] += duration
            body_counts[parsed.body] += 1
            body_durations[parsed.body] += duration
            body_classes[parsed.body] = parsed.label_class
            body_degrees[parsed.body] = " ".join(
                sorted(parsed.degrees, key=degree_sort_key)
            )
            partition_counts[partition][parsed.body] += 1
            if parsed.label_class == "parse-error":
                parse_errors[label] += 1

    args.out_dir.mkdir(parents=True, exist_ok=True)

    body_rows = [
        {
            "body": body,
            "class": body_classes[body],
            "observations": count,
            "duration": f"{body_durations[body]:.3f}",
            "degrees": body_degrees[body],
        }
        for body, count in body_counts.most_common()
    ]
    label_rows = [
        {
            "label": label,
            "observations": count,
            "duration": f"{label_durations[label]:.3f}",
        }
        for label, count in label_counts.most_common()
    ]
    unsupported_rows = [row for row in body_rows if row["class"] != "supported"]
    supported_observations = sum(
        count
        for body, count in body_counts.items()
        if body_classes[body] == "supported"
    )
    supported_duration = sum(
        duration
        for body, duration in body_durations.items()
        if body_classes[body] == "supported"
    )
    total_duration = sum(body_durations.values())

    write_csv(args.out_dir / "choco_chord_bodies.csv", body_rows)
    write_csv(args.out_dir / "choco_chord_labels.csv", label_rows)
    write_csv(args.out_dir / "choco_unsupported_bodies.csv", unsupported_rows)

    print(f"JAMS files: {len(files)}")
    print(f"Chord observations, excluding N/X: {observations}")
    print(f"Distinct full labels: {len(label_counts)}")
    print(f"Distinct chord bodies: {len(body_counts)}")
    print(
        "Supported observations: "
        f"{supported_observations} "
        f"({percentage(supported_observations, observations):.2f}%)"
    )
    print(
        "Supported duration: "
        f"{supported_duration:.3f} "
        f"({percentage(supported_duration, total_duration):.2f}%)"
    )
    print(f"Unsupported chord bodies: {len(unsupported_rows)}")
    print()
    print(f"Top {args.top} chord bodies:")
    for row in body_rows[: args.top]:
        print(
            f"{row['observations']:>8}  {row['duration']:>12}  "
            f"{row['class']:<11}  {row['body']:<24}  {row['degrees']}"
        )
    print()
    print(f"Top {args.top} unsupported chord bodies:")
    for row in unsupported_rows[: args.top]:
        print(
            f"{row['observations']:>8}  {row['duration']:>12}  "
            f"{row['body']:<24}  {row['degrees']}"
        )
    if parse_errors:
        print()
        print("Parse errors:")
        for label, count in parse_errors.most_common(args.top):
            print(f"{count:>8}  {label}")
    print()
    print(f"Wrote CSV reports to {args.out_dir}")
    return 0


def degree_sort_key(degree: str) -> tuple[int, str]:
    match = re.search(r"\d+", degree)
    if match is None:
        return (99, degree)
    numeric = int(match.group(0))
    order = {
        1: 0,
        2: 1,
        3: 2,
        4: 3,
        5: 4,
        6: 5,
        7: 6,
        9: 7,
        11: 8,
        13: 9,
    }
    return order.get(numeric, 99), degree


def percentage(value: float, total: float) -> float:
    if total == 0:
        return 0
    return (value / total) * 100


if __name__ == "__main__":
    raise SystemExit(main())

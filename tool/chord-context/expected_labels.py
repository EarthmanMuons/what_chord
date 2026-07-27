"""Expected-identity labels for the chord-context headroom study.

Walks a WhatKey fixture set (research/whatkey/data/fixtures/<set>/), realizes
each event's RomanText figure in its annotated local key via music21, and
emits a sidecar JSON of expected chord identities in WhatChord terms
(rootPc, quality enum name, bass) plus per-event category tags and the
previous-figure class for transition-conditioned breakdowns.

The sidecar is deterministic (no timestamps) and aligned to fixture events by
index. Figures are assumed to follow RomanText semantics; hand-authored chart
sets (pop-jazz) use shorthand with different semantics (blues "I7"), so their
results carry a documented caveat until charts gain explicit expected labels.

Usage:
  python tool/chord-context/expected_labels.py \
    --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
    --out build/chord-context/labels/when-in-rome-v1.labels.json
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import music21
from music21 import key as m21key
from music21 import roman

sys.path.insert(0, str(Path(__file__).resolve().parent))
from labels_common import classify_figure, map_quality

SCHEMA = "chord-context-labels/1"

SYMMETRIC_COMMON_NAMES = {"augmented triad", "diminished seventh chord"}


def wire_to_m21_key(wire: str) -> m21key.Key:
    tonic, _, mode = wire.partition(":")
    mode = {"maj": "major", "min": "minor"}.get(mode, mode or "major")
    tonic = tonic.replace("b", "-")
    if mode == "minor":
        tonic = tonic[0].lower() + tonic[1:]
    return m21key.Key(tonic, mode)


def realize(figure: str, wire_key: str):
    """RomanText figure + wire key -> music21 RomanNumeral, or raises."""
    k = wire_to_m21_key(wire_key)
    variants = [figure, figure.replace("ø", "/o")]
    error: Exception | None = None
    for variant in variants:
        try:
            return roman.RomanNumeral(variant, k)
        except Exception as exc:  # noqa: BLE001 - music21 raises broadly
            error = exc
    raise ValueError(f"unrealizable figure {figure!r} in {wire_key}: {error}")


def is_explicit_or_incomplete(figure: str, common_name: str) -> bool:
    if "[" in figure:
        return True
    if common_name.startswith(("incomplete ", "enharmonic equivalent")):
        return True
    return any(
        token in common_name for token in ("tetrachord", "pentachord", "tetramirror")
    )


def pcs_from_mask(pc_mask: int) -> frozenset[int]:
    return frozenset(pc for pc in range(12) if pc_mask & (1 << pc))


def label_event(event: dict, prev_figure: str | None) -> dict:
    labels = event.get("labels") or {}
    figure = labels.get("figure")
    local_key = labels.get("localKey")
    entry: dict = {
        "index": event["index"],
        "figure": figure,
        "localKey": local_key,
        "prevClass": classify_figure(prev_figure),
    }
    if not figure or not local_key:
        entry["category"] = "unlabeled"
        return entry

    try:
        rn = realize(figure, local_key)
    except ValueError as exc:
        entry["category"] = "unrealized"
        entry["reason"] = str(exc)
        return entry

    expected_pcs = frozenset(p.pitchClass for p in rn.pitches)
    root_pc = rn.root().pitchClass
    common_name = rn.commonName
    intervals = frozenset((pc - root_pc) % 12 for pc in expected_pcs)
    quality, extras = map_quality(intervals)
    entry["expected"] = {
        "rootPc": root_pc,
        "bassPc": rn.bass().pitchClass,
        "pcs": sorted(expected_pcs),
        "quality": quality,
        "extraIntervals": extras,
        "commonName": common_name,
    }

    sounding = pcs_from_mask(event["pcMask"])
    if "augmented sixth" in common_name:
        category = "functional-label"
    elif is_explicit_or_incomplete(figure, common_name):
        category = "explicit-or-incomplete"
    elif common_name in SYMMETRIC_COMMON_NAMES:
        category = "symmetric-root"
    elif root_pc not in sounding:
        category = "rootless"
    elif sounding == expected_pcs:
        category = "ok"
    elif expected_pcs < sounding:
        category = "extra-tones"
    else:
        category = "mismatch"
    if quality is None and category in ("ok", "extra-tones", "mismatch"):
        category = "unmapped-quality"
    entry["category"] = category
    return entry


def label_fixture(path: Path) -> tuple[str, list[dict]]:
    raw = json.loads(path.read_text())
    events = raw["events"]
    entries = []
    prev_figure = None
    for event in events:
        entries.append(label_event(event, prev_figure))
        prev_figure = (event.get("labels") or {}).get("figure")
    return raw["id"], entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads((args.fixtures / "manifest.json").read_text())
    pieces: dict[str, list[dict]] = {}
    categories: Counter[str] = Counter()
    unrealized: Counter[str] = Counter()
    for entry in manifest["fixtures"]:
        piece_id, labeled = label_fixture(args.fixtures / entry["file"])
        pieces[piece_id] = labeled
        for item in labeled:
            categories[item["category"]] += 1
            if item["category"] == "unrealized":
                unrealized[item["figure"]] += 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(
            {
                "schema": SCHEMA,
                "set": manifest["set"],
                "music21Version": music21.__version__,
                "fixtures": str(args.fixtures),
                "pieces": pieces,
            },
            indent=1,
            sort_keys=True,
        )
        + "\n"
    )

    total = sum(categories.values())
    print(f"{manifest['set']}: {total} events across {len(pieces)} pieces")
    for category, count in categories.most_common():
        print(f"  {category}: {count} ({count / total:.1%})")
    if unrealized:
        print("unrealized figures:")
        for figure, count in unrealized.most_common():
            print(f"  {figure}: {count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

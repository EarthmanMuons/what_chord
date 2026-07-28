#!/usr/bin/env python3
"""Dense-set (8-plus pitch-class) behavior census: the tone-pricing stress
guard.

Pricing levers that move the extended-name/base-name threshold shake dense
pedal-wash naming hardest, and no oracle or analyst convention exists past 7
pitch classes (performed-input log 2026-07-28-05), so the guard is
self-referential: what the engine emits on dense events and how consistently
it names the same dense class across real octave layouts. Run before and
after any adopted lever (research/tone-pricing/PROTOCOL.md); a material
consistency drop fails the guard.

Reports, per fixture set: dense event mass share, the top-1 quality
distribution on dense events, and mass-weighted revoicing consistency over
canonical (pc-set, bass) classes observed under 2 or more distinct octave
layouts.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REPORT_SCHEMA = "tone-pricing-dense-census/1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--split-file", type=Path, required=True)
    parser.add_argument("--split", default="development")
    parser.add_argument("--min-pcs", type=int, default=8)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def canonical_class(pcs: tuple[int, ...], bass_pc: int) -> str:
    rotations = {root: tuple(sorted((pc - root) % 12 for pc in pcs)) for root in pcs}
    canonical = min(rotations.values())
    root = min(r for r, rotation in rotations.items() if rotation == canonical)
    return "-".join(str(pc) for pc in canonical) + f"_b{(bass_pc - root) % 12}"


def class_root(pcs: tuple[int, ...]) -> int:
    rotations = {root: tuple(sorted((pc - root) % 12 for pc in pcs)) for root in pcs}
    canonical = min(rotations.values())
    return min(r for r, rotation in rotations.items() if rotation == canonical)


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())

    total = dense = 0.0
    quality_mass: dict[str, float] = defaultdict(float)
    names_by_class: dict[str, dict[tuple, float]] = defaultdict(
        lambda: defaultdict(float)
    )
    layouts_by_class: dict[str, set] = defaultdict(set)
    for entry in split["splits"][args.split]:
        name = entry["id"].split("/")[-1]
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        for event in fixture["events"]:
            candidate = (event.get("candidates") or [None])[0]
            if candidate is None:
                continue
            weight = event["durationMs"]
            total += weight
            pcs = tuple(i for i in range(12) if event["pcMask"] >> i & 1)
            if len(pcs) < args.min_pcs:
                continue
            dense += weight
            quality_mass[candidate["quality"]] += weight
            case = canonical_class(pcs, event["bassPc"])
            root = class_root(pcs)
            label = ((candidate["rootPc"] - root) % 12, candidate["quality"])
            names_by_class[case][label] += weight
            notes = event["midiNotes"]
            layouts_by_class[case].add(tuple(sorted(n - min(notes) for n in notes)))

    multi = {c for c, layouts in layouts_by_class.items() if len(layouts) >= 2}
    agree = sum(max(names_by_class[c].values()) for c in multi)
    seen = sum(sum(names_by_class[c].values()) for c in multi)

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "minPcs": args.min_pcs,
        "denseShareOfEventMass": dense / total if total else 0.0,
        "qualityShares": dict(
            sorted(
                ((q, m / dense) for q, m in quality_mass.items()),
                key=lambda x: -x[1],
            )
        )
        if dense
        else {},
        "revoicingConsistency": agree / seen if seen else None,
        "multiLayoutClasses": len(multi),
        "multiLayoutLayouts": sum(len(layouts_by_class[c]) for c in multi),
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    top = list(report["qualityShares"].items())[:6]
    quality_text = "  ".join(f"{q}:{s:.2f}" for q, s in top)
    consistency = report["revoicingConsistency"]
    print(
        f"{args.split}: dense {report['denseShareOfEventMass']:.3f} of event "
        f"mass; consistency "
        f"{'n/a' if consistency is None else f'{consistency:.4f}'} "
        f"({len(multi)} classes, "
        f"{report['multiLayoutLayouts']} layouts); top qualities {quality_text}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

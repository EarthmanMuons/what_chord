#!/usr/bin/env python3
"""Break down WhatKey claim errors by relationship to the labeled key.

Reads a harness claims.json and the fixture set it was produced from, and
pools every claimed event into MIREX-style relationship classes against the
fixture's localKey labels: exact, fifth (claim a fifth away, same mode),
relative (mode error, relative major/minor), parallel (mode error, same
tonic), other. Mode-resolved labels required; events with a null label or an
abstention are excluded.

With --min-segment-measures N, only events inside analyst key segments
spanning at least N measures are pooled (a segment is a maximal run of
consecutive events with the same localKey; its span uses the events' measure
labels). Inside such segments the tonicization-scale and section-scale answers
coincide, so the filtered breakdown isolates product-level error from the
deliberate timescale trade.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

PC_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def parse_key(key: str) -> tuple[int, bool]:
    tonic, mode = key.split(":")
    pc = PC_BASE[tonic[0]] + tonic.count("#") - tonic.count("b")
    return pc % 12, mode == "min"


def classify(claim: str, truth: str) -> str:
    claim_pc, claim_minor = parse_key(claim)
    truth_pc, truth_minor = parse_key(truth)
    if (claim_pc, claim_minor) == (truth_pc, truth_minor):
        return "exact"
    if claim_minor != truth_minor:
        relative_pc = (truth_pc + (3 if truth_minor else 9)) % 12
        if claim_pc == relative_pc:
            return "relative"
        if claim_pc == truth_pc:
            return "parallel"
    if claim_minor == truth_minor and (claim_pc - truth_pc) % 12 in (5, 7):
        return "fifth"
    return "other"


def segment_spans(events: list[dict]) -> list[int | None]:
    """Per event, the measure span of its maximal same-localKey run."""
    spans: list[int | None] = [None] * len(events)
    start = 0
    for i in range(1, len(events) + 1):
        if i < len(events) and (
            events[i]["labels"].get("localKey")
            == events[start]["labels"].get("localKey")
        ):
            continue
        measures = [
            e["labels"]["measure"]
            for e in events[start:i]
            if e["labels"].get("measure") is not None
        ]
        span = max(measures) - min(measures) + 1 if measures else None
        for j in range(start, i):
            spans[j] = span
        start = i
    return spans


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--claims", type=Path, required=True)
    parser.add_argument("--min-segment-measures", type=int, default=0)
    args = parser.parse_args()

    labels: dict[str, list[tuple[str | None, int | None]]] = {}
    for path in sorted(args.fixtures.glob("*.json")):
        if path.name == "manifest.json":
            continue
        fixture = json.loads(path.read_text())
        spans = segment_spans(fixture["events"])
        labels[fixture["id"]] = [
            (event["labels"].get("localKey"), span)
            for event, span in zip(fixture["events"], spans, strict=True)
        ]

    claims = json.loads(args.claims.read_text())["claims"]
    kinds: Counter[str] = Counter()
    for fixture_id, data in claims.items():
        for claim, (truth, span) in zip(
            data["events"], labels[fixture_id], strict=True
        ):
            if claim is None or truth is None:
                continue
            if args.min_segment_measures and (
                span is None or span < args.min_segment_measures
            ):
                continue
            kinds[classify(claim, truth)] += 1

    total = sum(kinds.values())
    for kind in ("exact", "fifth", "relative", "parallel", "other"):
        count = kinds[kind]
        print(f"{kind:9s} {count:6d}  ({count / total:.0%})")
    print(f"{'claimed':9s} {total:6d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

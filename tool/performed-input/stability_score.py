#!/usr/bin/env python3
"""Prefix-stability metrics over per-snapshot display-label streams.

Avenue 2 (research/performed-input/): live, the displayed label recomputes
as notes arrive, so there is a stability dimension no accuracy ruler sees.
From the frames sidecar files (asap_wir_extract.py --emit-frames: change
points of the top-1 (rootPc, quality), null entries when the display goes
blank), computes per piece:

  labeledShare   labeled display time over the piece span
  switchesPerMin transitions to a non-null label differing from the
                 previous non-null label, per minute of labeled time
  flickerShare   labeled time spent in dwells shorter than flickerMs
  settleMs       per committed event, the time from event start to the
                 last label change inside the event (0 = settled at
                 onset); reported as median and p90 over events
  churnPerEvent  label changes strictly inside committed events, mean

Movements must be listed explicitly or come from a split side; validating
plumbing on gate-excluded movements keeps the development split unseen
until the ruler freezes. Reads build/ artifacts; writes a JSON report.
"""

from __future__ import annotations

import argparse
import bisect
import json
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REPORT_SCHEMA = "performed-input-stability/1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("build/whatkey-fixtures/asap-wir-nc-v2"),
    )
    parser.add_argument(
        "--split-file",
        type=Path,
        default=REPO_ROOT / "research/performed-input/data/splits/asap-wir-nc-v2.json",
    )
    parser.add_argument(
        "--split",
        choices=("development", "test", "gateExcluded"),
        help="Score one split side (gateExcluded = plumbing checks only).",
    )
    parser.add_argument("movements", nargs="*", help="Explicit fixture names.")
    parser.add_argument("--flicker-ms", type=int, default=500)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def quantile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(int(q * len(ordered)), len(ordered) - 1)]


def score_piece(fixture: dict, frames: list[dict], flicker_ms: int) -> dict:
    events = fixture["events"]
    stream_end = max(
        [e["timestampMs"] + e["durationMs"] for e in events]
        + [frames[-1]["timestampMs"] if frames else 0]
    )

    labeled_ms = flicker_time = 0.0
    switches = 0
    previous_label = None
    for index, frame in enumerate(frames):
        label = (frame["rootPc"], frame["quality"]) if "rootPc" in frame else None
        end = (
            frames[index + 1]["timestampMs"] if index + 1 < len(frames) else stream_end
        )
        dwell = max(end - frame["timestampMs"], 0)
        if label is not None:
            labeled_ms += dwell
            if dwell < flicker_ms:
                flicker_time += dwell
            if previous_label is not None and label != previous_label:
                switches += 1
            previous_label = label

    change_times = [frame["timestampMs"] for frame in frames if "rootPc" in frame]
    settle: list[float] = []
    churn: list[int] = []
    for event in events:
        start = event["timestampMs"]
        end = start + event["durationMs"]
        lo = bisect.bisect_right(change_times, start)
        hi = bisect.bisect_right(change_times, end)
        inside = change_times[lo:hi]
        settle.append(inside[-1] - start if inside else 0.0)
        churn.append(len(inside))

    minutes = labeled_ms / 60_000
    return {
        "id": fixture["id"],
        "events": len(events),
        "labeledShare": labeled_ms / stream_end if stream_end else 0.0,
        "switchesPerMin": switches / minutes if minutes else 0.0,
        "flickerShare": flicker_time / labeled_ms if labeled_ms else 0.0,
        "settleMsMedian": quantile(settle, 0.5),
        "settleMsP90": quantile(settle, 0.9),
        "churnPerEvent": sum(churn) / len(churn) if churn else 0.0,
    }


def main() -> int:
    args = parse_args()
    names = list(args.movements)
    if args.split:
        split = json.loads(args.split_file.read_text())
        rows = (
            split["gateExcluded"]
            if args.split == "gateExcluded"
            else split["splits"][args.split]
        )
        names += [entry["id"].split("/")[-1] for entry in rows]
    if not names:
        raise SystemExit("Give movement names or --split.")

    pieces = []
    for name in sorted(set(names)):
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        frames = json.loads((args.fixtures / "frames" / f"{name}.json").read_text())[
            "frames"
        ]
        pieces.append(score_piece(fixture, frames, args.flicker_ms))

    def mean(field: str) -> float:
        return sum(p[field] for p in pieces) / len(pieces) if pieces else 0.0

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "flickerMs": args.flicker_ms,
        "summary": {
            "pieces": len(pieces),
            "meanPerPiece": {
                field: mean(field)
                for field in (
                    "labeledShare",
                    "switchesPerMin",
                    "flickerShare",
                    "settleMsMedian",
                    "settleMsP90",
                    "churnPerEvent",
                )
            },
        },
        "perPiece": pieces,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")

    s = report["summary"]["meanPerPiece"]
    print(
        f"{args.split or 'explicit'} ({len(pieces)} pieces): "
        f"labeled {s['labeledShare']:.3f}, "
        f"switches/min {s['switchesPerMin']:.1f}, "
        f"flicker {s['flickerShare']:.3f}, "
        f"settle med {s['settleMsMedian']:.0f}ms p90 {s['settleMsP90']:.0f}ms, "
        f"churn/event {s['churnPerEvent']:.2f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

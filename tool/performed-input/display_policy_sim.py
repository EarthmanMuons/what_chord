#!/usr/bin/env python3
"""Offline display-policy simulation: the flicker-versus-latency frontier.

Log 2026-07-27-14 scoped the stability findings to display policy. This
simulates candidate policies over the emitted frames and committed events,
with no app change:

  raw          today's behavior: the display follows every top-1 change.
  dwell-D      the display adopts a new label only after the raw stream has
               shown it continuously for D ms; it blanks when raw blanks.
  gated        segmenter-gated: the display shows each committed event's
               label from approximately its commit time (event start plus
               the 200 ms minimum chord duration) and holds through gaps.

Per policy: flickerShare and switchesPerMin of the simulated display
stream (stability ruler definitions), plus the UX price: per committed
event, the latency until the display first shows that event's label
(0 when already showing; an event whose label never appears during the
event is missed). Corpus caveat: metrics are ground-truth-free, so the
frontier can and should be replicated on broader corpora before a dial
ships; this split picks the shape, not the final value.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REPORT_SCHEMA = "performed-input-display-policy/1"
COMMIT_LAG_MS = 200
DWELLS = (100, 200, 300, 500, 750)


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
        "--split", choices=("development", "test"), default="development"
    )
    parser.add_argument("--flicker-ms", type=int, default=500)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def raw_stream(frames: list[dict]) -> list[tuple[int, tuple | None]]:
    return [
        (
            frame["timestampMs"],
            (frame["rootPc"], frame["quality"]) if "rootPc" in frame else None,
        )
        for frame in frames
    ]


def dwell_stream(
    raw: list[tuple[int, tuple | None]], dwell_ms: int, stream_end: int
) -> list[tuple[int, tuple | None]]:
    """The display adopts a label its raw dwell reaches dwell_ms; blanks pass
    through immediately."""
    out: list[tuple[int, tuple | None]] = []
    displayed: tuple | None = None
    for index, (start, label) in enumerate(raw):
        end = raw[index + 1][0] if index + 1 < len(raw) else stream_end
        if label is None:
            if displayed is not None or not out:
                out.append((start, None))
                displayed = None
        elif label != displayed and end - start >= dwell_ms:
            out.append((start + dwell_ms, label))
            displayed = label
    return out


def gated_stream(events: list[dict]) -> list[tuple[int, tuple | None]]:
    out: list[tuple[int, tuple | None]] = []
    displayed: tuple | None = None
    for event in events:
        candidate = (event.get("candidates") or [None])[0]
        if candidate is None:
            continue
        label = (candidate["rootPc"], candidate["quality"])
        if label != displayed:
            out.append((event["timestampMs"] + COMMIT_LAG_MS, label))
            displayed = label
    return out


def gated_live_stream(
    raw: list[tuple[int, tuple | None]], stream_end: int
) -> list[tuple[int, tuple | None]]:
    """The segmenter's live active-chord semantics: a label is adopted
    immediately when nothing is active (after a blank), while during an
    active chord a different label takes over only after surviving
    COMMIT_LAG_MS as a challenger. The immediate-onset variant of gating."""
    out: list[tuple[int, tuple | None]] = []
    current: tuple | None = None
    for index, (start, label) in enumerate(raw):
        end = raw[index + 1][0] if index + 1 < len(raw) else stream_end
        if label is None:
            if current is not None:
                out.append((start, None))
                current = None
        elif current is None:
            out.append((start, label))
            current = label
        elif label != current and end - start >= COMMIT_LAG_MS:
            out.append((start + COMMIT_LAG_MS, label))
            current = label
    return out


def stability(
    stream: list[tuple[int, tuple | None]], stream_end: int, flicker_ms: int
) -> tuple[float, float]:
    """(flickerShare, switchesPerMin) of a display stream."""
    labeled = flicker = 0.0
    switches = 0
    previous = None
    for index, (start, label) in enumerate(stream):
        end = stream[index + 1][0] if index + 1 < len(stream) else stream_end
        dwell = max(end - start, 0)
        if label is not None:
            labeled += dwell
            if dwell < flicker_ms:
                flicker += dwell
            if previous is not None and label != previous:
                switches += 1
            previous = label
    minutes = labeled / 60_000
    return (
        flicker / labeled if labeled else 0.0,
        switches / minutes if minutes else 0.0,
    )


def latency(
    stream: list[tuple[int, tuple | None]], events: list[dict]
) -> tuple[list[float], int]:
    """Per-event ms until the display shows the event's label; missed count."""
    latencies: list[float] = []
    missed = 0
    for event in events:
        candidate = (event.get("candidates") or [None])[0]
        if candidate is None:
            continue
        label = (candidate["rootPc"], candidate["quality"])
        start = event["timestampMs"]
        end = start + event["durationMs"]
        shown = None
        current = None
        for at, displayed in stream:
            if at > end:
                break
            if at <= start:
                current = displayed
                continue
            if current == label and shown is None:
                shown = start
            if displayed == label and at <= end and shown is None:
                shown = at
            current = displayed
        if current == label and shown is None:
            shown = start
        if shown is None:
            missed += 1
        else:
            latencies.append(max(shown - start, 0))
    return latencies, missed


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())
    names = [e["id"].split("/")[-1] for e in split["splits"][args.split]]

    policies: dict[str, dict] = {}
    for name in names:
        fixture = json.loads((args.fixtures / f"{name}.json").read_text())
        frames = json.loads((args.fixtures / "frames" / f"{name}.json").read_text())[
            "frames"
        ]
        events = fixture["events"]
        stream_end = max(
            [e["timestampMs"] + e["durationMs"] for e in events]
            + [frames[-1]["timestampMs"] if frames else 0]
        )
        raw = raw_stream(frames)
        candidates = {
            "raw": raw,
            "gated": gated_stream(events),
            "gated-live": gated_live_stream(raw, stream_end),
        }
        for dwell in DWELLS:
            candidates[f"dwell-{dwell}"] = dwell_stream(raw, dwell, stream_end)
        for policy, stream in candidates.items():
            flicker, switches = stability(stream, stream_end, args.flicker_ms)
            lats, missed = latency(stream, events)
            row = policies.setdefault(
                policy,
                {
                    "flicker": [],
                    "switches": [],
                    "latency": [],
                    "missed": 0,
                    "events": 0,
                },
            )
            row["flicker"].append(flicker)
            row["switches"].append(switches)
            row["latency"].extend(lats)
            row["missed"] += missed
            row["events"] += missed + len(lats)

    order = ["raw", *[f"dwell-{d}" for d in DWELLS], "gated", "gated-live"]
    summary = {}
    print(
        f"{'policy':>10} {'flicker':>8} {'sw/min':>8} "
        f"{'lat med':>8} {'lat p90':>8} {'missed':>7}"
    )
    for policy in order:
        row = policies[policy]
        lats = sorted(row["latency"])
        med = lats[len(lats) // 2] if lats else 0
        p90 = lats[min(int(0.9 * len(lats)), len(lats) - 1)] if lats else 0
        summary[policy] = {
            "flickerShare": sum(row["flicker"]) / len(row["flicker"]),
            "switchesPerMin": sum(row["switches"]) / len(row["switches"]),
            "latencyMsMedian": med,
            "latencyMsP90": p90,
            "missedEventShare": row["missed"] / row["events"],
        }
        s = summary[policy]
        print(
            f"{policy:>10} {s['flickerShare']:>8.3f} "
            f"{s['switchesPerMin']:>8.1f} {s['latencyMsMedian']:>8.0f} "
            f"{s['latencyMsP90']:>8.0f} {s['missedEventShare']:>7.3f}"
        )

    report = {
        "schema": REPORT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fixtures": str(args.fixtures),
        "split": args.split,
        "flickerMs": args.flicker_ms,
        "commitLagMs": COMMIT_LAG_MS,
        "policies": summary,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

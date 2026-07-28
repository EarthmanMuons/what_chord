#!/usr/bin/env python3
"""Emit POP909 stability fixtures: pop piano arrangements through capture.

Replays POP909 arrangements (three merged tracks, pedal-aware, expressive
timing) through the app's real capture path with display-frame emission, for
the performed-input stability ruler and display-policy work (log
2026-07-28-01: POP909 is admitted for ground-truth-free stability
measurement; its machine-extracted chord labels are advisory-only and are
not attached here).

Songs are sampled deterministically by stride over the 909 folders. Output
per song: an events fixture, a frames sidecar, and a roster file in
split-file shape so the stability tools consume the set unchanged. The
roster is NOT a frozen split; this corpus serves descriptive replication
only, and any tuning use would freeze a split first (PROTOCOL.md).

LICENSE GATE: the repository is MIT but the underlying 909 compositions are
copyrighted (log 2026-07-28-01); fixtures stay under build/ and this tool
refuses to write inside research/.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asap_extract as asap_x
from reproducibility import (
    ANALYSIS_PROFILES,
    CANONICALIZATION,
    DEFAULT_ANALYSIS_PROFILE,
    fixture_hashes,
)

REPO_ROOT = asap_x.REPO_ROOT


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pop909-root",
        type=Path,
        default=Path("build/whatkey-corpora/POP909-Dataset/POP909"),
    )
    parser.add_argument("--set", dest="set_name", default="pop909-nc-v1")
    parser.add_argument("--out", type=Path, default=Path("build/whatkey-fixtures"))
    parser.add_argument(
        "--stride",
        type=int,
        default=9,
        help="Take every Nth song folder (deterministic sample; 9 -> 101 songs).",
    )
    parser.add_argument(
        "--analysis-profile",
        choices=ANALYSIS_PROFILES,
        default=DEFAULT_ANALYSIS_PROFILE,
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if (REPO_ROOT / "research") in args.out.resolve().parents:
        raise SystemExit("License-gated fixtures: build/ only.")

    folders = sorted(
        p for p in args.pop909_root.iterdir() if p.is_dir() and p.name.isdigit()
    )
    selected = folders[:: args.stride]
    pieces = []
    for folder in selected:
        midi = folder / f"{folder.name}.mid"
        if not midi.exists():
            continue
        pieces.append(
            {
                "id": f"{args.set_name}/{folder.name}",
                "title": f"POP909/{folder.name}",
                "snapshots": asap_x.sounding_snapshots(midi),
                "replayExtras": {"emitFrames": True},
            }
        )
    print(f"{len(pieces)} songs selected (stride {args.stride})", file=sys.stderr)

    replayed = asap_x.replay(pieces, "C:maj", 200, args.analysis_profile)

    set_dir = args.out / args.set_name
    frames_dir = set_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    fixtures = []
    for piece in pieces:
        result = replayed[piece["id"]]
        name = piece["id"].split("/")[-1]
        fixture = {
            "schema": asap_x.FIXTURE_SCHEMA,
            "id": piece["id"],
            "title": piece["title"],
            "labels": {"source": "pop909", "arm": "A0"},
            "events": result["events"],
        }
        (set_dir / f"{name}.json").write_text(
            json.dumps(fixture, indent=2, sort_keys=True) + "\n"
        )
        (frames_dir / f"{name}.json").write_text(
            json.dumps(
                {"id": piece["id"], "frames": result["frames"]},
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )
        fixtures.append(
            {
                "id": piece["id"],
                "title": piece["title"],
                "file": f"{name}.json",
                "events": len(result["events"]),
            }
        )

    files = [entry["file"] for entry in fixtures]
    hashes, content_hash = fixture_hashes(set_dir, files)
    for entry in fixtures:
        entry["sha256"] = hashes[entry["file"]]

    manifest = {
        "schema": asap_x.MANIFEST_SCHEMA,
        "set": args.set_name,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": "python tool/whatkey/pop909_extract.py " + " ".join(sys.argv[1:]),
        "engineCommit": asap_x.git(REPO_ROOT, "rev-parse", "HEAD"),
        "engineLibDirty": bool(
            asap_x.git(REPO_ROOT, "status", "--porcelain", "--", "lib", "pubspec.yaml")
        ),
        "generator": {
            "script": "tool/whatkey/pop909_extract.py",
            "arguments": sys.argv[1:],
        },
        "context": "C:maj",
        "analysisProfile": args.analysis_profile,
        "segmenterMinMs": 200,
        "framesEmitted": True,
        "stride": args.stride,
        "contentHash": {
            "algorithm": "sha256",
            "canonicalization": CANONICALIZATION,
            "value": content_hash,
        },
        "source": {
            "type": "pop909",
            "pop909Commit": asap_x.git(args.pop909_root.parent, "rev-parse", "HEAD"),
            "license": (
                "GATED: repository MIT, but the underlying 909 pop "
                "compositions are copyrighted (performed-input log "
                "2026-07-28-01); local uncommitted fixtures only"
            ),
        },
        "fixtures": fixtures,
    }
    (set_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )

    roster = {
        "schema": "performed-input-roster/1",
        "note": (
            "Roster in split-file shape for the stability tools. NOT a "
            "frozen split: descriptive stability replication only "
            "(performed-input log 2026-07-28-01)."
        ),
        "set": args.set_name,
        "splits": {
            "development": [
                {"id": entry["id"], "events": entry["events"]} for entry in fixtures
            ]
        },
    }
    (set_dir / "roster.json").write_text(
        json.dumps(roster, indent=1, sort_keys=True) + "\n"
    )
    print(f"{len(fixtures)} fixtures -> {set_dir}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

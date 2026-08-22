#!/usr/bin/env python3
"""Run the single final POP909 held false-display exposure.

This harness has no sample or development switch. It resolves exactly the 808
IDs in the frozen ``held`` roster, sends label-blind normalized event streams to
the pure-Dart product engine, and writes all detailed output under ``build/``.
Run it only from the committed release-candidate boundary.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import shlex
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Self

import development_exposure as shared

REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_ROOT = REPO_ROOT / "build"
ROSTER = REPO_ROOT / "research/performed-input/data/pop909-held-pool.json"
DART_BATCH = REPO_ROOT / "tool/polychord/held_exposure_batch.dart"
CONTRACT = REPO_ROOT / "research/polychord/held-exposure-v1.md"

ROSTER_SHA256 = "b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781"
POP909_COMMIT = "d83e6edba6872a704f5d3b8b32f5cb540088dae6"
REPORT_SCHEMA = "polychord-held-exposure-report/1"
PIECE_SCHEMA = "polychord-held-exposure-piece/1"
MANIFEST_SCHEMA = "polychord-held-exposure-manifest/1"
MEASUREMENT_ID = "pop909-held-product-false-display/1"
ALLOWED_DISPOSITIONS = (
    "in-scope-polychord",
    "ordinary-integrated-harmony",
    "slash-or-bass-only-structure",
    "same-root-or-duplicated-harmony",
    "pedal-or-release-artifact",
    "transient-or-serialization-artifact",
    "other-out-of-scope",
)

CONTRACT_PATHS = (
    CONTRACT,
    REPO_ROOT / "research/polychord/product-output-contract-v3.md",
    REPO_ROOT / "research/polychord/onset-register-selector-v1.md",
    REPO_ROOT / "research/polychord/product-completion-plan.md",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_product_engine.dart",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_onset_register_selector.dart",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_continuous_authorization_gate.dart",
    REPO_ROOT / "tool/polychord/development_exposure.py",
    DART_BATCH,
    Path(__file__).resolve(),
    REPO_ROOT / "tool/polychord/held_exposure_verify.py",
    ROSTER,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pop909-root", type=Path, required=True)
    parser.add_argument("--out-directory", type=Path, required=True)
    return parser.parse_args()


def held_ids(payload: dict) -> list[str]:
    sample = payload.get("sample")
    held = payload.get("held")
    if not isinstance(sample, list) or not isinstance(held, list):
        raise TypeError("sample and held rosters must be arrays")
    if any(not isinstance(value, str) or not value for value in sample + held):
        raise TypeError("roster IDs must be nonempty strings")
    if len(sample) != 101 or len(set(sample)) != 101:
        raise ValueError("sample roster must contain 101 unique IDs")
    if len(held) != 808 or len(set(held)) != 808:
        raise ValueError("held roster must contain 808 unique IDs")
    if set(sample) & set(held):
        raise ValueError("sample and held rosters overlap")
    return held


def require_output_directory(path: Path) -> Path:
    resolved = path.resolve()
    if resolved == BUILD_ROOT.resolve() or BUILD_ROOT.resolve() not in resolved.parents:
        raise ValueError("output directory must be a new child of build/")
    if resolved.exists():
        raise FileExistsError(f"output directory already exists: {resolved}")
    return resolved


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def require_clean_checkout(path: Path, expected_commit: str, name: str) -> None:
    actual = git(path, "rev-parse", "HEAD")
    if actual != expected_commit:
        raise ValueError(f"{name} commit is {actual}, expected {expected_commit}")
    if git(path, "status", "--porcelain"):
        raise ValueError(f"{name} checkout is dirty")


def runtime_version(command: list[str]) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    value = result.stdout.strip() or result.stderr.strip()
    if not value:
        raise RuntimeError(f"runtime version command returned no text: {command}")
    return value


class DartBatch:
    def __init__(self) -> None:
        self.stderr_output = ""
        self.process = subprocess.Popen(
            ["dart", "run", str(DART_BATCH.relative_to(REPO_ROOT))],
            cwd=REPO_ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

    def analyze(self, request: dict) -> dict:
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("Dart batch streams are unavailable")
        self.process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            stderr = self.process.stderr.read() if self.process.stderr else ""
            raise RuntimeError(f"Dart batch ended before a response: {stderr}")
        result = json.loads(line)
        if result.get("schema") != PIECE_SCHEMA or result.get("id") != request["id"]:
            raise ValueError("Dart batch returned an unexpected result")
        if result.get("sourceEventCount") != len(request["events"]):
            raise ValueError("Dart batch source-event accounting differs")
        return result

    def close(self) -> str:
        if self.process.stdin is not None and not self.process.stdin.closed:
            self.process.stdin.close()
        stderr = self.process.stderr.read() if self.process.stderr else ""
        return_code = self.process.wait()
        if return_code:
            raise RuntimeError(f"Dart batch exited {return_code}: {stderr}")
        self.stderr_output = stderr
        return stderr

    def __enter__(self) -> Self:
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        if self.process.poll() is None:
            if exc_type is None:
                self.close()
            else:
                self.process.terminate()
                self.process.wait()


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def canonical_sha256(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def safe_piece_filename(piece_id: str) -> str:
    return hashlib.sha256(piece_id.encode()).hexdigest()[:16] + ".json"


def add_counts(total: Counter[str], values: dict) -> None:
    for key, value in values.items():
        total[key] += value


def note_name(midi_note: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi_note % 12]}{midi_note // 12 - 1}"


def review_item(piece_id: str, source_path: Path, episode: dict) -> dict:
    selected = episode["selected"]
    return {
        "itemId": f"pop909-held:{piece_id}:display-{episode['episodeIndex']}",
        "pieceId": piece_id,
        "sourcePath": str(source_path),
        "startMs": episode["startMs"],
        "endMs": episode["endMs"],
        "durationMs": episode["durationMs"],
        "symbol": selected["symbol"],
        "soundingNotes": [note_name(note) for note in episode["soundingMidiNotes"]],
        "lowerNotes": [note_name(note) for note in selected["lower"]["midiNotes"]],
        "upperNotes": [note_name(note) for note in selected["upper"]["midiNotes"]],
        "primary": episode["primary"],
        "pedalDown": episode["pedalDown"],
        "pressedNotes": [note_name(note) for note in episode["pressedMidiNotes"]],
        "sustainedNotes": [note_name(note) for note in episode["sustainedMidiNotes"]],
        "disposition": None,
        "musicalRationale": None,
    }


def output_hashes(output_root: Path) -> dict:
    return {
        str(path.relative_to(output_root)): shared.sha256_file(path)
        for path in sorted(output_root.rglob("*"))
        if path.is_file() and path.name not in {"manifest.json", "review.json"}
    }


def main() -> int:
    args = parse_args()
    output_root = require_output_directory(args.out_directory)
    pop909_root = args.pop909_root.resolve()

    shared.require_hash(ROSTER, ROSTER_SHA256)
    roster = json.loads(ROSTER.read_text())
    song_ids = held_ids(roster)
    require_clean_checkout(pop909_root.parent, POP909_COMMIT, "POP909")
    if git(REPO_ROOT, "status", "--porcelain"):
        raise SystemExit("repository is dirty; run only from the committed boundary")

    pieces = [
        (song_id, pop909_root / song_id / f"{song_id}.mid") for song_id in song_ids
    ]
    missing = [str(path) for _, path in pieces if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"missing held MIDI files: {missing}")
    sources = [
        {"pieceId": song_id, "sha256": shared.sha256_file(path)}
        for song_id, path in pieces
    ]

    output_root.mkdir(parents=True)
    aggregate_counts: Counter[str] = Counter()
    normalization_counts: Counter[str] = Counter()
    review_items = []
    piece_index = []
    displayed_ms = 0

    with DartBatch() as dart:
        for song_id, path in pieces:
            selected_channels, projection = shared.pop909_projection(path)
            messages, end_timestamp_ms, read_counts = shared.read_midi_messages(
                path, selected_channels=selected_channels
            )
            normalized = shared.normalize_midi_messages(messages, end_timestamp_ms)
            request = {
                "id": f"pop909/{song_id}",
                "endTimestampMs": end_timestamp_ms,
                "events": normalized["events"],
                "frames": normalized["frames"],
            }
            analysis = dart.analyze(request)
            add_counts(aggregate_counts, analysis["counts"])
            add_counts(normalization_counts, read_counts)
            add_counts(normalization_counts, normalized["normalization"])
            displayed_ms += analysis["displayedMs"]
            review_items.extend(
                review_item(song_id, path, episode)
                for episode in analysis["stableEpisodes"]
            )
            payload = {
                "schema": REPORT_SCHEMA,
                "measurementId": MEASUREMENT_ID,
                "source": {
                    "pieceId": song_id,
                    "path": str(path),
                    "sha256": shared.sha256_file(path),
                    "projection": projection,
                    "readCounts": read_counts,
                    "normalization": normalized["normalization"],
                    "labelsRead": False,
                },
                "analysis": analysis,
            }
            relative = Path("pieces") / safe_piece_filename(song_id)
            write_json(output_root / relative, payload)
            piece_index.append(
                {
                    "pieceId": song_id,
                    "path": str(relative),
                    "sha256": shared.sha256_file(output_root / relative),
                }
            )

    review_items.sort(key=lambda item: item["itemId"])
    summary = {
        "schema": REPORT_SCHEMA,
        "measurementId": MEASUREMENT_ID,
        "songCount": len(song_ids),
        "stableEpisodeCount": len(review_items),
        "displayedMs": displayed_ms,
        "counts": dict(sorted(aggregate_counts.items())),
        "normalization": dict(sorted(normalization_counts.items())),
        "pieces": piece_index,
    }
    review = {
        "schema": "polychord-held-exposure-review/1",
        "allowedDispositions": list(ALLOWED_DISPOSITIONS),
        "items": review_items,
    }
    write_json(output_root / "summary.json", summary)
    write_json(output_root / "review.json", review)

    manifest = {
        "schema": MANIFEST_SCHEMA,
        "measurementId": MEASUREMENT_ID,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(sys.orig_argv),
        "workingDirectory": str(Path.cwd()),
        "repositoryCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "repositoryDirty": bool(git(REPO_ROOT, "status", "--porcelain")),
        "runtime": {
            "pythonVersion": platform.python_version(),
            "dartVersion": runtime_version(["dart", "--version"]),
            "midoVersion": importlib.metadata.version("mido"),
            "dartBatchStderr": dart.stderr_output.splitlines(),
        },
        "isolation": {
            "pop909SampleSongsOpened": 0,
            "pop909HeldSongsOpened": len(song_ids),
            "corpusLabelsSuppliedToAnalysis": False,
        },
        "source": {
            "pop909Commit": POP909_COMMIT,
            "rosterPath": str(ROSTER.relative_to(REPO_ROOT)),
            "rosterSha256": ROSTER_SHA256,
            "heldRosterSha256": canonical_sha256(song_ids),
            "midiContentSha256": canonical_sha256(sources),
            "pieces": sources,
        },
        "contracts": [
            {
                "path": str(path.relative_to(REPO_ROOT)),
                "sha256": shared.sha256_file(path),
            }
            for path in CONTRACT_PATHS
        ],
        "outputs": output_hashes(output_root),
        "adjudicationTemplate": {
            "path": "review.json",
            "sha256": shared.sha256_file(output_root / "review.json"),
        },
    }
    write_json(output_root / "manifest.json", manifest)
    if git(REPO_ROOT, "status", "--porcelain"):
        raise SystemExit("repository changed during measurement; output is invalid")
    print(
        f"{len(song_ids)} held POP909 songs; {len(review_items)} stable episodes; "
        f"{displayed_ms} displayed ms -> {output_root}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

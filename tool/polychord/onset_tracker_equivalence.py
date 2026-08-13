"""Compare Python replay and pure-Dart onset tracking on pinned fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

import frame_replay
import onset_evidence

OUTPUT_SCHEMA = "polychord-onset-tracker-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
MANIFEST_PATH = Path("research/polychord/data/frame-replay/manifest.json")
FRAME_SCHEMA_PATH = Path("research/polychord/frame-replay-schema.md")
ONSET_SCHEMA_PATH = Path("research/polychord/onset-evidence-schema.md")
PYTHON_REPLAY_PATH = Path(frame_replay.__file__).relative_to(REPO_ROOT)
PYTHON_ONSET_PATH = Path(onset_evidence.__file__).relative_to(REPO_ROOT)
DART_BATCH_PATH = Path("tool/polychord/onset_tracker_batch.dart")
DART_ONSET_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_onset_evidence.dart"
)
DART_EVENT_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_temporal_event.dart"
)
DART_TRACKING_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_onset_tracking_frame.dart"
)
DART_TRACKER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/polychord_onset_tracker.dart"
)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_output(*args: str) -> str:
    return subprocess.run(
        ("git", *args),
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def dart_version() -> str:
    result = subprocess.run(
        ("dart", "--version"),
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return (result.stdout or result.stderr).strip()


def equivalence_cases() -> list[dict]:
    """Build one complete tracker request and expected frame list per fixture."""

    manifest = frame_replay.load_json(REPO_ROOT / MANIFEST_PATH)
    fixture_paths = frame_replay.validate_manifest(REPO_ROOT / MANIFEST_PATH)
    expected_ids = [entry["id"] for entry in manifest["fixtures"]]
    cases = []
    for expected_id, fixture_path in zip(expected_ids, fixture_paths, strict=True):
        fixture = frame_replay.load_json(fixture_path)
        onset_frames = onset_evidence.replay_onset_frames(fixture)
        expected_frames = []
        for frame, onset_frame in zip(fixture["frames"], onset_frames, strict=True):
            expected_frames.append(
                {
                    "trackerEpoch": 0,
                    **frame,
                    "onsetNotes": [note.as_dict() for note in onset_frame.notes],
                }
            )
        cases.append(
            {
                "id": expected_id,
                "initialState": fixture["initialState"],
                "events": fixture["events"],
                "frames": expected_frames,
            }
        )
    return cases


def measurement_payload() -> dict:
    cases = equivalence_cases()
    process = subprocess.Popen(
        ("dart", "run", str(DART_BATCH_PATH)),
        cwd=REPO_ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    if process.stdin is None or process.stdout is None or process.stderr is None:
        raise RuntimeError("failed to open Dart batch process pipes")

    mismatches = []
    frame_count = 0
    try:
        for case in cases:
            request = {
                "id": case["id"],
                "initialState": case["initialState"],
                "events": case["events"],
            }
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
            process.stdin.flush()
            response_line = process.stdout.readline()
            if not response_line:
                stderr = process.stderr.read()
                raise RuntimeError(f"Dart batch ended before {case['id']}: {stderr}")
            response = json.loads(response_line)
            if response.get("id") != case["id"]:
                raise ValueError(f"Dart response id differs for {case['id']}")

            expected = case["frames"]
            actual = response["frames"]
            frame_count += len(expected)
            if actual != expected:
                mismatches.append(
                    {
                        "fixtureId": case["id"],
                        "python": expected,
                        "dart": actual,
                    }
                )
        process.stdin.close()
        return_code = process.wait()
        stderr = process.stderr.read()
        if return_code != 0:
            raise RuntimeError(f"Dart batch failed ({return_code}): {stderr}")
        unexpected_stderr = stderr.replace("Running build hooks...", "").strip()
        if unexpected_stderr:
            raise RuntimeError(
                f"Dart batch wrote unexpected stderr: {unexpected_stderr}"
            )
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()

    return {
        "method": {
            "fixtureManifestSchema": "polychord-frame-replay-manifest/1",
            "frameSchema": "polychord-frame-replay/1",
            "onsetSchema": "polychord-onset-evidence/1",
            "comparison": "decoded complete combined-frame-list equality",
            "caseOrder": "fixture manifest order and event order",
        },
        "summary": {
            "fixtureComparisonCount": len(cases),
            "frameComparisonCount": frame_count,
            "mismatchCount": len(mismatches),
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "fixtureManifest": MANIFEST_PATH,
        "frameSchema": FRAME_SCHEMA_PATH,
        "onsetSchema": ONSET_SCHEMA_PATH,
        "pythonReplay": PYTHON_REPLAY_PATH,
        "pythonOnset": PYTHON_ONSET_PATH,
        "dartOnsetModel": DART_ONSET_MODEL_PATH,
        "dartEventModel": DART_EVENT_MODEL_PATH,
        "dartTrackingModel": DART_TRACKING_MODEL_PATH,
        "dartTracker": DART_TRACKER_PATH,
        "dartBatch": DART_BATCH_PATH,
        "harness": HARNESS_PATH,
    }
    return {
        "schema": OUTPUT_SCHEMA,
        "source": {
            "command": command,
            "workingDirectory": str(Path.cwd().resolve()),
            "repositoryCommit": git_output("rev-parse", "HEAD"),
            "repositoryDirty": bool(git_output("status", "--porcelain")),
            "pythonVersion": platform.python_version(),
            "dartVersion": dart_version(),
            "artifacts": {
                name: {"path": str(path), "sha256": sha256_file(REPO_ROOT / path)}
                for name, path in paths.items()
            },
        },
        **payload,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = build_report([sys.executable, *sys.argv])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{summary['frameComparisonCount']} frames across "
        f"{summary['fixtureComparisonCount']} fixtures; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

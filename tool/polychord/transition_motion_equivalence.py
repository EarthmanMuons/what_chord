"""Compare Python and pure-Dart transition and motion evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

import frame_replay
import motion_support
import register_candidates
import release_pedal_evidence
import transition_evidence

OUTPUT_SCHEMA = "polychord-transition-motion-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
MANIFEST_PATH = Path("research/polychord/data/frame-replay/manifest.json")
FRAME_SCHEMA_PATH = Path("research/polychord/frame-replay-schema.md")
TRANSITION_SCHEMA_PATH = Path("research/polychord/frame-transition-evidence-schema.md")
MOTION_SCHEMA_PATH = Path("research/polychord/motion-support-ablation.md")
DART_BATCH_PATH = Path("tool/polychord/transition_motion_batch.dart")
DART_EQUIVALENCE_TEST_PATH = Path(
    "tool/polychord/transition_motion_equivalence_test.py"
)
DART_PUBLIC_API_PATH = Path("packages/whatchord/lib/whatchord.dart")
DART_TRANSITION_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/"
    "polychord_frame_transition_evidence.dart"
)
DART_MOTION_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_motion_support.dart"
)
DART_TRANSITION_ANALYZER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_frame_transition_evidence_analyzer.dart"
)
DART_MOTION_INTERPRETER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_rigid_layer_motion_interpreter.dart"
)
DART_TEST_PATH = Path(
    "packages/whatchord/test/polychord_frame_transition_motion_test.dart"
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


def _window(
    fixture: dict,
    source_index: int,
    target_index: int,
) -> dict:
    source_frame = fixture["frames"][source_index]
    target_frame = fixture["frames"][target_index]
    steps = [
        {"event": event, "frame": frame}
        for event, frame in zip(
            fixture["events"][source_index + 1 : target_index + 1],
            fixture["frames"][source_index + 1 : target_index + 1],
            strict=True,
        )
    ]
    return {
        "sourceFrame": source_frame,
        "targetFrame": target_frame,
        "elapsedMs": target_frame["timestampMs"] - source_frame["timestampMs"],
        "transitionEventCount": len(steps),
        "interveningFrameCount": len(steps) - 1,
        "transitionSteps": steps,
    }


def _expected_windows(fixture: dict) -> list[dict]:
    release_frames = release_pedal_evidence.replay_release_pedal_frames(fixture)
    result = []
    for source_index, source_frame in enumerate(release_frames[:-1]):
        source_candidates = register_candidates.generate_register_candidates(
            fixture["frames"][source_index]["soundingMidiNotes"]
        )
        for target_index in range(source_index + 1, len(release_frames)):
            target_frame = release_frames[target_index]
            target_candidates = register_candidates.generate_register_candidates(
                fixture["frames"][target_index]["soundingMidiNotes"]
            )
            transitions = [
                transition_evidence.candidate_transition(
                    source_candidate_index,
                    target_candidate_index,
                    source_candidate,
                    target_candidate,
                    source_frame,
                    target_frame,
                )
                for source_candidate_index, source_candidate in enumerate(
                    source_candidates
                )
                for target_candidate_index, target_candidate in enumerate(
                    target_candidates
                )
            ]
            result.append(
                {
                    "sourceAfterEventIndex": source_index,
                    "targetAfterEventIndex": target_index,
                    "window": _window(fixture, source_index, target_index),
                    "sourceCandidates": [
                        candidate.as_dict() for candidate in source_candidates
                    ],
                    "targetCandidates": [
                        candidate.as_dict() for candidate in target_candidates
                    ],
                    "candidateTransitions": transitions,
                    "candidateInterpretations": [
                        motion_support.interpret_transition(transition)
                        for transition in transitions
                    ],
                }
            )
    return result


def equivalence_cases() -> list[dict]:
    """Build expectations for every ordered frame pair in pinned fixtures."""

    manifest = frame_replay.load_json(REPO_ROOT / MANIFEST_PATH)
    fixture_paths = frame_replay.validate_manifest(REPO_ROOT / MANIFEST_PATH)
    expected_ids = [entry["id"] for entry in manifest["fixtures"]]
    cases = []
    for expected_id, fixture_path in zip(expected_ids, fixture_paths, strict=True):
        fixture = frame_replay.load_json(fixture_path)
        cases.append(
            {
                "id": expected_id,
                "initialState": fixture["initialState"],
                "events": fixture["events"],
                "windows": _expected_windows(fixture),
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
    window_count = 0
    transition_step_count = 0
    candidate_transition_count = 0
    hypothesis_interpretation_count = 0
    zero_elapsed_window_count = 0
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

            expected_windows = case["windows"]
            actual_windows = response["windows"]
            if len(actual_windows) != len(expected_windows):
                raise ValueError(f"Dart window count differs for {case['id']}")
            for expected, actual in zip(expected_windows, actual_windows, strict=True):
                window_count += 1
                transition_step_count += expected["window"]["transitionEventCount"]
                zero_elapsed_window_count += expected["window"]["elapsedMs"] == 0
                candidate_transition_count += len(expected["candidateTransitions"])
                hypothesis_interpretation_count += sum(
                    len(item["hypothesisInterpretations"])
                    for item in expected["candidateInterpretations"]
                )
                if actual != expected:
                    mismatches.append(
                        {
                            "fixtureId": case["id"],
                            "sourceAfterEventIndex": expected["sourceAfterEventIndex"],
                            "targetAfterEventIndex": expected["targetAfterEventIndex"],
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
            "transitionEvidenceSchema": transition_evidence.OUTPUT_SCHEMA,
            "motionSupportSchema": motion_support.OUTPUT_SCHEMA,
            "motionSupportAblationId": motion_support.ABLATION_ID,
            "comparison": (
                "decoded complete window, candidate-transition, and "
                "motion-interpretation equality"
            ),
            "endpointEnumeration": (
                "every source-target frame pair within each fixture"
            ),
        },
        "summary": {
            "fixtureComparisonCount": len(cases),
            "windowComparisonCount": window_count,
            "transitionStepComparisonCount": transition_step_count,
            "zeroElapsedWindowComparisonCount": zero_elapsed_window_count,
            "candidateTransitionComparisonCount": candidate_transition_count,
            "hypothesisInterpretationComparisonCount": (
                hypothesis_interpretation_count
            ),
            "mismatchCount": len(mismatches),
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "fixtureManifest": MANIFEST_PATH,
        "frameSchema": FRAME_SCHEMA_PATH,
        "transitionSchema": TRANSITION_SCHEMA_PATH,
        "motionSchema": MOTION_SCHEMA_PATH,
        "pythonReplay": Path(frame_replay.__file__).relative_to(REPO_ROOT),
        "pythonGenerator": Path(register_candidates.__file__).relative_to(REPO_ROOT),
        "pythonReleasePedal": Path(release_pedal_evidence.__file__).relative_to(
            REPO_ROOT
        ),
        "pythonTransition": Path(transition_evidence.__file__).relative_to(REPO_ROOT),
        "pythonMotion": Path(motion_support.__file__).relative_to(REPO_ROOT),
        "dartTransitionModel": DART_TRANSITION_MODEL_PATH,
        "dartMotionModel": DART_MOTION_MODEL_PATH,
        "dartTransitionAnalyzer": DART_TRANSITION_ANALYZER_PATH,
        "dartMotionInterpreter": DART_MOTION_INTERPRETER_PATH,
        "dartPublicApi": DART_PUBLIC_API_PATH,
        "dartTests": DART_TEST_PATH,
        "dartBatch": DART_BATCH_PATH,
        "harness": HARNESS_PATH,
        "harnessTests": DART_EQUIVALENCE_TEST_PATH,
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
        f"{summary['windowComparisonCount']} frame windows, "
        f"{summary['candidateTransitionComparisonCount']} candidate transitions, and "
        f"{summary['hypothesisInterpretationComparisonCount']} hypothesis "
        f"interpretations across {summary['fixtureComparisonCount']} fixtures; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

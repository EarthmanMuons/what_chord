"""Generate and score preregistered polychord internal-suite predictions."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

import internal_suite
import internal_suite_scorer
import register_selector

REPORT_SCHEMA = "polychord-suite-evaluation/1"
DIAGNOSTIC_SCHEMA = "polychord-suite-selector-diagnostics/1"
INPUT_CONDITION = internal_suite_scorer.INPUT_CONDITION
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
DART_BATCH_PATH = Path("tool/polychord/register_selector_batch.dart")
PREREGISTRATION_PATH = Path("research/polychord/register-selector-v1.md")

SELECTOR_FILES = {
    register_selector.FULL_SELECTOR_ID: "full-v1",
    register_selector.WITHOUT_INTEGRATED_TERTIAN_VETO_ID: (
        "without-integrated-tertian-veto-v1"
    ),
    register_selector.WITHOUT_ASSIGNMENT_VETO_ID: "without-assignment-veto-v1",
    register_selector.WITHOUT_GAP_RESOLUTION_ID: "without-gap-resolution-v1",
}
SELECTOR_IDS = tuple(SELECTOR_FILES)

PINNED_IMPLEMENTATION_PATHS = {
    "preregistration": PREREGISTRATION_PATH,
    "pythonSelector": Path("tool/polychord/register_selector.py"),
    "dartModel": Path(
        "packages/whatchord/lib/src/polychord/models/polychord_candidate.dart"
    ),
    "dartGenerator": Path(
        "packages/whatchord/lib/src/polychord/services/"
        "polychord_register_candidate_generator.dart"
    ),
    "dartSelector": Path(
        "packages/whatchord/lib/src/polychord/services/polychord_register_selector.dart"
    ),
    "dartBatch": DART_BATCH_PATH,
    "evaluationHarness": HARNESS_PATH,
    "suiteValidator": Path("tool/polychord/internal_suite.py"),
    "exactScorer": Path("tool/polychord/internal_suite_scorer.py"),
}


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


def _fixture_frames_by_id(suite: dict) -> dict[str, dict]:
    manifest_relative = suite["dependencies"]["frameReplayManifest"]["path"]
    manifest_path = REPO_ROOT / manifest_relative
    return internal_suite.load_replay_fixtures(manifest_path)


def case_frames(case: dict, fixtures: dict[str, dict]) -> list[dict]:
    """Return exact registered frames without consulting case expectations."""

    observation = case["observation"]
    kind = observation["kind"]
    if kind == "snapshot":
        return [
            {
                "frameId": "snapshot",
                "afterEventIndex": None,
                "timestampMs": None,
                "midiNotes": observation["soundingMidiNotes"],
            }
        ]

    fixture = fixtures[observation["fixtureId"]]
    if kind == "frame-replay":
        indexes = (observation["afterEventIndex"],)
    elif kind == "frame-replay-window":
        indexes = range(
            observation["firstEventIndex"],
            observation["lastEventIndex"] + 1,
        )
    else:
        raise ValueError(f"unsupported observation kind: {kind!r}")

    frames_by_index = {frame["afterEventIndex"]: frame for frame in fixture["frames"]}
    return [
        {
            "frameId": f"event-{index}",
            "afterEventIndex": index,
            "timestampMs": frames_by_index[index]["timestampMs"],
            "midiNotes": frames_by_index[index]["soundingMidiNotes"],
        }
        for index in indexes
    ]


def evaluation_frames(suite: dict) -> list[dict]:
    fixtures = _fixture_frames_by_id(suite)
    frames = []
    for case in suite["cases"]:
        for frame in case_frames(case, fixtures):
            frames.append(
                {
                    "id": f"{case['id']}/{frame['frameId']}",
                    "caseId": case["id"],
                    "observationKind": case["observation"]["kind"],
                    **frame,
                }
            )
    return frames


def dart_decisions(frames: list[dict]) -> dict[str, dict]:
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

    decisions = {}
    try:
        for frame in frames:
            request = {
                "id": frame["id"],
                "midiNotes": frame["midiNotes"],
                "selectorIds": list(SELECTOR_IDS),
            }
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
            process.stdin.flush()
            response_line = process.stdout.readline()
            if not response_line:
                stderr = process.stderr.read()
                raise RuntimeError(f"Dart batch ended before {frame['id']}: {stderr}")
            response = json.loads(response_line)
            if set(response) != {"id", "decisions"}:
                raise ValueError(f"Dart response fields differ for {frame['id']}")
            if response.get("id") != frame["id"]:
                raise ValueError(f"Dart response id differs for {frame['id']}")
            if set(response["decisions"]) != set(SELECTOR_IDS):
                raise ValueError(f"Dart selector set differs for {frame['id']}")
            decisions[frame["id"]] = response["decisions"]

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
    return decisions


def prediction_candidate(selected: dict | None) -> dict | None:
    if selected is None:
        return None
    return {
        "identity": {
            "upper": {
                "rootPc": selected["upper"]["rootPc"],
                "quality": selected["upper"]["quality"],
            },
            "lower": {
                "rootPc": selected["lower"]["rootPc"],
                "quality": selected["lower"]["quality"],
            },
        },
        "upperMidiNotes": selected["upper"]["midiNotes"],
        "lowerMidiNotes": selected["lower"]["midiNotes"],
    }


def case_prediction(observation_kind: str, decisions: list[dict]) -> dict:
    """Map one exact snapshot to the frozen scorer's case-level contract."""

    if observation_kind == "frame-replay-window":
        return {
            "selected": None,
            "reasonCodes": ["missing-register-evidence"],
        }
    if len(decisions) != 1:
        raise ValueError("a snapshot prediction requires exactly one decision")
    decision = decisions[0]
    return {
        "selected": prediction_candidate(decision["selected"]),
        "reasonCodes": decision["reasonCodes"],
    }


def evaluate_decisions(suite: dict, frames: list[dict]) -> tuple[dict, dict]:
    """Compare both implementations and build label-free suite diagnostics."""

    dart_by_frame = dart_decisions(frames)
    frame_results = []
    by_case: dict[str, list[dict]] = {case["id"]: [] for case in suite["cases"]}
    for frame in frames:
        selector_decisions = {}
        for selector_id in SELECTOR_IDS:
            python_decision = register_selector.decision_document(
                frame["midiNotes"],
                selector_id=selector_id,
            )
            dart_decision = dart_by_frame[frame["id"]][selector_id]
            if python_decision != dart_decision:
                raise ValueError(
                    "Python/Dart decision mismatch for "
                    f"{frame['id']} under {selector_id}"
                )
            selector_decisions[selector_id] = python_decision
        result = {**frame, "decisions": selector_decisions}
        frame_results.append(result)
        by_case[frame["caseId"]].append(result)

    predictions = {}
    for selector_id in SELECTOR_IDS:
        predictions[selector_id] = [
            {
                "caseId": case["id"],
                **case_prediction(
                    case["observation"]["kind"],
                    [frame["decisions"][selector_id] for frame in by_case[case["id"]]],
                ),
            }
            for case in suite["cases"]
        ]

    diagnostics = {
        "schema": DIAGNOSTIC_SCHEMA,
        "inputCondition": INPUT_CONDITION,
        "selectorIds": list(SELECTOR_IDS),
        "comparison": "decoded complete Python/Dart decision-document equality",
        "suiteFieldsSuppliedToSelectors": ["caseId", "observation"],
        "frameCount": len(frame_results),
        "decisionComparisonCount": len(frame_results) * len(SELECTOR_IDS),
        "mismatchCount": 0,
        "frames": frame_results,
    }
    return predictions, diagnostics


def prediction_payload(
    suite_sha256: str,
    selector_id: str,
    predictions: list[dict],
) -> dict:
    return {
        "schema": internal_suite_scorer.PREDICTION_SCHEMA,
        "suiteSha256": suite_sha256,
        "inputCondition": INPUT_CONDITION,
        "selectorId": selector_id,
        "predictions": predictions,
    }


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def run_evaluation(suite_path: Path, out_directory: Path, command: list[str]) -> dict:
    if out_directory.exists():
        raise FileExistsError(
            f"output directory already exists; preserve it and choose a new path: "
            f"{out_directory}"
        )
    suite_relative = suite_path.relative_to(REPO_ROOT)
    out_directory.relative_to(REPO_ROOT)

    suite = internal_suite.load_json(suite_path)
    internal_suite.validate_suite_payload(suite)
    suite_sha256 = sha256_file(suite_path)
    source = {
        "command": command,
        "workingDirectory": str(Path.cwd().resolve()),
        "repositoryCommit": git_output("rev-parse", "HEAD"),
        "repositoryDirty": bool(git_output("status", "--porcelain")),
        "pythonVersion": platform.python_version(),
        "dartVersion": dart_version(),
        "heldPop909Read": False,
        "splitApplicability": (
            "not applicable: this evaluates the frozen internal suite"
        ),
        "suite": {
            "path": str(suite_relative),
            "sha256": suite_sha256,
        },
        "suiteDependencies": suite["dependencies"],
        "implementationArtifacts": {
            name: {
                "path": str(path),
                "sha256": sha256_file(REPO_ROOT / path),
            }
            for name, path in PINNED_IMPLEMENTATION_PATHS.items()
        },
    }
    frames = evaluation_frames(suite)
    predictions_by_selector, diagnostics = evaluate_decisions(suite, frames)
    diagnostics["suiteSha256"] = suite_sha256

    out_directory.mkdir(parents=True, exist_ok=False)
    diagnostics_path = out_directory / "diagnostics.json"
    write_json(diagnostics_path, diagnostics)

    outputs = {
        "diagnostics": {
            "path": str(diagnostics_path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(diagnostics_path),
        }
    }
    scores = {}
    for selector_id, filename in SELECTOR_FILES.items():
        predictions_path = out_directory / f"predictions-{filename}.json"
        write_json(
            predictions_path,
            prediction_payload(
                suite_sha256,
                selector_id,
                predictions_by_selector[selector_id],
            ),
        )
        score = internal_suite_scorer.score_suite(suite_path, predictions_path)
        score_path = out_directory / f"score-{filename}.json"
        write_json(score_path, score)
        scores[selector_id] = score["summary"]
        outputs[f"predictions:{selector_id}"] = {
            "path": str(predictions_path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(predictions_path),
        }
        outputs[f"score:{selector_id}"] = {
            "path": str(score_path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(score_path),
        }

    manifest_path = REPO_ROOT / suite["dependencies"]["frameReplayManifest"]["path"]
    manifest = internal_suite.load_json(manifest_path)
    source["replayFixtures"] = [
        {
            "path": str((manifest_path.parent / entry["file"]).relative_to(REPO_ROOT)),
            "sha256": entry["sha256"],
        }
        for entry in manifest["fixtures"]
    ]
    report = {
        "schema": REPORT_SCHEMA,
        "source": source,
        "method": {
            "inputCondition": INPUT_CONDITION,
            "selectorIds": list(SELECTOR_IDS),
            "selectorEvidence": "registered observations only",
            "windowPrediction": (
                "frame-replay windows have no single adjacent-register snapshot "
                "and abstain with missing-register-evidence"
            ),
            "scorerId": internal_suite_scorer.SCORER_SCHEMA,
        },
        "summary": {
            "caseCount": len(suite["cases"]),
            "frameCount": diagnostics["frameCount"],
            "decisionComparisonCount": diagnostics["decisionComparisonCount"],
            "mismatchCount": 0,
            "scores": scores,
        },
        "outputs": outputs,
    }
    report_path = out_directory / "manifest.json"
    write_json(report_path, report)
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", type=Path)
    parser.add_argument("--out-directory", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = run_evaluation(
        args.suite.resolve(),
        args.out_directory.resolve(),
        [sys.executable, *sys.argv],
    )
    summary = report["summary"]
    print(
        f"{summary['decisionComparisonCount']} decisions across "
        f"{summary['caseCount']} suite cases; 0 mismatches; "
        f"results -> {args.out_directory}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Run source-independent transport controls for every prior-art adapter."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

import prior_art_baselines as baselines

SCHEMA = "polychord-prior-art-adapter-smoke/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
HARNESS_TEST_PATH = Path("tool/polychord/prior_art_baseline_test.py")
BASELINE_CONTRACT_PATH = Path("research/polychord/prior-art-baseline-contract-v1.md")
SOURCE_MANIFEST_PATH = Path("research/polychord/baselines/source-manifest-v1.json")

CONTROL_NOTES = {
    "empty": [],
    "one-note": [60],
    "two-note": [60, 67],
    "pitch-class-duplicate": [48, 60, 64, 67],
    "root-position-major": [60, 64, 67],
    "root-position-dominant-seven": [60, 64, 67, 70],
    "six-note-composite-path": [42, 46, 49, 79, 83, 86],
}


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_output(*args: str) -> str:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def controls() -> list[dict]:
    return [
        baselines.make_observation(f"smoke/{control_id}", midi_notes)
        for control_id, midi_notes in CONTROL_NOTES.items()
    ]


def _adapter_input_exact(baseline_id: str, result: dict, observation: dict) -> bool:
    if baseline_id in {
        baselines.WHATCHORD_ID,
        baselines.CHORDRECGEN_ID,
    }:
        return result["adapterInput"] == observation["orderedMidiNotes"]
    if baseline_id == baselines.MINGUS_ID:
        return result["adapterInput"] == observation["pitchClassSharps"]
    values = result["adapterInput"]
    if not isinstance(values, list) or len(values) != len(
        observation["orderedMidiNotes"]
    ):
        return False
    converted = []
    for value in values:
        if not isinstance(value, dict) or not isinstance(value.get("fields"), dict):
            return False
        fields = value["fields"]
        converted.append(
            f"{fields['base_name']}{fields['accidental'] or ''}{fields['num']}"
        )
    return converted == observation["scientificPitchSharps"]


def _alternatives_preserved(baseline_id: str, result: dict) -> bool:
    raw = result["rawReturn"]
    normalized = result["normalizedAlternatives"]
    if result["status"] != "ok":
        return not normalized
    if baseline_id == baselines.MUSICPY_ID:
        expected_count = 1
    elif baseline_id in {baselines.MINGUS_ID, baselines.CHORDRECGEN_ID}:
        expected_count = len(raw)
    else:
        expected_count = int(raw["python"]["selected"] is not None)
    return len(normalized) == expected_count and [
        value["nativeIndex"] for value in normalized
    ] == list(range(expected_count))


def smoke_payload(runtime_manifest_path: Path) -> dict:
    observations = controls()
    baseline_reports = {}
    for baseline_id in baselines.BASELINE_IDS:
        first = baselines.run_baseline(
            baseline_id,
            observations,
            runtime_manifest_path=runtime_manifest_path,
        )
        second = baselines.run_baseline(
            baseline_id,
            observations,
            runtime_manifest_path=runtime_manifest_path,
        )
        injected_result = baselines.run_baseline(
            baseline_id,
            [observations[-1]],
            runtime_manifest_path=runtime_manifest_path,
            inject_exception=True,
        )[0]
        assertions = {
            "resultCountExact": len(first) == len(observations),
            "adapterInputExact": all(
                _adapter_input_exact(baseline_id, result, observation)
                for result, observation in zip(first, observations)
            ),
            "smallInputsRetained": all(
                result["status"] in {"ok", "no-output", "exception"}
                for result in first[:3]
            ),
            "ordinaryControlsRetained": all(
                result["status"] in {"ok", "no-output"} for result in first[4:6]
            ),
            "compositePathRetained": (
                first[-1]["status"] == "ok"
                and any(
                    alternative["classification"] == "ordered-composite"
                    for alternative in first[-1]["normalizedAlternatives"]
                )
            ),
            "rawAlternativesPreserved": all(
                _alternatives_preserved(baseline_id, result) for result in first
            ),
            "injectedExceptionSerialized": (
                injected_result["status"] == "exception"
                and not injected_result["normalizedAlternatives"]
            ),
            "repeatNormalizedOutputExact": [
                baselines.deterministic_projection(value) for value in first
            ]
            == [baselines.deterministic_projection(value) for value in second],
        }
        baseline_reports[baseline_id] = {
            "assertions": assertions,
            "pass": all(assertions.values()),
            "firstRun": first,
            "secondRun": second,
            "injectedException": injected_result,
        }
    return {
        "summary": {
            "baselineCount": len(baselines.BASELINE_IDS),
            "controlCountPerBaseline": len(observations),
            "allPass": all(value["pass"] for value in baseline_reports.values()),
        },
        "controls": observations,
        "baselines": baseline_reports,
    }


def build_report(runtime_manifest_path: Path) -> dict:
    artifacts = {
        "baselineContract": BASELINE_CONTRACT_PATH,
        "sourceManifest": SOURCE_MANIFEST_PATH,
        "runtimeManifest": runtime_manifest_path.relative_to(REPO_ROOT),
        "adapter": Path(baselines.__file__).relative_to(REPO_ROOT),
        "pythonWorker": baselines.PYTHON_WORKER_PATH,
        "dartWorker": baselines.DART_WORKER_PATH,
        "harness": HARNESS_PATH,
        "harnessTests": HARNESS_TEST_PATH,
    }
    return {
        "schema": SCHEMA,
        "source": {
            "command": [sys.executable, *sys.argv],
            "workingDirectory": str(Path.cwd().resolve()),
            "repositoryCommit": git_output("rev-parse", "HEAD"),
            "repositoryDirty": bool(git_output("status", "--porcelain")),
            "pythonVersion": platform.python_version(),
            "artifacts": {
                key: {"path": str(path), "sha256": sha256_file(REPO_ROOT / path)}
                for key, path in artifacts.items()
            },
        },
        **smoke_payload(runtime_manifest_path),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--runtime-manifest",
        type=Path,
        default=baselines.RUNTIME_MANIFEST_PATH,
    )
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    runtime_manifest_path = args.runtime_manifest.resolve()
    report = build_report(runtime_manifest_path)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{summary['baselineCount']} baselines x "
        f"{summary['controlCountPerBaseline']} controls; "
        f"allPass={str(summary['allPass']).lower()} -> {args.out}"
    )
    return int(not summary["allPass"])


if __name__ == "__main__":
    raise SystemExit(main())

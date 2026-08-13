"""Compare Python and pure-Dart onset-support interpretations."""

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
import onset_support
import register_candidates

OUTPUT_SCHEMA = "polychord-onset-support-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
MANIFEST_PATH = Path("research/polychord/data/frame-replay/manifest.json")
EVIDENCE_SCHEMA_PATH = Path("research/polychord/onset-evidence-schema.md")
SUPPORT_SCHEMA_PATH = Path("research/polychord/onset-support-ablation.md")
DART_BATCH_PATH = Path("tool/polychord/onset_support_batch.dart")
DART_HARNESS_TEST_PATH = Path("tool/polychord/onset_support_equivalence_test.py")
DART_PUBLIC_API_PATH = Path("packages/whatchord/lib/whatchord.dart")
DART_EVIDENCE_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_onset_evidence.dart"
)
DART_SUPPORT_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_onset_support.dart"
)
DART_EVIDENCE_ANALYZER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_onset_evidence_analyzer.dart"
)
DART_INTERPRETER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_coherent_separated_onset_interpreter.dart"
)
DART_TEST_PATH = Path("packages/whatchord/test/polychord_onset_support_test.dart")


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
    """Build one complete Python interpretation expectation per frame."""

    manifest = frame_replay.load_json(REPO_ROOT / MANIFEST_PATH)
    fixture_paths = frame_replay.validate_manifest(REPO_ROOT / MANIFEST_PATH)
    expected_ids = [entry["id"] for entry in manifest["fixtures"]]
    cases = []
    for expected_id, fixture_path in zip(expected_ids, fixture_paths, strict=True):
        fixture = frame_replay.load_json(fixture_path)
        onset_frames = onset_evidence.replay_onset_frames(fixture)
        for frame, onset_frame in zip(fixture["frames"], onset_frames, strict=True):
            candidates = register_candidates.generate_register_candidates(
                frame["soundingMidiNotes"]
            )
            interpretations = []
            for candidate in candidates:
                evidence = onset_evidence.candidate_onset_evidence(
                    candidate, onset_frame
                )
                interpretations.append(
                    {
                        "candidate": evidence["candidate"],
                        "onsetEvidence": evidence["onsetEvidence"],
                        "onsetInterpretation": onset_support.interpret_onset_evidence(
                            evidence["onsetEvidence"]
                        ),
                    }
                )
            cases.append(
                {
                    "id": f"{expected_id}/{frame['afterEventIndex']}",
                    "fixtureId": expected_id,
                    "afterEventIndex": frame["afterEventIndex"],
                    "soundingNotes": [note.as_dict() for note in onset_frame.notes],
                    "candidateInterpretations": interpretations,
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
    interpretation_count = 0
    complete_count = 0
    incomplete_count = 0
    positive_count = 0
    neutral_count = 0
    try:
        for case in cases:
            request = {"id": case["id"], "soundingNotes": case["soundingNotes"]}
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
            process.stdin.flush()
            response_line = process.stdout.readline()
            if not response_line:
                stderr = process.stderr.read()
                raise RuntimeError(f"Dart batch ended before {case['id']}: {stderr}")
            response = json.loads(response_line)
            if response.get("id") != case["id"]:
                raise ValueError(f"Dart response id differs for {case['id']}")

            expected = case["candidateInterpretations"]
            actual = response["candidateInterpretations"]
            interpretation_count += len(expected)
            for item in expected:
                interpretation = item["onsetInterpretation"]
                complete_count += interpretation["availability"] == "complete"
                incomplete_count += interpretation["availability"] == "incomplete"
                positive_count += interpretation["onsetCohortSupport"] == "positive"
                neutral_count += interpretation["onsetCohortSupport"] == "neutral"
            if actual != expected:
                mismatches.append(
                    {
                        "caseId": case["id"],
                        "fixtureId": case["fixtureId"],
                        "afterEventIndex": case["afterEventIndex"],
                        "soundingNotes": case["soundingNotes"],
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
            "onsetEvidenceSchema": onset_evidence.OUTPUT_SCHEMA,
            "onsetSupportSchema": onset_support.OUTPUT_SCHEMA,
            "onsetSupportAblationId": onset_support.ABLATION_ID,
            "comparison": (
                "decoded complete candidate-evidence and onset-interpretation "
                "list equality"
            ),
            "caseOrder": "manifest fixture order followed by frame order",
        },
        "summary": {
            "fixtureCount": len({case["fixtureId"] for case in cases}),
            "frameComparisonCount": len(cases),
            "candidateInterpretationComparisonCount": interpretation_count,
            "completeInterpretationCount": complete_count,
            "incompleteInterpretationCount": incomplete_count,
            "positiveInterpretationCount": positive_count,
            "neutralInterpretationCount": neutral_count,
            "mismatchCount": len(mismatches),
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "fixtureManifest": MANIFEST_PATH,
        "evidenceSchema": EVIDENCE_SCHEMA_PATH,
        "supportSchema": SUPPORT_SCHEMA_PATH,
        "pythonReplay": Path(frame_replay.__file__).relative_to(REPO_ROOT),
        "pythonGenerator": Path(register_candidates.__file__).relative_to(REPO_ROOT),
        "pythonEvidence": Path(onset_evidence.__file__).relative_to(REPO_ROOT),
        "pythonSupport": Path(onset_support.__file__).relative_to(REPO_ROOT),
        "dartPublicApi": DART_PUBLIC_API_PATH,
        "dartEvidenceModel": DART_EVIDENCE_MODEL_PATH,
        "dartSupportModel": DART_SUPPORT_MODEL_PATH,
        "dartEvidenceAnalyzer": DART_EVIDENCE_ANALYZER_PATH,
        "dartInterpreter": DART_INTERPRETER_PATH,
        "dartTests": DART_TEST_PATH,
        "dartBatch": DART_BATCH_PATH,
        "harness": HARNESS_PATH,
        "harnessTests": DART_HARNESS_TEST_PATH,
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
        f"{summary['frameComparisonCount']} frames and "
        f"{summary['candidateInterpretationComparisonCount']} candidate "
        f"interpretations across {summary['fixtureCount']} fixtures; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

"""Compare Python and pure-Dart onset evidence on every pinned replay frame."""

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
import register_candidates

OUTPUT_SCHEMA = "polychord-onset-evidence-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
MANIFEST_PATH = Path("research/polychord/data/frame-replay/manifest.json")
SCHEMA_PATH = Path("research/polychord/onset-evidence-schema.md")
PYTHON_EVIDENCE_PATH = Path(onset_evidence.__file__).relative_to(REPO_ROOT)
PYTHON_GENERATOR_PATH = Path(register_candidates.__file__).relative_to(REPO_ROOT)
DART_BATCH_PATH = Path("tool/polychord/onset_evidence_batch.dart")
DART_CANDIDATE_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_candidate.dart"
)
DART_GENERATOR_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_register_candidate_generator.dart"
)
DART_EVIDENCE_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_onset_evidence.dart"
)
DART_EVIDENCE_ANALYZER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_onset_evidence_analyzer.dart"
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
    """Build one complete Python evidence expectation per manifest frame."""

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
            cases.append(
                {
                    "id": f"{expected_id}/{frame['afterEventIndex']}",
                    "fixtureId": expected_id,
                    "afterEventIndex": frame["afterEventIndex"],
                    "soundingNotes": [note.as_dict() for note in onset_frame.notes],
                    "candidateEvidence": [
                        onset_evidence.candidate_onset_evidence(candidate, onset_frame)
                        for candidate in candidates
                    ],
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
    candidate_record_count = 0
    candidate_frame_count = 0
    try:
        for case in cases:
            request = {
                "id": case["id"],
                "soundingNotes": case["soundingNotes"],
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

            expected = case["candidateEvidence"]
            actual = response["candidateEvidence"]
            candidate_record_count += len(expected)
            candidate_frame_count += bool(expected)
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
            "evidenceSchema": "polychord-onset-evidence/1",
            "comparison": "decoded complete candidate-evidence-list equality",
            "caseOrder": "manifest fixture order followed by frame order",
        },
        "summary": {
            "fixtureCount": len({case["fixtureId"] for case in cases}),
            "frameComparisonCount": len(cases),
            "candidateFrameCount": candidate_frame_count,
            "candidateEvidenceRecordCount": candidate_record_count,
            "mismatchCount": len(mismatches),
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "fixtureManifest": MANIFEST_PATH,
        "schema": SCHEMA_PATH,
        "pythonGenerator": PYTHON_GENERATOR_PATH,
        "pythonEvidence": PYTHON_EVIDENCE_PATH,
        "dartCandidateModel": DART_CANDIDATE_MODEL_PATH,
        "dartGenerator": DART_GENERATOR_PATH,
        "dartEvidenceModel": DART_EVIDENCE_MODEL_PATH,
        "dartEvidenceAnalyzer": DART_EVIDENCE_ANALYZER_PATH,
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
        f"{summary['frameComparisonCount']} frames and "
        f"{summary['candidateEvidenceRecordCount']} candidate records; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

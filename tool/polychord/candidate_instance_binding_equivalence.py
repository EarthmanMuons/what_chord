"""Compare Python and pure-Dart candidate-instance bindings."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

import automatic_timing_sensitivity
import frame_replay
import onset_evidence
import register_candidates

OUTPUT_SCHEMA = "polychord-candidate-instance-binding-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
MANIFEST_PATH = Path("research/polychord/data/frame-replay/manifest.json")
OUTPUT_CONTRACT_PATH = Path("research/polychord/automatic-output-contract-v2.md")
DART_BATCH_PATH = Path("tool/polychord/candidate_instance_binding_batch.dart")
DART_HARNESS_TEST_PATH = Path(
    "tool/polychord/candidate_instance_binding_equivalence_test.py"
)
DART_PUBLIC_API_PATH = Path("packages/whatchord/lib/whatchord.dart")
DART_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/"
    "polychord_candidate_instance_binding.dart"
)
DART_BINDER_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_candidate_instance_binder.dart"
)
DART_TEST_PATH = Path(
    "packages/whatchord/test/polychord_candidate_instance_binding_test.dart"
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


def binding_from_python_opportunity(item: dict, tracker_epoch: int) -> dict:
    """Adapt the existing Python opportunity key to the frozen v2 shape."""

    opportunity = automatic_timing_sensitivity.opportunity_key(item)
    layer_binding = opportunity["soundingInstanceBinding"]
    instances = sorted(
        layer_binding["lower"] + layer_binding["upper"],
        key=lambda instance: instance["midiNote"],
    )
    return {
        "trackerEpoch": tracker_epoch,
        "candidate": opportunity["candidate"],
        "targetInstances": instances,
        "availability": (
            "complete"
            if all(instance["onsetEventIndex"] is not None for instance in instances)
            else "incomplete"
        ),
    }


def equivalence_cases() -> list[dict]:
    """Build bindings for every pinned frame and one incomplete control."""

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
            items = [
                onset_evidence.candidate_onset_evidence(candidate, onset_frame)
                for candidate in candidates
            ]
            cases.append(
                {
                    "id": f"{expected_id}/{frame['afterEventIndex']}",
                    "fixtureId": expected_id,
                    "afterEventIndex": frame["afterEventIndex"],
                    "frame": {
                        "trackerEpoch": 0,
                        "afterEventIndex": frame["afterEventIndex"],
                        "timestampMs": frame["timestampMs"],
                        "pedalDown": frame["pedalDown"],
                        "soundingNotes": [note.as_dict() for note in onset_frame.notes],
                    },
                    "candidateBindings": [
                        binding_from_python_opportunity(item, 0) for item in items
                    ],
                }
            )
    incomplete_notes = tuple(
        onset_evidence.SoundingNoteOnset(
            midi_note=midi_note,
            sounding_state="pressed",
            origin=None,
        )
        for midi_note in (43, 46, 50, 60, 64, 67)
    )
    incomplete_frame = onset_evidence.OnsetFrame(
        after_event_index=0,
        timestamp_ms=0,
        notes=incomplete_notes,
    )
    incomplete_candidates = register_candidates.generate_register_candidates(
        [note.midi_note for note in incomplete_notes]
    )
    incomplete_items = [
        onset_evidence.candidate_onset_evidence(candidate, incomplete_frame)
        for candidate in incomplete_candidates
    ]
    cases.append(
        {
            "id": "synthetic-carried-in/0",
            "fixtureId": None,
            "afterEventIndex": 0,
            "frame": {
                "trackerEpoch": 7,
                "afterEventIndex": 0,
                "timestampMs": 0,
                "pedalDown": False,
                "soundingNotes": [note.as_dict() for note in incomplete_notes],
            },
            "candidateBindings": [
                binding_from_python_opportunity(item, 7) for item in incomplete_items
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
    binding_count = 0
    complete_count = 0
    incomplete_count = 0
    try:
        for case in cases:
            request = {
                "id": case["id"],
                "frame": case["frame"],
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

            expected = case["candidateBindings"]
            actual = response["candidateBindings"]
            binding_count += len(expected)
            complete_count += sum(
                item["availability"] == "complete" for item in expected
            )
            incomplete_count += sum(
                item["availability"] == "incomplete" for item in expected
            )
            if actual != expected:
                mismatches.append(
                    {
                        "caseId": case["id"],
                        "fixtureId": case["fixtureId"],
                        "afterEventIndex": case["afterEventIndex"],
                        "frame": case["frame"],
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
            "outputContract": "polychord-output/2",
            "syntheticControl": (
                "one complete structural candidate with six carried-in onset "
                "identifiers and nonzero tracker epoch"
            ),
            "pythonReference": (
                "automatic_timing_sensitivity.opportunity_key adapted with "
                "tracker epoch and flattened sorted instances"
            ),
            "comparison": "decoded complete candidate-binding list equality",
            "caseOrder": "manifest fixture order followed by frame order",
        },
        "summary": {
            "fixtureCount": len(
                {case["fixtureId"] for case in cases if case["fixtureId"] is not None}
            ),
            "frameComparisonCount": len(cases),
            "pinnedFrameComparisonCount": sum(
                case["fixtureId"] is not None for case in cases
            ),
            "syntheticFrameComparisonCount": sum(
                case["fixtureId"] is None for case in cases
            ),
            "candidateBindingComparisonCount": binding_count,
            "completeBindingCount": complete_count,
            "incompleteBindingCount": incomplete_count,
            "mismatchCount": len(mismatches),
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "fixtureManifest": MANIFEST_PATH,
        "outputContract": OUTPUT_CONTRACT_PATH,
        "pythonReplay": Path(frame_replay.__file__).relative_to(REPO_ROOT),
        "pythonGenerator": Path(register_candidates.__file__).relative_to(REPO_ROOT),
        "pythonEvidence": Path(onset_evidence.__file__).relative_to(REPO_ROOT),
        "pythonOpportunityKey": Path(automatic_timing_sensitivity.__file__).relative_to(
            REPO_ROOT
        ),
        "dartPublicApi": DART_PUBLIC_API_PATH,
        "dartModel": DART_MODEL_PATH,
        "dartInstanceKey": Path(
            "packages/whatchord/lib/src/polychord/models/"
            "polychord_sounding_instance_key.dart"
        ),
        "dartBinder": DART_BINDER_PATH,
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
        f"{summary['candidateBindingComparisonCount']} candidate bindings "
        f"across {summary['fixtureCount']} fixtures; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

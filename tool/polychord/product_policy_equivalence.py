"""Compare Python and pure-Dart automatic polychord product policy paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from collections import Counter
from collections.abc import Iterator
from pathlib import Path

import onset_evidence
import product_policy
import product_suite
import register_conformance

OUTPUT_SCHEMA = "polychord-product-policy-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
HARNESS_TEST_PATH = Path("tool/polychord/product_policy_equivalence_test.py")
SUITE_PATH = Path("research/polychord/data/product-suite/suite-v0.json")
FIXTURE_MANIFEST_PATH = Path(
    "research/polychord/data/product-suite/fixture-manifest.json"
)
OUTPUT_CONTRACT_PATH = Path("research/polychord/product-output-contract-v3.md")
SELECTOR_SPECIFICATION_PATH = Path("research/polychord/onset-register-selector-v1.md")
DART_BATCH_PATH = Path("tool/polychord/product_policy_batch.dart")
DART_PUBLIC_API_PATH = Path("packages/whatchord/lib/whatchord.dart")
DART_DECISION_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_product_decision.dart"
)
DART_OUTPUT_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_product_output.dart"
)
DART_CUE_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/"
    "polychord_product_onset_cue_record.dart"
)
DART_SELECTOR_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_onset_register_selector.dart"
)
DART_ENGINE_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/polychord_product_engine.dart"
)
DART_GATE_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_continuous_authorization_gate.dart"
)
DART_TEST_PATH = Path("packages/whatchord/test/polychord_product_policy_test.dart")


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


def _stripped_action(action: dict) -> dict:
    """Remove every checkpoint and expectation from a Dart session request."""

    return {
        "id": action["id"],
        "type": action["type"],
        "timestampMs": action["timestampMs"],
        "eventIndex": action["eventIndex"],
        "displayable": action["displayable"],
    }


def session_cases() -> list[dict]:
    """Build expectation-free requests and independent Python observations."""

    suite = product_suite.validate_suite(
        REPO_ROOT / SUITE_PATH,
        require_scoring_allowed=True,
    )
    fixtures = product_suite.validate_fixture_manifest(
        REPO_ROOT / FIXTURE_MANIFEST_PATH
    )
    cases = []
    for case in suite["cases"]:
        fixture = fixtures[case["fixtureId"]]["fixture"]
        onset_frames = onset_evidence.replay_onset_frames(fixture)
        session = product_policy.ProductPolicySession(
            initial_primary_displayable=case["initialPrimaryDisplayable"]
        )
        observations = []
        for action in case["actions"]:
            timestamp_ms = action["timestampMs"]
            if action["type"] == "musicalEvent":
                event_index = action["eventIndex"]
                if fixture["events"][event_index]["timestampMs"] != timestamp_ms:
                    raise ValueError(
                        f"{case['id']} action timestamp differs from event"
                    )
                observation = session.observe_frame(
                    tracker_epoch=0,
                    frame=fixture["frames"][event_index],
                    onset_frame=onset_frames[event_index],
                )
            elif action["type"] == "timer":
                observation = session.observe_timer(timestamp_ms)
            elif action["type"] == "primaryAvailability":
                observation = session.set_primary_displayable(
                    timestamp_ms=timestamp_ms,
                    displayable=action["displayable"],
                )
            elif action["type"] == "trackerReset":
                observation = session.reset(timestamp_ms)
            else:
                raise ValueError(f"unsupported product action: {action['type']!r}")
            observations.append({"actionId": action["id"], "observation": observation})
        cases.append(
            {
                "id": case["id"],
                "request": {
                    "id": case["id"],
                    "mode": "session",
                    "initialState": fixture["initialState"],
                    "initialPrimaryDisplayable": case["initialPrimaryDisplayable"],
                    "events": fixture["events"],
                    "actions": [_stripped_action(action) for action in case["actions"]],
                },
                "observations": observations,
            }
        )
    return cases


def _structural_frame(
    *, lower_notes: tuple[int, ...], upper_notes: tuple[int, ...]
) -> tuple[dict, onset_evidence.OnsetFrame]:
    midi_notes = sorted((*lower_notes, *upper_notes))
    origin_by_note = {}
    for event_index, midi_note in enumerate((*lower_notes, *upper_notes)):
        origin_by_note[midi_note] = onset_evidence.OnsetOrigin(
            event_index=event_index,
            timestamp_ms=0 if midi_note in lower_notes else 80,
            velocity=80,
        )
    onset_frame = onset_evidence.OnsetFrame(
        after_event_index=len(midi_notes) - 1,
        timestamp_ms=80,
        notes=tuple(
            onset_evidence.SoundingNoteOnset(
                midi_note=midi_note,
                sounding_state="pressed",
                origin=origin_by_note[midi_note],
            )
            for midi_note in midi_notes
        ),
    )
    replay_frame = {
        "afterEventIndex": onset_frame.after_event_index,
        "timestampMs": 80,
        "pressedMidiNotes": midi_notes,
        "sustainedMidiNotes": [],
        "soundingMidiNotes": midi_notes,
        "pedalDown": False,
    }
    return (
        product_policy.frame_document(
            tracker_epoch=0,
            frame=replay_frame,
            onset_frame=onset_frame,
        ),
        onset_frame,
    )


def structural_controls() -> Iterator[dict]:
    """Cover every symmetric vocabulary pair, root relation, and transposition."""

    for lower_quality in register_conformance.QUALITIES:
        for upper_quality in register_conformance.QUALITIES:
            for interval in register_conformance.RELATIVE_ROOT_INTERVALS:
                for transposition in register_conformance.TRANSPOSITIONS:
                    lower_notes = register_conformance.root_position_notes(
                        transposition,
                        lower_quality,
                        36,
                    )
                    upper_notes = register_conformance.root_position_notes(
                        (transposition + interval) % 12,
                        upper_quality,
                        72,
                    )
                    frame, onset_frame = _structural_frame(
                        lower_notes=lower_notes,
                        upper_notes=upper_notes,
                    )
                    case_id = (
                        f"matrix/{lower_quality}/{upper_quality}/"
                        f"{interval}/{transposition}"
                    )
                    yield {
                        "id": case_id,
                        "request": {"id": case_id, "mode": "decision", "frame": frame},
                        "decision": product_policy.decision_document(
                            observation=frame,
                            onset_frame=onset_frame,
                        ),
                    }


def _unexpected_stderr(stderr: str) -> str:
    return stderr.replace("Running build hooks...", "").strip()


def measurement_payload() -> dict:
    sessions = session_cases()
    controls = list(structural_controls())
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
    outcomes: Counter[str] = Counter()
    try:
        for case in (*sessions, *controls):
            process.stdin.write(
                json.dumps(case["request"], separators=(",", ":")) + "\n"
            )
            process.stdin.flush()
            response_line = process.stdout.readline()
            if not response_line:
                stderr = process.stderr.read()
                raise RuntimeError(f"Dart batch ended before {case['id']}: {stderr}")
            response = json.loads(response_line)
            if response.get("id") != case["id"]:
                raise ValueError(f"Dart response id differs for {case['id']}")
            if case["request"]["mode"] == "session":
                expected = case["observations"]
                actual = response["observations"]
            else:
                expected = case["decision"]
                actual = response["decision"]
                outcome = expected["reasonCode"] or "selected"
                outcomes[outcome] += 1
                if len(expected["stageSurvivors"]["positiveSupport"]) > 1:
                    raise AssertionError("Python positive-survivor uniqueness failed")
            if actual != expected:
                mismatches.append(
                    {
                        "caseId": case["id"],
                        "mode": case["request"]["mode"],
                        "python": expected,
                        "dart": actual,
                    }
                )
        process.stdin.close()
        return_code = process.wait()
        stderr = process.stderr.read()
        if return_code != 0:
            raise RuntimeError(f"Dart batch failed ({return_code}): {stderr}")
        unexpected = _unexpected_stderr(stderr)
        if unexpected:
            raise RuntimeError(f"Dart batch wrote unexpected stderr: {unexpected}")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()

    return {
        "method": {
            "outputSchema": product_policy.OUTPUT_SCHEMA,
            "selectorId": product_policy.SELECTOR_ID,
            "cueId": product_policy.CUE_ID,
            "displayId": product_policy.DISPLAY_ID,
            "sessionInput": (
                "frozen product fixtures and action scripts with all checkpoint "
                "expectations removed"
            ),
            "structuralInput": register_conformance.OUTPUT_SCHEMA,
            "comparison": (
                "decoded complete product-observation and raw-decision equality"
            ),
        },
        "summary": {
            "sessionComparisonCount": len(sessions),
            "sessionActionComparisonCount": sum(
                len(case["observations"]) for case in sessions
            ),
            "structuralDecisionComparisonCount": len(controls),
            "totalComparisonCount": len(sessions) + len(controls),
            "mismatchCount": len(mismatches),
        },
        "structuralOutcomes": {key: outcomes[key] for key in sorted(outcomes)},
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "productSuite": SUITE_PATH,
        "productFixtureManifest": FIXTURE_MANIFEST_PATH,
        "outputContract": OUTPUT_CONTRACT_PATH,
        "selectorSpecification": SELECTOR_SPECIFICATION_PATH,
        "pythonPolicy": Path(product_policy.__file__).relative_to(REPO_ROOT),
        "pythonHarness": HARNESS_PATH,
        "pythonHarnessTests": HARNESS_TEST_PATH,
        "dartPublicApi": DART_PUBLIC_API_PATH,
        "dartCueModel": DART_CUE_MODEL_PATH,
        "dartDecisionModel": DART_DECISION_MODEL_PATH,
        "dartOutputModel": DART_OUTPUT_MODEL_PATH,
        "dartSelector": DART_SELECTOR_PATH,
        "dartDisplayGate": DART_GATE_PATH,
        "dartEngine": DART_ENGINE_PATH,
        "dartBatch": DART_BATCH_PATH,
        "dartTests": DART_TEST_PATH,
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
        f"{summary['sessionActionComparisonCount']} product actions and "
        f"{summary['structuralDecisionComparisonCount']} structural decisions; "
        f"{summary['mismatchCount']} mismatches -> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

"""Project pure-Dart product output into the frozen scorer document shape."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import product_suite

PREDICTION_SCHEMA = "polychord-product-predictions/1"
PRODUCER_ID = "whatchord-polychord-product-dart/1"
REPO_ROOT = Path(__file__).parents[2]
SUITE_PATH = Path("research/polychord/data/product-suite/suite-v0.json")
FIXTURE_MANIFEST_PATH = Path(
    "research/polychord/data/product-suite/fixture-manifest.json"
)
DART_BATCH_PATH = Path("tool/polychord/product_policy_batch.dart")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_json(value: object) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def _action_request(action: dict) -> dict:
    return {
        "id": action["id"],
        "type": action["type"],
        "timestampMs": action["timestampMs"],
        "eventIndex": action["eventIndex"],
        "displayable": action["displayable"],
    }


def session_requests(suite_path: Path = REPO_ROOT / SUITE_PATH) -> list[dict]:
    """Build Dart requests with every expected value removed."""

    suite = product_suite.validate_suite(suite_path, require_scoring_allowed=True)
    fixtures = product_suite.validate_fixture_manifest(
        REPO_ROOT / FIXTURE_MANIFEST_PATH
    )
    requests = []
    for case in suite["cases"]:
        fixture = fixtures[case["fixtureId"]]["fixture"]
        requests.append(
            {
                "caseId": case["id"],
                "construction": case["constructionExpectation"],
                "checkpointActionIds": [
                    action["id"]
                    for action in case["actions"]
                    if action["checkpoint"] is not False
                ],
                "request": {
                    "id": case["id"],
                    "mode": "session",
                    "initialState": fixture["initialState"],
                    "initialPrimaryDisplayable": case["initialPrimaryDisplayable"],
                    "events": fixture["events"],
                    "actions": [_action_request(action) for action in case["actions"]],
                },
            }
        )
    return requests


def _candidate_id(candidate: dict, identifiers: dict[str, str]) -> str:
    key = canonical_json(candidate)
    if key not in identifiers:
        identifiers[key] = f"candidate-{len(identifiers) + 1}"
    return identifiers[key]


def _existing_candidate_id(candidate: dict, identifiers: dict[str, str]) -> str:
    key = canonical_json(candidate)
    if key not in identifiers:
        raise ValueError("product output referenced an unenumerated candidate")
    return identifiers[key]


def _binding(binding: dict) -> list[dict]:
    return [
        {
            "midiNote": item["midiNote"],
            "onsetEventIndex": item["onsetEventIndex"],
        }
        for item in binding["targetInstances"]
    ]


def _key(value: dict | None, identifiers: dict[str, str]) -> dict | None:
    if value is None:
        return None
    return {
        "trackerEpoch": value["trackerEpoch"],
        "candidateId": _existing_candidate_id(value["candidate"], identifiers),
        "binding": _binding(value),
    }


def _frame(value: dict | None) -> dict | None:
    if value is None:
        return None
    return {
        "trackerEpoch": value["trackerEpoch"],
        "afterEventIndex": value["afterEventIndex"],
        "timestampMs": value["timestampMs"],
        "pressedMidiNotes": value["pressedMidiNotes"],
        "sustainedMidiNotes": value["sustainedMidiNotes"],
        "soundingMidiNotes": value["soundingMidiNotes"],
        "pedalDown": value["pedalDown"],
        "onsetNotes": [
            {
                "midiNote": note["midiNote"],
                "soundingState": note["soundingState"],
                "onsetEventIndex": note["onsetEventIndex"],
            }
            for note in value["onsetNotes"]
        ],
    }


def _cue_record(value: dict, identifiers: dict[str, str]) -> dict:
    interpretation = value["diagnostic"]["onsetInterpretation"]
    evidence = value["diagnostic"]["onsetEvidence"]

    def layer(name: str) -> dict:
        source = evidence[name]
        return {
            "earliestOnsetMs": source["earliestKnownOnsetMs"],
            "latestOnsetMs": source["latestKnownOnsetMs"],
            "spanMs": source["knownOnsetSpanMs"],
            "withinMaximum": interpretation[f"{name}WithinCohortSpanMaximum"],
        }

    return {
        "candidateId": _existing_candidate_id(
            value["targetBinding"]["candidate"], identifiers
        ),
        "binding": _binding(value["targetBinding"]),
        "availability": value["availability"],
        "support": value["support"],
        "lower": layer("lower"),
        "upper": layer("upper"),
        "layerOnsetOrder": interpretation["layerOnsetOrder"],
        "betweenLayerGapMs": interpretation["betweenLayerOnsetIntervalGapMs"],
        "reasonCodes": value["reasonCodes"],
    }


def _raw_decision(value: dict | None, identifiers: dict[str, str]) -> dict | None:
    if value is None:
        return None

    def candidate_ids(candidates: list[dict]) -> list[str]:
        return [
            _existing_candidate_id(candidate, identifiers) for candidate in candidates
        ]

    return {
        "stageSurvivors": {
            stage: candidate_ids(value["stageSurvivors"][stage])
            for stage in (
                "structural",
                "assignment",
                "integrated",
                "positiveSupport",
            )
        },
        "candidateTraces": [
            {
                "candidateId": _existing_candidate_id(trace["candidate"], identifiers),
                "identityAssignmentCount": trace["identityAssignmentCount"],
                "integratedTertian": trace["integratedTertian"],
                "aggregateSupport": trace["aggregateSupport"],
                "removedAt": trace["removedAt"],
                "selected": trace["selected"],
            }
            for trace in value["candidateTraces"]
        ],
        "selectedCandidateId": (
            None
            if value["selected"] is None
            else _existing_candidate_id(value["selected"], identifiers)
        ),
        "reason": value["reasonCode"],
    }


def project_observation(
    value: dict,
    *,
    construction: dict,
    identifiers: dict[str, str],
) -> dict:
    for candidate in value["candidates"]:
        _candidate_id(candidate, identifiers)
    authorization = value["authorization"]
    display = value["display"]
    return {
        # Construction is suite-owned evaluation metadata. It is attached only
        # after execution and is never included in the Dart request.
        "construction": construction,
        "observationTimestampMs": value["observationTimestampMs"],
        "frame": _frame(value["frame"]),
        "candidates": [
            _existing_candidate_id(candidate, identifiers)
            for candidate in value["candidates"]
        ],
        "cueRecords": [
            _cue_record(record, identifiers) for record in value["candidateRecords"]
        ],
        "rawDecision": _raw_decision(value["rawDecision"], identifiers),
        "authorization": (
            None
            if authorization is None
            else {
                "key": _key(authorization["key"], identifiers),
                "reason": authorization["reasonCode"],
            }
        ),
        "display": {
            "state": display["state"],
            "transition": display["transition"],
            "key": _key(display["key"], identifiers),
            "deadlineMs": display["deadlineMs"],
            "reason": display["reasonCode"],
        },
    }


def project_case(case: dict, observations: list[dict]) -> dict:
    if len(observations) != len(case["request"]["actions"]):
        raise ValueError("Dart product response does not cover every action")
    identifiers: dict[str, str] = {}
    checkpoint_ids = set(case["checkpointActionIds"])
    checkpoints = []
    for action, item in zip(case["request"]["actions"], observations):
        if item["actionId"] != action["id"]:
            raise ValueError("Dart product action order differs")
        observation = item["observation"]
        if action["id"] in checkpoint_ids:
            checkpoints.append(
                {
                    "actionId": action["id"],
                    "observation": project_observation(
                        observation,
                        construction=case["construction"],
                        identifiers=identifiers,
                    ),
                }
            )
        else:
            for candidate in observation["candidates"]:
                _candidate_id(candidate, identifiers)
    return {"caseId": case["caseId"], "checkpoints": checkpoints}


def produce(suite_path: Path = REPO_ROOT / SUITE_PATH) -> dict:
    cases = session_requests(suite_path)
    process = subprocess.run(
        ["dart", "run", str(DART_BATCH_PATH)],
        cwd=REPO_ROOT,
        input="\n".join(canonical_json(case["request"]) for case in cases) + "\n",
        capture_output=True,
        text=True,
        check=True,
    )
    unexpected_stderr = process.stderr.replace("Running build hooks...", "").strip()
    if unexpected_stderr:
        raise RuntimeError(f"Dart product worker stderr: {unexpected_stderr}")
    lines = process.stdout.splitlines()
    if len(lines) != len(cases):
        raise RuntimeError("Dart product response count differs")
    projected = []
    for case, line in zip(cases, lines):
        response = json.loads(line)
        if response.get("id") != case["caseId"]:
            raise ValueError("Dart product case ID differs")
        projected.append(project_case(case, response["observations"]))
    suite = product_suite.validate_suite(suite_path, require_scoring_allowed=True)
    return {
        "schema": PREDICTION_SCHEMA,
        "suiteSha256": sha256_file(suite_path),
        "versionIds": suite["versionIds"],
        "producerId": PRODUCER_ID,
        "cases": projected,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", type=Path, default=SUITE_PATH)
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = produce(args.suite.resolve())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    checkpoint_count = sum(len(case["checkpoints"]) for case in payload["cases"])
    print(
        f"projected {len(payload['cases'])} cases and {checkpoint_count} "
        f"checkpoints -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

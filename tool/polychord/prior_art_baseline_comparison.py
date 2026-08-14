"""Run the frozen polychord prior-art comparison without leaking expectations."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from collections.abc import Callable
from pathlib import Path

import internal_suite
import prior_art_baselines
import product_suite

COMPARISON_SCHEMA = "polychord-prior-art-comparison/1"
INPUT_SCHEMA = "polychord-prior-art-comparison-inputs/1"
TASK_NAMED = "named-snapshot/1"
TASK_STREAM = "adapted-stream/1"
REPO_ROOT = Path(__file__).parents[2]
SUITE_PATH = Path("research/polychord/data/product-suite/suite-v0.json")
CONTRACT_PATH = Path("research/polychord/prior-art-baseline-contract-v1.md")
ADAPTER_FREEZE_PATH = Path("research/polychord/baselines/adapter-freeze-v1.json")
COMPARISON_FREEZE_PATH = Path("research/polychord/baselines/comparison-freeze-v1.json")
RUNTIME_MANIFEST_PATH = Path(
    "build/polychord/prior-art-env-v1/runtime-manifest-v1.json"
)
ASSIGNMENT_CAPABLE = {
    prior_art_baselines.WHATCHORD_ID,
    prior_art_baselines.MUSICPY_ID,
    prior_art_baselines.CHORDRECGEN_ID,
}
FAILURE_STATUSES = {
    "exception",
    "timeout",
    "build-unavailable",
    "unparseable",
}
REPORT_STRATA = ("inherited", "authored-positive", "authored-guard")
RESULT_STATUSES = (
    "ok",
    "no-output",
    "exception",
    "timeout",
    "build-unavailable",
    "unparseable",
)


def canonical_json(value: object) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_serialized(value: object) -> str:
    serialized = json.dumps(value, indent=2, sort_keys=True) + "\n"
    return hashlib.sha256(serialized.encode()).hexdigest()


def _repo_path(relative: str) -> Path:
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("comparison dependency paths must be repository-relative")
    return REPO_ROOT / path


def _component(unit: dict) -> dict:
    return {"rootPc": unit["rootPc"], "quality": unit["quality"]}


def _expected_from_internal(case: dict) -> dict:
    product = case["productExpectation"]
    units = {unit["id"]: unit for unit in case["construction"]["units"]}
    identities = []
    assignments = []
    unresolved_order = False
    for expected in product["expectedPolychords"]:
        expected_units = [units[unit_id] for unit_id in expected["unitIds"]]
        if expected["symbol"] is None:
            unresolved_order = True
            identities.append(
                {
                    "upper": None,
                    "lower": None,
                    "components": [_component(unit) for unit in expected_units],
                }
            )
            continue
        upper, lower = expected_units
        identities.append(
            {
                "upper": _component(upper),
                "lower": _component(lower),
                "components": [_component(upper), _component(lower)],
            }
        )
        assignments.append(
            {
                "upperMidiNotes": upper["midiNotes"],
                "lowerMidiNotes": lower["midiNotes"],
            }
        )
    return {
        "class": product["class"],
        "acceptableIdentities": identities,
        "acceptableAssignments": assignments,
        "orderedIdentityCoverage": (
            "excluded-unresolved-construction-order" if unresolved_order else "eligible"
        ),
        "reason": product["reason"],
    }


def _expected_from_automatic(case: dict, action: dict) -> dict:
    construction = action["checkpoint"]["construction"]
    identities = []
    assignments = []
    if construction["candidateId"] is not None:
        expected = next(
            item["candidate"]
            for item in case["expectedCandidates"]
            if item["id"] == construction["candidateId"]
        )
        identities.append(
            {
                "upper": expected["identity"]["upper"],
                "lower": expected["identity"]["lower"],
                "components": [
                    expected["identity"]["upper"],
                    expected["identity"]["lower"],
                ],
            }
        )
        assignments.append(
            {
                "upperMidiNotes": expected["upperMidiNotes"],
                "lowerMidiNotes": expected["lowerMidiNotes"],
            }
        )
    return {
        "class": construction["class"],
        "acceptableIdentities": identities,
        "acceptableAssignments": assignments,
        "orderedIdentityCoverage": "eligible",
        "reason": construction["reason"],
    }


def _internal_notes(case: dict, fixtures: dict[str, dict]) -> list[int] | None:
    observation = case["observation"]
    if observation["kind"] == "snapshot":
        return observation["soundingMidiNotes"]
    if observation["kind"] == "frame-replay":
        fixture = fixtures[observation["fixtureId"]]["fixture"]
        return fixture["frames"][observation["afterEventIndex"]]["soundingMidiNotes"]
    if observation["kind"] == "frame-replay-window":
        return None
    raise ValueError(f"unsupported internal observation kind: {observation['kind']}")


def _report_stratum(source_kind: str, expectation_class: str) -> str:
    if source_kind == "internalSuiteCase":
        return "inherited"
    return "authored-positive" if expectation_class == "positive" else "authored-guard"


def _prepare_named_targets(
    suite: dict,
    internal_cases: dict[str, dict],
    product_cases: dict[str, dict],
    fixtures: dict[str, dict],
) -> list[dict]:
    targets = []
    for target in suite["baselineTargets"]["namedSnapshots"]:
        if target["sourceKind"] == "internalSuiteCase":
            case = internal_cases[target["sourceId"]]
            expected = _expected_from_internal(case)
            notes = _internal_notes(case, fixtures)
            source = {
                "kind": target["sourceKind"],
                "caseId": case["id"],
                "actionId": None,
            }
        else:
            case = product_cases[target["sourceId"]]
            action = next(
                item for item in case["actions"] if item["id"] == target["actionId"]
            )
            if action["checkpoint"] is False:
                raise ValueError("a named automatic target must be a checkpoint")
            expected = _expected_from_automatic(case, action)
            notes = action["checkpoint"]["frame"]["soundingMidiNotes"]
            source = {
                "kind": target["sourceKind"],
                "caseId": case["id"],
                "actionId": action["id"],
            }
        if target["coverage"] == "ordered-composite-exclusion":
            if notes is not None:
                raise ValueError("an excluded named target unexpectedly has a snapshot")
            exclusion = "no-simultaneous-complete-layer-snapshot"
            observation = None
        else:
            if notes is None:
                raise ValueError("an eligible named target has no static observation")
            exclusion = None
            observation = prior_art_baselines.make_observation(target["id"], notes)
        targets.append(
            {
                "id": target["id"],
                "task": TASK_NAMED,
                "stratum": _report_stratum(target["sourceKind"], expected["class"]),
                "source": source,
                "coverage": target["coverage"],
                "coverageExclusionReason": exclusion,
                "expectation": expected,
                "observation": observation,
            }
        )
    return targets


def _prepare_stream_targets(
    suite: dict,
    product_cases: dict[str, dict],
    fixtures: dict[str, dict],
) -> list[dict]:
    streams = []
    for target in suite["baselineTargets"]["adaptedStreams"]:
        case = product_cases[target["caseId"]]
        fixture = fixtures[case["fixtureId"]]["fixture"]
        previous = sorted(
            set(fixture["initialState"]["pressedMidiNotes"])
            | set(fixture["initialState"]["sustainedMidiNotes"])
        )
        frames = []
        for action in case["actions"]:
            if action["type"] != "musicalEvent":
                continue
            frame = fixture["frames"][action["eventIndex"]]
            notes = frame["soundingMidiNotes"]
            if notes == previous:
                continue
            observation_id = f"{target['id']}/event-{action['eventIndex']}"
            frames.append(
                {
                    "observationId": observation_id,
                    "eventIndex": action["eventIndex"],
                    "timestampMs": frame["timestampMs"],
                    "observation": prior_art_baselines.make_observation(
                        observation_id, notes
                    ),
                }
            )
            previous = notes
        stream_end = max(action["timestampMs"] for action in case["actions"])
        for index, frame in enumerate(frames):
            next_timestamp = (
                frames[index + 1]["timestampMs"]
                if index + 1 < len(frames)
                else stream_end
            )
            if next_timestamp < frame["timestampMs"]:
                raise ValueError("adapted-stream timestamps are not monotonic")
            frame["knownDwellMs"] = next_timestamp - frame["timestampMs"]
        streams.append(
            {
                "id": target["id"],
                "task": TASK_STREAM,
                "caseId": case["id"],
                "fixtureId": case["fixtureId"],
                "streamEndTimestampMs": stream_end,
                "frames": frames,
            }
        )
    return streams


def prepare_inputs(suite_path: Path = REPO_ROOT / SUITE_PATH) -> dict:
    suite_path = suite_path.resolve()
    suite = product_suite.validate_suite(suite_path, require_scoring_allowed=True)
    internal_path = _repo_path(suite["dependencies"]["internalSuite"]["path"])
    internal_suite.validate_suite(internal_path)
    internal_payload = json.loads(internal_path.read_text())
    fixture_manifest_path = _repo_path(
        suite["dependencies"]["productFixtureManifest"]["path"]
    )
    fixtures = product_suite.validate_fixture_manifest(fixture_manifest_path)
    internal_cases = {case["id"]: case for case in internal_payload["cases"]}
    product_cases = {case["id"]: case for case in suite["cases"]}
    named = _prepare_named_targets(suite, internal_cases, product_cases, fixtures)
    streams = _prepare_stream_targets(suite, product_cases, fixtures)
    observations = [
        target["observation"] for target in named if target["observation"] is not None
    ] + [frame["observation"] for stream in streams for frame in stream["frames"]]
    observation_ids = [item["observationId"] for item in observations]
    if len(observation_ids) != len(set(observation_ids)):
        raise ValueError("comparison observation IDs are not unique")
    return {
        "schema": INPUT_SCHEMA,
        "suite": {
            "path": str(suite_path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(suite_path),
        },
        "namedTargets": named,
        "streamTargets": streams,
        "adapterObservations": observations,
    }


def _ordered_identity(alternative: dict) -> dict | None:
    if alternative["classification"] != "ordered-composite":
        return None
    return {"upper": alternative["upper"], "lower": alternative["lower"]}


def _has_native_composite(result: dict) -> bool:
    return any(
        item["classification"] in {"ordered-composite", "unsupported-composite"}
        for item in result["normalizedAlternatives"]
    )


def _max_component_matches(result: dict, expected: dict) -> int:
    expected_components = expected["components"]
    maximum = 0
    for alternative in result["normalizedAlternatives"]:
        actual = [item for item in alternative["components"] if item is not None]
        if len(expected_components) == 2:
            direct = int(actual[:1] == expected_components[:1]) + int(
                len(actual) > 1 and actual[1] == expected_components[1]
            )
            reverse = int(actual[:1] == expected_components[1:]) + int(
                len(actual) > 1 and actual[1] == expected_components[0]
            )
            maximum = max(maximum, direct, reverse)
        elif actual:
            maximum = max(maximum, int(actual[0] in expected_components))
    return maximum


def evaluate_named_target(target: dict, result: dict, baseline_id: str) -> dict:
    if target["observation"] is None:
        return {
            "status": "coverage-exclusion",
            "reason": target["coverageExclusionReason"],
            "metrics": None,
            "result": None,
        }
    expectation = target["expectation"]
    positive = expectation["class"] == "positive"
    ordered_eligible = positive and expectation["orderedIdentityCoverage"] == "eligible"
    expected_ordered = [
        {"upper": item["upper"], "lower": item["lower"]}
        for item in expectation["acceptableIdentities"]
        if item["upper"] is not None and item["lower"] is not None
    ]
    ordered_actual = [
        identity
        for item in result["normalizedAlternatives"]
        if (identity := _ordered_identity(item)) is not None
    ]
    component_matches = None
    if positive:
        component_matches = max(
            (
                _max_component_matches(result, expected)
                for expected in expectation["acceptableIdentities"]
            ),
            default=0,
        )
    assignment_eligible = (
        positive
        and expectation["orderedIdentityCoverage"] == "eligible"
        and baseline_id in ASSIGNMENT_CAPABLE
    )
    assignment_exact = None
    if assignment_eligible:
        assignment_exact = any(
            item["classification"] == "ordered-composite"
            and item["assignment"] in expectation["acceptableAssignments"]
            for item in result["normalizedAlternatives"]
        )
    unsupported_count = sum(
        item["classification"] == "unsupported-composite"
        for item in result["normalizedAlternatives"]
    )
    unparseable_count = sum(
        item["classification"] == "unparseable"
        for item in result["normalizedAlternatives"]
    )
    return {
        "status": "evaluated",
        "reason": None,
        "metrics": {
            "anyCompositeEmitted": _has_native_composite(result),
            "orderedCompositeExact": (
                any(item in expected_ordered for item in ordered_actual)
                if ordered_eligible
                else None
            ),
            "orderedCompositeExactExclusion": (
                None
                if ordered_eligible
                else (
                    expectation["orderedIdentityCoverage"]
                    if positive
                    else "not-a-positive-target"
                )
            ),
            "unorderedComponentMatches": component_matches,
            "unorderedComponentDenominator": 2 if positive else None,
            "assignmentExact": assignment_exact,
            "assignmentExactExclusion": (
                None
                if assignment_eligible
                else (
                    "not-a-positive-target"
                    if not positive
                    else (
                        expectation["orderedIdentityCoverage"]
                        if expectation["orderedIdentityCoverage"] != "eligible"
                        else "baseline-does-not-expose-exact-partition"
                    )
                )
            ),
            "correctCompositeAbstention": (
                result["status"] not in FAILURE_STATUSES
                and not _has_native_composite(result)
                and not unparseable_count
                if not positive
                else None
            ),
            "failure": result["status"] in FAILURE_STATUSES,
            "unsupportedCompositeAlternatives": unsupported_count,
            "unparseableAlternatives": unparseable_count,
        },
        "result": result,
    }


def _identity_state(result: dict) -> list[dict]:
    return [
        identity
        for alternative in result["normalizedAlternatives"]
        if (identity := _ordered_identity(alternative)) is not None
    ]


def evaluate_stream(stream: dict, results: dict[str, dict]) -> dict:
    evaluated_frames = []
    previous_identity = None
    identity_changes = 0
    for frame in stream["frames"]:
        result = results[frame["observationId"]]
        identity = _identity_state(result)
        if previous_identity is not None and identity != previous_identity:
            identity_changes += 1
        previous_identity = identity
        evaluated_frames.append(
            {
                **frame,
                "rawOrderedCompositeIdentity": identity,
                "anyCompositeEmitted": _has_native_composite(result),
                "result": result,
            }
        )
    return {
        "id": stream["id"],
        "task": stream["task"],
        "caseId": stream["caseId"],
        "fixtureId": stream["fixtureId"],
        "streamEndTimestampMs": stream["streamEndTimestampMs"],
        "summary": {
            "changedSoundingFrameCount": len(evaluated_frames),
            "identityChanges": identity_changes,
            "compositeFrameCount": sum(
                frame["anyCompositeEmitted"] for frame in evaluated_frames
            ),
            "knownCompositeDwellMs": sum(
                frame["knownDwellMs"]
                for frame in evaluated_frames
                if frame["anyCompositeEmitted"]
            ),
            "exceptionFrames": sum(
                frame["result"]["status"] == "exception" for frame in evaluated_frames
            ),
            "noOutputFrames": sum(
                frame["result"]["status"] == "no-output" for frame in evaluated_frames
            ),
            "failureFrames": sum(
                frame["result"]["status"] in FAILURE_STATUSES
                for frame in evaluated_frames
            ),
        },
        "frames": evaluated_frames,
    }


def _empty_named_summary() -> dict:
    return {
        "targetCount": 0,
        "evaluatedTargetCount": 0,
        "coverageExclusionCount": 0,
        "compositeEmitted": {"count": 0, "eligible": 0},
        "orderedCompositeExact": {"count": 0, "eligible": 0},
        "unorderedComponents": {"matched": 0, "eligible": 0},
        "assignmentExact": {"count": 0, "eligible": 0},
        "guardAbstention": {"count": 0, "eligible": 0},
        "failureCount": 0,
        "resultStatusCounts": {status: 0 for status in RESULT_STATUSES},
        "unsupportedCompositeAlternativeCount": 0,
        "unparseableAlternativeCount": 0,
    }


def summarize_named(values: list[dict]) -> dict:
    summary = {stratum: _empty_named_summary() for stratum in REPORT_STRATA}
    for value in values:
        totals = summary[value["stratum"]]
        totals["targetCount"] += 1
        evaluation = value["evaluation"]
        if evaluation["status"] == "coverage-exclusion":
            totals["coverageExclusionCount"] += 1
            continue
        totals["evaluatedTargetCount"] += 1
        metrics = evaluation["metrics"]
        totals["resultStatusCounts"][evaluation["result"]["status"]] += 1
        totals["compositeEmitted"]["eligible"] += 1
        totals["compositeEmitted"]["count"] += int(metrics["anyCompositeEmitted"])
        if metrics["orderedCompositeExact"] is not None:
            totals["orderedCompositeExact"]["eligible"] += 1
            totals["orderedCompositeExact"]["count"] += int(
                metrics["orderedCompositeExact"]
            )
        if metrics["unorderedComponentMatches"] is not None:
            totals["unorderedComponents"]["eligible"] += 2
            totals["unorderedComponents"]["matched"] += metrics[
                "unorderedComponentMatches"
            ]
        if metrics["assignmentExact"] is not None:
            totals["assignmentExact"]["eligible"] += 1
            totals["assignmentExact"]["count"] += int(metrics["assignmentExact"])
        if metrics["correctCompositeAbstention"] is not None:
            totals["guardAbstention"]["eligible"] += 1
            totals["guardAbstention"]["count"] += int(
                metrics["correctCompositeAbstention"]
            )
        totals["failureCount"] += int(metrics["failure"])
        totals["unsupportedCompositeAlternativeCount"] += metrics[
            "unsupportedCompositeAlternatives"
        ]
        totals["unparseableAlternativeCount"] += metrics["unparseableAlternatives"]
    return summary


def summarize_streams(values: list[dict]) -> dict:
    fields = (
        "changedSoundingFrameCount",
        "identityChanges",
        "compositeFrameCount",
        "knownCompositeDwellMs",
        "exceptionFrames",
        "noOutputFrames",
        "failureFrames",
    )
    result_status_counts = {status: 0 for status in RESULT_STATUSES}
    for value in values:
        for frame in value["frames"]:
            result_status_counts[frame["result"]["status"]] += 1
    return {
        "streamCount": len(values),
        "resultStatusCounts": result_status_counts,
        **{field: sum(value["summary"][field] for value in values) for field in fields},
    }


def _git_output(*args: str) -> str:
    process = subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return process.stdout.strip()


def validate_comparison_freeze(
    prepared: dict,
    runtime_manifest_path: Path,
) -> dict:
    freeze = json.loads((REPO_ROOT / COMPARISON_FREEZE_PATH).read_text())
    if freeze.get("schema") != "polychord-prior-art-comparison-freeze/1":
        raise ValueError("comparison freeze has the wrong schema")
    if freeze.get("status") != "frozen-before-first-baseline-suite-output":
        raise ValueError("comparison freeze is not active")
    pins = {
        "suite": freeze["suite"],
        "contract": freeze["contract"],
        "adapterFreeze": freeze["adapterFreeze"],
        "runner": freeze["runner"],
        "runnerTests": freeze["runnerTests"],
        "runtimeManifest": freeze["runtimeManifest"],
    }
    for name, pin in pins.items():
        path = _repo_path(pin["path"])
        if sha256_file(path) != pin["sha256"]:
            raise ValueError(f"comparison freeze {name} digest does not match")
    if (
        _repo_path(freeze["suite"]["path"]).resolve()
        != (REPO_ROOT / prepared["suite"]["path"]).resolve()
    ):
        raise ValueError("prepared suite path differs from the comparison freeze")
    if freeze["suite"]["sha256"] != prepared["suite"]["sha256"]:
        raise ValueError("prepared suite digest differs from the comparison freeze")
    if _repo_path(freeze["runtimeManifest"]["path"]).resolve() != (
        runtime_manifest_path.resolve()
    ):
        raise ValueError("runtime manifest path differs from the comparison freeze")
    expected_inputs = freeze["preparedInputs"]
    if sha256_serialized(prepared) != expected_inputs["sha256"]:
        raise ValueError("prepared inputs differ from the comparison freeze")
    counts = {
        "namedTargetCount": len(prepared["namedTargets"]),
        "namedInvocationCount": sum(
            target["observation"] is not None for target in prepared["namedTargets"]
        ),
        "streamCount": len(prepared["streamTargets"]),
        "changedSoundingFrameCount": sum(
            len(stream["frames"]) for stream in prepared["streamTargets"]
        ),
        "adapterObservationCount": len(prepared["adapterObservations"]),
    }
    for name, count in counts.items():
        if expected_inputs[name] != count:
            raise ValueError(f"comparison freeze {name} differs")
    return freeze


def _provenance(
    prepared: dict,
    runtime_manifest_path: Path,
    command: list[str],
) -> dict:
    validate_comparison_freeze(prepared, runtime_manifest_path)
    dirty = _git_output("status", "--short")
    if dirty:
        raise RuntimeError(
            "the first frozen baseline comparison must start from a clean tree"
        )
    runtime_manifest_path = runtime_manifest_path.resolve()
    return {
        "sourceCommit": _git_output("rev-parse", "HEAD"),
        "sourceTreeCleanAtStart": True,
        "command": command,
        "suite": prepared["suite"],
        "contract": {
            "path": str(CONTRACT_PATH),
            "sha256": sha256_file(REPO_ROOT / CONTRACT_PATH),
        },
        "adapterFreeze": {
            "path": str(ADAPTER_FREEZE_PATH),
            "sha256": sha256_file(REPO_ROOT / ADAPTER_FREEZE_PATH),
        },
        "comparisonFreeze": {
            "path": str(COMPARISON_FREEZE_PATH),
            "sha256": sha256_file(REPO_ROOT / COMPARISON_FREEZE_PATH),
        },
        "runtimeManifest": {
            "path": str(runtime_manifest_path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(runtime_manifest_path),
        },
        "runner": {
            "path": str(Path(__file__).relative_to(REPO_ROOT)),
            "sha256": sha256_file(Path(__file__)),
        },
    }


def run_comparison(
    prepared: dict,
    *,
    runtime_manifest_path: Path,
    command: list[str],
    runner: Callable[..., list[dict]] = prior_art_baselines.run_baseline,
) -> dict:
    provenance = _provenance(prepared, runtime_manifest_path, command)
    observations = prepared["adapterObservations"]
    baselines = []
    for baseline_id in prior_art_baselines.BASELINE_IDS:
        raw_results = runner(
            baseline_id,
            observations,
            runtime_manifest_path=runtime_manifest_path,
        )
        results = {result["observationId"]: result for result in raw_results}
        expected_ids = {observation["observationId"] for observation in observations}
        if (
            len(raw_results) != len(observations)
            or len(results) != len(raw_results)
            or set(results) != expected_ids
        ):
            raise RuntimeError(f"{baseline_id} did not cover every observation")
        if any(result["baseline"]["id"] != baseline_id for result in raw_results):
            raise RuntimeError(f"{baseline_id} returned a mismatched baseline ID")
        named = []
        for target in prepared["namedTargets"]:
            result = (
                None
                if target["observation"] is None
                else results[target["observation"]["observationId"]]
            )
            named.append(
                {
                    **target,
                    "evaluation": evaluate_named_target(
                        target,
                        result,
                        baseline_id,
                    ),
                }
            )
        streams = [
            evaluate_stream(stream, results) for stream in prepared["streamTargets"]
        ]
        baselines.append(
            {
                "baselineId": baseline_id,
                "namedSnapshots": {
                    "summaryByStratum": summarize_named(named),
                    "targets": named,
                },
                "adaptedStreams": {
                    "summary": summarize_streams(streams),
                    "evaluationWrapper": {
                        "status": "not-run",
                        "reason": (
                            "Version 1 reports native static-detector frames; "
                            "no common temporal wrapper was preregistered."
                        ),
                    },
                    "streams": streams,
                },
            }
        )
    return {
        "schema": COMPARISON_SCHEMA,
        "provenance": provenance,
        "inputSummary": {
            "namedTargetCount": len(prepared["namedTargets"]),
            "namedInvocationCount": sum(
                target["observation"] is not None for target in prepared["namedTargets"]
            ),
            "streamCount": len(prepared["streamTargets"]),
            "changedSoundingFrameCount": sum(
                len(stream["frames"]) for stream in prepared["streamTargets"]
            ),
            "adapterObservationCount": len(observations),
        },
        "baselines": baselines,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", type=Path, default=SUITE_PATH)
    parser.add_argument("--runtime-manifest", type=Path, default=RUNTIME_MANIFEST_PATH)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument(
        "--prepare-only",
        action="store_true",
        help="serialize neutral inputs without invoking any detector",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    prepared = prepare_inputs((REPO_ROOT / args.suite).resolve())
    if args.prepare_only:
        payload = prepared
    else:
        command = [
            "mise",
            "exec",
            "--",
            "python",
            str(Path(__file__).relative_to(REPO_ROOT)),
            "--suite",
            str(args.suite),
            "--runtime-manifest",
            str(args.runtime_manifest),
            "--out",
            str(args.out),
        ]
        payload = run_comparison(
            prepared,
            runtime_manifest_path=(REPO_ROOT / args.runtime_manifest).resolve(),
            command=command,
        )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"wrote: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

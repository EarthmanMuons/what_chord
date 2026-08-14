"""Score exact automatic polychord product observations independently."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import product_suite

PREDICTION_SCHEMA = "polychord-product-predictions/1"
SCORE_SCHEMA = "polychord-product-score/1"
SCORER_ID = "polychord-product-exact-scorer/1"
CONTROL_SCHEMA = "polychord-product-scorer-controls/1"

PREDICTION_FIELDS = {
    "schema",
    "suiteSha256",
    "versionIds",
    "producerId",
    "cases",
}
PREDICTION_CASE_FIELDS = {"caseId", "checkpoints"}
PREDICTION_CHECKPOINT_FIELDS = {"actionId", "observation"}
CONTROL_FIELDS = {
    "schema",
    "suiteSha256",
    "exactProducerId",
    "materialization",
    "deliberateFailures",
}
FAILURE_FIELDS = {"id", "dimension", "caseId", "actionId", "mutation"}
MUTATION_FIELDS = {"operation", "path", "value"}
DIMENSIONS = (
    "frame",
    "construction",
    "candidates",
    "cueRecords",
    "rawDecision",
    "authorization",
    "display",
)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise ValueError(
            f"{context} fields are invalid: missing {missing}, unknown {unknown}"
        )


def require_string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{context} must be a nonempty string")
    return value


def expected_checkpoints(case: dict) -> list[tuple[str, dict]]:
    return [
        (action["id"], action["checkpoint"])
        for action in case["actions"]
        if action["checkpoint"] is not False
    ]


def validate_predictions(
    payload: object,
    *,
    suite: dict,
    suite_sha256: str,
) -> dict:
    if not isinstance(payload, dict):
        raise TypeError("predictions must be an object")
    require_fields(payload, PREDICTION_FIELDS, "predictions")
    if payload["schema"] != PREDICTION_SCHEMA:
        raise ValueError(f"predictions.schema must be {PREDICTION_SCHEMA!r}")
    if payload["suiteSha256"] != suite_sha256:
        raise ValueError("predictions.suiteSha256 does not match the suite")
    if payload["versionIds"] != suite["versionIds"]:
        raise ValueError("predictions.versionIds do not match the suite")
    producer_id = require_string(payload["producerId"], "predictions.producerId")
    cases = payload["cases"]
    if not isinstance(cases, list):
        raise TypeError("predictions.cases must be an array")
    if len(cases) != len(suite["cases"]):
        raise ValueError("predictions.cases must cover every suite case")

    normalized = []
    for case_index, (value, expected_case) in enumerate(zip(cases, suite["cases"])):
        context = f"predictions.cases[{case_index}]"
        if not isinstance(value, dict):
            raise TypeError(f"{context} must be an object")
        require_fields(value, PREDICTION_CASE_FIELDS, context)
        case_id = require_string(value["caseId"], f"{context}.caseId")
        if case_id != expected_case["id"]:
            raise ValueError(f"{context}.caseId is missing, extra, or out of order")
        expected_actions = expected_checkpoints(expected_case)
        checkpoints = value["checkpoints"]
        if not isinstance(checkpoints, list):
            raise TypeError(f"{context}.checkpoints must be an array")
        if len(checkpoints) != len(expected_actions):
            raise ValueError(f"{context}.checkpoints must cover every checkpoint")
        normalized_checkpoints = []
        for checkpoint_index, (checkpoint, expected) in enumerate(
            zip(checkpoints, expected_actions)
        ):
            checkpoint_context = f"{context}.checkpoints[{checkpoint_index}]"
            if not isinstance(checkpoint, dict):
                raise TypeError(f"{checkpoint_context} must be an object")
            require_fields(
                checkpoint,
                PREDICTION_CHECKPOINT_FIELDS,
                checkpoint_context,
            )
            action_id = require_string(
                checkpoint["actionId"], f"{checkpoint_context}.actionId"
            )
            if action_id != expected[0]:
                raise ValueError(
                    f"{checkpoint_context}.actionId is missing, extra, or out of order"
                )
            observation = checkpoint["observation"]
            if not isinstance(observation, dict):
                raise TypeError(f"{checkpoint_context}.observation must be an object")
            require_fields(
                observation,
                product_suite.CHECKPOINT_FIELDS,
                f"{checkpoint_context}.observation",
            )
            normalized_checkpoints.append(
                {"actionId": action_id, "observation": observation}
            )
        normalized.append({"caseId": case_id, "checkpoints": normalized_checkpoints})
    return {"producerId": producer_id, "cases": normalized}


def validate_controls(
    payload: object,
    *,
    suite: dict,
    suite_sha256: str,
) -> dict:
    """Validate the pinned exact-pass and deliberate-failure recipes."""

    if not isinstance(payload, dict):
        raise TypeError("controls must be an object")
    require_fields(payload, CONTROL_FIELDS, "controls")
    if payload["schema"] != CONTROL_SCHEMA:
        raise ValueError(f"controls.schema must be {CONTROL_SCHEMA!r}")
    if payload["suiteSha256"] != suite_sha256:
        raise ValueError("controls.suiteSha256 does not match the suite")
    require_string(payload["exactProducerId"], "controls.exactProducerId")
    require_string(payload["materialization"], "controls.materialization")
    failures = payload["deliberateFailures"]
    if not isinstance(failures, list):
        raise TypeError("controls.deliberateFailures must be an array")
    case_actions = {
        case["id"]: {
            action["id"]
            for action in case["actions"]
            if action["checkpoint"] is not False
        }
        for case in suite["cases"]
    }
    seen_ids = set()
    seen_dimensions = set()
    for index, value in enumerate(failures):
        context = f"controls.deliberateFailures[{index}]"
        if not isinstance(value, dict):
            raise TypeError(f"{context} must be an object")
        require_fields(value, FAILURE_FIELDS, context)
        failure_id = require_string(value["id"], f"{context}.id")
        if failure_id in seen_ids:
            raise ValueError(f"{context}.id is duplicated")
        seen_ids.add(failure_id)
        dimension = require_string(value["dimension"], f"{context}.dimension")
        if dimension not in DIMENSIONS:
            raise ValueError(f"{context}.dimension is unsupported")
        if dimension in seen_dimensions:
            raise ValueError(f"{context}.dimension is duplicated")
        seen_dimensions.add(dimension)
        case_id = require_string(value["caseId"], f"{context}.caseId")
        action_id = require_string(value["actionId"], f"{context}.actionId")
        if case_id not in case_actions or action_id not in case_actions[case_id]:
            raise ValueError(f"{context} does not identify one suite checkpoint")
        mutation = value["mutation"]
        if not isinstance(mutation, dict):
            raise TypeError(f"{context}.mutation must be an object")
        require_fields(mutation, MUTATION_FIELDS, f"{context}.mutation")
        if mutation["operation"] not in {"replace", "reverse", "append"}:
            raise ValueError(f"{context}.mutation.operation is unsupported")
        path = require_string(mutation["path"], f"{context}.mutation.path")
        if not path.startswith("/") or "~" in path:
            raise ValueError(f"{context}.mutation.path must be a simple JSON pointer")
    if seen_dimensions != set(DIMENSIONS):
        raise ValueError("controls must contain one failure for every dimension")
    return payload


def score(
    suite_path: Path,
    predictions_path: Path,
) -> dict:
    suite = product_suite.validate_suite(suite_path, require_scoring_allowed=True)
    suite_sha256 = sha256_file(suite_path)
    predictions = validate_predictions(
        json.loads(predictions_path.read_text()),
        suite=suite,
        suite_sha256=suite_sha256,
    )

    stratum_summary = {
        stratum: {dimension: {"exact": 0, "eligible": 0} for dimension in DIMENSIONS}
        for stratum in (
            "inherited-source",
            "authored-musical-policy",
            "authored-contract-mechanics",
        )
    }
    results = []
    all_exact = True
    for case, predicted_case in zip(suite["cases"], predictions["cases"]):
        expected_values = expected_checkpoints(case)
        checkpoint_results = []
        for (action_id, expected), predicted in zip(
            expected_values, predicted_case["checkpoints"]
        ):
            actual = predicted["observation"]
            metrics = {}
            for dimension in DIMENSIONS:
                eligible = not (
                    dimension == "construction"
                    and expected["construction"]["class"] == "coverage-exclusion"
                )
                exact = None
                if eligible:
                    exact = actual[dimension] == expected[dimension]
                    if dimension == "frame":
                        exact = (
                            exact
                            and actual["observationTimestampMs"]
                            == expected["observationTimestampMs"]
                        )
                metrics[f"{dimension}Exact"] = exact
                if eligible:
                    summary = stratum_summary[case["stratum"]][dimension]
                    summary["eligible"] += 1
                    summary["exact"] += int(exact)
                    all_exact &= exact
            checkpoint_exact = all(
                value for value in metrics.values() if value is not None
            )
            checkpoint_results.append(
                {
                    "actionId": action_id,
                    "metrics": metrics,
                    "checkpointExact": checkpoint_exact,
                }
            )
        results.append(
            {
                "caseId": case["id"],
                "stratum": case["stratum"],
                "checkpoints": checkpoint_results,
                "caseExact": all(
                    checkpoint["checkpointExact"] for checkpoint in checkpoint_results
                ),
            }
        )

    return {
        "schema": SCORE_SCHEMA,
        "scorerId": SCORER_ID,
        "suiteSha256": suite_sha256,
        "producerId": predictions["producerId"],
        "results": results,
        "summaryByStratum": stratum_summary,
        "suiteExactGatePass": all_exact,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", type=Path, required=True)
    parser.add_argument("--predictions", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = score(args.suite, args.predictions)
    serialized = json.dumps(report, indent=2) + "\n"
    if args.out is None:
        print(serialized, end="")
    else:
        args.out.write_text(serialized)
        print(f"wrote: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

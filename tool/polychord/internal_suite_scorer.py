"""Score frozen polychord-suite predictions under the exact adoption contract."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import decision_contract
import internal_suite

SCORER_SCHEMA = "polychord-exact-scorer/1"
PREDICTION_SCHEMA = "polychord-suite-predictions/1"
SCORE_SCHEMA = "polychord-suite-score/1"
INPUT_CONDITION = "adjacentRegisterSnapshot"

EXPECTED_FIELDS = {
    "expectedId",
    "identity",
    "upperMidiNotes",
    "lowerMidiNotes",
}
PREDICTION_TOP_LEVEL_FIELDS = {
    "schema",
    "suiteSha256",
    "inputCondition",
    "selectorId",
    "predictions",
}
PREDICTION_FIELDS = {"caseId", "selected", "reasonCodes"}


def _require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise ValueError(
            f"{context} fields are invalid: missing {missing}, unknown {unknown}"
        )


def _require_string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{context} must be a nonempty string")
    return value


def normalize_expected(value: object, context: str = "expected") -> dict:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    _require_fields(value, EXPECTED_FIELDS, context)
    candidate = decision_contract.normalize_candidate(
        {
            "identity": value["identity"],
            "upperMidiNotes": value["upperMidiNotes"],
            "lowerMidiNotes": value["lowerMidiNotes"],
        },
        context,
    )
    return {
        "expectedId": _require_string(value["expectedId"], f"{context}.expectedId"),
        **candidate,
    }


def _layer_key(layer: dict) -> tuple[int, str]:
    return layer["rootPc"], layer["quality"]


def _candidate_key(candidate: dict) -> tuple:
    return (
        _layer_key(candidate["identity"]["upper"]),
        _layer_key(candidate["identity"]["lower"]),
        tuple(candidate["upperMidiNotes"]),
        tuple(candidate["lowerMidiNotes"]),
    )


def _score_one_expected(expected: dict, prediction: dict) -> dict:
    expected_identity = expected["identity"]
    prediction_identity = prediction["identity"]
    ordered_exact = int(prediction_identity == expected_identity)
    assignment_exact = int(
        prediction["upperMidiNotes"] == expected["upperMidiNotes"]
        and prediction["lowerMidiNotes"] == expected["lowerMidiNotes"]
    )

    expected_layers = [
        _layer_key(expected_identity["upper"]),
        _layer_key(expected_identity["lower"]),
    ]
    predicted_layers = [
        _layer_key(prediction_identity["upper"]),
        _layer_key(prediction_identity["lower"]),
    ]
    matched_layers = sum(layer in predicted_layers for layer in expected_layers)
    layer_credit = matched_layers / 2
    orientation = None
    if layer_credit == 1:
        orientation = int(predicted_layers == expected_layers)

    expected_notes_by_layer = {
        expected_layers[0]: set(expected["upperMidiNotes"]),
        expected_layers[1]: set(expected["lowerMidiNotes"]),
    }
    predicted_notes_by_layer = {
        predicted_layers[0]: set(prediction["upperMidiNotes"]),
        predicted_layers[1]: set(prediction["lowerMidiNotes"]),
    }
    observation = decision_contract.assigned_notes(expected)
    correct_notes = sum(
        len(notes & predicted_notes_by_layer.get(layer, set()))
        for layer, notes in expected_notes_by_layer.items()
    )
    note_accuracy = correct_notes / len(observation)
    return {
        "winningExpectedId": expected["expectedId"],
        "orderedCompositeExact": ordered_exact,
        "assignmentExact": assignment_exact,
        "layerIdentityMatches": matched_layers,
        "layerIdentityTotal": 2,
        "layerIdentityCredit": layer_credit,
        "orientationCorrect": orientation,
        "noteAssignmentCorrect": correct_notes,
        "noteAssignmentTotal": len(observation),
        "noteAssignmentAccuracy": note_accuracy,
        "abstentionCorrect": None,
    }


def _winner_key(result: dict) -> tuple[float, ...]:
    orientation = result["orientationCorrect"]
    return (
        result["orderedCompositeExact"],
        result["assignmentExact"],
        result["layerIdentityCredit"],
        -1 if orientation is None else orientation,
        result["noteAssignmentAccuracy"],
    )


def score_case(
    *,
    product_class: str,
    acceptable_expected: list[dict],
    prediction: dict | None,
) -> dict:
    """Score one case without consulting a selector or suite label at runtime."""

    if product_class not in internal_suite.PRODUCT_CLASSES:
        raise ValueError(f"product_class is unsupported: {product_class!r}")
    expected = [
        normalize_expected(value, f"acceptable_expected[{index}]")
        for index, value in enumerate(acceptable_expected)
    ]
    expected_ids = [value["expectedId"] for value in expected]
    if len(expected_ids) != len(set(expected_ids)):
        raise ValueError("acceptable_expected ids must be unique")
    expected_candidates = [_candidate_key(value) for value in expected]
    if len(expected_candidates) != len(set(expected_candidates)):
        raise ValueError("acceptable_expected decompositions must be distinct")
    if product_class == "positive" and not expected:
        raise ValueError("positive cases require an acceptable expected result")
    if product_class != "positive" and expected:
        raise ValueError("non-positive cases cannot carry expected polychords")
    observation = None
    if product_class == "positive":
        observation = decision_contract.assigned_notes(expected[0])
        if any(
            decision_contract.assigned_notes(value) != observation for value in expected
        ):
            raise ValueError("acceptable expected results must cover one observation")

    normalized_prediction = (
        None
        if prediction is None
        else decision_contract.normalize_candidate(prediction, "prediction")
    )
    if product_class != "positive":
        return {
            "winningExpectedId": None,
            "orderedCompositeExact": None,
            "assignmentExact": None,
            "layerIdentityMatches": None,
            "layerIdentityTotal": None,
            "layerIdentityCredit": None,
            "orientationCorrect": None,
            "noteAssignmentCorrect": None,
            "noteAssignmentTotal": None,
            "noteAssignmentAccuracy": None,
            "abstentionCorrect": int(normalized_prediction is None),
        }
    if normalized_prediction is None:
        assert observation is not None
        return {
            "winningExpectedId": None,
            "orderedCompositeExact": 0,
            "assignmentExact": 0,
            "layerIdentityMatches": 0,
            "layerIdentityTotal": 2,
            "layerIdentityCredit": 0,
            "orientationCorrect": None,
            "noteAssignmentCorrect": 0,
            "noteAssignmentTotal": len(observation),
            "noteAssignmentAccuracy": 0,
            "abstentionCorrect": None,
        }

    assert observation is not None
    if decision_contract.assigned_notes(normalized_prediction) != observation:
        raise ValueError("prediction must assign every observed MIDI note")

    scored = [_score_one_expected(value, normalized_prediction) for value in expected]
    return max(enumerate(scored), key=lambda item: (_winner_key(item[1]), -item[0]))[1]


def expected_results_for_case(case: dict) -> list[dict]:
    product = case["productExpectation"]
    if product["class"] != "positive":
        return []
    units = {unit["id"]: unit for unit in case["construction"]["units"]}
    return [
        {
            "expectedId": expected["id"],
            "identity": {
                "upper": {
                    "rootPc": units[expected["unitIds"][0]]["rootPc"],
                    "quality": units[expected["unitIds"][0]]["quality"],
                },
                "lower": {
                    "rootPc": units[expected["unitIds"][1]]["rootPc"],
                    "quality": units[expected["unitIds"][1]]["quality"],
                },
            },
            "upperMidiNotes": units[expected["unitIds"][0]]["midiNotes"],
            "lowerMidiNotes": units[expected["unitIds"][1]]["midiNotes"],
        }
        for expected in product["expectedPolychords"]
    ]


def structural_candidates_for_case(case: dict) -> list[dict]:
    return [
        decision_contract.normalize_candidate(
            {
                "identity": {
                    "upper": {
                        "rootPc": candidate["upper"]["rootPc"],
                        "quality": candidate["upper"]["quality"],
                    },
                    "lower": {
                        "rootPc": candidate["lower"]["rootPc"],
                        "quality": candidate["lower"]["quality"],
                    },
                },
                "upperMidiNotes": candidate["upper"]["midiNotes"],
                "lowerMidiNotes": candidate["lower"]["midiNotes"],
            },
            f"{case['id']}.registerBaseline.expectedCandidates[{index}]",
        )
        for index, candidate in enumerate(
            case["registerBaseline"].get("expectedCandidates", [])
        )
    ]


def _validate_predictions(
    payload: object, case_ids: list[str], suite_sha256: str
) -> dict:
    if not isinstance(payload, dict):
        raise TypeError("predictions must be an object")
    _require_fields(payload, PREDICTION_TOP_LEVEL_FIELDS, "predictions")
    if payload["schema"] != PREDICTION_SCHEMA:
        raise ValueError(f"predictions.schema must be {PREDICTION_SCHEMA!r}")
    if payload["suiteSha256"] != suite_sha256:
        raise ValueError("predictions.suiteSha256 does not match the suite")
    if payload["inputCondition"] != INPUT_CONDITION:
        raise ValueError(f"predictions.inputCondition must be {INPUT_CONDITION!r}")
    _require_string(payload["selectorId"], "predictions.selectorId")
    values = payload["predictions"]
    if not isinstance(values, list):
        raise TypeError("predictions.predictions must be an array")
    by_id = {}
    for index, value in enumerate(values):
        if not isinstance(value, dict):
            raise TypeError(f"predictions.predictions[{index}] must be an object")
        _require_fields(value, PREDICTION_FIELDS, f"predictions.predictions[{index}]")
        case_id = _require_string(
            value["caseId"], f"predictions.predictions[{index}].caseId"
        )
        if case_id in by_id:
            raise ValueError(f"predictions contains duplicate case {case_id!r}")
        selected = value["selected"]
        if selected is not None:
            selected = decision_contract.normalize_candidate(
                selected, f"predictions.predictions[{index}].selected"
            )
        reason_codes = value["reasonCodes"]
        if not isinstance(reason_codes, list):
            raise TypeError(
                f"predictions.predictions[{index}].reasonCodes must be an array"
            )
        reason_codes = [
            _require_string(
                reason,
                f"predictions.predictions[{index}].reasonCodes[{reason_index}]",
            )
            for reason_index, reason in enumerate(reason_codes)
        ]
        if len(reason_codes) != len(set(reason_codes)):
            raise ValueError(
                f"predictions.predictions[{index}].reasonCodes must be distinct"
            )
        unsupported_reasons = sorted(set(reason_codes) - decision_contract.REASON_CODES)
        if unsupported_reasons:
            raise ValueError(
                f"predictions.predictions[{index}].reasonCodes contains unsupported "
                f"values: {unsupported_reasons}"
            )
        if selected is None and not reason_codes:
            raise ValueError(
                f"predictions.predictions[{index}] abstention requires a reason code"
            )
        if selected is not None and reason_codes:
            raise ValueError(
                f"predictions.predictions[{index}] selection cannot carry an "
                "abstention reason code"
            )
        by_id[case_id] = {"selected": selected, "reasonCodes": reason_codes}
    if set(by_id) != set(case_ids):
        raise ValueError("predictions must contain every suite case exactly once")
    return {"selectorId": payload["selectorId"], "byCaseId": by_id}


def _summarize(results: list[dict]) -> dict:
    positive = [result for result in results if result["productClass"] == "positive"]
    guards = [result for result in results if result["productClass"] != "positive"]
    strata = {}
    for result in results:
        stratum = strata.setdefault(
            result["epistemicStatus"],
            {
                "evaluatedCaseCount": 0,
                "positiveCount": 0,
                "positiveExactCount": 0,
                "guardCount": 0,
                "correctAbstentionCount": 0,
            },
        )
        stratum["evaluatedCaseCount"] += 1
        if result["productClass"] == "positive":
            stratum["positiveCount"] += 1
            stratum["positiveExactCount"] += int(
                result["metrics"]["orderedCompositeExact"] == 1
                and result["metrics"]["assignmentExact"] == 1
            )
        else:
            stratum["guardCount"] += 1
            stratum["correctAbstentionCount"] += result["metrics"]["abstentionCorrect"]
    positive_exact = sum(
        result["metrics"]["orderedCompositeExact"] == 1
        and result["metrics"]["assignmentExact"] == 1
        for result in positive
    )
    correct_abstentions = sum(
        result["metrics"]["abstentionCorrect"] for result in guards
    )
    orientation_results = [
        result["metrics"]["orientationCorrect"]
        for result in positive
        if result["metrics"]["orientationCorrect"] is not None
    ]
    return {
        "eligiblePositiveCount": len(positive),
        "positiveExactCount": positive_exact,
        "guardCount": len(guards),
        "correctAbstentionCount": correct_abstentions,
        "suiteExactGatePass": bool(positive)
        and bool(guards)
        and positive_exact == len(positive)
        and correct_abstentions == len(guards),
        "metricCounts": {
            "orderedCompositeExact": {
                "numerator": sum(
                    result["metrics"]["orderedCompositeExact"] for result in positive
                ),
                "denominator": len(positive),
            },
            "assignmentExact": {
                "numerator": sum(
                    result["metrics"]["assignmentExact"] for result in positive
                ),
                "denominator": len(positive),
            },
            "layerIdentityCredit": {
                "numerator": sum(
                    result["metrics"]["layerIdentityMatches"] for result in positive
                ),
                "denominator": sum(
                    result["metrics"]["layerIdentityTotal"] for result in positive
                ),
            },
            "orientationCorrect": {
                "numerator": sum(orientation_results),
                "denominator": len(orientation_results),
            },
            "noteAssignmentAccuracy": {
                "numerator": sum(
                    result["metrics"]["noteAssignmentCorrect"] for result in positive
                ),
                "denominator": sum(
                    result["metrics"]["noteAssignmentTotal"] for result in positive
                ),
            },
            "abstentionCorrect": {
                "numerator": correct_abstentions,
                "denominator": len(guards),
            },
        },
        "strata": strata,
    }


def score_suite(suite_path: Path, prediction_path: Path) -> dict:
    suite = internal_suite.load_json(suite_path)
    case_ids = internal_suite.validate_suite_payload(suite)
    if suite["scoringAllowed"] is not True:
        raise ValueError("suite.scoringAllowed must be true before scoring")
    suite_sha256 = hashlib.sha256(suite_path.read_bytes()).hexdigest()
    predictions = _validate_predictions(
        internal_suite.load_json(prediction_path), case_ids, suite_sha256
    )

    for case in suite["cases"]:
        selected = predictions["byCaseId"][case["id"]]["selected"]
        if selected is not None and selected not in structural_candidates_for_case(
            case
        ):
            raise ValueError(
                f"prediction for {case['id']!r} must select one frozen structural "
                "candidate"
            )

    results = []
    exclusions = []
    for case in suite["cases"]:
        case_id = case["id"]
        product_class = case["productExpectation"]["class"]
        eligibility = case["inputEligibility"][INPUT_CONDITION]
        if product_class == "positive" and eligibility["status"] != "eligible":
            exclusions.append(
                {
                    "caseId": case_id,
                    "status": eligibility["status"],
                    "reason": eligibility["reason"],
                }
            )
            continue
        result = score_case(
            product_class=product_class,
            acceptable_expected=expected_results_for_case(case),
            prediction=predictions["byCaseId"][case_id]["selected"],
        )
        results.append(
            {
                "caseId": case_id,
                "epistemicStatus": case["epistemicStatus"],
                "productClass": product_class,
                "reasonCodes": predictions["byCaseId"][case_id]["reasonCodes"],
                "metrics": result,
            }
        )

    return {
        "schema": SCORE_SCHEMA,
        "scorerId": SCORER_SCHEMA,
        "suiteSha256": suite_sha256,
        "inputCondition": INPUT_CONDITION,
        "selectorId": predictions["selectorId"],
        "coverageExclusions": exclusions,
        "results": results,
        "summary": _summarize(results),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", type=Path)
    parser.add_argument("predictions", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    print(
        json.dumps(score_suite(args.suite, args.predictions), indent=2, sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

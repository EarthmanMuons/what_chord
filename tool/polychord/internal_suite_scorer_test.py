"""Unit tests for the frozen polychord exact scorer."""

from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import internal_suite_scorer as subject

REPO_ROOT = Path(__file__).parents[2]
SUITE_PATH = REPO_ROOT / "research/polychord/data/internal-suite/suite-v0.json"


def expected_c_over_g_minor(expected_id: str = "c-over-g-minor") -> dict:
    return {
        "expectedId": expected_id,
        "identity": {
            "upper": {"rootPc": 0, "quality": "major"},
            "lower": {"rootPc": 7, "quality": "minor"},
        },
        "upperMidiNotes": [60, 64, 67],
        "lowerMidiNotes": [43, 46, 50],
    }


def candidate_from_expected(expected: dict) -> dict:
    return {
        "identity": expected["identity"],
        "upperMidiNotes": expected["upperMidiNotes"],
        "lowerMidiNotes": expected["lowerMidiNotes"],
    }


def expected_f_over_g_seven() -> dict:
    return {
        "expectedId": "f-over-g-seven",
        "identity": {
            "upper": {"rootPc": 5, "quality": "major"},
            "lower": {"rootPc": 7, "quality": "dominant7"},
        },
        "upperMidiNotes": [53, 57, 60],
        "lowerMidiNotes": [41, 43, 47, 50],
    }


class InternalSuiteScorerTest(unittest.TestCase):
    def test_exact_prediction_passes_both_exact_metrics(self) -> None:
        expected = expected_c_over_g_minor()

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected],
            prediction=candidate_from_expected(expected),
        )

        self.assertEqual(result["orderedCompositeExact"], 1)
        self.assertEqual(result["assignmentExact"], 1)
        self.assertEqual(result["layerIdentityCredit"], 1)
        self.assertEqual(result["layerIdentityMatches"], 2)
        self.assertEqual(result["orientationCorrect"], 1)
        self.assertEqual(result["noteAssignmentAccuracy"], 1)
        self.assertEqual(result["noteAssignmentCorrect"], 6)

    def test_swapped_orientation_retains_unordered_layer_credit(self) -> None:
        expected = expected_c_over_g_minor()
        prediction = {
            "identity": {
                "upper": expected["identity"]["lower"],
                "lower": expected["identity"]["upper"],
            },
            "upperMidiNotes": expected["lowerMidiNotes"],
            "lowerMidiNotes": expected["upperMidiNotes"],
        }

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected],
            prediction=prediction,
        )

        self.assertEqual(result["orderedCompositeExact"], 0)
        self.assertEqual(result["assignmentExact"], 0)
        self.assertEqual(result["layerIdentityCredit"], 1)
        self.assertEqual(result["orientationCorrect"], 0)
        self.assertEqual(result["noteAssignmentAccuracy"], 1)

    def test_one_correct_layer_receives_only_half_layer_credit(self) -> None:
        expected = expected_f_over_g_seven()
        prediction = {
            "identity": {
                "upper": expected["identity"]["upper"],
                "lower": {"rootPc": 7, "quality": "major"},
            },
            "upperMidiNotes": [41, 53, 57, 60],
            "lowerMidiNotes": [43, 47, 50],
        }

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected],
            prediction=prediction,
        )

        self.assertEqual(result["layerIdentityCredit"], 0.5)
        self.assertEqual(result["layerIdentityMatches"], 1)
        self.assertIsNone(result["orientationCorrect"])
        self.assertEqual(result["noteAssignmentAccuracy"], 3 / 7)
        self.assertEqual(result["noteAssignmentCorrect"], 3)

    def test_wrong_assignment_is_diagnostic_not_an_exact_pass(self) -> None:
        expected = expected_c_over_g_minor()
        prediction = candidate_from_expected(expected)
        prediction["upperMidiNotes"] = [43, 60, 64]
        prediction["lowerMidiNotes"] = [46, 50, 67]

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected],
            prediction=prediction,
        )

        self.assertEqual(result["orderedCompositeExact"], 1)
        self.assertEqual(result["assignmentExact"], 0)
        self.assertEqual(result["noteAssignmentAccuracy"], 4 / 6)

    def test_positive_abstention_receives_zero_positive_metrics(self) -> None:
        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected_c_over_g_minor()],
            prediction=None,
        )

        self.assertEqual(result["orderedCompositeExact"], 0)
        self.assertEqual(result["assignmentExact"], 0)
        self.assertEqual(result["layerIdentityCredit"], 0)
        self.assertEqual(result["noteAssignmentAccuracy"], 0)
        self.assertIsNone(result["abstentionCorrect"])

    def test_boundary_abstention_and_unexpected_fire_are_binary(self) -> None:
        expected = expected_c_over_g_minor()

        abstention = subject.score_case(
            product_class="boundary",
            acceptable_expected=[],
            prediction=None,
        )
        fire = subject.score_case(
            product_class="boundary",
            acceptable_expected=[],
            prediction=candidate_from_expected(expected),
        )

        self.assertEqual(abstention["abstentionCorrect"], 1)
        self.assertEqual(fire["abstentionCorrect"], 0)
        self.assertIsNone(fire["layerIdentityCredit"])

    def test_multiple_acceptable_answers_use_gate_first_lexicographic_winner(
        self,
    ) -> None:
        first = expected_c_over_g_minor("first-orientation")
        second = {
            "expectedId": "second-orientation",
            "identity": {
                "upper": first["identity"]["lower"],
                "lower": first["identity"]["upper"],
            },
            "upperMidiNotes": first["lowerMidiNotes"],
            "lowerMidiNotes": first["upperMidiNotes"],
        }

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[first, second],
            prediction=candidate_from_expected(second),
        )

        self.assertEqual(result["winningExpectedId"], "second-orientation")
        self.assertEqual(result["orderedCompositeExact"], 1)
        self.assertEqual(result["assignmentExact"], 1)

    def test_first_expected_wins_an_exact_tie(self) -> None:
        first = {
            "expectedId": "c-over-d-flat-seven",
            "identity": {
                "upper": {"rootPc": 0, "quality": "major"},
                "lower": {"rootPc": 1, "quality": "dominant7"},
            },
            "upperMidiNotes": [60, 64, 67],
            "lowerMidiNotes": [61, 65, 68, 71],
        }
        second = {
            "expectedId": "c-major-seven-over-d-flat",
            "identity": {
                "upper": {"rootPc": 0, "quality": "major7"},
                "lower": {"rootPc": 1, "quality": "major"},
            },
            "upperMidiNotes": [60, 64, 67, 71],
            "lowerMidiNotes": [61, 65, 68],
        }
        tied_prediction = {
            "identity": {
                "upper": {"rootPc": 1, "quality": "major7"},
                "lower": {"rootPc": 4, "quality": "minor"},
            },
            "upperMidiNotes": [60, 61, 65, 68],
            "lowerMidiNotes": [64, 67, 71],
        }

        result = subject.score_case(
            product_class="positive",
            acceptable_expected=[first, second],
            prediction=tied_prediction,
        )

        self.assertEqual(result["winningExpectedId"], "c-over-d-flat-seven")

    def test_duplicate_acceptable_decomposition_is_rejected(self) -> None:
        first = expected_c_over_g_minor("first")
        duplicate = expected_c_over_g_minor("duplicate")

        with self.assertRaisesRegex(ValueError, "decompositions must be distinct"):
            subject.score_case(
                product_class="positive",
                acceptable_expected=[first, duplicate],
                prediction=candidate_from_expected(first),
            )

    def test_active_seed_refuses_scoring(self) -> None:
        with self.assertRaisesRegex(ValueError, "scoringAllowed must be true"):
            subject.score_suite(SUITE_PATH, SUITE_PATH)

    def test_prediction_artifact_rejects_unversioned_reason_code(self) -> None:
        payload = {
            "schema": subject.PREDICTION_SCHEMA,
            "suiteSha256": "suite-digest",
            "inputCondition": subject.INPUT_CONDITION,
            "selectorId": "synthetic-control/1",
            "predictions": [
                {
                    "caseId": "control-case",
                    "selected": None,
                    "reasonCodes": ["unversioned-reason"],
                }
            ],
        }

        with self.assertRaisesRegex(ValueError, "unsupported values"):
            subject._validate_predictions(
                payload,
                ["control-case"],
                "suite-digest",
            )

    def test_prediction_artifact_requires_a_reason_for_abstention(self) -> None:
        payload = {
            "schema": subject.PREDICTION_SCHEMA,
            "suiteSha256": "suite-digest",
            "inputCondition": subject.INPUT_CONDITION,
            "selectorId": "synthetic-control/1",
            "predictions": [
                {
                    "caseId": "control-case",
                    "selected": None,
                    "reasonCodes": [],
                }
            ],
        }

        with self.assertRaisesRegex(ValueError, "abstention requires"):
            subject._validate_predictions(
                payload,
                ["control-case"],
                "suite-digest",
            )

    def test_prediction_artifact_rejects_abstention_reason_on_selection(self) -> None:
        expected = expected_c_over_g_minor()
        payload = {
            "schema": subject.PREDICTION_SCHEMA,
            "suiteSha256": "suite-digest",
            "inputCondition": subject.INPUT_CONDITION,
            "selectorId": "synthetic-control/1",
            "predictions": [
                {
                    "caseId": "control-case",
                    "selected": candidate_from_expected(expected),
                    "reasonCodes": ["not-selected-by-policy"],
                }
            ],
        }

        with self.assertRaisesRegex(ValueError, "selection cannot carry"):
            subject._validate_predictions(
                payload,
                ["control-case"],
                "suite-digest",
            )

    def _write_frozen_control_artifacts(
        self,
        directory: Path,
    ) -> tuple[Path, Path, dict]:
        suite = subject.internal_suite.load_json(SUITE_PATH)
        suite["status"] = "frozen-author-adjudicated-adoption"
        suite["scoringAllowed"] = True
        suite_path = directory / "suite.json"
        suite_path.write_text(json.dumps(suite, indent=2) + "\n")
        suite_sha256 = hashlib.sha256(suite_path.read_bytes()).hexdigest()

        predictions = []
        for case in suite["cases"]:
            eligible_positive = (
                case["productExpectation"]["class"] == "positive"
                and case["inputEligibility"][subject.INPUT_CONDITION]["status"]
                == "eligible"
            )
            expected = subject.expected_results_for_case(case)
            predictions.append(
                {
                    "caseId": case["id"],
                    "selected": (
                        candidate_from_expected(expected[0])
                        if eligible_positive
                        else None
                    ),
                    "reasonCodes": (
                        [] if eligible_positive else ["not-selected-by-policy"]
                    ),
                }
            )
        prediction_payload = {
            "schema": subject.PREDICTION_SCHEMA,
            "suiteSha256": suite_sha256,
            "inputCondition": subject.INPUT_CONDITION,
            "selectorId": "synthetic-perfect-control/1",
            "predictions": predictions,
        }
        prediction_path = directory / "predictions.json"
        prediction_path.write_text(json.dumps(prediction_payload, indent=2) + "\n")
        return suite_path, prediction_path, prediction_payload

    def test_frozen_synthetic_control_exercises_complete_scorer(self) -> None:
        with tempfile.TemporaryDirectory() as temp_directory:
            suite_path, prediction_path, _ = self._write_frozen_control_artifacts(
                Path(temp_directory)
            )

            result = subject.score_suite(suite_path, prediction_path)

        self.assertEqual(result["summary"]["eligiblePositiveCount"], 6)
        self.assertEqual(result["summary"]["positiveExactCount"], 6)
        self.assertEqual(result["summary"]["guardCount"], 9)
        self.assertEqual(result["summary"]["correctAbstentionCount"], 9)
        self.assertTrue(result["summary"]["suiteExactGatePass"])
        self.assertEqual(len(result["coverageExclusions"]), 2)
        self.assertEqual(
            result["summary"]["metricCounts"]["orderedCompositeExact"],
            {"numerator": 6, "denominator": 6},
        )
        self.assertEqual(
            result["summary"]["metricCounts"]["layerIdentityCredit"],
            {"numerator": 12, "denominator": 12},
        )
        note_counts = result["summary"]["metricCounts"]["noteAssignmentAccuracy"]
        self.assertEqual(note_counts["numerator"], note_counts["denominator"])
        self.assertEqual(
            result["summary"]["metricCounts"]["abstentionCorrect"],
            {"numerator": 9, "denominator": 9},
        )

    def test_partial_metric_summary_retains_integer_counts(self) -> None:
        exact = subject.score_case(
            product_class="positive",
            acceptable_expected=[expected_c_over_g_minor()],
            prediction=candidate_from_expected(expected_c_over_g_minor()),
        )
        partial_expected = expected_f_over_g_seven()
        partial = subject.score_case(
            product_class="positive",
            acceptable_expected=[partial_expected],
            prediction={
                "identity": {
                    "upper": partial_expected["identity"]["upper"],
                    "lower": {"rootPc": 7, "quality": "major"},
                },
                "upperMidiNotes": [41, 53, 57, 60],
                "lowerMidiNotes": [43, 47, 50],
            },
        )

        summary = subject._summarize(
            [
                {
                    "productClass": "positive",
                    "epistemicStatus": "literature-attested-construction",
                    "metrics": exact,
                },
                {
                    "productClass": "positive",
                    "epistemicStatus": "synthetic-regression-guard",
                    "metrics": partial,
                },
            ]
        )

        self.assertEqual(
            summary["metricCounts"]["layerIdentityCredit"],
            {"numerator": 3, "denominator": 4},
        )
        self.assertEqual(
            summary["metricCounts"]["orientationCorrect"],
            {"numerator": 1, "denominator": 1},
        )
        self.assertEqual(
            summary["metricCounts"]["noteAssignmentAccuracy"],
            {"numerator": 9, "denominator": 13},
        )

    def test_suite_exact_gate_cannot_pass_vacuously(self) -> None:
        self.assertFalse(subject._summarize([])["suiteExactGatePass"])

    def test_suite_scorer_rejects_selection_outside_frozen_candidates(self) -> None:
        with tempfile.TemporaryDirectory() as temp_directory:
            suite_path, prediction_path, predictions = (
                self._write_frozen_control_artifacts(Path(temp_directory))
            )
            prediction = next(
                value
                for value in predictions["predictions"]
                if value["caseId"] == "ives-psalm-67-opening"
            )
            prediction["selected"] = {
                "identity": {
                    "upper": {"rootPc": 0, "quality": "major"},
                    "lower": {"rootPc": 7, "quality": "minor"},
                },
                "upperMidiNotes": [55, 60, 64, 72],
                "lowerMidiNotes": [43, 50, 58, 67],
            }
            prediction_path.write_text(json.dumps(predictions, indent=2) + "\n")

            with self.assertRaisesRegex(ValueError, "frozen structural candidate"):
                subject.score_suite(suite_path, prediction_path)

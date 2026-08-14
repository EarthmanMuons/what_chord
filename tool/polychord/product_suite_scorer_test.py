"""Tests for the independent exact polychord product-suite scorer."""

from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

import product_suite
import product_suite_scorer as subject

REPO_ROOT = Path(__file__).parents[2]
SUITE = REPO_ROOT / "research/polychord/data/product-suite/suite-v0.json"
CONTROLS = REPO_ROOT / "research/polychord/data/product-suite/scorer-controls-v0.json"


def exact_predictions(suite: dict, suite_sha256: str, producer_id: str) -> dict:
    return {
        "schema": subject.PREDICTION_SCHEMA,
        "suiteSha256": suite_sha256,
        "versionIds": suite["versionIds"],
        "producerId": producer_id,
        "cases": [
            {
                "caseId": case["id"],
                "checkpoints": [
                    {
                        "actionId": action["id"],
                        "observation": deepcopy(action["checkpoint"]),
                    }
                    for action in case["actions"]
                    if action["checkpoint"] is not False
                ],
            }
            for case in suite["cases"]
        ],
    }


def observation_for(predictions: dict, case_id: str, action_id: str) -> dict:
    case = next(case for case in predictions["cases"] if case["caseId"] == case_id)
    return next(
        checkpoint["observation"]
        for checkpoint in case["checkpoints"]
        if checkpoint["actionId"] == action_id
    )


def apply_mutation(observation: dict, mutation: dict) -> None:
    parts = mutation["path"].removeprefix("/").split("/")
    target = observation
    for part in parts[:-1]:
        target = target[int(part)] if isinstance(target, list) else target[part]
    field = parts[-1]
    index_or_field = int(field) if isinstance(target, list) else field
    operation = mutation["operation"]
    if operation == "replace":
        target[index_or_field] = mutation["value"]
    elif operation == "reverse":
        target[index_or_field].reverse()
    elif operation == "append":
        target[index_or_field].append(mutation["value"])
    else:  # pragma: no cover - validate_controls rejects this first.
        raise AssertionError(operation)


class ProductSuiteScorerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.suite = json.loads(SUITE.read_text())
        self.suite_path = self.directory / "suite.json"
        self.suite_path.write_text(json.dumps(self.suite, indent=2) + "\n")
        self.suite_sha256 = hashlib.sha256(self.suite_path.read_bytes()).hexdigest()
        self.controls = subject.validate_controls(
            json.loads(CONTROLS.read_text()),
            suite=self.suite,
            suite_sha256=self.suite_sha256,
        )
        self.predictions = exact_predictions(
            self.suite,
            self.suite_sha256,
            self.controls["exactProducerId"],
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_predictions(self, predictions: dict) -> Path:
        path = self.directory / "predictions.json"
        path.write_text(json.dumps(predictions, indent=2) + "\n")
        return path

    def test_exact_synthetic_control_passes_every_nonempty_stratum(self) -> None:
        report = subject.score(
            self.suite_path,
            self.write_predictions(self.predictions),
        )

        self.assertTrue(report["suiteExactGatePass"])
        for stratum in report["summaryByStratum"].values():
            for dimension in subject.DIMENSIONS:
                self.assertGreater(stratum[dimension]["eligible"], 0)
                self.assertEqual(
                    stratum[dimension]["exact"],
                    stratum[dimension]["eligible"],
                )

    def test_one_deliberate_failure_in_each_dimension_fails_the_gate(self) -> None:
        for failure in self.controls["deliberateFailures"]:
            with self.subTest(dimension=failure["dimension"]):
                predictions = deepcopy(self.predictions)
                observation = observation_for(
                    predictions,
                    failure["caseId"],
                    failure["actionId"],
                )
                apply_mutation(observation, failure["mutation"])
                report = subject.score(
                    self.suite_path,
                    self.write_predictions(predictions),
                )
                case_result = next(
                    case
                    for case in report["results"]
                    if case["caseId"] == failure["caseId"]
                )
                metrics = next(
                    checkpoint["metrics"]
                    for checkpoint in case_result["checkpoints"]
                    if checkpoint["actionId"] == failure["actionId"]
                )
                self.assertFalse(report["suiteExactGatePass"])
                self.assertFalse(metrics[f"{failure['dimension']}Exact"])

    def test_missing_checkpoint_and_version_mismatch_are_rejected(self) -> None:
        predictions = deepcopy(self.predictions)
        predictions["cases"][0]["checkpoints"].pop()
        with self.assertRaisesRegex(ValueError, "cover every checkpoint"):
            subject.score(
                self.suite_path,
                self.write_predictions(predictions),
            )

        predictions = deepcopy(self.predictions)
        predictions["versionIds"]["selector"] = "wrong-selector/1"
        with self.assertRaisesRegex(ValueError, "versionIds"):
            subject.score(
                self.suite_path,
                self.write_predictions(predictions),
            )

    def test_timer_observation_timestamp_is_part_of_frame_exactness(self) -> None:
        predictions = deepcopy(self.predictions)
        observation = observation_for(
            predictions,
            "pending-key-change-restarts-deadline",
            "timer-280",
        )
        observation["observationTimestampMs"] = 281

        report = subject.score(
            self.suite_path,
            self.write_predictions(predictions),
        )
        case = next(
            case
            for case in report["results"]
            if case["caseId"] == "pending-key-change-restarts-deadline"
        )
        metrics = next(
            checkpoint["metrics"]
            for checkpoint in case["checkpoints"]
            if checkpoint["actionId"] == "timer-280"
        )
        self.assertFalse(metrics["frameExact"])
        self.assertFalse(report["suiteExactGatePass"])

    def test_checked_in_suite_accepts_only_the_exact_synthetic_control(self) -> None:
        checked_in = product_suite.validate_suite(SUITE)
        digest = hashlib.sha256(SUITE.read_bytes()).hexdigest()
        controls = subject.validate_controls(
            json.loads(CONTROLS.read_text()),
            suite=checked_in,
            suite_sha256=digest,
        )
        predictions = exact_predictions(
            checked_in,
            digest,
            controls["exactProducerId"],
        )

        report = subject.score(SUITE, self.write_predictions(predictions))
        self.assertTrue(report["suiteExactGatePass"])


if __name__ == "__main__":
    unittest.main()

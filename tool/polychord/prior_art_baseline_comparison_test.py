"""Controls for frozen prior-art comparison preparation and scoring."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

import prior_art_baseline_comparison as subject
import prior_art_baselines

REPO_ROOT = Path(__file__).parents[2]
SUITE = REPO_ROOT / "research/polychord/data/product-suite/suite-v0.json"


def _alternative(
    *,
    classification: str,
    upper: dict | None = None,
    lower: dict | None = None,
    components: list[dict | None] | None = None,
    assignment: dict | None = None,
) -> dict:
    return {
        "nativeIndex": 0,
        "classification": classification,
        "upper": upper,
        "lower": lower,
        "components": components or [],
        "assignment": assignment,
        "rawLabel": None,
        "reason": None,
    }


def _result(
    observation_id: str,
    alternatives: list[dict],
    *,
    status: str = "ok",
) -> dict:
    return {
        "observationId": observation_id,
        "status": status,
        "normalizedAlternatives": alternatives,
    }


class InputPreparationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.prepared = subject.prepare_inputs(SUITE)

    def test_frozen_target_counts_and_coverage_exclusion_are_preserved(self) -> None:
        self.assertEqual(len(self.prepared["namedTargets"]), 29)
        self.assertEqual(len(self.prepared["streamTargets"]), 20)
        excluded = [
            target
            for target in self.prepared["namedTargets"]
            if target["observation"] is None
        ]
        self.assertEqual(
            [target["id"] for target in excluded],
            ["named-internal-stravinsky-petrushka-r49-arpeggios"],
        )
        self.assertEqual(
            len(self.prepared["adapterObservations"]),
            len(
                {
                    value["observationId"]
                    for value in self.prepared["adapterObservations"]
                }
            ),
        )

    def test_adapter_records_contain_only_the_frozen_neutral_fields(self) -> None:
        expected_fields = {
            "observationId",
            "orderedMidiNotes",
            "scientificPitchSharps",
            "pitchClassSharps",
        }
        for observation in self.prepared["adapterObservations"]:
            self.assertEqual(set(observation), expected_fields)
            serialized = subject.canonical_json(observation).lower()
            self.assertNotIn("expected", serialized)
            self.assertNotIn("construction", serialized)
            self.assertNotIn("source", serialized)

    def test_streams_keep_only_events_that_change_the_sounding_set(self) -> None:
        for stream in self.prepared["streamTargets"]:
            previous = None
            for frame in stream["frames"]:
                notes = frame["observation"]["orderedMidiNotes"]
                self.assertNotEqual(notes, previous)
                self.assertGreaterEqual(frame["knownDwellMs"], 0)
                previous = notes

    def test_static_replay_targets_resolve_to_the_declared_frame(self) -> None:
        target = next(
            value
            for value in self.prepared["namedTargets"]
            if value["id"] == "named-internal-stravinsky-shrovetide-second-attack"
        )
        self.assertEqual(
            target["observation"]["orderedMidiNotes"],
            [58, 62, 65, 70, 74, 79],
        )

    def test_comparison_freeze_matches_prepared_inputs_without_built_runtime(
        self,
    ) -> None:
        freeze = json.loads((REPO_ROOT / subject.COMPARISON_FREEZE_PATH).read_text())

        self.assertEqual(
            freeze["preparedInputs"]["sha256"],
            subject.sha256_serialized(self.prepared),
        )
        self.assertEqual(
            freeze["preparedInputs"]["adapterObservationCount"],
            len(self.prepared["adapterObservations"]),
        )


class NamedEvaluationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.upper = {"rootPc": 6, "quality": "major"}
        self.lower = {"rootPc": 0, "quality": "major"}
        self.assignment = {
            "upperMidiNotes": [66, 70, 73],
            "lowerMidiNotes": [48, 52, 55],
        }
        self.target = {
            "observation": prior_art_baselines.make_observation(
                "positive", [48, 52, 55, 66, 70, 73]
            ),
            "coverageExclusionReason": None,
            "expectation": {
                "class": "positive",
                "acceptableIdentities": [
                    {
                        "upper": self.upper,
                        "lower": self.lower,
                        "components": [self.upper, self.lower],
                    }
                ],
                "acceptableAssignments": [self.assignment],
                "orderedIdentityCoverage": "eligible",
                "reason": "control",
            },
        }

    def test_exact_order_components_and_assignment_are_scored_separately(self) -> None:
        result = _result(
            "positive",
            [
                _alternative(
                    classification="ordered-composite",
                    upper=self.upper,
                    lower=self.lower,
                    components=[self.upper, self.lower],
                    assignment=self.assignment,
                )
            ],
        )

        value = subject.evaluate_named_target(
            self.target, result, prior_art_baselines.WHATCHORD_ID
        )["metrics"]

        self.assertTrue(value["anyCompositeEmitted"])
        self.assertTrue(value["orderedCompositeExact"])
        self.assertEqual(value["unorderedComponentMatches"], 2)
        self.assertTrue(value["assignmentExact"])

    def test_single_component_gets_partial_unordered_credit_only(self) -> None:
        result = _result(
            "positive",
            [
                _alternative(
                    classification="single-chord-output",
                    components=[self.lower],
                )
            ],
        )

        value = subject.evaluate_named_target(
            self.target, result, prior_art_baselines.MINGUS_ID
        )["metrics"]

        self.assertFalse(value["anyCompositeEmitted"])
        self.assertFalse(value["orderedCompositeExact"])
        self.assertEqual(value["unorderedComponentMatches"], 1)
        self.assertIsNone(value["assignmentExact"])
        self.assertEqual(
            value["assignmentExactExclusion"],
            "baseline-does-not-expose-exact-partition",
        )

    def test_guard_scores_composite_abstention_without_positive_denominators(
        self,
    ) -> None:
        self.target["expectation"] = {
            "class": "negative-guard",
            "acceptableIdentities": [],
            "acceptableAssignments": [],
            "orderedIdentityCoverage": "eligible",
            "reason": "control",
        }

        value = subject.evaluate_named_target(
            self.target,
            _result("positive", []),
            prior_art_baselines.WHATCHORD_ID,
        )["metrics"]

        self.assertTrue(value["correctCompositeAbstention"])
        self.assertIsNone(value["orderedCompositeExact"])
        self.assertIsNone(value["unorderedComponentMatches"])
        self.assertIsNone(value["assignmentExact"])

    def test_failure_does_not_count_as_correct_guard_abstention(self) -> None:
        self.target["expectation"] = {
            "class": "negative-guard",
            "acceptableIdentities": [],
            "acceptableAssignments": [],
            "orderedIdentityCoverage": "eligible",
            "reason": "control",
        }

        value = subject.evaluate_named_target(
            self.target,
            _result("positive", [], status="exception"),
            prior_art_baselines.WHATCHORD_ID,
        )["metrics"]

        self.assertFalse(value["correctCompositeAbstention"])
        self.assertTrue(value["failure"])


class StreamEvaluationTest(unittest.TestCase):
    def test_raw_identity_changes_and_known_dwell_are_descriptive(self) -> None:
        upper = {"rootPc": 6, "quality": "major"}
        lower = {"rootPc": 0, "quality": "major"}
        composite = _alternative(
            classification="ordered-composite",
            upper=upper,
            lower=lower,
            components=[upper, lower],
        )
        stream = {
            "id": "stream-control",
            "task": subject.TASK_STREAM,
            "caseId": "case-control",
            "fixtureId": "fixture-control",
            "streamEndTimestampMs": 300,
            "frames": [
                {"observationId": "one", "knownDwellMs": 100},
                {"observationId": "two", "knownDwellMs": 200},
            ],
        }
        results = {
            "one": _result("one", [composite]),
            "two": _result("two", [], status="no-output"),
        }

        value = subject.evaluate_stream(stream, results)

        self.assertEqual(value["summary"]["identityChanges"], 1)
        self.assertEqual(value["summary"]["compositeFrameCount"], 1)
        self.assertEqual(value["summary"]["knownCompositeDwellMs"], 100)
        self.assertEqual(value["summary"]["noOutputFrames"], 1)


if __name__ == "__main__":
    unittest.main()

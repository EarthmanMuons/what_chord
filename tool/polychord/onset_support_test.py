"""Unit tests for the conservative polychord onset-support ablation."""

from __future__ import annotations

import unittest
from copy import deepcopy
from pathlib import Path

import onset_support as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


def support_document(name: str, after_event_index: int) -> dict:
    return subject.support_document(FIXTURE_DIR / name, after_event_index)


def complete_evidence(
    lower_earliest: int,
    lower_latest: int,
    upper_earliest: int,
    upper_latest: int,
) -> dict:
    return {
        "allCandidateOnsetsKnown": True,
        "lower": {
            "earliestKnownOnsetMs": lower_earliest,
            "latestKnownOnsetMs": lower_latest,
            "knownOnsetSpanMs": lower_latest - lower_earliest,
        },
        "upper": {
            "earliestKnownOnsetMs": upper_earliest,
            "latestKnownOnsetMs": upper_latest,
            "knownOnsetSpanMs": upper_latest - upper_earliest,
        },
    }


class OnsetSupportTest(unittest.TestCase):
    def test_named_parameters_are_fixed(self) -> None:
        self.assertEqual(
            subject.ABLATION_ID,
            "coherent-separated-onsets-50-200ms/1",
        )
        self.assertEqual(
            subject.interpretation_parameters(),
            {
                "withinLayerCohortSpanMaximumMs": 50,
                "betweenLayerSeparationMinimumMs": 200,
            },
        )

    def test_layered_control_receives_positive_support(self) -> None:
        document = support_document("two-register-held-cohorts.json", 5)

        interpretation = document["candidateInterpretations"][0]["onsetInterpretation"]
        self.assertEqual(interpretation["availability"], "complete")
        self.assertTrue(interpretation["lowerWithinCohortSpanMaximum"])
        self.assertTrue(interpretation["upperWithinCohortSpanMaximum"])
        self.assertEqual(interpretation["layerOnsetOrder"], "lower-then-upper")
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 400)
        self.assertEqual(interpretation["onsetCohortSupport"], "positive")
        self.assertEqual(
            interpretation["reasonCodes"],
            ["separate-coherent-onset-cohorts"],
        )

    def test_synchronous_control_remains_neutral(self) -> None:
        document = support_document("synchronous-six-note-cohort.json", 5)

        interpretation = document["candidateInterpretations"][0]["onsetInterpretation"]
        self.assertEqual(interpretation["layerOnsetOrder"], "overlapping")
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 0)
        self.assertEqual(interpretation["onsetCohortSupport"], "neutral")
        self.assertEqual(
            interpretation["reasonCodes"],
            ["between-layer-separation-below-minimum"],
        )

    def test_reverse_layer_order_is_equally_eligible(self) -> None:
        evidence = complete_evidence(300, 340, 0, 50)

        interpretation = subject.interpret_onset_evidence(evidence)

        self.assertEqual(interpretation["layerOnsetOrder"], "upper-then-lower")
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 250)
        self.assertEqual(interpretation["onsetCohortSupport"], "positive")

    def test_exact_synchrony_and_separation_boundaries_are_inclusive(self) -> None:
        evidence = complete_evidence(0, 50, 250, 300)

        interpretation = subject.interpret_onset_evidence(evidence)

        self.assertTrue(interpretation["lowerWithinCohortSpanMaximum"])
        self.assertTrue(interpretation["upperWithinCohortSpanMaximum"])
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 200)
        self.assertEqual(interpretation["onsetCohortSupport"], "positive")

    def test_either_layer_outside_cohort_span_boundary_remains_neutral(self) -> None:
        cases = (
            (
                complete_evidence(0, 51, 251, 300),
                "lower-span-exceeds-maximum",
            ),
            (
                complete_evidence(0, 50, 250, 301),
                "upper-span-exceeds-maximum",
            ),
        )

        for evidence, reason in cases:
            with self.subTest(reason=reason):
                interpretation = subject.interpret_onset_evidence(evidence)

                self.assertEqual(
                    interpretation["betweenLayerOnsetIntervalGapMs"],
                    200,
                )
                self.assertEqual(
                    interpretation["onsetCohortSupport"],
                    "neutral",
                )
                self.assertEqual(interpretation["reasonCodes"], [reason])

    def test_separation_just_below_boundary_remains_neutral(self) -> None:
        evidence = complete_evidence(0, 50, 249, 299)

        interpretation = subject.interpret_onset_evidence(evidence)

        self.assertTrue(interpretation["lowerWithinCohortSpanMaximum"])
        self.assertTrue(interpretation["upperWithinCohortSpanMaximum"])
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 199)
        self.assertEqual(interpretation["onsetCohortSupport"], "neutral")
        self.assertEqual(
            interpretation["reasonCodes"],
            ["between-layer-separation-below-minimum"],
        )

    def test_incomplete_history_is_neutral_and_not_partially_interpreted(
        self,
    ) -> None:
        evidence = complete_evidence(0, 0, 400, 400)
        evidence["allCandidateOnsetsKnown"] = False

        interpretation = subject.interpret_onset_evidence(evidence)

        self.assertEqual(
            interpretation,
            {
                "availability": "incomplete",
                "lowerWithinCohortSpanMaximum": None,
                "upperWithinCohortSpanMaximum": None,
                "layerOnsetOrder": None,
                "betweenLayerOnsetIntervalGapMs": None,
                "onsetCohortSupport": "neutral",
                "reasonCodes": ["onset-history-incomplete"],
            },
        )

    def test_attack_velocity_does_not_change_interpretation(self) -> None:
        document = support_document("two-register-held-cohorts.json", 5)
        evidence = document["candidateInterpretations"][0]["onsetEvidence"]
        changed = deepcopy(evidence)
        for note in changed["lower"]["notes"] + changed["upper"]["notes"]:
            note["onsetVelocity"] = 1

        self.assertEqual(
            subject.interpret_onset_evidence(evidence),
            subject.interpret_onset_evidence(changed),
        )

    def test_frames_without_candidates_remain_empty(self) -> None:
        document = support_document("carried-in-state.json", 0)

        self.assertEqual(document["candidateInterpretations"], [])

    def test_output_document_has_the_exact_contract_fields(self) -> None:
        document = support_document("two-register-held-cohorts.json", 5)

        self.assertEqual(
            set(document),
            {
                "schema",
                "ablationId",
                "parameters",
                "sourceEvidenceSchema",
                "fixtureId",
                "fixtureSha256",
                "observationFrame",
                "candidateInterpretations",
            },
        )
        self.assertEqual(document["schema"], "polychord-onset-support/1")
        self.assertEqual(
            document["sourceEvidenceSchema"],
            "polychord-onset-evidence/1",
        )
        item = document["candidateInterpretations"][0]
        self.assertEqual(
            set(item),
            {"candidate", "onsetEvidence", "onsetInterpretation"},
        )
        self.assertEqual(
            set(item["onsetInterpretation"]),
            {
                "availability",
                "lowerWithinCohortSpanMaximum",
                "upperWithinCohortSpanMaximum",
                "layerOnsetOrder",
                "betweenLayerOnsetIntervalGapMs",
                "onsetCohortSupport",
                "reasonCodes",
            },
        )


if __name__ == "__main__":
    unittest.main()

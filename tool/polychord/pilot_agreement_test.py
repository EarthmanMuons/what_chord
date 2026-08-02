"""Unit tests for pre-adjudication polychord pilot agreement."""

from __future__ import annotations

import json
import unittest
from copy import deepcopy
from pathlib import Path

import pilot_agreement as subject
import pilot_ruler

ROOT = Path(__file__).parents[2]
RULER = ROOT / "research/polychord/pilot-ruler-v0.json"
GUIDE = ROOT / "research/polychord/pilot-annotation.md"


class PilotAgreementTest(unittest.TestCase):
    def setUp(self) -> None:
        self.ruler = json.loads(RULER.read_text())
        self.review = pilot_ruler.build_review_packet(
            self.ruler,
            ruler_sha256=pilot_ruler.sha256_file(RULER),
            guide_sha256=pilot_ruler.sha256_file(GUIDE),
        )
        self.review["status"] = "complete"
        self.review["reviewMetadata"] = {
            "annotatorId": "reviewer-test",
            "completedOn": "2026-08-02",
        }

    def complete_from_initial(self) -> None:
        for initial, independent in zip(
            pilot_ruler.ordered_review_cases(self.ruler),
            self.review["cases"],
            strict=True,
        ):
            response = independent["response"]
            response["observationKind"] = initial["observation"]["kind"]
            response["constructionTag"] = initial["tag"]
            response["layers"] = deepcopy(initial["layers"])
            response["sharedPitchClasses"] = initial["sharedPitchClasses"].copy()
            response["singleChordAlternatives"] = initial[
                "singleChordAlternatives"
            ].copy()
            observed = set(independent["evidence"].get("midiNotes", []))
            assigned = {
                note
                for layer in response["layers"]
                for note in layer.get("midiNotes", [])
            }
            response["unassignedMidiNotes"] = sorted(observed - assigned)
            response["inputEligibility"] = deepcopy(initial["inputEligibility"])
            response["confidence"] = "high"
            response["notes"] = "Test fixture copied from the initial annotation."

    def report(self) -> dict:
        return subject.agreement_report(
            self.ruler,
            self.review,
            ruler_sha256=pilot_ruler.sha256_file(RULER),
            guide_sha256=pilot_ruler.sha256_file(GUIDE),
            review_sha256="test-review-digest",
            tool_sha256="test-tool-digest",
            generating_command="python3 tool/polychord/pilot_agreement.py ...",
            working_directory=str(ROOT),
            python_version="test-python",
        )

    def test_identical_annotations_have_complete_raw_agreement(self) -> None:
        self.complete_from_initial()

        report = self.report()

        self.assertEqual(report["constructionTag"]["rate"], 1.0)
        self.assertEqual(report["observationKind"]["rate"], 1.0)
        self.assertEqual(report["layerPitchClasses"]["exactAgreements"], 6)
        self.assertEqual(report["layerPitchClasses"]["meanBestMatchJaccard"], 1.0)
        self.assertEqual(
            report["syntheticNotePartitions"], {"exactAgreements": 4, "total": 4}
        )
        for summary in report["inputEligibility"].values():
            self.assertEqual(summary["rate"], 1.0)

    def test_layer_matching_is_order_invariant_and_penalizes_missing_layers(
        self,
    ) -> None:
        layers = [
            {"pitchClasses": [0, 4, 7]},
            {"pitchClasses": [1, 6, 10]},
        ]

        self.assertEqual(
            subject.best_layer_jaccard(layers, list(reversed(layers)), "pitchClasses"),
            1.0,
        )
        self.assertEqual(
            subject.best_layer_jaccard(layers, layers[:1], "pitchClasses"), 0.5
        )

    def test_abstentions_are_reported_as_pre_adjudication_disagreement(self) -> None:
        self.complete_from_initial()
        self.review["cases"][0]["response"]["constructionTag"] = "abstain"
        self.review["cases"][0]["response"]["layers"] = []
        self.review["cases"][0]["response"]["sharedPitchClasses"] = []
        self.review["cases"][0]["response"]["unassignedMidiNotes"] = self.review[
            "cases"
        ][0]["evidence"].get("midiNotes", [])

        report = self.report()

        self.assertEqual(report["constructionTag"]["agreements"], 5)
        self.assertEqual(report["constructionTag"]["reviewerAbstentions"], 1)
        self.assertEqual(report["status"], "pre-adjudication")
        self.assertEqual(report["method"]["adjudication"], "excluded")


if __name__ == "__main__":
    unittest.main()

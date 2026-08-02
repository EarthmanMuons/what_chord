"""Unit tests for the draft polychord pilot ruler."""

from __future__ import annotations

import json
import unittest
from copy import deepcopy
from pathlib import Path

import pilot_ruler as subject

RULER = Path(__file__).parents[2] / "research/polychord/pilot-ruler-v0.json"
GUIDE = Path(__file__).parents[2] / "research/polychord/pilot-annotation.md"


class PilotRulerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.payload = json.loads(RULER.read_text())

    def review_packet(self) -> dict:
        return subject.build_review_packet(
            self.payload,
            ruler_sha256=subject.sha256_file(RULER),
            guide_sha256=subject.sha256_file(GUIDE),
        )

    def test_ruler_is_structurally_valid_but_not_scorable(self) -> None:
        subject.validate(self.payload)
        self.assertFalse(self.payload["scoringAllowed"])

    def test_matched_shared_tone_controls_have_identical_snapshots(self) -> None:
        cases = {case["id"]: case for case in self.payload["cases"]}

        layered = cases["synthetic-shared-tone-layered-c-over-gm"]
        integrated = cases["synthetic-integrated-c9-matched-snapshot"]

        self.assertEqual(
            layered["observation"]["midiNotes"],
            integrated["observation"]["midiNotes"],
        )
        self.assertNotEqual(layered["tag"], integrated["tag"])

    def test_canonical_cases_do_not_claim_adjacent_register_eligibility(self) -> None:
        cases = {case["id"]: case for case in self.payload["cases"]}

        for case_id in ("stravinsky-petrushka-r49", "stravinsky-augurs-r13"):
            with self.subTest(case=case_id):
                status = cases[case_id]["inputEligibility"]["adjacentRegisterSnapshot"][
                    "status"
                ]
                self.assertEqual(status, "ineligible")

    def test_review_packet_is_valid_and_does_not_mutate_ruler(self) -> None:
        original = deepcopy(self.payload)

        packet = self.review_packet()
        subject.validate_review_packet(
            packet,
            self.payload,
            ruler_sha256=subject.sha256_file(RULER),
            guide_sha256=subject.sha256_file(GUIDE),
        )

        self.assertEqual(self.payload, original)
        self.assertEqual(packet["status"], "template")

    def test_review_packet_omits_initial_judgments_and_descriptive_ids(self) -> None:
        packet = self.review_packet()
        original_ids = {case["id"] for case in self.payload["cases"]}

        for index, case in enumerate(packet["cases"], start=1):
            self.assertEqual(case["reviewId"], f"case-{index:03d}")
            self.assertEqual(set(case), {"reviewId", "evidence", "response"})
            self.assertEqual(case["response"], subject.blank_response())

        serialized = json.dumps(packet["cases"], sort_keys=True)
        for case_id in original_ids:
            self.assertNotIn(case_id, serialized)
        for field in (
            "verificationStatus",
            "independentReview",
        ):
            self.assertNotIn(f'"{field}"', serialized)

    def test_review_packet_preserves_raw_matched_control_evidence(self) -> None:
        packet = self.review_packet()
        synthetic = [
            case["evidence"]
            for case in packet["cases"]
            if case["evidence"]["kind"] == "synthetic-midi"
        ]
        matched = [
            evidence
            for evidence in synthetic
            if evidence.get("midiNotes") == [43, 46, 50, 60, 64, 67]
        ]

        self.assertEqual(len(matched), 2)
        self.assertNotEqual(matched[0]["onsetCohortsMs"], matched[1]["onsetCohortsMs"])

    def test_review_packet_rejects_a_mapping_or_changed_evidence(self) -> None:
        for mutation in ("mapping", "evidence"):
            with self.subTest(mutation=mutation):
                packet = self.review_packet()
                if mutation == "mapping":
                    packet["caseMapping"] = {"case-001": "initial-case-id"}
                else:
                    packet["cases"][0]["evidence"]["midiNotes"] = [60]

                with self.assertRaises(AssertionError):
                    subject.validate_review_packet(
                        packet,
                        self.payload,
                        ruler_sha256=subject.sha256_file(RULER),
                        guide_sha256=subject.sha256_file(GUIDE),
                    )

    def test_complete_review_requires_independent_answers(self) -> None:
        packet = self.review_packet()
        packet["status"] = "complete"
        packet["reviewMetadata"] = {
            "annotatorId": "reviewer-opaque-01",
            "completedOn": "2026-08-02",
        }
        for case in packet["cases"]:
            response = case["response"]
            response["observationKind"] = "snapshot"
            response["constructionTag"] = "abstain"
            response["confidence"] = "low"
            response["notes"] = "Insufficient evidence for a construction label."
            response["unassignedMidiNotes"] = case["evidence"].get("midiNotes", [])
            for judgment in response["inputEligibility"].values():
                judgment["status"] = "unknown"
                judgment["reason"] = "Not resolved in this review."

        subject.validate_review_packet(
            packet,
            self.payload,
            ruler_sha256=subject.sha256_file(RULER),
            guide_sha256=subject.sha256_file(GUIDE),
        )


if __name__ == "__main__":
    unittest.main()

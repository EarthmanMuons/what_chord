"""Unit tests for the draft polychord pilot ruler."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

import pilot_ruler as subject

RULER = Path(__file__).parents[2] / "research/polychord/pilot-ruler-v0.json"


class PilotRulerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.payload = json.loads(RULER.read_text())

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


if __name__ == "__main__":
    unittest.main()

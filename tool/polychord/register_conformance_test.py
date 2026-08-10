"""Tests for the symmetric register-candidate conformance matrix."""

from __future__ import annotations

import unittest

import register_conformance as subject


class RegisterConformanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.measurement = subject.measurement_payload()

    def test_core_matrix_contains_every_exact_target_assignment(self) -> None:
        core = self.measurement["coreMatrix"]

        self.assertEqual(core["combinationCount"], 3300)
        self.assertEqual(core["intendedExactAssignmentCount"], 3300)
        self.assertEqual(core["failureCount"], 0)
        self.assertEqual(core["failures"], [])

    def test_core_matrix_covers_the_symmetric_quality_vocabulary(self) -> None:
        method = self.measurement["method"]
        core = self.measurement["coreMatrix"]

        self.assertEqual(
            method["qualities"],
            ["major", "minor", "dominant7", "major7", "minor7"],
        )
        self.assertEqual(method["orderedQualityPairCount"], 25)
        self.assertEqual(method["relativeRootIntervals"], list(range(1, 12)))
        self.assertEqual(method["transpositions"], list(range(12)))
        self.assertEqual(
            sum(core["targetGapSemitoneDistribution"].values()),
            3300,
        )
        self.assertEqual(
            sum(core["targetSharedPitchClassCountDistribution"].values()),
            3300,
        )

    def test_additional_candidates_are_retained_in_full(self) -> None:
        core = self.measurement["coreMatrix"]
        additional_cases = core["additionalCandidateCases"]

        self.assertEqual(core["combinationsWithAdditionalCandidates"], 984)
        self.assertEqual(core["totalAdditionalCandidateCount"], 1140)
        self.assertEqual(len(additional_cases), 984)
        self.assertEqual(
            sum(len(case["additionalCandidates"]) for case in additional_cases),
            1140,
        )

    def test_every_focused_control_passes(self) -> None:
        controls = self.measurement["focusedControls"]

        self.assertEqual(len(controls), 11)
        self.assertTrue(all(control["passed"] for control in controls))

    def test_assignment_ambiguity_is_preserved_as_two_candidates(self) -> None:
        control = next(
            control
            for control in self.measurement["focusedControls"]
            if control["id"] == "same-identity-multiple-assignments"
        )

        self.assertEqual(control["actual"]["symbols"], ["G|C", "G|C"])
        self.assertEqual(
            control["actual"]["assignments"],
            [
                {"lower": [48, 52, 55], "upper": [67, 71, 74, 79]},
                {"lower": [48, 52, 55, 67], "upper": [71, 74, 79]},
            ],
        )

    def test_multiple_identity_control_preserves_both_candidates(self) -> None:
        control = next(
            control
            for control in self.measurement["focusedControls"]
            if control["id"] == "multiple-candidate-identities"
        )

        self.assertEqual(control["actual"]["symbols"], ["Bm7|C", "D|Cmaj7"])


if __name__ == "__main__":
    unittest.main()

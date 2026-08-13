"""Controls for the Python/Dart onset-support equivalence harness."""

from __future__ import annotations

import unittest

import onset_support_equivalence as subject


class OnsetSupportEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_replays_every_frame_from_the_pinned_manifest(self) -> None:
        self.assertEqual(len(self.cases), 124)
        self.assertEqual(len({case["fixtureId"] for case in self.cases}), 9)
        self.assertEqual(len({case["id"] for case in self.cases}), 124)

    def test_expected_records_have_complete_support_shape(self) -> None:
        records = [
            interpretation
            for case in self.cases
            for interpretation in case["candidateInterpretations"]
        ]

        self.assertEqual(len(records), 18)
        self.assertTrue(
            all(
                set(record) == {"candidate", "onsetEvidence", "onsetInterpretation"}
                for record in records
            )
        )

    def test_fixture_controls_include_positive_and_neutral_results(self) -> None:
        results = [
            interpretation["onsetInterpretation"]["onsetCohortSupport"]
            for case in self.cases
            for interpretation in case["candidateInterpretations"]
        ]

        self.assertIn("positive", results)
        self.assertIn("neutral", results)


if __name__ == "__main__":
    unittest.main()

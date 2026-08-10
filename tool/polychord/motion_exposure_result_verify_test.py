"""Unit tests for the frozen motion-exposure report verifier."""

from __future__ import annotations

import unittest

import motion_exposure_result_verify as subject


class MotionExposureResultVerifyTest(unittest.TestCase):
    def test_distribution_summary_uses_nearest_rank(self) -> None:
        self.assertEqual(
            subject.distribution_summary([4, 1, 3, 2]),
            {
                "count": 4,
                "minimum": 1,
                "medianNearestRank": 2,
                "p90NearestRank": 4,
                "maximum": 4,
            },
        )

    def test_endpoint_classification_is_total_for_detailed_windows(self) -> None:
        self.assertEqual(
            subject.expected_classification([1], [2]), "candidate-to-candidate"
        )
        self.assertEqual(subject.expected_classification([], [2]), "candidate-entry")
        self.assertEqual(subject.expected_classification([1], []), "candidate-exit")
        with self.assertRaisesRegex(ValueError, "candidate at one endpoint"):
            subject.expected_classification([], [])


if __name__ == "__main__":
    unittest.main()

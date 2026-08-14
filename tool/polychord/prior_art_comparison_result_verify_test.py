"""Controls for retained polychord comparison result verification."""

from __future__ import annotations

import unittest

import prior_art_comparison_result_verify as subject


class PriorArtComparisonResultVerifyTest(unittest.TestCase):
    def test_retained_results_recompute_exactly(self) -> None:
        summary = subject.verify()

        self.assertTrue(summary["product"]["suiteExactGatePass"])
        self.assertEqual(summary["product"]["checkpointCount"], 108)
        totals = {
            value["baselineId"]: value["namedSnapshots"]
            for value in summary["baselines"]
        }
        self.assertEqual(
            totals["whatchord-register-policy-1"]["orderedCompositeExact"],
            {"count": 14, "eligible": 14},
        )
        self.assertEqual(
            totals["musicpy-7.15-poly-chord-first"]["orderedCompositeExact"],
            {"count": 5, "eligible": 14},
        )
        self.assertEqual(
            totals["python-mingus-6558cac-polychords"]["assignmentExact"],
            {"count": 0, "eligible": 0},
        )


if __name__ == "__main__":
    unittest.main()

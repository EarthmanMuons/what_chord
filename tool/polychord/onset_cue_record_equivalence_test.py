"""Controls for the Python/Dart onset-cue-record equivalence harness."""

from __future__ import annotations

import unittest

import onset_cue_record_equivalence as subject


class OnsetCueRecordEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_covers_every_pinned_frame_and_one_incomplete_control(self) -> None:
        fixture_cases = [case for case in self.cases if case["fixtureId"] is not None]
        synthetic_cases = [case for case in self.cases if case["fixtureId"] is None]

        self.assertEqual(len(self.cases), 125)
        self.assertEqual(len(fixture_cases), 124)
        self.assertEqual(len({case["fixtureId"] for case in fixture_cases}), 9)
        self.assertEqual(len(synthetic_cases), 1)

    def test_records_preserve_complete_v2_diagnostic_shape(self) -> None:
        records = [record for case in self.cases for record in case["cueRecords"]]

        self.assertEqual(len(records), 19)
        self.assertTrue(
            all(
                set(record)
                == {
                    "cueId",
                    "evidenceSchemaId",
                    "targetObservation",
                    "targetBinding",
                    "availability",
                    "support",
                    "reasonCodes",
                    "diagnostic",
                }
                for record in records
            )
        )
        self.assertTrue(all(record["cueId"] == subject.CUE_ID for record in records))
        self.assertTrue(
            all(
                record["evidenceSchemaId"] == subject.EVIDENCE_SCHEMA_ID
                for record in records
            )
        )

    def test_support_states_distinguish_neutral_from_incomplete(self) -> None:
        records = [record for case in self.cases for record in case["cueRecords"]]

        self.assertEqual(
            [record["availability"] for record in records].count("complete"),
            18,
        )
        self.assertEqual(
            [record["availability"] for record in records].count("incomplete"),
            1,
        )
        self.assertEqual([record["support"] for record in records].count("positive"), 1)
        self.assertEqual([record["support"] for record in records].count("neutral"), 17)
        self.assertEqual([record["support"] for record in records].count(None), 1)


if __name__ == "__main__":
    unittest.main()

"""Controls for the Python/Dart onset-evidence equivalence harness."""

from __future__ import annotations

import unittest

import onset_evidence_equivalence as subject


class OnsetEvidenceEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_replays_every_frame_from_the_pinned_manifest(self) -> None:
        fixture_ids = {case["fixtureId"] for case in self.cases}

        self.assertEqual(len(fixture_ids), 9)
        self.assertEqual(len({case["id"] for case in self.cases}), len(self.cases))
        self.assertEqual(len(self.cases), 124)

    def test_each_request_contains_complete_sorted_sounding_note_evidence(
        self,
    ) -> None:
        for case in self.cases:
            with self.subTest(case=case["id"]):
                notes = case["soundingNotes"]
                self.assertEqual(
                    [note["midiNote"] for note in notes],
                    sorted(note["midiNote"] for note in notes),
                )
                self.assertTrue(
                    all(
                        set(note)
                        == {
                            "midiNote",
                            "soundingState",
                            "onsetEventIndex",
                            "onsetTimestampMs",
                            "onsetVelocity",
                        }
                        for note in notes
                    )
                )

    def test_python_expectations_use_the_complete_candidate_evidence_shape(
        self,
    ) -> None:
        records = [
            evidence for case in self.cases for evidence in case["candidateEvidence"]
        ]

        self.assertEqual(len(records), 18)
        self.assertTrue(
            all(set(record) == {"candidate", "onsetEvidence"} for record in records)
        )


if __name__ == "__main__":
    unittest.main()

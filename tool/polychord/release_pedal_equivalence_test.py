"""Controls for the Python/Dart release-pedal equivalence harness."""

from __future__ import annotations

import unittest

import release_pedal_equivalence as subject


class ReleasePedalEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_compares_every_frame_from_every_pinned_fixture(self) -> None:
        self.assertEqual(len(self.cases), 9)
        self.assertEqual(len({case["id"] for case in self.cases}), 9)
        self.assertEqual(sum(len(case["frames"]) for case in self.cases), 124)
        candidate_counts = [
            len(frame["candidateEvidence"])
            for case in self.cases
            for frame in case["frames"]
        ]
        self.assertEqual(sum(bool(count) for count in candidate_counts), 18)
        self.assertEqual(sum(candidate_counts), 18)

    def test_expected_frames_combine_raw_history_and_candidates(self) -> None:
        expected_fields = {
            "trackerEpoch",
            "afterEventIndex",
            "timestampMs",
            "pedal",
            "notes",
            "candidateEvidence",
        }
        for case in self.cases:
            with self.subTest(fixture=case["id"]):
                self.assertTrue(
                    all(set(frame) == expected_fields for frame in case["frames"])
                )

    def test_carried_in_release_and_pedal_origins_remain_unknown(self) -> None:
        carried = next(case for case in self.cases if case["id"] == "carried-in-state")
        first_frame = carried["frames"][0]
        notes = {note["midiNote"]: note for note in first_frame["notes"]}

        self.assertIsNone(first_frame["pedal"]["lastTransitionEventIndex"])
        self.assertIsNone(notes[36]["onsetEventIndex"])
        self.assertIsNone(notes[36]["releaseEventIndex"])
        self.assertIsNone(notes[48]["currentStateSinceEventIndex"])
        self.assertEqual(notes[60]["onsetEventIndex"], 0)


if __name__ == "__main__":
    unittest.main()

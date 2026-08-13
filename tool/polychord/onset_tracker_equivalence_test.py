"""Controls for the Python/Dart onset-tracker equivalence harness."""

from __future__ import annotations

import unittest

import onset_tracker_equivalence as subject


class OnsetTrackerEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_compares_every_frame_from_every_pinned_fixture(self) -> None:
        self.assertEqual(len(self.cases), 9)
        self.assertEqual(len({case["id"] for case in self.cases}), 9)
        self.assertEqual(sum(len(case["frames"]) for case in self.cases), 124)

    def test_expected_frames_combine_replay_and_onset_fields(self) -> None:
        expected_fields = {
            "trackerEpoch",
            "afterEventIndex",
            "timestampMs",
            "pressedMidiNotes",
            "sustainedMidiNotes",
            "soundingMidiNotes",
            "pedalDown",
            "onsetNotes",
        }

        for case in self.cases:
            with self.subTest(fixture=case["id"]):
                self.assertTrue(
                    all(set(frame) == expected_fields for frame in case["frames"])
                )

    def test_carried_in_notes_remain_unknown(self) -> None:
        carried = next(case for case in self.cases if case["id"] == "carried-in-state")
        first_frame = carried["frames"][0]
        notes = {note["midiNote"]: note for note in first_frame["onsetNotes"]}

        self.assertIsNone(notes[36]["onsetEventIndex"])
        self.assertIsNone(notes[48]["onsetEventIndex"])
        self.assertEqual(notes[60]["onsetEventIndex"], 0)


if __name__ == "__main__":
    unittest.main()

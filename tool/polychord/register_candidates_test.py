"""Unit tests for the register-only polychord candidate generator."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

import register_candidates as subject
import split_census as historical_census

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


class RegisterCandidatesTest(unittest.TestCase):
    def test_v0_vocabulary_is_symmetric_complete_common_chords(self) -> None:
        self.assertEqual(
            set(subject.COMMON_CHORD_TEMPLATES.values()),
            {"major", "minor", "dominant7", "major7", "minor7"},
        )

    def test_clean_triads_report_exact_assignment_and_observed_gap(self) -> None:
        candidates = subject.generate_register_candidates([48, 52, 55, 66, 70, 73])

        self.assertEqual(len(candidates), 1)
        candidate = candidates[0]
        self.assertEqual(candidate.symbol, "F#|C")
        self.assertEqual(candidate.split_after_index, 2)
        self.assertEqual(candidate.lower.midi_notes, (48, 52, 55))
        self.assertEqual(candidate.upper.midi_notes, (66, 70, 73))
        self.assertEqual(candidate.lower.pitch_classes, (0, 4, 7))
        self.assertEqual(candidate.upper.pitch_classes, (1, 6, 10))
        self.assertEqual(candidate.lower_top_midi, 55)
        self.assertEqual(candidate.upper_bottom_midi, 66)
        self.assertEqual(candidate.gap_semitones, 11)

    def test_serialized_document_has_the_exact_schema_fields(self) -> None:
        document = subject.candidate_document([48, 52, 55, 66, 70, 73])

        self.assertEqual(set(document), {"schema", "midiNotes", "candidates"})
        self.assertEqual(document["schema"], "polychord-register-candidates/1")
        self.assertEqual(document["midiNotes"], [48, 52, 55, 66, 70, 73])
        self.assertEqual(len(document["candidates"]), 1)
        candidate = document["candidates"][0]
        self.assertEqual(
            set(candidate),
            {
                "splitAfterIndex",
                "lowerTopMidi",
                "upperBottomMidi",
                "gapSemitones",
                "lower",
                "upper",
                "sharedPitchClasses",
                "symbol",
            },
        )
        self.assertEqual(
            set(candidate["lower"]),
            {"rootPc", "quality", "midiNotes", "pitchClasses"},
        )
        self.assertEqual(
            set(candidate["upper"]),
            {"rootPc", "quality", "midiNotes", "pitchClasses"},
        )
        self.assertEqual(candidate["symbol"], "F#|C")

    def test_shared_pitch_classes_require_separate_notes_across_layers(self) -> None:
        candidates = subject.generate_register_candidates([43, 46, 50, 60, 64, 67])

        self.assertEqual([candidate.symbol for candidate in candidates], ["C|Gm"])
        self.assertEqual(candidates[0].shared_pitch_classes, (7,))
        self.assertEqual(candidates[0].lower.midi_notes, (43, 46, 50))
        self.assertEqual(candidates[0].upper.midi_notes, (60, 64, 67))

    def test_layer_inversions_and_internal_octave_doubling_are_allowed(self) -> None:
        # C major in first inversion with a doubled E, below D major in second
        # inversion.
        candidates = subject.generate_register_candidates([40, 43, 48, 52, 57, 62, 66])

        self.assertEqual([candidate.symbol for candidate in candidates], ["D|C"])
        self.assertEqual(candidates[0].lower.midi_notes, (40, 43, 48, 52))
        self.assertEqual(candidates[0].upper.midi_notes, (57, 62, 66))

    def test_same_root_in_two_registers_is_excluded(self) -> None:
        candidates = subject.generate_register_candidates([36, 40, 43, 60, 64, 67])

        self.assertEqual(candidates, ())

    def test_incomplete_layer_is_excluded(self) -> None:
        # D major over a C7 shell without its fifth.
        candidates = subject.generate_register_candidates([36, 52, 58, 62, 66, 69])

        self.assertEqual(candidates, ())

    def test_no_register_gap_threshold_is_hidden_in_generation(self) -> None:
        # An integrated D6 sonority has an exact B-minor-over-D split separated
        # by only two semitones. Generation reports the structural possibility;
        # later evidence and display policy must decide whether to use it.
        candidates = subject.generate_register_candidates([50, 54, 57, 59, 62, 66])

        self.assertEqual([candidate.symbol for candidate in candidates], ["Bm|D"])
        self.assertEqual(candidates[0].gap_semitones, 2)
        self.assertEqual(candidates[0].shared_pitch_classes, (2, 6))

    def test_every_qualifying_boundary_is_reported_in_register_order(self) -> None:
        notes = [36, 40, 43, 59, 74, 78, 81]

        candidates = subject.generate_register_candidates(notes)

        self.assertEqual(
            [candidate.symbol for candidate in candidates],
            ["Bm7|C", "D|Cmaj7"],
        )
        self.assertEqual(
            [candidate.split_after_index for candidate in candidates],
            [2, 3],
        )

    def test_matching_replay_frames_have_identical_register_candidates(self) -> None:
        synchronous = json.loads(
            (FIXTURE_DIR / "synchronous-six-note-cohort.json").read_text()
        )
        layered = json.loads(
            (FIXTURE_DIR / "two-register-held-cohorts.json").read_text()
        )

        synchronous_candidates = subject.generate_register_candidates(
            synchronous["frames"][5]["soundingMidiNotes"]
        )
        layered_candidates = subject.generate_register_candidates(
            layered["frames"][5]["soundingMidiNotes"]
        )

        self.assertEqual(synchronous_candidates, layered_candidates)
        self.assertEqual(
            [candidate.symbol for candidate in synchronous_candidates],
            ["C|Gm"],
        )

    def test_matches_historical_complete_common_census_on_synthetic_cases(
        self,
    ) -> None:
        cases = (
            [48, 52, 55, 66, 70, 73],
            [43, 46, 50, 60, 64, 67],
            [36, 40, 43, 59, 74, 78, 81],
            [50, 54, 57, 59, 62, 66],
        )
        profile = historical_census.TEMPLATE_PROFILES["complete-common"]

        for notes in cases:
            with self.subTest(notes=notes):
                historical = historical_census.registral_splits(
                    notes,
                    1,
                    profile["upper"],
                    profile["lower"],
                    allow_shared_pitch_classes=True,
                )
                expected = {
                    (
                        split["lowerTopMidi"],
                        split["upperBottomMidi"],
                        split["upperRoot"],
                        split["upperQuality"],
                        split["lowerRoot"],
                        split["lowerQuality"],
                        tuple(split["sharedPitchClasses"]),
                    )
                    for split in historical
                }
                actual = {
                    (
                        candidate.lower_top_midi,
                        candidate.upper_bottom_midi,
                        candidate.upper.root_pitch_class,
                        candidate.upper.quality,
                        candidate.lower.root_pitch_class,
                        candidate.lower.quality,
                        candidate.shared_pitch_classes,
                    )
                    for candidate in subject.generate_register_candidates(notes)
                }
                self.assertEqual(actual, expected)

    def test_frame_input_must_be_strictly_increasing_midi(self) -> None:
        invalid_cases = (
            ([60, 59], ValueError),
            ([60, 60], ValueError),
            ([-1], ValueError),
            ([128], ValueError),
            ([True], TypeError),
        )

        for notes, error_type in invalid_cases:
            with self.subTest(notes=notes), self.assertRaises(error_type):
                subject.generate_register_candidates(notes)


if __name__ == "__main__":
    unittest.main()

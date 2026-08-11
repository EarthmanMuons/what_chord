"""Unit tests for the preregistered register-only polychord selector."""

from __future__ import annotations

import unittest

import register_candidates
import register_selector as subject


def transposed(shape: set[int], root_pc: int) -> frozenset[int]:
    return frozenset((root_pc + interval) % 12 for interval in shape)


def layer(
    *,
    root_pc: int,
    quality: str,
    midi_notes: tuple[int, ...],
) -> register_candidates.LayerCandidate:
    return register_candidates.LayerCandidate(
        root_pitch_class=root_pc,
        quality=quality,
        midi_notes=midi_notes,
        pitch_classes=tuple(sorted({note % 12 for note in midi_notes})),
    )


def candidate(
    *,
    lower: register_candidates.LayerCandidate,
    upper: register_candidates.LayerCandidate,
) -> register_candidates.RegisterCandidate:
    return register_candidates.RegisterCandidate(
        split_after_index=len(lower.midi_notes) - 1,
        lower_top_midi=lower.midi_notes[-1],
        upper_bottom_midi=upper.midi_notes[0],
        gap_semitones=upper.midi_notes[0] - lower.midi_notes[-1],
        lower=lower,
        upper=upper,
        shared_pitch_classes=tuple(
            sorted(set(lower.pitch_classes) & set(upper.pitch_classes))
        ),
    )


class IntegratedTertianTest(unittest.TestCase):
    def test_every_compact_shape_is_recognized_in_every_transposition(self) -> None:
        for shape in subject.COMPACT_INTEGRATED_SHAPES:
            for root_pc in range(12):
                with self.subTest(shape=sorted(shape), root_pc=root_pc):
                    self.assertTrue(
                        subject._is_compact_integrated(transposed(set(shape), root_pc))
                    )

    def test_compact_test_requires_an_exact_shape(self) -> None:
        self.assertFalse(subject._is_compact_integrated(frozenset({0, 1, 4, 7})))
        self.assertFalse(subject._is_compact_integrated(frozenset({0, 2, 4, 7, 11})))

    def test_every_rooted_ninth_shape_is_orientation_sensitive(self) -> None:
        lower_major = layer(root_pc=0, quality="major", midi_notes=(48, 52, 55))
        lower_minor = layer(root_pc=0, quality="minor", midi_notes=(48, 51, 55))
        upper = layer(root_pc=7, quality="major", midi_notes=(67, 71, 74))
        major_candidate = candidate(lower=lower_major, upper=upper)
        minor_candidate = candidate(lower=lower_minor, upper=upper)

        for shape in subject.ROOTED_NINTH_SHAPES["major"]:
            self.assertTrue(subject._is_rooted_ninth_integrated(shape, major_candidate))
            shifted_lower = layer(
                root_pc=1,
                quality="major",
                midi_notes=(49, 53, 56),
            )
            self.assertFalse(
                subject._is_rooted_ninth_integrated(
                    shape,
                    candidate(lower=shifted_lower, upper=upper),
                )
            )

        minor_shape = next(iter(subject.ROOTED_NINTH_SHAPES["minor"]))
        self.assertTrue(
            subject._is_rooted_ninth_integrated(minor_shape, minor_candidate)
        )

    def test_seventh_extension_palettes_accept_only_preregistered_intervals(
        self,
    ) -> None:
        quality_notes = {
            "dominant7": (48, 52, 55, 58),
            "major7": (48, 52, 55, 59),
            "minor7": (48, 51, 55, 58),
        }
        upper = layer(root_pc=1, quality="major", midi_notes=(73, 77, 80))
        for quality, allowed in subject.ROOTED_SEVENTH_EXTENSION_INTERVALS.items():
            lower = layer(root_pc=0, quality=quality, midi_notes=quality_notes[quality])
            test_candidate = candidate(lower=lower, upper=upper)
            lower_pitch_classes = frozenset(lower.pitch_classes)
            for interval in range(12):
                if interval in lower_pitch_classes:
                    continue
                collection = lower_pitch_classes | {interval}
                with self.subTest(quality=quality, interval=interval):
                    self.assertEqual(
                        subject._is_rooted_seventh_extension_integrated(
                            frozenset(collection), test_candidate
                        ),
                        interval in allowed,
                    )


class RegisterSelectorTest(unittest.TestCase):
    def test_no_candidate_abstains_with_frozen_reason(self) -> None:
        decision = subject.decision_document([60, 64, 67])

        self.assertIsNone(decision["selected"])
        self.assertEqual(decision["reasonCodes"], ["no-structural-candidate"])

    def test_compact_integrated_collection_is_removed(self) -> None:
        decision = subject.decision_document([50, 54, 57, 59, 62, 66])

        self.assertEqual([c["symbol"] for c in decision["candidates"]], ["Bm|D"])
        self.assertIsNone(decision["selected"])
        self.assertEqual(decision["reasonCodes"], ["not-selected-by-policy"])
        self.assertTrue(decision["traces"][0]["integratedTertian"]["compact"])

    def test_multiple_assignments_remove_the_whole_identity(self) -> None:
        decision = subject.decision_document([48, 52, 55, 67, 71, 74, 79])

        self.assertEqual(len(decision["candidates"]), 2)
        self.assertIsNone(decision["selected"])
        self.assertTrue(
            all(trace["removedByAssignmentVeto"] for trace in decision["traces"])
        )

    def test_unique_widest_gap_wins_independent_of_input_order(self) -> None:
        notes = (36, 40, 43, 76, 80, 83, 87)
        candidates = register_candidates.generate_register_candidates(notes)

        forward = subject.decision_document(notes, candidates=candidates)
        reverse = subject.decision_document(
            notes,
            candidates=tuple(reversed(candidates)),
        )

        self.assertEqual(forward["selected"], reverse["selected"])
        self.assertEqual(forward["reasonCodes"], [])
        self.assertEqual(forward["selected"]["symbol"], "Emaj7|C")

    def test_equal_widest_gaps_abstain_without_iteration_tie_break(self) -> None:
        decision = subject.decision_document([33, 37, 40, 44, 48, 51, 55])

        self.assertIsNone(decision["selected"])
        self.assertEqual(decision["reasonCodes"], ["multiple-unresolved-identities"])

    def test_gap_resolution_ablation_abstains_on_multiple_survivors(self) -> None:
        notes = [36, 40, 43, 76, 80, 83, 87]
        decision = subject.decision_document(notes)
        without_gap = subject.decision_document(
            notes,
            selector_id=subject.WITHOUT_GAP_RESOLUTION_ID,
        )

        self.assertIsNotNone(decision["selected"])
        self.assertIsNone(without_gap["selected"])
        self.assertEqual(without_gap["reasonCodes"], ["multiple-unresolved-identities"])

    def test_supplied_candidates_must_be_exact_contiguous_assignments(self) -> None:
        notes = (48, 52, 55, 66, 70, 73)
        valid = register_candidates.generate_register_candidates(notes)[0]
        invalid = register_candidates.RegisterCandidate(
            split_after_index=valid.split_after_index,
            lower_top_midi=valid.lower_top_midi,
            upper_bottom_midi=valid.upper_bottom_midi,
            gap_semitones=valid.gap_semitones,
            lower=valid.lower,
            upper=layer(root_pc=1, quality="minor", midi_notes=valid.upper.midi_notes),
            shared_pitch_classes=valid.shared_pitch_classes,
        )

        with self.assertRaisesRegex(ValueError, "upper identity is invalid"):
            subject.decision_document(notes, candidates=(invalid,))

    def test_selector_profile_must_be_preregistered(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported selector_id"):
            subject.decision_document([], selector_id="post-hoc/1")


if __name__ == "__main__":
    unittest.main()

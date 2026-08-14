"""Tests for the frozen automatic polychord product policy."""

from __future__ import annotations

import unittest

import onset_evidence
import product_policy as subject
import register_conformance


def _frame_input(
    midi_notes: list[int],
    timestamps: list[int | None],
    *,
    tracker_epoch: int = 0,
) -> tuple[dict, onset_evidence.OnsetFrame]:
    known = sorted(
        (
            (timestamp, midi_note)
            for midi_note, timestamp in zip(midi_notes, timestamps, strict=True)
            if timestamp is not None
        ),
        key=lambda value: (value[0], value[1]),
    )
    event_index_by_note = {
        midi_note: index for index, (_, midi_note) in enumerate(known)
    }
    timestamp_ms = max((value for value in timestamps if value is not None), default=0)
    notes = tuple(
        onset_evidence.SoundingNoteOnset(
            midi_note=midi_note,
            sounding_state="pressed",
            origin=(
                None
                if onset_timestamp is None
                else onset_evidence.OnsetOrigin(
                    event_index=event_index_by_note[midi_note],
                    timestamp_ms=onset_timestamp,
                    velocity=80,
                )
            ),
        )
        for midi_note, onset_timestamp in zip(midi_notes, timestamps, strict=True)
    )
    onset_frame = onset_evidence.OnsetFrame(
        after_event_index=max(len(known) - 1, 0),
        timestamp_ms=timestamp_ms,
        notes=notes,
    )
    replay_frame = {
        "afterEventIndex": onset_frame.after_event_index,
        "timestampMs": timestamp_ms,
        "pressedMidiNotes": midi_notes,
        "sustainedMidiNotes": [],
        "soundingMidiNotes": midi_notes,
        "pedalDown": False,
    }
    observation = subject.frame_document(
        tracker_epoch=tracker_epoch,
        frame=replay_frame,
        onset_frame=onset_frame,
    )
    return observation, onset_frame


def _decision(
    midi_notes: list[int], timestamps: list[int | None], *, tracker_epoch: int = 0
) -> dict:
    observation, onset_frame = _frame_input(
        midi_notes,
        timestamps,
        tracker_epoch=tracker_epoch,
    )
    return subject.decision_document(
        observation=observation,
        onset_frame=onset_frame,
    )


class ProductOnsetCueTest(unittest.TestCase):
    def test_inclusive_50_and_80_boundaries_are_positive(self) -> None:
        decision = _decision(
            [43, 46, 50, 60, 64, 67],
            [0, 25, 50, 130, 155, 180],
        )

        record = decision["candidateRecords"][0]
        interpretation = record["diagnostic"]["onsetInterpretation"]
        self.assertEqual(record["cueId"], subject.CUE_ID)
        self.assertEqual(record["support"], "positive")
        self.assertTrue(interpretation["lowerWithinCohortSpanMaximum"])
        self.assertTrue(interpretation["upperWithinCohortSpanMaximum"])
        self.assertEqual(interpretation["betweenLayerOnsetIntervalGapMs"], 80)

    def test_just_outside_boundaries_are_neutral_in_reason_order(self) -> None:
        span = _decision(
            [43, 46, 50, 60, 64, 67],
            [0, 25, 51, 131, 156, 181],
        )["candidateRecords"][0]
        gap = _decision(
            [43, 46, 50, 60, 64, 67],
            [0, 0, 0, 79, 79, 79],
        )["candidateRecords"][0]

        self.assertEqual(span["support"], "neutral")
        self.assertEqual(span["reasonCodes"], ["lower-span-exceeds-maximum"])
        self.assertEqual(gap["support"], "neutral")
        self.assertEqual(
            gap["reasonCodes"],
            ["between-layer-separation-below-minimum"],
        )

    def test_upper_then_lower_is_equivalent_and_incomplete_is_unavailable(self) -> None:
        reverse = _decision(
            [42, 46, 49, 60, 64, 67],
            [80, 80, 80, 0, 0, 0],
        )["candidateRecords"][0]
        incomplete = _decision(
            [43, 46, 50, 60, 64, 67],
            [None, None, None, None, None, None],
        )["candidateRecords"][0]

        self.assertEqual(reverse["support"], "positive")
        self.assertEqual(
            reverse["diagnostic"]["onsetInterpretation"]["layerOnsetOrder"],
            "upper-then-lower",
        )
        self.assertEqual(incomplete["availability"], "incomplete")
        self.assertIsNone(incomplete["support"])


class OnsetRegisterSelectorTest(unittest.TestCase):
    def test_reason_precedence_and_positive_selection(self) -> None:
        positive = _decision(
            [43, 46, 50, 60, 64, 67],
            [0, 0, 0, 80, 80, 80],
        )
        ambiguous = _decision(
            [48, 52, 55, 67, 71, 74, 79],
            [0, 0, 0, 80, 80, 80, 80],
        )
        integrated = _decision(
            [48, 52, 55, 67, 71, 74],
            [0, 0, 0, 80, 80, 80],
        )
        neutral = _decision(
            [43, 46, 50, 60, 64, 67],
            [0, 0, 0, 79, 79, 79],
        )
        incomplete = _decision(
            [43, 46, 50, 60, 64, 67],
            [None, None, None, None, None, None],
        )

        self.assertEqual(positive["selected"]["symbol"], "C|Gm")
        self.assertIsNone(positive["reasonCode"])
        self.assertEqual(ambiguous["reasonCode"], subject.AMBIGUOUS_EXACT_ASSIGNMENT)
        self.assertEqual(integrated["reasonCode"], subject.INTEGRATED_TERTIAN_READING)
        self.assertEqual(neutral["reasonCode"], subject.LAYER_SEPARATION_NOT_SUPPORTED)
        self.assertEqual(
            incomplete["reasonCode"], subject.MISSING_LAYER_SEPARATION_HISTORY
        )

    def test_upper_seventh_layer_is_selected(self) -> None:
        decision = _decision(
            [28, 40, 44, 47, 51, 55, 58, 61],
            [0, 0, 0, 0, 80, 80, 80, 80],
        )

        self.assertEqual(decision["selected"]["symbol"], "D#7|E")
        self.assertEqual(decision["selected"]["upper"]["quality"], "dominant7")

    def test_positive_survivor_uniqueness_across_complete_matrix(self) -> None:
        checked = 0
        for lower_quality in register_conformance.QUALITIES:
            for upper_quality in register_conformance.QUALITIES:
                for interval in register_conformance.RELATIVE_ROOT_INTERVALS:
                    for transposition in register_conformance.TRANSPOSITIONS:
                        lower = register_conformance.root_position_notes(
                            transposition,
                            lower_quality,
                            36,
                        )
                        upper = register_conformance.root_position_notes(
                            (transposition + interval) % 12,
                            upper_quality,
                            72,
                        )
                        midi_notes = sorted((*lower, *upper))
                        timestamps = [0] * len(lower) + [80] * len(upper)
                        decision = _decision(midi_notes, timestamps)
                        self.assertLessEqual(
                            len(decision["stageSurvivors"]["positiveSupport"]),
                            1,
                        )
                        checked += 1
        self.assertEqual(checked, 3300)


class ProductOutputReducerTest(unittest.TestCase):
    def test_continuous_authorization_appears_at_inclusive_deadline(self) -> None:
        frame, onset_frame = _frame_input(
            [43, 46, 50, 60, 64, 67],
            [0, 0, 0, 80, 80, 80],
        )
        raw_frame = {
            key: frame[key]
            for key in (
                "afterEventIndex",
                "timestampMs",
                "pressedMidiNotes",
                "sustainedMidiNotes",
                "soundingMidiNotes",
                "pedalDown",
            )
        }
        session = subject.ProductPolicySession(initial_primary_displayable=True)

        pending = session.observe_frame(
            tracker_epoch=0,
            frame=raw_frame,
            onset_frame=onset_frame,
        )
        before = session.observe_timer(279)
        visible = session.observe_timer(280)
        stable = session.observe_timer(281)

        self.assertEqual(pending["display"]["transition"], "pending")
        self.assertEqual(pending["display"]["deadlineMs"], 280)
        self.assertEqual(before["display"]["transition"], "none")
        self.assertEqual(visible["display"]["transition"], "appearance")
        self.assertEqual(stable["display"]["transition"], "stable")

    def test_primary_loss_clears_and_restore_restarts(self) -> None:
        frame, onset_frame = _frame_input(
            [43, 46, 50, 60, 64, 67],
            [0, 0, 0, 80, 80, 80],
        )
        raw_frame = {
            key: frame[key]
            for key in (
                "afterEventIndex",
                "timestampMs",
                "pressedMidiNotes",
                "sustainedMidiNotes",
                "soundingMidiNotes",
                "pedalDown",
            )
        }
        session = subject.ProductPolicySession(initial_primary_displayable=True)
        session.observe_frame(
            tracker_epoch=0,
            frame=raw_frame,
            onset_frame=onset_frame,
        )
        session.observe_timer(280)

        cleared = session.set_primary_displayable(
            timestamp_ms=300,
            displayable=False,
        )
        restarted = session.set_primary_displayable(
            timestamp_ms=310,
            displayable=True,
        )

        self.assertEqual(cleared["display"]["transition"], "clear")
        self.assertEqual(cleared["display"]["reasonCode"], "primary-not-displayable")
        self.assertEqual(restarted["display"]["transition"], "pending")
        self.assertEqual(restarted["display"]["deadlineMs"], 510)


if __name__ == "__main__":
    unittest.main()

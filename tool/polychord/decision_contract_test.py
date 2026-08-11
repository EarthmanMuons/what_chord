"""Unit tests for selector-independent polychord decision controls."""

from __future__ import annotations

import unittest
from copy import deepcopy

import decision_contract as subject


def c_over_g_minor() -> dict:
    return {
        "identity": {
            "upper": {"rootPc": 0, "quality": "major"},
            "lower": {"rootPc": 7, "quality": "minor"},
        },
        "upperMidiNotes": [60, 64, 67],
        "lowerMidiNotes": [43, 46, 50],
    }


def c_over_g_minor_alternative_assignment() -> dict:
    return {
        "identity": {
            "upper": {"rootPc": 0, "quality": "major"},
            "lower": {"rootPc": 7, "quality": "minor"},
        },
        "upperMidiNotes": [43, 60, 64],
        "lowerMidiNotes": [46, 50, 67],
    }


OBSERVED_NOTES = [43, 46, 50, 60, 64, 67]
MULTIPLE_IDENTITY_NOTES = [44, 48, 51, 54, 67, 71, 74]


def g_major_over_a_flat_seven() -> dict:
    return {
        "identity": {
            "upper": {"rootPc": 7, "quality": "major"},
            "lower": {"rootPc": 8, "quality": "dominant7"},
        },
        "upperMidiNotes": [67, 71, 74],
        "lowerMidiNotes": [44, 48, 51, 54],
    }


def g_major_seven_over_a_flat() -> dict:
    return {
        "identity": {
            "upper": {"rootPc": 7, "quality": "major7"},
            "lower": {"rootPc": 8, "quality": "major"},
        },
        "upperMidiNotes": [54, 67, 71, 74],
        "lowerMidiNotes": [44, 48, 51],
    }


class DecisionContractTest(unittest.TestCase):
    def test_registered_static_input_remains_selected_without_history(self) -> None:
        candidate = c_over_g_minor()

        decision = subject.evaluate_decision(
            input_mode="registered-static-midi",
            sounding_midi_notes=OBSERVED_NOTES,
            structural_candidates=[candidate],
            policy_selection=candidate,
            primary_displayable=True,
            onset_support="unavailable",
            motion_support="unavailable",
        )

        self.assertEqual(decision["selected"], candidate)
        self.assertEqual(decision["reasonCodes"], [])
        self.assertEqual(decision["support"]["onsetCohort"], "unavailable")
        self.assertEqual(decision["support"]["rigidLayerMotion"], "unavailable")

    def test_neutral_temporal_support_does_not_reject_selection(self) -> None:
        candidate = c_over_g_minor()

        decision = subject.evaluate_decision(
            input_mode="registered-event-stream",
            sounding_midi_notes=OBSERVED_NOTES,
            structural_candidates=[candidate],
            policy_selection=candidate,
            primary_displayable=True,
            onset_support="neutral",
            motion_support="neutral",
            release_and_pedal="available",
        )

        self.assertEqual(decision["selected"], candidate)
        self.assertEqual(decision["support"]["releaseAndPedal"], "available")

    def test_positive_temporal_support_does_not_authorize_selection(self) -> None:
        candidate = c_over_g_minor()

        decision = subject.evaluate_decision(
            input_mode="registered-event-stream",
            sounding_midi_notes=OBSERVED_NOTES,
            structural_candidates=[candidate],
            policy_selection=None,
            primary_displayable=True,
            onset_support="positive",
            motion_support="positive",
        )

        self.assertIsNone(decision["selected"])
        self.assertEqual(decision["reasonCodes"], ["not-selected-by-policy"])
        self.assertEqual(decision["support"]["onsetCohort"], "positive")
        self.assertEqual(decision["support"]["rigidLayerMotion"], "positive")

    def test_pitch_class_only_input_reports_missing_register_evidence(self) -> None:
        decision = subject.evaluate_decision(
            input_mode="pitch-class-only",
            sounding_midi_notes=[],
            structural_candidates=[],
            policy_selection=None,
            primary_displayable=True,
            onset_support="unavailable",
            motion_support="unavailable",
        )

        self.assertIsNone(decision["selected"])
        self.assertEqual(decision["reasonCodes"], ["missing-register-evidence"])

    def test_policy_selection_must_be_a_structural_candidate(self) -> None:
        with self.assertRaisesRegex(ValueError, "one structural candidate"):
            subject.evaluate_decision(
                input_mode="registered-static-midi",
                sounding_midi_notes=OBSERVED_NOTES,
                structural_candidates=[c_over_g_minor()],
                policy_selection=c_over_g_minor_alternative_assignment(),
                primary_displayable=True,
                onset_support="unavailable",
                motion_support="unavailable",
            )

    def test_candidate_identity_must_match_assigned_pitch_classes(self) -> None:
        candidate = c_over_g_minor()
        candidate["identity"]["upper"] = {"rootPc": 6, "quality": "major"}

        with self.assertRaisesRegex(ValueError, "root and quality"):
            subject.normalize_candidate(candidate)

    def _display_candidate(self) -> subject.StableDisplayGate:
        gate = subject.StableDisplayGate()
        candidate = c_over_g_minor()
        first = gate.step(
            timestamp_ms=0,
            raw_selected=candidate,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )
        almost = gate.step(
            timestamp_ms=199,
            raw_selected=candidate,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )
        shown = gate.step(
            timestamp_ms=200,
            raw_selected=candidate,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )
        self.assertEqual(first["transition"], "pending")
        self.assertEqual(almost["transition"], "pending")
        self.assertEqual(shown["transition"], "appearance")
        self.assertEqual(shown["displayed"], candidate)
        return gate

    def test_silence_clears_immediately(self) -> None:
        gate = self._display_candidate()

        result = gate.step(
            timestamp_ms=201,
            raw_selected=None,
            primary_displayable=True,
            sounding_midi_notes=[],
        )

        self.assertEqual(result["transition"], "clear")
        self.assertEqual(result["reason"], "silence")
        self.assertIsNone(result["displayed"])

    def test_primary_absence_clears_immediately(self) -> None:
        gate = self._display_candidate()

        result = gate.step(
            timestamp_ms=201,
            raw_selected=c_over_g_minor(),
            primary_displayable=False,
            sounding_midi_notes=OBSERVED_NOTES,
        )

        self.assertEqual(result["transition"], "clear")
        self.assertEqual(result["reason"], "primary-not-displayable")
        self.assertIsNone(result["displayed"])

    def test_invalidated_assignment_clears_immediately(self) -> None:
        gate = self._display_candidate()

        result = gate.step(
            timestamp_ms=201,
            raw_selected=None,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES[:-1],
        )

        self.assertEqual(result["transition"], "clear")
        self.assertEqual(result["reason"], "invalidated-assignment")
        self.assertIsNone(result["displayed"])

    def test_abstention_clears_immediately_without_a_note_change(self) -> None:
        gate = self._display_candidate()

        result = gate.step(
            timestamp_ms=201,
            raw_selected=None,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )

        self.assertEqual(result["transition"], "clear")
        self.assertEqual(result["reason"], "abstention")
        self.assertIsNone(result["displayed"])

    def test_changed_assignment_waits_even_when_identity_is_unchanged(self) -> None:
        gate = self._display_candidate()
        changed = c_over_g_minor_alternative_assignment()

        pending = gate.step(
            timestamp_ms=201,
            raw_selected=changed,
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )
        shown = gate.step(
            timestamp_ms=401,
            raw_selected=deepcopy(changed),
            primary_displayable=True,
            sounding_midi_notes=OBSERVED_NOTES,
        )

        self.assertEqual(pending["transition"], "pending")
        self.assertEqual(pending["displayed"], c_over_g_minor())
        self.assertEqual(shown["transition"], "change")
        self.assertEqual(shown["displayed"], changed)

    def test_changed_identity_waits_while_old_assignment_remains_valid(self) -> None:
        gate = subject.StableDisplayGate()
        original = g_major_over_a_flat_seven()
        changed = g_major_seven_over_a_flat()
        gate.step(
            timestamp_ms=0,
            raw_selected=original,
            primary_displayable=True,
            sounding_midi_notes=MULTIPLE_IDENTITY_NOTES,
        )
        gate.step(
            timestamp_ms=200,
            raw_selected=original,
            primary_displayable=True,
            sounding_midi_notes=MULTIPLE_IDENTITY_NOTES,
        )

        pending = gate.step(
            timestamp_ms=201,
            raw_selected=changed,
            primary_displayable=True,
            sounding_midi_notes=MULTIPLE_IDENTITY_NOTES,
        )
        shown = gate.step(
            timestamp_ms=401,
            raw_selected=deepcopy(changed),
            primary_displayable=True,
            sounding_midi_notes=MULTIPLE_IDENTITY_NOTES,
        )

        self.assertEqual(pending["transition"], "pending")
        self.assertEqual(pending["displayed"], original)
        self.assertEqual(shown["transition"], "change")
        self.assertEqual(shown["displayed"], changed)

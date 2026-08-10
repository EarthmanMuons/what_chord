"""Unit tests for the rigid-layer polychord motion-support ablation."""

from __future__ import annotations

import json
import unittest
from copy import deepcopy
from pathlib import Path

import motion_support as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"
SOURCE_NOTES = [43, 46, 50, 60, 64, 67]


def support_document(name: str, source: int, target: int) -> dict:
    return subject.support_document(FIXTURE_DIR / name, source, target)


def sounding_history(
    midi_note: int,
    event_index: int,
    timestamp_ms: int,
) -> subject.transition_evidence.release_pedal_evidence.SoundingNoteHistory:
    origin = subject.transition_evidence.release_pedal_evidence.NoteEventOrigin(
        event_index,
        timestamp_ms,
        96,
    )
    return subject.transition_evidence.release_pedal_evidence.SoundingNoteHistory(
        midi_note=midi_note,
        sounding_state="pressed",
        onset=origin,
        release=None,
        current_state_since=origin,
        reattacked_from_sustain=False,
        prior_sustain_release=None,
    )


def transition_for(source_notes: list[int], target_notes: list[int]) -> dict:
    source_candidates = (
        subject.transition_evidence.register_candidates.generate_register_candidates(
            source_notes
        )
    )
    target_candidates = (
        subject.transition_evidence.register_candidates.generate_register_candidates(
            target_notes
        )
    )
    if len(source_candidates) != 1 or len(target_candidates) != 1:
        raise AssertionError("test notes must each produce exactly one candidate")

    source_histories = {
        midi_note: sounding_history(midi_note, index, 0)
        for index, midi_note in enumerate(source_notes)
    }
    target_histories = {
        midi_note: (
            source_histories[midi_note]
            if midi_note in source_histories
            else sounding_history(midi_note, 100 + index, 100)
        )
        for index, midi_note in enumerate(target_notes)
    }
    source_frame = subject.transition_evidence.release_pedal_evidence.ReleasePedalFrame(
        after_event_index=5,
        timestamp_ms=0,
        pedal_down=False,
        pedal_transition=None,
        notes=tuple(source_histories[note] for note in source_notes),
    )
    target_frame = subject.transition_evidence.release_pedal_evidence.ReleasePedalFrame(
        after_event_index=11,
        timestamp_ms=100,
        pedal_down=False,
        pedal_transition=None,
        notes=tuple(target_histories[note] for note in target_notes),
    )
    return subject.transition_evidence.candidate_transition(
        0,
        0,
        source_candidates[0],
        target_candidates[0],
        source_frame,
        target_frame,
    )


def interpretation_by_id(transition: dict, hypothesis_id: str) -> dict:
    interpreted = subject.interpret_transition(transition)
    return next(
        item
        for item in interpreted["hypothesisInterpretations"]
        if item["hypothesisId"] == hypothesis_id
    )


class MotionSupportTest(unittest.TestCase):
    def test_named_policies_are_fixed_and_threshold_free(self) -> None:
        self.assertEqual(
            subject.ABLATION_ID,
            "rigid-layers-oblique-or-contrary/1",
        )
        self.assertEqual(
            subject.interpretation_parameters(),
            {
                "withinLayerTransform": "exact-midi-set-translation",
                "betweenLayerSupportClasses": ["oblique", "contrary"],
                "retainedInstanceContradictionPolicy": "neutral",
                "nonRigidOrCardinalityChangePolicy": "neutral",
            },
        )

    def test_contrary_rigid_layer_control_receives_positive_support(self) -> None:
        document = support_document("two-register-contrary-motion.json", 5, 17)

        self.assertEqual(document["sourceCandidates"][0]["symbol"], "C|Gm")
        self.assertEqual(document["targetCandidates"][0]["symbol"], "D|Fm")
        item = document["candidateInterpretations"][0]
        preserving = next(
            interpretation
            for interpretation in item["hypothesisInterpretations"]
            if interpretation["hypothesisId"] == "register-role-preserving"
        )

        self.assertEqual(preserving["retainedInstanceEvidence"], "none")
        self.assertTrue(preserving["bothLayersExactTranslations"])
        self.assertEqual(
            [
                translation["translationSemitones"]
                for translation in preserving["layerTranslations"]
            ],
            [-2, 2],
        )
        self.assertEqual(preserving["betweenLayerMotionClass"], "contrary")
        self.assertEqual(preserving["motionSupport"], "positive")
        self.assertEqual(
            preserving["reasonCodes"],
            ["rigid-layer-translations-contrary"],
        )

    def test_score_derived_shrovetide_window_matches_oblique_construct(self) -> None:
        document = support_document(
            "stravinsky-shrovetide-oblique-motion.json",
            5,
            17,
        )

        self.assertEqual(
            document["sourceCandidates"][0]["lower"]["midiNotes"],
            [60, 64, 67],
        )
        self.assertEqual(
            document["sourceCandidates"][0]["upper"]["midiNotes"],
            [70, 74, 79],
        )
        self.assertEqual(
            document["targetCandidates"][0]["lower"]["midiNotes"],
            [58, 62, 65],
        )
        self.assertEqual(
            document["targetCandidates"][0]["upper"]["midiNotes"],
            [70, 74, 79],
        )

        interpretations = document["candidateInterpretations"][0][
            "hypothesisInterpretations"
        ]
        preserving = next(
            item
            for item in interpretations
            if item["hypothesisId"] == "register-role-preserving"
        )
        exchanging = next(
            item
            for item in interpretations
            if item["hypothesisId"] == "register-role-exchanging"
        )

        self.assertEqual(preserving["retainedInstanceEvidence"], "none")
        self.assertEqual(
            [
                translation["translationSemitones"]
                for translation in preserving["layerTranslations"]
            ],
            [-2, 0],
        )
        self.assertEqual(preserving["betweenLayerMotionClass"], "oblique")
        self.assertEqual(preserving["motionSupport"], "positive")
        self.assertEqual(exchanging["motionSupport"], "neutral")

    def test_oblique_exact_translations_receive_positive_support(self) -> None:
        transition = transition_for(
            SOURCE_NOTES,
            [43, 46, 50, 62, 66, 69],
        )

        preserving = interpretation_by_id(transition, "register-role-preserving")

        self.assertEqual(preserving["retainedInstanceEvidence"], "consistent")
        self.assertEqual(
            [
                translation["translationSemitones"]
                for translation in preserving["layerTranslations"]
            ],
            [0, 2],
        )
        self.assertEqual(preserving["betweenLayerMotionClass"], "oblique")
        self.assertEqual(preserving["motionSupport"], "positive")

    def test_common_whole_sonority_translation_remains_neutral(self) -> None:
        transition = transition_for(
            SOURCE_NOTES,
            [45, 48, 52, 62, 66, 69],
        )

        preserving = interpretation_by_id(transition, "register-role-preserving")

        self.assertEqual(
            [
                translation["translationSemitones"]
                for translation in preserving["layerTranslations"]
            ],
            [2, 2],
        )
        self.assertEqual(
            preserving["betweenLayerMotionClass"],
            "common-translation",
        )
        self.assertEqual(preserving["motionSupport"], "neutral")
        self.assertEqual(
            preserving["reasonCodes"],
            ["whole-sonority-common-translation"],
        )

    def test_unequal_motion_in_the_same_direction_remains_neutral(self) -> None:
        transition = transition_for(
            SOURCE_NOTES,
            [44, 47, 51, 62, 66, 69],
        )

        preserving = interpretation_by_id(transition, "register-role-preserving")

        self.assertEqual(
            [
                translation["translationSemitones"]
                for translation in preserving["layerTranslations"]
            ],
            [1, 2],
        )
        self.assertEqual(
            preserving["betweenLayerMotionClass"],
            "unequal-similar-direction",
        )
        self.assertEqual(preserving["motionSupport"], "neutral")

    def test_static_layers_remain_neutral(self) -> None:
        transition = transition_for(SOURCE_NOTES, SOURCE_NOTES)

        preserving = interpretation_by_id(transition, "register-role-preserving")

        self.assertEqual(preserving["betweenLayerMotionClass"], "static")
        self.assertEqual(preserving["motionSupport"], "neutral")
        self.assertEqual(
            preserving["reasonCodes"],
            ["both-layer-translations-static"],
        )

    def test_internal_revoicing_or_quality_change_remains_neutral(self) -> None:
        document = support_document("two-register-inner-motion.json", 5, 9)

        interpretations = document["candidateInterpretations"][0][
            "hypothesisInterpretations"
        ]
        preserving = next(
            item
            for item in interpretations
            if item["hypothesisId"] == "register-role-preserving"
        )
        exchanging = next(
            item
            for item in interpretations
            if item["hypothesisId"] == "register-role-exchanging"
        )

        self.assertFalse(preserving["bothLayersExactTranslations"])
        self.assertIsNone(preserving["betweenLayerMotionClass"])
        self.assertEqual(preserving["motionSupport"], "neutral")
        self.assertEqual(
            preserving["reasonCodes"],
            [
                "lower-to-lower-not-exact-midi-set-translation",
                "upper-to-upper-not-exact-midi-set-translation",
            ],
        )
        self.assertTrue(exchanging["bothLayersExactTranslations"])
        self.assertEqual(exchanging["betweenLayerMotionClass"], "contrary")
        self.assertEqual(exchanging["retainedInstanceEvidence"], "contradictory")
        self.assertEqual(exchanging["motionSupport"], "neutral")
        self.assertEqual(
            exchanging["reasonCodes"],
            ["retained-instance-contradicts-correspondence"],
        )

    def test_cardinality_change_is_not_an_exact_translation(self) -> None:
        relation = {
            "id": "lower-to-lower",
            "sourceLayer": "lower",
            "targetLayer": "lower",
            "sourceMidiNotes": [43, 46, 50],
            "targetMidiNotes": [43, 46, 50, 55],
            "sourceRootPc": 7,
            "targetRootPc": 7,
            "sameQuality": True,
        }

        translation = subject.exact_layer_translation(relation)

        self.assertFalse(translation["sameCardinality"])
        self.assertFalse(translation["exactMidiSetTranslation"])
        self.assertIsNone(translation["translationSemitones"])
        self.assertIsNone(translation["chordIdentityFollowsTranslation"])

    def test_retained_instance_contradiction_forces_neutral_support(self) -> None:
        transition = transition_for(
            SOURCE_NOTES,
            [43, 46, 50, 62, 66, 69],
        )

        exchanging = interpretation_by_id(transition, "register-role-exchanging")

        self.assertEqual(exchanging["retainedInstanceEvidence"], "contradictory")
        self.assertEqual(exchanging["motionSupport"], "neutral")
        self.assertIn(
            "retained-instance-contradicts-correspondence",
            exchanging["reasonCodes"],
        )

    def test_corrupt_chord_identity_cannot_receive_support(self) -> None:
        transition = transition_for(
            SOURCE_NOTES,
            [41, 44, 48, 62, 66, 69],
        )
        changed = deepcopy(transition)
        changed["layerRelations"][0]["targetRootPc"] = 6

        preserving = interpretation_by_id(changed, "register-role-preserving")

        self.assertTrue(preserving["layerTranslations"][0]["exactMidiSetTranslation"])
        self.assertFalse(
            preserving["layerTranslations"][0]["chordIdentityFollowsTranslation"]
        )
        self.assertEqual(preserving["motionSupport"], "neutral")
        self.assertIn(
            "lower-to-lower-chord-identity-does-not-follow-translation",
            preserving["reasonCodes"],
        )

    def test_empty_candidate_product_has_no_interpretations(self) -> None:
        document = support_document("two-register-inner-motion.json", 5, 7)

        self.assertEqual(document["targetCandidates"], [])
        self.assertEqual(document["candidateInterpretations"], [])

    def test_output_document_has_the_exact_contract_fields(self) -> None:
        document = support_document("two-register-contrary-motion.json", 5, 17)

        self.assertEqual(
            set(document),
            {
                "schema",
                "ablationId",
                "parameters",
                "sourceEvidenceSchema",
                "fixtureId",
                "fixtureSha256",
                "window",
                "sourceCandidates",
                "targetCandidates",
                "candidateInterpretations",
            },
        )
        self.assertEqual(document["schema"], subject.OUTPUT_SCHEMA)
        self.assertEqual(
            document["sourceEvidenceSchema"],
            subject.transition_evidence.OUTPUT_SCHEMA,
        )
        serialized = json.dumps(document).lower()
        self.assertNotIn("confidence", serialized)
        self.assertNotIn("eligible", serialized)
        self.assertNotIn("display", serialized)
        self.assertNotIn("selectedhypothesis", serialized)


if __name__ == "__main__":
    unittest.main()

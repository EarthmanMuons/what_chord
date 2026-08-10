"""Unit tests for threshold-free polychord frame-transition evidence."""

from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import patch

import transition_evidence as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


def evidence_document(name: str, source: int, target: int) -> dict:
    return subject.evidence_document(FIXTURE_DIR / name, source, target)


def relation_by_id(transition: dict, relation_id: str) -> dict:
    return next(
        relation
        for relation in transition["layerRelations"]
        if relation["id"] == relation_id
    )


def hypothesis_by_id(transition: dict, hypothesis_id: str) -> dict:
    return next(
        hypothesis
        for hypothesis in transition["layerCorrespondenceHypotheses"]
        if hypothesis["id"] == hypothesis_id
    )


class TransitionEvidenceTest(unittest.TestCase):
    def test_changed_inner_pitches_preserve_exact_instance_continuity(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 9)

        self.assertEqual(document["sourceCandidates"][0]["symbol"], "C|Gm")
        self.assertEqual(document["targetCandidates"][0]["symbol"], "Cm|G")
        transition = document["candidateTransitions"][0]
        continuity = transition["instanceContinuity"]

        self.assertEqual(
            [note["midiNote"] for note in continuity["retainedInstances"]],
            [43, 50, 60, 67],
        )
        self.assertEqual(
            [note["midiNote"] for note in continuity["departedInstances"]],
            [46, 64],
        )
        self.assertEqual(
            [note["midiNote"] for note in continuity["arrivedInstances"]],
            [47, 63],
        )
        self.assertEqual(
            [
                (note["sourceLayer"], note["targetLayer"])
                for note in continuity["retainedInstances"]
            ],
            [
                ("lower", "lower"),
                ("lower", "lower"),
                ("upper", "upper"),
                ("upper", "upper"),
            ],
        )

    def test_window_retains_every_ordered_transition_step(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 9)

        window = document["window"]
        self.assertEqual(window["elapsedMs"], 200)
        self.assertEqual(window["transitionEventCount"], 4)
        self.assertEqual(window["interveningFrameCount"], 3)
        self.assertEqual(
            [step["event"]["index"] for step in window["transitionSteps"]],
            [6, 7, 8, 9],
        )
        self.assertEqual(
            [step["frame"]["afterEventIndex"] for step in window["transitionSteps"]],
            [6, 7, 8, 9],
        )
        self.assertEqual(
            [step["event"]["timestampMs"] for step in window["transitionSteps"]],
            [100, 100, 200, 200],
        )

    def test_all_pair_pitch_deltas_do_not_choose_changed_pitch_links(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 9)

        transition = document["candidateTransitions"][0]
        lower = relation_by_id(transition, "lower-to-lower")
        upper = relation_by_id(transition, "upper-to-upper")

        self.assertEqual(
            lower["allPairTargetMinusSourceSemitones"],
            [[0, 4, 7], [-3, 1, 4], [-7, -3, 0]],
        )
        self.assertEqual(
            upper["allPairTargetMinusSourceSemitones"],
            [[0, 3, 7], [-4, -1, 3], [-7, -4, 0]],
        )
        serialized = json.dumps(document).lower()
        self.assertNotIn("voiceassignment", serialized)
        self.assertNotIn("selectedpair", serialized)
        self.assertNotIn("confidence", serialized)
        self.assertNotIn("support", serialized)
        self.assertNotIn("eligible", serialized)

    def test_both_two_layer_correspondence_hypotheses_remain_unranked(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 9)

        transition = document["candidateTransitions"][0]
        preserving = hypothesis_by_id(transition, "register-role-preserving")
        exchanging = hypothesis_by_id(transition, "register-role-exchanging")

        self.assertEqual(preserving["retainedInstanceCountFollowingRelations"], 4)
        self.assertEqual(preserving["retainedInstanceCountOutsideRelations"], 0)
        self.assertEqual(exchanging["retainedInstanceCountFollowingRelations"], 0)
        self.assertEqual(exchanging["retainedInstanceCountOutsideRelations"], 4)
        self.assertEqual(
            set(preserving),
            set(exchanging),
        )

    def test_pressed_to_sustained_change_retains_the_same_instances(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 5, 12)

        transition = document["candidateTransitions"][0]
        retained = transition["instanceContinuity"]["retainedInstances"]

        self.assertEqual(len(retained), 6)
        self.assertTrue(
            all(note["sourceSoundingState"] == "pressed" for note in retained)
        )
        self.assertTrue(
            all(note["targetSoundingState"] == "sustained" for note in retained)
        )

    def test_reattack_is_departure_and_arrival_not_retention(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 12, 14)

        continuity = document["candidateTransitions"][0]["instanceContinuity"]
        retained = continuity["retainedInstances"]
        departed = continuity["departedInstances"]
        arrived = continuity["arrivedInstances"]

        self.assertEqual(len(retained), 5)
        self.assertEqual(
            [(note["midiNote"], note["onsetEventIndex"]) for note in departed],
            [(43, 0)],
        )
        self.assertEqual(
            [(note["midiNote"], note["onsetEventIndex"]) for note in arrived],
            [(43, 13)],
        )

    def test_zero_elapsed_time_is_valid_when_event_order_advances(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 0, 1)

        self.assertEqual(document["window"]["elapsedMs"], 0)
        self.assertEqual(document["window"]["transitionEventCount"], 1)
        self.assertEqual(document["candidateTransitions"], [])

    def test_empty_endpoint_candidate_set_produces_no_transitions(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 7)

        self.assertEqual(len(document["sourceCandidates"]), 1)
        self.assertEqual(document["targetCandidates"], [])
        self.assertEqual(document["candidateTransitions"], [])

    def test_every_source_target_candidate_pair_is_reported(self) -> None:
        candidate = subject.register_candidates.generate_register_candidates(
            [43, 46, 50, 60, 64, 67]
        )[0]
        with patch.object(
            subject.register_candidates,
            "generate_register_candidates",
            side_effect=[(candidate, candidate), (candidate, candidate, candidate)],
        ):
            document = evidence_document("two-register-pedal-history.json", 5, 12)

        self.assertEqual(
            [
                (
                    transition["sourceCandidateIndex"],
                    transition["targetCandidateIndex"],
                )
                for transition in document["candidateTransitions"]
            ],
            [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
        )

    def test_output_document_has_the_exact_top_level_fields(self) -> None:
        document = evidence_document("two-register-inner-motion.json", 5, 9)

        self.assertEqual(
            set(document),
            {
                "schema",
                "fixtureId",
                "fixtureSha256",
                "window",
                "sourceCandidates",
                "targetCandidates",
                "candidateTransitions",
            },
        )
        self.assertEqual(document["schema"], subject.OUTPUT_SCHEMA)
        self.assertEqual(
            set(document["candidateTransitions"][0]),
            {
                "sourceCandidateIndex",
                "targetCandidateIndex",
                "sameSymbol",
                "sameExactCandidate",
                "instanceContinuity",
                "layerRelations",
                "layerCorrespondenceHypotheses",
            },
        )

    def test_unknown_and_reversed_endpoints_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "identify exactly one"):
            evidence_document("two-register-inner-motion.json", 5, 99)
        with self.assertRaisesRegex(ValueError, "must precede"):
            evidence_document("two-register-inner-motion.json", 9, 5)
        with self.assertRaisesRegex(TypeError, "must be integers"):
            subject.evidence_document(
                FIXTURE_DIR / "two-register-inner-motion.json",
                True,
                9,
            )


if __name__ == "__main__":
    unittest.main()

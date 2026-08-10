"""Unit tests for threshold-free polychord onset evidence."""

from __future__ import annotations

import json
import unittest
from copy import deepcopy
from pathlib import Path

import onset_evidence as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURE_DIR / name).read_text())


def evidence_document(name: str, after_event_index: int) -> dict:
    return subject.evidence_document(FIXTURE_DIR / name, after_event_index)


class OnsetEvidenceTest(unittest.TestCase):
    def test_matched_histories_keep_the_same_register_candidate(self) -> None:
        synchronous = evidence_document("synchronous-six-note-cohort.json", 5)
        layered = evidence_document("two-register-held-cohorts.json", 5)

        self.assertEqual(
            synchronous["candidateEvidence"][0]["candidate"],
            layered["candidateEvidence"][0]["candidate"],
        )
        self.assertEqual(
            synchronous["candidateEvidence"][0]["candidate"]["symbol"],
            "C|Gm",
        )

    def test_synchronous_history_reports_zero_spans_and_relations(self) -> None:
        document = evidence_document("synchronous-six-note-cohort.json", 5)

        evidence = document["candidateEvidence"][0]["onsetEvidence"]
        self.assertTrue(evidence["allCandidateOnsetsKnown"])
        self.assertEqual(evidence["lower"]["knownOnsetSpanMs"], 0)
        self.assertEqual(evidence["upper"]["knownOnsetSpanMs"], 0)
        self.assertEqual(evidence["upperEarliestMinusLowerLatestMs"], 0)
        self.assertEqual(evidence["upperLatestMinusLowerEarliestMs"], 0)

    def test_layered_history_reports_raw_four_hundred_millisecond_offset(
        self,
    ) -> None:
        document = evidence_document("two-register-held-cohorts.json", 5)

        evidence = document["candidateEvidence"][0]["onsetEvidence"]
        self.assertEqual(evidence["lower"]["distinctKnownOnsetTimestampsMs"], [0])
        self.assertEqual(evidence["upper"]["distinctKnownOnsetTimestampsMs"], [400])
        self.assertEqual(evidence["upperEarliestMinusLowerLatestMs"], 400)
        self.assertEqual(evidence["upperLatestMinusLowerEarliestMs"], 400)

    def test_same_timestamp_attacks_retain_distinct_event_indices(self) -> None:
        fixture = load_fixture("synchronous-six-note-cohort.json")

        onset_frame = subject.replay_onset_frames(fixture)[5]

        self.assertEqual(
            [note.origin.event_index for note in onset_frame.notes],
            [0, 1, 2, 3, 4, 5],
        )
        self.assertEqual(
            {note.origin.timestamp_ms for note in onset_frame.notes},
            {0},
        )

    def test_carried_in_notes_have_unknown_onsets(self) -> None:
        fixture = load_fixture("carried-in-state.json")

        onset_frame = subject.replay_onset_frames(fixture)[0]
        summary = subject.summarize_layer((36, 48, 60), onset_frame)

        self.assertEqual(summary["knownOnsetCount"], 1)
        self.assertEqual(summary["unknownOnsetCount"], 2)
        self.assertFalse(summary["allOnsetsKnown"])
        self.assertEqual(summary["distinctKnownOnsetTimestampsMs"], [100])
        self.assertIsNone(summary["notes"][0]["onsetTimestampMs"])
        self.assertIsNone(summary["notes"][1]["onsetTimestampMs"])
        self.assertIsNone(summary["notes"][0]["onsetVelocity"])
        self.assertIsNone(summary["notes"][1]["onsetVelocity"])
        self.assertEqual(summary["notes"][2]["onsetTimestampMs"], 100)

    def test_candidate_relations_remain_null_with_unknown_onsets(self) -> None:
        candidate = subject.register_candidates.generate_register_candidates(
            [43, 46, 50, 60, 64, 67]
        )[0]
        onset_frame = subject.OnsetFrame(
            after_event_index=5,
            timestamp_ms=400,
            notes=(
                subject.SoundingNoteOnset(43, "pressed", None),
                subject.SoundingNoteOnset(46, "pressed", None),
                subject.SoundingNoteOnset(50, "pressed", None),
                subject.SoundingNoteOnset(
                    60, "pressed", subject.OnsetOrigin(3, 400, 80)
                ),
                subject.SoundingNoteOnset(
                    64, "pressed", subject.OnsetOrigin(4, 400, 80)
                ),
                subject.SoundingNoteOnset(
                    67, "pressed", subject.OnsetOrigin(5, 400, 80)
                ),
            ),
        )

        evidence = subject.candidate_onset_evidence(candidate, onset_frame)[
            "onsetEvidence"
        ]

        self.assertFalse(evidence["allCandidateOnsetsKnown"])
        self.assertEqual(evidence["lower"]["unknownOnsetCount"], 3)
        self.assertEqual(evidence["upper"]["knownOnsetCount"], 3)
        self.assertIsNone(evidence["upperEarliestMinusLowerLatestMs"])
        self.assertIsNone(evidence["upperLatestMinusLowerEarliestMs"])

    def test_pedal_sustain_preserves_the_original_onsets(self) -> None:
        fixture = load_fixture("pedal-release-and-repress.json")

        onset_frame = subject.replay_onset_frames(fixture)[6]

        self.assertEqual(
            [note.sounding_state for note in onset_frame.notes],
            ["sustained", "sustained", "sustained"],
        )
        self.assertEqual(
            [note.origin.timestamp_ms for note in onset_frame.notes],
            [0, 0, 0],
        )

    def test_reattack_replaces_only_that_sounding_note_instance(self) -> None:
        fixture = load_fixture("pedal-release-and-repress.json")

        onset_frame = subject.replay_onset_frames(fixture)[7]
        notes = onset_frame.note_map()

        self.assertEqual(notes[48].sounding_state, "pressed")
        self.assertEqual(notes[48].origin.event_index, 7)
        self.assertEqual(notes[48].origin.timestamp_ms, 500)
        self.assertEqual(notes[48].origin.velocity, 72)
        self.assertEqual(notes[52].origin.timestamp_ms, 0)
        self.assertEqual(notes[55].origin.timestamp_ms, 0)

    def test_pedal_release_removes_stopped_onset_records(self) -> None:
        fixture = load_fixture("pedal-release-and-repress.json")

        onset_frame = subject.replay_onset_frames(fixture)[9]

        self.assertEqual(onset_frame.notes, ())

    def test_frame_without_register_candidate_has_empty_evidence(self) -> None:
        document = evidence_document("carried-in-state.json", 0)

        self.assertEqual(document["candidateEvidence"], [])

    def test_output_document_has_the_exact_top_level_fields(self) -> None:
        document = evidence_document("two-register-held-cohorts.json", 5)

        self.assertEqual(
            set(document),
            {
                "schema",
                "fixtureId",
                "fixtureSha256",
                "observationFrame",
                "candidateEvidence",
            },
        )
        self.assertEqual(document["schema"], "polychord-onset-evidence/1")
        candidate_evidence = document["candidateEvidence"][0]
        self.assertEqual(set(candidate_evidence), {"candidate", "onsetEvidence"})
        self.assertEqual(
            set(candidate_evidence["onsetEvidence"]),
            {
                "allCandidateOnsetsKnown",
                "lower",
                "upper",
                "upperEarliestMinusLowerLatestMs",
                "upperLatestMinusLowerEarliestMs",
            },
        )
        self.assertEqual(
            set(candidate_evidence["onsetEvidence"]["lower"]["notes"][0]),
            {
                "midiNote",
                "soundingState",
                "onsetEventIndex",
                "onsetTimestampMs",
                "onsetVelocity",
            },
        )

    def test_unknown_frame_and_invalid_replay_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "identify exactly one"):
            evidence_document("two-register-held-cohorts.json", 99)

        fixture = load_fixture("two-register-held-cohorts.json")
        changed = deepcopy(fixture)
        changed["frames"][5]["soundingMidiNotes"] = [43, 46, 50, 60, 64]
        with self.assertRaisesRegex(ValueError, "does not match replayed state"):
            subject.replay_onset_frames(changed)


if __name__ == "__main__":
    unittest.main()

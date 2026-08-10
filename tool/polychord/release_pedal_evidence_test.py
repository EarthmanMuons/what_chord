"""Unit tests for threshold-free polychord release and pedal evidence."""

from __future__ import annotations

import json
import unittest
from copy import deepcopy
from pathlib import Path

import onset_evidence
import release_pedal_evidence as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"
MANIFEST = FIXTURE_DIR / "manifest.json"


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURE_DIR / name).read_text())


def evidence_document(name: str, after_event_index: int) -> dict:
    return subject.evidence_document(FIXTURE_DIR / name, after_event_index)


class ReleasePedalEvidenceTest(unittest.TestCase):
    def test_current_onsets_match_the_existing_onset_contract(self) -> None:
        manifest = json.loads(MANIFEST.read_text())
        for entry in manifest["fixtures"]:
            with self.subTest(fixture=entry["id"]):
                fixture = load_fixture(entry["file"])
                release_frames = subject.replay_release_pedal_frames(fixture)
                onset_frames = onset_evidence.replay_onset_frames(fixture)

                self.assertEqual(len(release_frames), len(onset_frames))
                for release_frame, onset_frame in zip(release_frames, onset_frames):
                    release_notes = release_frame.note_map()
                    onset_notes = onset_frame.note_map()
                    self.assertEqual(set(release_notes), set(onset_notes))
                    for midi_note, release_note in release_notes.items():
                        onset_note = onset_notes[midi_note]
                        self.assertEqual(
                            release_note.sounding_state,
                            onset_note.sounding_state,
                        )
                        if onset_note.origin is None:
                            self.assertIsNone(release_note.onset)
                        else:
                            self.assertEqual(
                                (
                                    release_note.onset.event_index,
                                    release_note.onset.timestamp_ms,
                                    release_note.onset.velocity,
                                ),
                                (
                                    onset_note.origin.event_index,
                                    onset_note.origin.timestamp_ms,
                                    onset_note.origin.velocity,
                                ),
                            )

    def test_grouped_layer_releases_remain_raw_timestamp_facts(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 12)

        item = document["candidateEvidence"][0]
        evidence = item["releasePedalEvidence"]

        self.assertEqual(item["candidate"]["symbol"], "C|Gm")
        self.assertEqual(
            evidence["pedal"],
            {
                "down": True,
                "lastTransitionEventIndex": 6,
                "lastTransitionTimestampMs": 200,
                "lastTransitionDown": True,
                "currentStateAgeMs": 200,
            },
        )
        self.assertEqual(evidence["lower"]["distinctKnownReleaseTimestampsMs"], [300])
        self.assertEqual(evidence["upper"]["distinctKnownReleaseTimestampsMs"], [400])
        self.assertEqual(evidence["lower"]["knownReleaseSpanMs"], 0)
        self.assertEqual(evidence["upper"]["knownReleaseSpanMs"], 0)
        self.assertEqual(evidence["pressedCandidateNoteCount"], 0)
        self.assertEqual(evidence["sustainedCandidateNoteCount"], 6)
        self.assertTrue(evidence["allSustainedReleasesKnown"])
        self.assertEqual(evidence["onsetBeforeCurrentPedalDownCount"], 6)
        self.assertEqual(evidence["onsetAtOrAfterCurrentPedalDownCount"], 0)
        self.assertEqual(evidence["unknownPedalRelationCount"], 0)
        self.assertEqual(
            [note["releaseVelocity"] for note in evidence["lower"]["notes"]],
            [1, 2, 3],
        )
        self.assertEqual(
            [note["releaseVelocity"] for note in evidence["upper"]["notes"]],
            [4, 5, 6],
        )

    def test_reattack_preserves_the_prior_sustain_release(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 13)

        evidence = document["candidateEvidence"][0]["releasePedalEvidence"]
        note = evidence["lower"]["notes"][0]

        self.assertEqual(note["midiNote"], 43)
        self.assertEqual(note["soundingState"], "pressed")
        self.assertEqual(note["onsetEventIndex"], 13)
        self.assertEqual(note["onsetTimestampMs"], 500)
        self.assertEqual(note["onsetVelocity"], 72)
        self.assertEqual(note["onsetAgeMs"], 0)
        self.assertIsNone(note["releaseEventIndex"])
        self.assertTrue(note["reattackedFromSustain"])
        self.assertEqual(note["priorSustainReleaseEventIndex"], 7)
        self.assertEqual(note["priorSustainReleaseTimestampMs"], 300)
        self.assertEqual(note["priorSustainReleaseVelocity"], 1)
        self.assertEqual(note["priorSustainReleaseAgeMs"], 200)
        self.assertFalse(note["onsetBeforeCurrentPedalDown"])
        self.assertEqual(evidence["reattackedFromSustainCount"], 1)
        self.assertEqual(evidence["onsetBeforeCurrentPedalDownCount"], 5)
        self.assertEqual(evidence["onsetAtOrAfterCurrentPedalDownCount"], 1)

    def test_release_after_reattack_preserves_both_release_origins(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 14)

        note = document["candidateEvidence"][0]["releasePedalEvidence"]["lower"][
            "notes"
        ][0]

        self.assertEqual(note["soundingState"], "sustained")
        self.assertEqual(note["releaseEventIndex"], 14)
        self.assertEqual(note["releaseTimestampMs"], 600)
        self.assertEqual(note["releaseVelocity"], 7)
        self.assertEqual(note["currentStateSinceEventIndex"], 14)
        self.assertEqual(note["currentStateAgeMs"], 0)
        self.assertEqual(note["priorSustainReleaseEventIndex"], 7)
        self.assertEqual(note["priorSustainReleaseAgeMs"], 300)

    def test_carried_in_origins_remain_unknown(self) -> None:
        fixture = load_fixture("carried-in-state.json")

        evidence_frame = subject.replay_release_pedal_frames(fixture)[0]
        summary = subject.summarize_layer((36, 48, 60), evidence_frame)
        notes = {note["midiNote"]: note for note in summary["notes"]}

        self.assertEqual(
            evidence_frame.pedal_as_dict(),
            {
                "down": True,
                "lastTransitionEventIndex": None,
                "lastTransitionTimestampMs": None,
                "lastTransitionDown": None,
                "currentStateAgeMs": None,
            },
        )
        self.assertEqual(summary["knownOnsetCount"], 1)
        self.assertEqual(summary["unknownOnsetCount"], 2)
        self.assertEqual(summary["knownReleaseCount"], 0)
        self.assertEqual(summary["unknownReleaseCount"], 1)
        self.assertFalse(summary["allSustainedReleasesKnown"])
        self.assertEqual(summary["knownCurrentStateOriginCount"], 1)
        self.assertEqual(summary["unknownCurrentStateOriginCount"], 2)
        self.assertEqual(summary["notReattackedFromSustainCount"], 1)
        self.assertEqual(summary["unknownReattackCount"], 2)
        self.assertEqual(summary["unknownPedalRelationCount"], 3)
        self.assertIsNone(notes[36]["onsetTimestampMs"])
        self.assertIsNone(notes[36]["releaseTimestampMs"])
        self.assertIsNone(notes[36]["currentStateSinceTimestampMs"])
        self.assertIsNone(notes[48]["reattackedFromSustain"])
        self.assertFalse(notes[60]["reattackedFromSustain"])

    def test_later_observed_release_does_not_fill_an_unknown_onset(self) -> None:
        fixture = load_fixture("carried-in-state.json")

        evidence_frame = subject.replay_release_pedal_frames(fixture)[1]
        summary = subject.summarize_layer((36, 48, 60), evidence_frame)
        notes = {note["midiNote"]: note for note in summary["notes"]}

        self.assertEqual(summary["knownReleaseCount"], 1)
        self.assertEqual(summary["unknownReleaseCount"], 1)
        self.assertEqual(notes[48]["releaseEventIndex"], 1)
        self.assertEqual(notes[48]["releaseTimestampMs"], 300)
        self.assertIsNone(notes[48]["onsetEventIndex"])
        self.assertEqual(notes[48]["currentStateSinceEventIndex"], 1)

    def test_same_timestamp_pedal_relation_uses_event_order(self) -> None:
        pedal = subject.PedalTransition(event_index=1, timestamp_ms=100, down=True)
        before = subject.SoundingNoteHistory(
            midi_note=60,
            sounding_state="pressed",
            onset=subject.NoteEventOrigin(0, 100, 80),
            release=None,
            current_state_since=subject.NoteEventOrigin(0, 100, 80),
            reattacked_from_sustain=False,
            prior_sustain_release=None,
        )
        after = subject.SoundingNoteHistory(
            midi_note=64,
            sounding_state="pressed",
            onset=subject.NoteEventOrigin(2, 100, 80),
            release=None,
            current_state_since=subject.NoteEventOrigin(2, 100, 80),
            reattacked_from_sustain=False,
            prior_sustain_release=None,
        )

        self.assertTrue(before.as_dict(100, True, pedal)["onsetBeforeCurrentPedalDown"])
        self.assertFalse(after.as_dict(100, True, pedal)["onsetBeforeCurrentPedalDown"])

    def test_pedal_release_removes_stopped_history_and_candidates(self) -> None:
        fixture = load_fixture("two-register-pedal-history.json")

        evidence_frame = subject.replay_release_pedal_frames(fixture)[15]
        document = evidence_document("two-register-pedal-history.json", 15)

        self.assertEqual(evidence_frame.notes, ())
        self.assertEqual(
            evidence_frame.pedal_as_dict(),
            {
                "down": False,
                "lastTransitionEventIndex": 15,
                "lastTransitionTimestampMs": 700,
                "lastTransitionDown": False,
                "currentStateAgeMs": 0,
            },
        )
        self.assertEqual(document["candidateEvidence"], [])

    def test_pedal_release_retains_pressed_note_history(self) -> None:
        fixture = load_fixture("carried-in-state.json")

        evidence_frame = subject.replay_release_pedal_frames(fixture)[2]
        note = evidence_frame.note_map()[60]
        record = note.as_dict(
            evidence_frame.timestamp_ms,
            evidence_frame.pedal_down,
            evidence_frame.pedal_transition,
        )

        self.assertEqual([item.midi_note for item in evidence_frame.notes], [60])
        self.assertFalse(evidence_frame.pedal_down)
        self.assertEqual(evidence_frame.pedal_transition.event_index, 2)
        self.assertEqual(note.sounding_state, "pressed")
        self.assertEqual(record["onsetEventIndex"], 0)
        self.assertEqual(record["currentStateSinceEventIndex"], 0)
        self.assertEqual(record["currentStateAgeMs"], 400)
        self.assertIsNone(record["onsetBeforeCurrentPedalDown"])

    def test_output_fields_contain_no_interpretation(self) -> None:
        document = evidence_document("two-register-pedal-history.json", 12)

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
        self.assertEqual(document["schema"], subject.OUTPUT_SCHEMA)
        item = document["candidateEvidence"][0]
        self.assertEqual(set(item), {"candidate", "releasePedalEvidence"})
        evidence = item["releasePedalEvidence"]
        self.assertEqual(
            set(evidence),
            {
                "pedal",
                "lower",
                "upper",
                "pressedCandidateNoteCount",
                "sustainedCandidateNoteCount",
                "allSustainedReleasesKnown",
                "reattackedFromSustainCount",
                "onsetBeforeCurrentPedalDownCount",
                "onsetAtOrAfterCurrentPedalDownCount",
                "unknownPedalRelationCount",
            },
        )
        self.assertEqual(
            set(evidence["pedal"]),
            {
                "down",
                "lastTransitionEventIndex",
                "lastTransitionTimestampMs",
                "lastTransitionDown",
                "currentStateAgeMs",
            },
        )
        self.assertEqual(
            set(evidence["lower"]),
            {
                "notes",
                "pressedNoteCount",
                "sustainedNoteCount",
                "knownOnsetCount",
                "unknownOnsetCount",
                "knownOnsetAgeRangeMs",
                "knownReleaseCount",
                "unknownReleaseCount",
                "allSustainedReleasesKnown",
                "distinctKnownReleaseTimestampsMs",
                "earliestKnownReleaseMs",
                "latestKnownReleaseMs",
                "knownReleaseSpanMs",
                "knownCurrentStateOriginCount",
                "unknownCurrentStateOriginCount",
                "knownCurrentStateAgeRangeMs",
                "reattackedFromSustainCount",
                "notReattackedFromSustainCount",
                "unknownReattackCount",
                "onsetBeforeCurrentPedalDownCount",
                "onsetAtOrAfterCurrentPedalDownCount",
                "unknownPedalRelationCount",
            },
        )
        self.assertEqual(
            set(evidence["lower"]["notes"][0]),
            {
                "midiNote",
                "soundingState",
                "onsetEventIndex",
                "onsetTimestampMs",
                "onsetVelocity",
                "onsetAgeMs",
                "releaseEventIndex",
                "releaseTimestampMs",
                "releaseVelocity",
                "releaseAgeMs",
                "currentStateSinceEventIndex",
                "currentStateSinceTimestampMs",
                "currentStateAgeMs",
                "reattackedFromSustain",
                "priorSustainReleaseEventIndex",
                "priorSustainReleaseTimestampMs",
                "priorSustainReleaseVelocity",
                "priorSustainReleaseAgeMs",
                "onsetBeforeCurrentPedalDown",
            },
        )
        serialized = json.dumps(document).lower()
        for forbidden in (
            "support",
            "confidence",
            "eligible",
            "penalty",
            "display",
        ):
            self.assertNotIn(forbidden, serialized)

    def test_unknown_frame_and_invalid_replay_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "identify exactly one"):
            evidence_document("two-register-pedal-history.json", 99)

        fixture = load_fixture("two-register-pedal-history.json")
        changed = deepcopy(fixture)
        changed["frames"][12]["sustainedMidiNotes"] = [43, 46, 50, 60, 64]
        with self.assertRaisesRegex(ValueError, "does not match replayed state"):
            subject.replay_release_pedal_frames(changed)


if __name__ == "__main__":
    unittest.main()

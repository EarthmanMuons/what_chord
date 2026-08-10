"""Unit tests for the preregistered release and pedal audit."""

from __future__ import annotations

import unittest

import frame_replay
import release_pedal_audit as subject


def fixture(
    events: list[dict], end_timestamp_ms: int, initial_state: dict | None = None
):
    payload = {
        "schema": frame_replay.FIXTURE_SCHEMA,
        "id": "synthetic/release-pedal-audit",
        "description": "Synthetic release and pedal history.",
        "timeBase": "milliseconds",
        "initialState": initial_state
        or {
            "pressedMidiNotes": [],
            "sustainedMidiNotes": [],
            "pedalDown": False,
        },
        "events": events,
        "frames": [],
        "endTimestampMs": end_timestamp_ms,
    }
    payload["frames"] = frame_replay.replay_fixture(payload)
    return payload


def candidate(
    lower_notes: list[int] | None = None,
    upper_notes: list[int] | None = None,
) -> dict:
    lower = lower_notes or [48, 52, 55]
    upper = upper_notes or [66, 69, 73]
    return {
        "splitAfterIndex": len(lower) - 1,
        "lowerTopMidi": lower[-1],
        "upperBottomMidi": upper[0],
        "gapSemitones": upper[0] - lower[-1],
        "lower": {
            "rootPc": 0,
            "quality": "major",
            "midiNotes": lower,
            "pitchClasses": sorted({note % 12 for note in lower}),
        },
        "upper": {
            "rootPc": 6,
            "quality": "minor",
            "midiNotes": upper,
            "pitchClasses": sorted({note % 12 for note in upper}),
        },
        "sharedPitchClasses": [],
        "symbol": "F#m|C",
    }


class ReleasePedalAuditTest(unittest.TestCase):
    def test_replay_retains_release_origin_and_reattack(self) -> None:
        payload = fixture(
            [
                {"index": 0, "timestampMs": 0, "type": "pedal", "down": True},
                {
                    "index": 1,
                    "timestampMs": 10,
                    "type": "noteOn",
                    "midiNote": 60,
                    "velocity": 90,
                },
                {
                    "index": 2,
                    "timestampMs": 20,
                    "type": "noteOff",
                    "midiNote": 60,
                    "velocity": 7,
                },
                {
                    "index": 3,
                    "timestampMs": 30,
                    "type": "noteOn",
                    "midiNote": 60,
                    "velocity": 80,
                },
                {
                    "index": 4,
                    "timestampMs": 40,
                    "type": "noteOn",
                    "midiNote": 64,
                    "velocity": 70,
                },
                {
                    "index": 5,
                    "timestampMs": 50,
                    "type": "noteOff",
                    "midiNote": 64,
                    "velocity": 5,
                },
                {"index": 6, "timestampMs": 60, "type": "pedal", "down": False},
            ],
            70,
        )

        frames = subject.replay_temporal_history_frames(payload)
        sustained = frames[2].note_map()[60]
        reattacked = frames[3].note_map()[60]
        final = frames[6].note_map()[60]

        self.assertEqual(sustained.sounding_state, "sustained")
        self.assertEqual(sustained.release.event_index, 2)
        self.assertEqual(sustained.release.velocity, 7)
        self.assertEqual(sustained.current_state_since.event_index, 2)
        self.assertEqual(frames[2].pedal_transition.event_index, 0)
        self.assertEqual(reattacked.sounding_state, "pressed")
        self.assertTrue(reattacked.reattacked_from_sustain)
        self.assertIsNone(reattacked.release)
        self.assertEqual(reattacked.prior_sustain_release.event_index, 2)
        self.assertEqual(reattacked.prior_sustain_release.velocity, 7)
        self.assertEqual(final.current_state_since.event_index, 3)
        self.assertEqual([note.midi_note for note in frames[6].notes], [60])
        self.assertFalse(frames[6].pedal_down)
        self.assertEqual(frames[6].pedal_transition.event_index, 6)

    def test_carried_in_history_remains_unknown(self) -> None:
        payload = fixture(
            [
                {
                    "index": 0,
                    "timestampMs": 10,
                    "type": "noteOn",
                    "midiNote": 67,
                    "velocity": 90,
                }
            ],
            20,
            {
                "pressedMidiNotes": [60],
                "sustainedMidiNotes": [64],
                "pedalDown": True,
            },
        )

        frame = subject.replay_temporal_history_frames(payload)[0]
        notes = frame.note_map()

        self.assertIsNone(frame.pedal_transition)
        self.assertIsNone(notes[60].onset)
        self.assertIsNone(notes[64].release)
        self.assertIsNone(notes[64].current_state_since)
        self.assertIsNone(notes[60].reattacked_from_sustain)
        self.assertIsNone(notes[60].prior_sustain_release)
        self.assertFalse(notes[67].reattacked_from_sustain)

    def test_candidate_evidence_reports_raw_state_without_a_gate(self) -> None:
        payload = fixture(
            [
                {"index": 0, "timestampMs": 0, "type": "pedal", "down": True},
                {
                    "index": 1,
                    "timestampMs": 10,
                    "type": "noteOn",
                    "midiNote": 60,
                    "velocity": 90,
                },
                {
                    "index": 2,
                    "timestampMs": 20,
                    "type": "noteOn",
                    "midiNote": 64,
                    "velocity": 80,
                },
                {
                    "index": 3,
                    "timestampMs": 30,
                    "type": "noteOff",
                    "midiNote": 64,
                    "velocity": 4,
                },
            ],
            40,
        )
        history_frame = subject.replay_temporal_history_frames(payload)[3]
        evidence = subject.candidate_release_pedal_evidence(
            {"lower": {"midiNotes": [60]}, "upper": {"midiNotes": [64]}},
            history_frame,
        )

        self.assertTrue(evidence["pedal"]["down"])
        self.assertEqual(evidence["pedal"]["currentStateAgeMs"], 30)
        self.assertEqual(evidence["pressedCandidateNoteCount"], 1)
        self.assertEqual(evidence["sustainedCandidateNoteCount"], 1)
        self.assertTrue(evidence["allSustainedReleasesKnown"])
        self.assertEqual(evidence["upper"]["knownReleaseSpanMs"], 0)
        self.assertEqual(evidence["upper"]["notes"][0]["releaseVelocity"], 4)
        self.assertNotIn("support", evidence)
        self.assertNotIn("eligible", evidence)

    def test_extract_keeps_each_disjoint_candidate_on_a_frame(self) -> None:
        disjoint_a = candidate()
        disjoint_b = candidate([43, 47, 50], [65, 68, 72])
        overlapping = candidate()
        overlapping["sharedPitchClasses"] = [0]
        report = {
            "candidateFrames": [
                {
                    "songId": "001",
                    "afterEventIndex": 2,
                    "timestampMs": 30,
                    "dwellMs": 10,
                    "observationFrame": {},
                    "candidateInterpretations": [
                        {"candidate": disjoint_a, "onsetEvidence": {}},
                        {"candidate": overlapping, "onsetEvidence": {}},
                        {"candidate": disjoint_b, "onsetEvidence": {}},
                    ],
                }
            ]
        }

        selected = subject.extract_disjoint_instances(report)

        self.assertEqual(len(selected), 2)
        self.assertEqual({item["candidate"]["symbol"] for item in selected}, {"F#m|C"})
        self.assertEqual(
            {tuple(item["candidate"]["lower"]["midiNotes"]) for item in selected},
            {(48, 52, 55), (43, 47, 50)},
        )

    def test_runs_require_exact_allocation_and_consecutive_event_indices(self) -> None:
        candidate_a = candidate()
        candidate_b = candidate([43, 47, 50], [65, 68, 72])
        payload = fixture(
            [
                {
                    "index": index,
                    "timestampMs": index * 10,
                    "type": "noteOn",
                    "midiNote": 40 + index,
                    "velocity": 80,
                }
                for index in range(6)
            ],
            60,
        )

        def evidence() -> dict:
            return {
                "pedal": {"lastTransitionEventIndex": None},
                "lower": {"notes": []},
                "upper": {"notes": []},
            }

        def instance(event_index: int, item_candidate: dict, dwell_ms: int) -> dict:
            return {
                "songId": "001",
                "afterEventIndex": event_index,
                "timestampMs": event_index * 10,
                "dwellMs": dwell_ms,
                "observationFrame": payload["frames"][event_index],
                "candidate": item_candidate,
                "onsetEvidence": {},
                "causingEvent": payload["events"][event_index],
                "releasePedalEvidence": evidence(),
            }

        runs = subject.group_candidate_runs(
            [
                instance(1, candidate_a, 0),
                instance(2, candidate_a, 10),
                instance(2, candidate_b, 10),
                instance(4, candidate_a, 10),
            ],
            {"001": payload},
        )

        self.assertEqual(len(runs), 3)
        self.assertEqual([run["frameCount"] for run in runs], [2, 1, 1])
        self.assertEqual(runs[0]["zeroDwellFrameCount"], 1)
        self.assertEqual(runs[0]["observedDurationMs"], 10)
        self.assertEqual(runs[0]["terminatingEvent"]["index"], 3)
        self.assertNotEqual(runs[0]["candidate"], runs[1]["candidate"])

    def test_source_report_digest_is_hard_pinned(self) -> None:
        with self.assertRaisesRegex(ValueError, "source report digest"):
            subject.validate_source_report({}, "0" * 64)

    def test_output_must_stay_below_build(self) -> None:
        self.assertTrue(
            subject.output_is_allowed(
                subject.REPO_ROOT / "build/polychord/release-audit.json"
            )
        )
        self.assertFalse(
            subject.output_is_allowed(
                subject.REPO_ROOT / "research/polychord/release-audit.json"
            )
        )


if __name__ == "__main__":
    unittest.main()

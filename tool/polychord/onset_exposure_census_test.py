"""Unit tests for the preregistered polychord onset-exposure census."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import onset_exposure_census as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


def message(
    timestamp_ms: int,
    message_type: str,
    *,
    channel: int = 0,
    midi_note: int | None = None,
    velocity: int | None = None,
    pedal_down: bool | None = None,
    controller: int | None = None,
) -> subject.MidiInputMessage:
    return subject.MidiInputMessage(
        timestamp_ms=timestamp_ms,
        type=message_type,
        channel=channel,
        midi_note=midi_note,
        velocity=velocity,
        pedal_down=pedal_down,
        controller=controller,
    )


def note_on(
    timestamp_ms: int,
    midi_note: int,
    *,
    channel: int = 0,
    velocity: int = 96,
) -> subject.MidiInputMessage:
    return message(
        timestamp_ms,
        "noteOn",
        channel=channel,
        midi_note=midi_note,
        velocity=velocity,
    )


def note_off(
    timestamp_ms: int,
    midi_note: int,
    *,
    channel: int = 0,
    velocity: int = 0,
) -> subject.MidiInputMessage:
    return message(
        timestamp_ms,
        "noteOff",
        channel=channel,
        midi_note=midi_note,
        velocity=velocity,
    )


class FakeMidiFile:
    def __init__(self, tracks: list[list[SimpleNamespace]], merged: list) -> None:
        self.tracks = tracks
        self._merged = merged

    def __iter__(self):
        return iter(self._merged)


class OnsetExposureCensusTest(unittest.TestCase):
    def test_roster_reader_selects_only_the_previously_exposed_sample(self) -> None:
        roster = {
            "schema": "performed-input-held-pool/1",
            "sample": ["001", "010"],
            "held": ["002", "003"],
        }
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "roster.json"
            path.write_text(json.dumps(roster))

            self.assertEqual(subject.load_sample_song_ids(path), ["001", "010"])

    def test_roster_reader_rejects_overlap_with_the_held_pool(self) -> None:
        roster = {
            "schema": "performed-input-held-pool/1",
            "sample": ["001"],
            "held": ["001"],
        }
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "roster.json"
            path.write_text(json.dumps(roster))

            with self.assertRaisesRegex(ValueError, "overlap"):
                subject.load_sample_song_ids(path)

    def test_frozen_roster_is_hard_pinned(self) -> None:
        self.assertEqual(
            subject.sha256_file(subject.DEFAULT_ROSTER),
            subject.FROZEN_ROSTER_SHA256,
        )
        self.assertEqual(len(subject.load_frozen_sample_song_ids()), 101)

    def test_midi_reader_maps_relevant_messages_and_retains_resets(self) -> None:
        raw_messages = [
            SimpleNamespace(
                time=0,
                type="note_on",
                velocity=80,
                channel=0,
                note=72,
            ),
            SimpleNamespace(
                time=0.010,
                type="note_on",
                velocity=90,
                channel=2,
                note=60,
            ),
            SimpleNamespace(
                time=0.020,
                type="note_on",
                velocity=0,
                channel=2,
                note=60,
            ),
            SimpleNamespace(
                time=0.030,
                type="control_change",
                channel=2,
                control=64,
                value=127,
            ),
            SimpleNamespace(
                time=0.040,
                type="control_change",
                channel=2,
                control=123,
                value=0,
            ),
            SimpleNamespace(time=0.050, type="program_change"),
        ]
        tracks = [
            [SimpleNamespace(type="track_name", name="MELODY", channel=0)],
            [SimpleNamespace(type="track_name", name="BRIDGE", channel=1)],
            [SimpleNamespace(type="track_name", name="PIANO", channel=2)],
        ]
        fake_midi = FakeMidiFile(tracks, raw_messages)
        fake_mido = SimpleNamespace(MidiFile=lambda _: fake_midi)

        with patch.dict(sys.modules, {"mido": fake_mido}):
            messages, end_timestamp, projection = subject.read_midi_messages(
                Path("synthetic.mid")
            )

        self.assertEqual(
            [(item.timestamp_ms, item.type) for item in messages],
            [(10, "noteOn"), (30, "noteOff"), (60, "pedal"), (100, "unsupportedReset")],
        )
        self.assertEqual(end_timestamp, 150)
        self.assertEqual(projection["selectedTrackNames"], ["BRIDGE", "PIANO"])
        self.assertEqual(projection["selectedChannels"], [1, 2])
        self.assertEqual(
            projection["channelsByTrack"],
            {"MELODY": [0], "BRIDGE": [1], "PIANO": [2]},
        )
        self.assertEqual(projection["excludedRelevantMessages"], 1)
        self.assertEqual(projection["selectedPedalMessagesByChannel"], {"1": 0, "2": 1})
        self.assertEqual(projection["channelPedalDisagreementMs"], 90)

    def test_midi_reader_rejects_an_unknown_track_projection(self) -> None:
        tracks = [
            [SimpleNamespace(type="track_name", name="MELODY", channel=0)],
            [SimpleNamespace(type="track_name", name="PIANO", channel=2)],
        ]
        fake_mido = SimpleNamespace(MidiFile=lambda _: FakeMidiFile(tracks, []))

        with (
            patch.dict(sys.modules, {"mido": fake_mido}),
            self.assertRaisesRegex(ValueError, "named tracks must be"),
        ):
            subject.read_midi_messages(Path("synthetic.mid"))

    def test_normalization_preserves_pedal_sustain_and_reattack(self) -> None:
        messages = [
            note_on(0, 60, velocity=88),
            message(100, "pedal", pedal_down=True, controller=64),
            note_off(200, 60),
            note_on(300, 60, velocity=72),
            note_off(400, 60),
            message(500, "pedal", pedal_down=False, controller=64),
        ]

        fixture, normalization = subject.normalize_messages("001", messages, 600)

        self.assertEqual(normalization["rawRelevantMessages"], 6)
        self.assertEqual(normalization["normalizedEvents"], 6)
        self.assertEqual(fixture["frames"][2]["sustainedMidiNotes"], [60])
        self.assertEqual(fixture["frames"][3]["pressedMidiNotes"], [60])
        self.assertEqual(fixture["events"][3]["velocity"], 72)
        self.assertEqual(fixture["frames"][5]["soundingMidiNotes"], [])

    def test_channels_collapse_to_the_apps_single_pressed_pitch_set(self) -> None:
        messages = [
            note_on(0, 60, channel=1),
            note_on(10, 60, channel=2),
            note_off(20, 60, channel=1),
            note_off(30, 60, channel=2),
        ]

        fixture, normalization = subject.normalize_messages("001", messages, 40)

        self.assertEqual(
            [event["type"] for event in fixture["events"]],
            ["noteOn", "noteOff"],
        )
        self.assertEqual(
            [event["timestampMs"] for event in fixture["events"]],
            [0, 20],
        )
        self.assertEqual(normalization["repeatedNoteOnMessages"], 1)
        self.assertEqual(normalization["unmatchedNoteOffMessages"], 1)

    def test_noop_messages_are_counted_instead_of_silently_replayed(self) -> None:
        messages = [
            note_off(0, 60),
            message(10, "pedal", pedal_down=False, controller=64),
        ]

        fixture, normalization = subject.normalize_messages("001", messages, 20)

        self.assertEqual(fixture["events"], [])
        self.assertEqual(normalization["unmatchedNoteOffMessages"], 1)
        self.assertEqual(normalization["repeatedPedalMessages"], 1)

    def test_same_timestamp_pedal_reversal_is_visible(self) -> None:
        messages = [
            message(10, "pedal", pedal_down=True, controller=64),
            message(10, "pedal", pedal_down=False, controller=64),
        ]

        fixture, normalization = subject.normalize_messages("001", messages, 20)

        self.assertEqual(len(fixture["events"]), 2)
        self.assertEqual(normalization["sameTimestampPedalReversals"], 1)

    def test_unsupported_all_notes_off_is_a_hard_failure(self) -> None:
        messages = [
            message(0, "unsupportedReset", controller=123),
        ]

        with self.assertRaisesRegex(ValueError, "unsupported controller 123"):
            subject.normalize_messages("001", messages, 0)

    def test_matched_controls_have_distinct_support_time(self) -> None:
        synchronous = json.loads(
            (FIXTURE_DIR / "synchronous-six-note-cohort.json").read_text()
        )
        layered = json.loads(
            (FIXTURE_DIR / "two-register-held-cohorts.json").read_text()
        )

        synchronous_metrics, _ = subject.analyze_fixture(synchronous)
        layered_metrics, _ = subject.analyze_fixture(layered)

        self.assertEqual(
            synchronous_metrics["candidateInstances"]["positiveSupport"],
            0,
        )
        self.assertGreater(
            synchronous_metrics["dwellMs"]["withCandidates"],
            0,
        )
        self.assertEqual(
            synchronous_metrics["dwellMs"]["withPositiveSupport"],
            0,
        )
        self.assertEqual(
            layered_metrics["candidateInstances"]["positiveSupport"],
            1,
        )
        self.assertGreater(layered_metrics["dwellMs"]["withPositiveSupport"], 0)

    def test_zero_dwell_candidate_frame_is_not_display_time(self) -> None:
        messages = [
            *(note_on(0, midi_note) for midi_note in (43, 46, 50, 60, 64, 67)),
            note_on(0, 61),
        ]
        fixture, _ = subject.normalize_messages("001", messages, 100)

        metrics, candidate_frames = subject.analyze_fixture(fixture)

        self.assertEqual(metrics["eventFrames"]["withCandidates"], 1)
        self.assertEqual(metrics["eventFrames"]["zeroDwellWithCandidates"], 1)
        self.assertEqual(metrics["dwellMs"]["withCandidates"], 0)
        self.assertEqual(candidate_frames[0]["dwellMs"], 0)

    def test_candidate_frame_retains_raw_and_interpreted_evidence(self) -> None:
        fixture = json.loads(
            (FIXTURE_DIR / "two-register-held-cohorts.json").read_text()
        )

        _, candidate_frames = subject.analyze_fixture(fixture)

        item = candidate_frames[0]["candidateInterpretations"][0]
        self.assertEqual(
            set(item), {"candidate", "onsetEvidence", "onsetInterpretation"}
        )
        self.assertEqual(item["candidate"]["symbol"], "C|Gm")
        self.assertEqual(
            item["onsetInterpretation"]["onsetCohortSupport"],
            "positive",
        )

    def test_metric_shares_keep_event_time_and_instance_denominators_separate(
        self,
    ) -> None:
        metrics = subject.empty_metrics()
        metrics["eventFrames"].update(
            {"sounding": 4, "withCandidates": 2, "withPositiveSupport": 1}
        )
        metrics["dwellMs"].update(
            {"sounding": 1000, "withCandidates": 100, "withPositiveSupport": 25}
        )
        metrics["candidateInstances"].update(
            {"total": 3, "completeEvidence": 2, "positiveSupport": 1}
        )

        finalized = subject.finalize_metrics(metrics)

        self.assertEqual(
            finalized["eventFrames"]["candidateShareOfSounding"],
            0.5,
        )
        self.assertEqual(
            finalized["dwellMs"]["candidateShareOfSounding"],
            0.1,
        )
        self.assertEqual(
            finalized["candidateInstances"]["completeEvidenceShare"],
            2 / 3,
        )

    def test_projection_summary_retains_channel_limitation_totals(self) -> None:
        per_piece = [
            {
                "projection": {
                    "selectedRelevantMessages": 10,
                    "excludedRelevantMessages": 3,
                    "channelPedalDisagreementMs": 40,
                    "selectedNoteMessagesByChannel": {"1": 2, "2": 4},
                    "selectedPedalMessagesByChannel": {"1": 1, "2": 2},
                }
            },
            {
                "projection": {
                    "selectedRelevantMessages": 20,
                    "excludedRelevantMessages": 5,
                    "channelPedalDisagreementMs": 0,
                    "selectedNoteMessagesByChannel": {"1": 3, "2": 5},
                    "selectedPedalMessagesByChannel": {"1": 0, "2": 4},
                }
            },
        ]

        summary = subject.summarize_projections(per_piece)

        self.assertEqual(summary["selectedRelevantMessages"], 30)
        self.assertEqual(summary["channelPedalDisagreementMs"], 40)
        self.assertEqual(summary["piecesWithChannelPedalDisagreement"], 1)
        self.assertEqual(summary["piecesWithPedalOnEverySelectedChannel"], 1)
        self.assertEqual(summary["selectedPedalMessagesByChannel"], {"1": 1, "2": 6})

    def test_contract_pins_are_exact_and_output_cannot_enter_research(self) -> None:
        pins = subject.contract_pins()

        self.assertEqual(
            subject.MEASUREMENT_ID,
            "pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1",
        )
        self.assertEqual(len(pins), 10)
        self.assertTrue(all(len(pin["sha256"]) == 64 for pin in pins))
        self.assertFalse(
            subject.output_is_allowed(
                REPO_ROOT / "research/polychord/results/pop909.json"
            )
        )
        self.assertFalse(
            subject.output_is_allowed(REPO_ROOT / "tool/polychord/results/pop909.json")
        )
        self.assertTrue(
            subject.output_is_allowed(
                REPO_ROOT / "build/polychord/pop909-onset-exposure.json"
            )
        )
        self.assertEqual(subject.format_ratio(None), "n/a")


if __name__ == "__main__":
    unittest.main()

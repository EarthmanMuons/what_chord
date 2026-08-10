"""Unit tests for exact polychord frame replay."""

from __future__ import annotations

import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

import frame_replay as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"
MANIFEST = FIXTURE_DIR / "manifest.json"


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURE_DIR / name).read_text())


class FrameReplayTest(unittest.TestCase):
    def test_manifest_pins_and_validates_every_fixture(self) -> None:
        paths = subject.validate_manifest(MANIFEST)

        self.assertEqual(
            {path.name for path in paths},
            {
                "carried-in-state.json",
                "pedal-release-and-repress.json",
                "synchronous-six-note-cohort.json",
                "two-register-contrary-motion.json",
                "two-register-held-cohorts.json",
                "two-register-inner-motion.json",
                "two-register-pedal-history.json",
            },
        )

    def test_onset_pair_reaches_the_same_six_note_state_differently(self) -> None:
        synchronous = load_fixture("synchronous-six-note-cohort.json")
        layered = load_fixture("two-register-held-cohorts.json")

        synchronous_full = synchronous["frames"][5]
        layered_full = layered["frames"][5]
        self.assertEqual(
            synchronous_full["soundingMidiNotes"],
            layered_full["soundingMidiNotes"],
        )
        self.assertEqual(synchronous_full["timestampMs"], 0)
        self.assertEqual(layered_full["timestampMs"], 400)
        self.assertEqual(layered["frames"][2]["soundingMidiNotes"], [43, 46, 50])

    def test_pedal_release_and_repress_preserve_note_provenance(self) -> None:
        fixture = load_fixture("pedal-release-and-repress.json")

        subject.validate_fixture(fixture)

        released = fixture["frames"][6]
        repressed = fixture["frames"][7]
        pedal_up = fixture["frames"][9]
        self.assertEqual(released["sustainedMidiNotes"], [48, 52, 55])
        self.assertEqual(repressed["pressedMidiNotes"], [48])
        self.assertEqual(repressed["sustainedMidiNotes"], [52, 55])
        self.assertEqual(pedal_up["soundingMidiNotes"], [])

    def test_explicit_initial_state_supports_cropped_windows(self) -> None:
        fixture = load_fixture("carried-in-state.json")

        frames = subject.replay_fixture(fixture)

        self.assertEqual(frames[0]["soundingMidiNotes"], [36, 48, 60])
        self.assertEqual(frames[1]["pressedMidiNotes"], [60])
        self.assertEqual(frames[1]["sustainedMidiNotes"], [36, 48])
        self.assertEqual(frames[2]["soundingMidiNotes"], [60])

    def test_recorded_frames_must_equal_replayed_state(self) -> None:
        fixture = load_fixture("carried-in-state.json")
        fixture["frames"][1]["sustainedMidiNotes"] = [36]

        with self.assertRaisesRegex(ValueError, "does not match replayed state"):
            subject.validate_fixture(fixture)

    def test_invalid_transitions_are_rejected(self) -> None:
        fixture = load_fixture("carried-in-state.json")
        fixture["events"][0] = {
            "index": 0,
            "timestampMs": 100,
            "type": "noteOff",
            "midiNote": 61,
            "velocity": 0,
        }

        with self.assertRaisesRegex(ValueError, "which is not pressed"):
            subject.replay_fixture(fixture)

    def test_note_on_velocity_zero_must_be_normalized(self) -> None:
        fixture = load_fixture("synchronous-six-note-cohort.json")
        fixture["events"][0]["velocity"] = 0

        with self.assertRaisesRegex(ValueError, "must be from 1 through 127"):
            subject.replay_fixture(fixture)

    def test_manifest_rejects_a_changed_fixture(self) -> None:
        manifest = json.loads(MANIFEST.read_text())
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for entry in manifest["fixtures"]:
                source = FIXTURE_DIR / entry["file"]
                (directory / entry["file"]).write_bytes(source.read_bytes())
            changed = directory / manifest["fixtures"][0]["file"]
            payload = json.loads(changed.read_text())
            payload["description"] += " Changed."
            changed.write_text(json.dumps(payload))
            manifest_path = directory / "manifest.json"
            manifest_path.write_text(json.dumps(deepcopy(manifest)))

            with self.assertRaisesRegex(ValueError, "digest does not match"):
                subject.validate_manifest(manifest_path)


if __name__ == "__main__":
    unittest.main()

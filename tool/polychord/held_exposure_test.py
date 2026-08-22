"""Controls for the final POP909 held-exposure harness."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import held_exposure as subject

REPO_ROOT = Path(__file__).resolve().parents[2]


class HeldExposureTest(unittest.TestCase):
    def test_adjudication_file_is_not_an_immutable_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "summary.json").write_text("summary\n")
            (root / "review.json").write_text("review\n")
            (root / "manifest.json").write_text("manifest\n")

            self.assertEqual(
                subject.output_hashes(root),
                {"summary.json": subject.shared.sha256_file(root / "summary.json")},
            )

    def test_held_roster_is_exact_and_disjoint(self) -> None:
        payload = {
            "sample": [f"sample-{index}" for index in range(101)],
            "held": [f"held-{index}" for index in range(808)],
        }
        self.assertEqual(len(subject.held_ids(payload)), 808)

        payload["held"][0] = payload["sample"][0]
        with self.assertRaisesRegex(ValueError, "overlap"):
            subject.held_ids(payload)

    def test_dart_batch_reaches_only_the_separated_onset_positive(self) -> None:
        positive = self._request(
            "positive",
            [
                (0, 43),
                (0, 46),
                (0, 50),
                (80, 60),
                (80, 64),
                (80, 67),
            ],
        )
        simultaneous = self._request(
            "simultaneous",
            [(0, note) for note in (43, 46, 50, 60, 64, 67)],
        )
        process = subprocess.run(
            ["dart", "run", "tool/polychord/held_exposure_batch.dart"],
            cwd=REPO_ROOT,
            input="\n".join((json.dumps(positive), json.dumps(simultaneous))) + "\n",
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        results = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual(len(results[0]["stableEpisodes"]), 1)
        self.assertEqual(results[0]["stableEpisodes"][0]["startMs"], 280)
        self.assertEqual(results[0]["stableEpisodes"][0]["selected"]["symbol"], "C|Gm")
        self.assertEqual(results[1]["stableEpisodes"], [])

    @staticmethod
    def _request(identifier: str, timed_notes: list[tuple[int, int]]) -> dict:
        pressed: list[int] = []
        events = []
        frames = []
        for index, (timestamp_ms, midi_note) in enumerate(timed_notes):
            pressed.append(midi_note)
            pressed.sort()
            events.append(
                {
                    "index": index,
                    "rawMessageIndex": index,
                    "timestampMs": timestamp_ms,
                    "type": "noteOn",
                    "sourceChannel": 0,
                    "midiNote": midi_note,
                    "velocity": 80,
                }
            )
            frames.append(
                {
                    "afterEventIndex": index,
                    "timestampMs": timestamp_ms,
                    "pressedMidiNotes": pressed.copy(),
                    "sustainedMidiNotes": [],
                    "soundingMidiNotes": pressed.copy(),
                    "pedalDown": False,
                }
            )
        return {
            "id": identifier,
            "endTimestampMs": 400,
            "events": events,
            "frames": frames,
        }


if __name__ == "__main__":
    unittest.main()

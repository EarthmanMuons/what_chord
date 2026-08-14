"""Controls for prior-art baseline observation and normalization behavior."""

from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

import prior_art_baseline_smoke
import prior_art_baselines as subject

REPO_ROOT = Path(__file__).parents[2]


def _musicpy_chord(root: str, quality: str) -> dict:
    return {
        "class": "musicpy.chord_class.chord_type",
        "fields": {
            "altered": None,
            "chord_speciality": "root position",
            "chord_type": quality,
            "inversion": None,
            "non_chord_bass_note": None,
            "omit": None,
            "polychords": None,
            "root": root,
            "type": "chord",
        },
    }


def _chordrec_chord(root_pc: int, quality: str, notes: list[int]) -> dict:
    seventh = len({note % 12 for note in notes}) == 4
    return {
        "rootPitchClass": root_pc,
        "notes": notes,
        "quality": {"name": "min" if quality == "minor7" else "Maj"},
        "factorQuality": {"name": "Maj" if quality == "major7" else "dom"},
        "factors": ([{"degree": {"name": "7"}, "signs": []}] if seventh else []),
        "additions": [],
        "alteredNotes": [],
        "omission": None,
        "invertedNotes": [],
        "inversion": 0,
    }


class NeutralObservationTest(unittest.TestCase):
    def test_registered_and_pitch_class_spellings_are_both_preserved(self) -> None:
        value = subject.make_observation("doubling", [48, 60, 64, 67])

        self.assertEqual(value["scientificPitchSharps"], ["C3", "C4", "E4", "G4"])
        self.assertEqual(value["pitchClassSharps"], ["C", "C", "E", "G"])
        self.assertEqual(subject.validate_observation(value), value)

    def test_midi_notes_must_be_sorted_distinct_and_registered(self) -> None:
        for notes in ([60, 60], [64, 60], [-1], [128]):
            with self.subTest(notes=notes), self.assertRaises(ValueError):
                subject.make_observation("invalid", notes)


class NormalizationTest(unittest.TestCase):
    def test_musicpy_reverses_structured_lower_upper_roles_for_display(self) -> None:
        lower = _musicpy_chord("C", "major")
        upper = _musicpy_chord("F#", "major")
        raw = {
            "value": {
                "class": "musicpy.chord_class.chord_type",
                "fields": {"polychords": [lower, upper]},
            },
            "toText": "[F#major]/[Cmajor]",
        }

        value = subject.normalize_musicpy(raw, [48, 52, 55, 66, 70, 73])[0]

        self.assertEqual(value["classification"], "ordered-composite")
        self.assertEqual(value["upper"], {"rootPc": 6, "quality": "major"})
        self.assertEqual(value["lower"], {"rootPc": 0, "quality": "major"})
        self.assertEqual(value["assignment"]["lowerMidiNotes"], [48, 52, 55])

    def test_musicpy_nested_or_altered_components_remain_unsupported(self) -> None:
        nested = {
            "class": "musicpy.chord_class.chord_type",
            "fields": {"polychords": [_musicpy_chord("C", "major")]},
        }
        raw = {
            "value": {
                "class": "musicpy.chord_class.chord_type",
                "fields": {"polychords": [_musicpy_chord("F#", "major"), nested]},
            },
            "toText": "nested",
        }

        value = subject.normalize_musicpy(raw, [48, 52, 55, 66, 70, 73])[0]

        self.assertEqual(value["classification"], "unsupported-composite")
        self.assertEqual(value["reason"], "unsupported-component")

    def test_mingus_preserves_every_alternative_and_upper_first_pipe_order(
        self,
    ) -> None:
        values = subject.normalize_mingus(["CM7", "Em|CM", "Cdim|FM"])

        self.assertEqual([value["nativeIndex"] for value in values], [0, 1, 2])
        self.assertEqual(values[0]["classification"], "single-chord-output")
        self.assertEqual(values[1]["upper"], {"rootPc": 4, "quality": "minor"})
        self.assertEqual(values[1]["lower"], {"rootPc": 0, "quality": "major"})
        self.assertEqual(values[2]["classification"], "unsupported-composite")

    def test_chordrecgen_orients_only_an_exact_register_partition(self) -> None:
        lower = _chordrec_chord(0, "major", [48, 52, 55])
        upper = _chordrec_chord(6, "major", [66, 70, 73])
        raw = [{"fullName": "C - F# (poly)", "chords": [lower, upper]}]

        value = subject.normalize_chordrecgen(raw, [48, 52, 55, 66, 70, 73])[0]

        self.assertEqual(value["classification"], "ordered-composite")
        self.assertEqual(value["upper"], {"rootPc": 6, "quality": "major"})
        self.assertEqual(value["lower"], {"rootPc": 0, "quality": "major"})

        raw[0]["chords"][1] = _chordrec_chord(7, "major", [55, 59, 62])
        unsupported = subject.normalize_chordrecgen(raw, [48, 52, 55, 59, 62])[0]
        self.assertEqual(unsupported["classification"], "unsupported-composite")
        self.assertEqual(
            unsupported["reason"], "component-notes-do-not-partition-input"
        )

    def test_whatchord_normalization_retains_exact_assignment(self) -> None:
        decision = {
            "selected": {
                "upper": {
                    "rootPc": 6,
                    "quality": "major",
                    "midiNotes": [66, 70, 73],
                },
                "lower": {
                    "rootPc": 0,
                    "quality": "major",
                    "midiNotes": [48, 52, 55],
                },
                "symbol": "F#|C",
            }
        }

        value = subject.normalize_whatchord(decision)[0]

        self.assertEqual(value["classification"], "ordered-composite")
        self.assertEqual(value["rawLabel"], "F#|C")
        self.assertEqual(value["assignment"]["upperMidiNotes"], [66, 70, 73])


class ContractControlTest(unittest.TestCase):
    def test_smoke_inputs_do_not_import_or_name_product_suite_cases(self) -> None:
        self.assertNotIn("product_suite", prior_art_baseline_smoke.__dict__)
        self.assertEqual(len(prior_art_baseline_smoke.CONTROL_NOTES), 7)
        self.assertTrue(
            all(
                not control_id.startswith(("named-", "stream-"))
                for control_id in prior_art_baseline_smoke.CONTROL_NOTES
            )
        )

    def test_machine_schemas_and_source_manifest_are_parseable(self) -> None:
        paths = (
            "research/polychord/baselines/schemas/neutral-observation-v1.schema.json",
            "research/polychord/baselines/schemas/baseline-result-v1.schema.json",
            "research/polychord/baselines/source-manifest-v1.json",
        )
        values = [json.loads((REPO_ROOT / path).read_text()) for path in paths]

        self.assertEqual(
            values[0]["title"], "Polychord prior-art neutral observation v1"
        )
        self.assertEqual(
            values[1]["properties"]["schema"]["const"], subject.RESULT_SCHEMA
        )
        self.assertEqual(
            set(values[2]["sources"]),
            {subject.MUSICPY_ID, subject.MINGUS_ID, subject.CHORDRECGEN_ID},
        )

    def test_adapter_freeze_pins_every_tracked_artifact(self) -> None:
        freeze = json.loads(
            (
                REPO_ROOT / "research/polychord/baselines/adapter-freeze-v1.json"
            ).read_text()
        )

        self.assertEqual(
            freeze["preAdapterSuiteSha256"],
            "f3891fb35466ef8019c3785c21bd21fcbfad12375b10283e2c364bf544406af4",
        )
        for name, pin in freeze["artifacts"].items():
            with self.subTest(name=name):
                actual = hashlib.sha256((REPO_ROOT / pin["path"]).read_bytes())
                self.assertEqual(actual.hexdigest(), pin["sha256"])

    def test_exception_result_cannot_be_normalized_as_output(self) -> None:
        observation = subject.make_observation("failure", [60, 64, 67])
        value = subject._injected_exception_results(
            subject.WHATCHORD_ID, [observation]
        )[0]

        self.assertEqual(value["status"], "exception")
        self.assertEqual(value["normalizedAlternatives"], [])
        self.assertEqual(subject.validate_result(value), value)


if __name__ == "__main__":
    unittest.main()

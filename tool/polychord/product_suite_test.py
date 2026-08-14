"""Tests for automatic polychord product-suite artifact validation."""

from __future__ import annotations

import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

import onset_evidence
import product_suite as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_MANIFEST = (
    REPO_ROOT / "research/polychord/data/product-suite/fixture-manifest.json"
)


class ProductFixtureManifestTest(unittest.TestCase):
    def test_manifest_pins_the_isolated_product_fixture_inventory(self) -> None:
        fixtures = subject.validate_fixture_manifest(FIXTURE_MANIFEST)

        self.assertEqual(
            list(fixtures),
            [
                "stravinsky-petrushka-r49-arpeggios",
                "stravinsky-shrovetide-oblique-motion",
                "synchronous-six-note-cohort",
                "two-register-held-cohorts",
                "product-assignment-ambiguity-80",
                "product-basic-positive-80",
                "product-carried-in-complete-candidate",
                "product-cohort-50-gap-80",
                "product-cohort-51-gap-80",
                "product-compact-integrated-80",
                "product-disjoint-upper-first-80",
                "product-gap-79",
                "product-lower-seventh-multiple-identities-80",
                "product-pedal-held-release",
                "product-pending-key-change",
                "product-reattack-binding",
                "product-rooted-ninth-80",
                "product-rooted-seventh-extension-80",
                "product-upper-seventh-80",
            ],
        )
        self.assertEqual(
            {
                fixture_id
                for fixture_id, record in fixtures.items()
                if record["origin"] == "inherited-replay"
            },
            {
                "stravinsky-petrushka-r49-arpeggios",
                "stravinsky-shrovetide-oblique-motion",
                "synchronous-six-note-cohort",
                "two-register-held-cohorts",
            },
        )
        self.assertEqual(
            len(
                [
                    record
                    for record in fixtures.values()
                    if record["origin"] == "authored-product-realization"
                ]
            ),
            15,
        )

    def test_manifest_rejects_unknown_fields_and_digest_changes(self) -> None:
        manifest = json.loads(FIXTURE_MANIFEST.read_text())
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "manifest.json"

            changed = deepcopy(manifest)
            changed["unexpected"] = True
            path.write_text(json.dumps(changed))
            with self.assertRaisesRegex(ValueError, r"unknown \['unexpected'\]"):
                subject.validate_fixture_manifest(path)

            changed = deepcopy(manifest)
            changed["fixtures"][0]["sha256"] = "0" * 64
            path.write_text(json.dumps(changed))
            with self.assertRaisesRegex(ValueError, "sha256 does not match"):
                subject.validate_fixture_manifest(path)

    def test_authored_boundaries_are_literal_fixture_facts(self) -> None:
        fixtures = subject.validate_fixture_manifest(FIXTURE_MANIFEST)
        exact = fixtures["product-cohort-50-gap-80"]["fixture"]
        outside = fixtures["product-cohort-51-gap-80"]["fixture"]
        gap_outside = fixtures["product-gap-79"]["fixture"]

        self.assertEqual(
            [event["timestampMs"] for event in exact["events"]],
            [0, 25, 50, 130, 155, 180],
        )
        self.assertEqual(
            [event["timestampMs"] for event in outside["events"]],
            [0, 25, 51, 131, 156, 181],
        )
        self.assertEqual(
            [event["timestampMs"] for event in gap_outside["events"]],
            [0, 0, 0, 79, 79, 79],
        )

    def test_upper_layer_vocabulary_is_not_triads_only(self) -> None:
        fixture = subject.validate_fixture_manifest(FIXTURE_MANIFEST)[
            "product-upper-seventh-80"
        ]["fixture"]

        self.assertEqual(
            fixture["frames"][-1]["soundingMidiNotes"],
            [28, 40, 44, 47, 51, 55, 58, 61],
        )

    def test_carried_in_candidate_has_incomplete_onset_history(self) -> None:
        fixture = subject.validate_fixture_manifest(FIXTURE_MANIFEST)[
            "product-carried-in-complete-candidate"
        ]["fixture"]

        onset_frame = onset_evidence.replay_onset_frames(fixture)[0]
        self.assertTrue(all(note.origin is None for note in onset_frame.notes))

    def test_pedal_fixture_preserves_binding_until_pedal_up(self) -> None:
        fixture = subject.validate_fixture_manifest(FIXTURE_MANIFEST)[
            "product-pedal-held-release"
        ]["fixture"]

        for frame in fixture["frames"][7:13]:
            self.assertEqual(
                frame["soundingMidiNotes"],
                [43, 46, 50, 60, 64, 67],
            )
        self.assertEqual(fixture["frames"][-1]["soundingMidiNotes"], [])


if __name__ == "__main__":
    unittest.main()

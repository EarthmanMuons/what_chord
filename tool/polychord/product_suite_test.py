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
SUITE = REPO_ROOT / "research/polychord/data/product-suite/suite-v0.json"


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


class ProductSuiteTest(unittest.TestCase):
    def test_complete_suite_matches_the_preregistered_inventory(self) -> None:
        suite = subject.validate_suite(SUITE)

        self.assertEqual(len(suite["cases"]), 20)
        self.assertEqual(
            [case["stratum"] for case in suite["cases"]].count("inherited-source"),
            3,
        )
        self.assertEqual(
            [case["stratum"] for case in suite["cases"]].count(
                "authored-musical-policy"
            ),
            12,
        )
        self.assertEqual(
            [case["stratum"] for case in suite["cases"]].count(
                "authored-contract-mechanics"
            ),
            5,
        )
        self.assertTrue(suite["status"]["scoringAllowed"])

    def test_literal_boundaries_and_symmetric_layer_vocabulary_are_present(
        self,
    ) -> None:
        suite = subject.validate_suite(SUITE)
        cases = {case["id"]: case for case in suite["cases"]}

        upper_seventh = cases["upper-seventh-positive"]
        expected_id = upper_seventh["constructionExpectation"]["candidateId"]
        expected = next(
            value["candidate"]
            for value in upper_seventh["expectedCandidates"]
            if value["id"] == expected_id
        )
        self.assertEqual(
            expected["identity"]["upper"],
            {"rootPc": 3, "quality": "dominant7"},
        )
        self.assertEqual(expected["upperMidiNotes"], [51, 55, 58, 61])

        exact = _checkpoint(cases["cohort-50-gap-80-positive"], "event-5")
        outside_span = _checkpoint(cases["cohort-51-neutral"], "event-5")
        outside_gap = _checkpoint(cases["gap-79-neutral"], "event-5")
        self.assertEqual(exact["cueRecords"][0]["support"], "positive")
        self.assertEqual(exact["cueRecords"][0]["lower"]["spanMs"], 50)
        self.assertEqual(exact["cueRecords"][0]["betweenLayerGapMs"], 80)
        self.assertEqual(
            outside_span["cueRecords"][0]["reasonCodes"],
            ["lower-span-exceeds-maximum"],
        )
        self.assertEqual(
            outside_gap["cueRecords"][0]["reasonCodes"],
            ["between-layer-separation-below-minimum"],
        )

    def test_candidate_bound_multiple_identity_case_is_literal(self) -> None:
        suite = subject.validate_suite(SUITE)
        case = next(
            case
            for case in suite["cases"]
            if case["id"] == "lower-seventh-multiple-identities-positive"
        )
        checkpoint = _checkpoint(case, "event-6")

        self.assertEqual(len(checkpoint["candidates"]), 2)
        self.assertEqual(
            [cue["support"] for cue in checkpoint["cueRecords"]],
            ["neutral", "positive"],
        )
        self.assertEqual(
            checkpoint["rawDecision"]["stageSurvivors"]["positiveSupport"],
            [case["constructionExpectation"]["candidateId"]],
        )

    def test_each_integrated_predicate_has_an_isolated_guard(self) -> None:
        suite = subject.validate_suite(SUITE)
        cases = {case["id"]: case for case in suite["cases"]}
        expected = {
            "compact-integrated-before-cue": {
                "compact": True,
                "rootedNinth": False,
                "rootedSeventhExtension": False,
            },
            "rooted-ninth-before-cue": {
                "compact": False,
                "rootedNinth": True,
                "rootedSeventhExtension": False,
            },
            "rooted-seventh-extension-before-cue": {
                "compact": False,
                "rootedNinth": False,
                "rootedSeventhExtension": True,
            },
        }

        for case_id, predicates in expected.items():
            with self.subTest(case_id=case_id):
                case = cases[case_id]
                checkpoint = next(
                    action["checkpoint"]
                    for action in case["actions"]
                    if action["type"] == "musicalEvent"
                    and action["checkpoint"] is not False
                )
                trace = checkpoint["rawDecision"]["candidateTraces"][0]
                self.assertEqual(trace["integratedTertian"], predicates)
                self.assertEqual(trace["removedAt"], "integrated")
                self.assertEqual(
                    checkpoint["rawDecision"]["reason"],
                    "integrated-tertian-reading",
                )

    def test_pedal_release_and_reattack_have_distinct_binding_outcomes(self) -> None:
        suite = subject.validate_suite(SUITE)
        cases = {case["id"]: case for case in suite["cases"]}

        pedal = cases["pedal-held-release-stable-then-silence"]
        for event_index in range(7, 13):
            display = _checkpoint(pedal, f"event-{event_index}")["display"]
            self.assertEqual(display["state"], "visible")
            self.assertEqual(display["transition"], "stable")
        self.assertEqual(_checkpoint(pedal, "event-13")["display"]["reason"], "silence")

        reattack = _checkpoint(cases["reattack-invalidates-binding"], "event-8")
        self.assertEqual(
            reattack["rawDecision"]["reason"],
            "layer-separation-not-supported",
        )
        self.assertEqual(
            reattack["display"]["reason"],
            "invalidated-support-binding",
        )

    def test_display_lifecycle_covers_key_change_and_reset(self) -> None:
        suite = subject.validate_suite(SUITE)
        cases = {case["id"]: case for case in suite["cases"]}

        key_change = cases["pending-key-change-restarts-deadline"]
        changed = _checkpoint(key_change, "event-6")["display"]
        old_deadline = _checkpoint(key_change, "timer-280")["display"]
        appearance = _checkpoint(key_change, "timer-300")["display"]
        self.assertEqual(changed["reason"], "authorization-key-changed")
        self.assertEqual(changed["deadlineMs"], 300)
        self.assertEqual(old_deadline["state"], "pending")
        self.assertEqual(appearance["transition"], "appearance")

        reset = _checkpoint(cases["tracker-reset-clears"], "trackerReset-300")
        self.assertIsNone(reset["frame"])
        self.assertIsNone(reset["authorization"])
        self.assertEqual(reset["display"]["reason"], "tracker-reset")

    def test_suite_rejects_changed_literal_candidates(self) -> None:
        suite = json.loads(SUITE.read_text())
        case = next(
            case
            for case in suite["cases"]
            if case["id"] == "lower-seventh-multiple-identities-positive"
        )
        checkpoint = next(
            action["checkpoint"]
            for action in case["actions"]
            if action["id"] == "event-6"
        )
        checkpoint["candidates"].reverse()

        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "suite.json"
            path.write_text(json.dumps(suite, indent=2) + "\n")
            with self.assertRaisesRegex(ValueError, "canonical list"):
                subject.validate_suite(path)

    def test_suite_rejects_inconsistent_instance_bindings(self) -> None:
        original = json.loads(SUITE.read_text())
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "suite.json"

            suite = deepcopy(original)
            checkpoint = _checkpoint(
                next(
                    case
                    for case in suite["cases"]
                    if case["id"] == "lower-seventh-multiple-identities-positive"
                ),
                "event-6",
            )
            checkpoint["cueRecords"][1]["binding"][0]["onsetEventIndex"] = 99
            path.write_text(json.dumps(suite, indent=2) + "\n")
            with self.assertRaisesRegex(ValueError, "binding disagrees with the frame"):
                subject.validate_suite(path)

            suite = deepcopy(original)
            checkpoint = _checkpoint(
                next(
                    case
                    for case in suite["cases"]
                    if case["id"] == "lower-seventh-multiple-identities-positive"
                ),
                "event-6",
            )
            checkpoint["authorization"]["key"]["binding"][0]["onsetEventIndex"] = 99
            path.write_text(json.dumps(suite, indent=2) + "\n")
            with self.assertRaisesRegex(ValueError, "disagrees with the cue binding"):
                subject.validate_suite(path)


def _checkpoint(case: dict, action_id: str) -> dict:
    return next(
        action["checkpoint"] for action in case["actions"] if action["id"] == action_id
    )


if __name__ == "__main__":
    unittest.main()

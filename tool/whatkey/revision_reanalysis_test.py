#!/usr/bin/env python3
"""Unit tests for revision_reanalysis.py using synthetic, non-corpus data."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import revision_reanalysis as subject


def event(key: str | None, measure: int, timestamp_ms: int = 0) -> dict:
    return {
        "timestampMs": timestamp_ms,
        "labels": {"localKey": key, "measure": measure},
    }


class RevisionReanalysisTest(unittest.TestCase):
    def test_diatonic_collection_merges_relative_major_and_minor(self) -> None:
        self.assertEqual(subject.diatonic_collection("C:maj"), 0)
        self.assertEqual(subject.diatonic_collection("A:min"), 0)
        self.assertEqual(subject.diatonic_collection("Eb:maj"), 3)
        self.assertEqual(subject.diatonic_collection("C:min"), 3)

    def test_signature_collections_uses_first_signature_before_its_time(self) -> None:
        signatures = {"1.5": [8, -4], "3.0": [3, -3]}
        self.assertEqual(
            subject.signature_collections(signatures, [500, 1500, 2999, 3000]),
            [8, 8, 8, 3],
        )

    def test_segment_spans_follow_maximal_equal_key_runs(self) -> None:
        events = [
            event("C:maj", 2),
            event("C:maj", 4),
            event("G:maj", 5),
            event("G:maj", 5),
            event("C:maj", 9),
        ]
        self.assertEqual(subject.segment_spans(events), [3, 3, 1, 1, 1])
        fixture = subject.Fixture("set/piece", "piece", events)
        self.assertEqual(
            subject.threshold_mask(fixture, 2), [True, True, False, False, False]
        )

    def test_piece_score_pairs_coverage_and_accuracy_on_one_cohort(self) -> None:
        fixture = subject.Fixture(
            "set/piece",
            "piece",
            [event("C:maj", 1), event(None, 2), event("G:maj", 3)],
        )
        score = subject.score_piece(
            fixture,
            ["C:maj", "A:min", None],
            subject.scorable_mask(fixture),
            subject.local_truth(fixture),
        )
        self.assertIsNotNone(score)
        assert score is not None
        self.assertEqual(score.eligible_events, 2)
        self.assertEqual(score.claims, 1)
        self.assertEqual(score.correct, 1)
        self.assertEqual(score.coverage, 0.5)
        self.assertEqual(score.accuracy, 1.0)

    def test_exact_key_scoring_canonicalizes_enharmonic_spelling(self) -> None:
        fixture = subject.Fixture("set/piece", "piece", [event("Eb:min", 1)])
        score = subject.score_piece(
            fixture,
            ["D#:min"],
            [True],
            subject.local_truth(fixture),
            transform_claim=subject.parse_key,
            transform_reference=subject.parse_key,
        )
        self.assertIsNotNone(score)
        assert score is not None
        self.assertEqual(score.correct, 1)

    def test_abstentions_do_not_break_switch_continuity(self) -> None:
        claims = [None, "C:maj", None, "C:maj", "G:maj", None, "G:maj"]
        self.assertEqual(subject.time_to_first_claim(claims), 1)
        self.assertEqual(subject.claim_switches(claims), 1)

    def test_factorial_effect_has_declared_direction(self) -> None:
        def piece(correct: int) -> subject.PieceScore:
            return subject.PieceScore("piece", 10, 10, correct)

        scores = {
            (1, "0"): {"piece": piece(5)},
            (1, "0.1"): {"piece": piece(6)},
            (30, "0"): {"piece": piece(7)},
            (30, "0.1"): {"piece": piece(9)},
        }
        effects = subject.factorial_effects(scores, "accuracy", 100, 17)
        self.assertAlmostEqual(effects["memory30Minus1AtFunctional0"]["mean"], 0.2)
        self.assertAlmostEqual(effects["functional0.1Minus0AtMemory1"]["mean"], 0.1)
        self.assertAlmostEqual(effects["interaction"]["mean"], 0.1)
        self.assertAlmostEqual(effects["paperMinusReflexPackage"]["mean"], 0.1)

    def test_factorial_confidence_guard_accepts_disabled_evidence(self) -> None:
        config = (
            "selfTransition=0.9 fifthsDecay=0.5 modeSwitchFactor=0.5 "
            "emissionTemperature=0.25 minEvents=3 marginFloor=0.3 "
            "modeTilt=2.0 relativeTilt=0.0 relativeCadenceTilt=0.0 "
            "relativeEvidenceTilt=0.0 relativeEvidenceWindow=1 "
            "cadenceBoost=0.0 cadenceTriadBoost=0.0 cadenceMarginFactor=1.0 "
            "coldStartTonicPrior=0.0 relativeSwitchFactor=1.0 "
            "functionalBlend=0.0 progressionBlend=0.0 "
            "profiles=albrechtShanahan durationWeighted=true "
            "decayHalfLifeMs=1000 | evidence: disabled"
        )
        command = "dart run harness.dart --confidence-weighting off"
        self.assertEqual(
            subject.factorial_configuration_mismatches(config, command, 1, "0"),
            [],
        )
        self.assertEqual(
            subject.factorial_configuration_mismatches(
                config,
                "dart run harness.dart --confidence-weighting on",
                1,
                "0",
            ),
            ["--confidence-weighting off"],
        )

    def test_fixture_loader_checks_manifest_and_fixture_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fixture = {
                "schema": "whatkey-fixture/1",
                "id": "set/piece",
                "title": "piece",
                "events": [event("C:maj", 1)],
            }
            fixture_path = directory / "piece.json"
            fixture_path.write_text(json.dumps(fixture))
            manifest = {
                "schema": "whatkey-manifest/1",
                "set": "set",
                "contentHash": {"value": "synthetic"},
                "fixtures": [
                    {
                        "id": "set/piece",
                        "title": "piece",
                        "file": "piece.json",
                        "events": 1,
                        "sha256": subject.canonical_sha256(fixture),
                    }
                ],
            }
            manifest["contentHash"]["value"] = subject.canonical_sha256(
                [{"file": "piece.json", "sha256": subject.canonical_sha256(fixture)}]
            )
            manifest_path = directory / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            with patch.dict(
                subject.PINNED_SHA256,
                {"synthetic_manifest": subject.sha256(manifest_path)},
            ):
                loaded = subject.load_fixture_set(directory, "synthetic_manifest")
                self.assertEqual(set(loaded.fixtures), {"set/piece"})
                fixture_path.write_text(json.dumps({**fixture, "events": []}))
                with self.assertRaisesRegex(subject.AnalysisError, "Fixture SHA-256"):
                    subject.load_fixture_set(directory, "synthetic_manifest")

    def test_fixture_loader_uses_content_lock_for_legacy_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fixture = {
                "schema": "whatkey-fixture/1",
                "id": "set/piece",
                "title": "piece",
                "events": [event("C:maj", 1)],
            }
            (directory / "piece.json").write_text(json.dumps(fixture))
            fixture_hash = subject.canonical_sha256(fixture)
            content_hash = subject.canonical_sha256(
                [{"file": "piece.json", "sha256": fixture_hash}]
            )
            manifest = {
                "schema": "whatkey-manifest/1",
                "set": "set",
                "fixtures": [
                    {
                        "id": "set/piece",
                        "title": "piece",
                        "file": "piece.json",
                        "events": 1,
                    }
                ],
            }
            manifest_path = directory / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            with (
                patch.dict(
                    subject.PINNED_SHA256,
                    {"legacy_manifest": subject.sha256(manifest_path)},
                ),
                patch.dict(
                    subject.PINNED_FIXTURE_CONTENT_SHA256,
                    {"legacy_manifest": content_hash},
                ),
            ):
                loaded = subject.load_fixture_set(directory, "legacy_manifest")
                self.assertEqual(loaded.content_hash, content_hash)

    def test_claim_validation_rejects_an_event_length_mismatch(self) -> None:
        fixture = subject.Fixture("set/piece", "piece", [event("C:maj", 1)])
        run = subject.ClaimRun(
            "run",
            Path("claims.json"),
            {"name": "synthetic"},
            {"set/piece": ["C:maj", "G:maj"]},
        )
        with self.assertRaisesRegex(subject.AnalysisError, "expected 1"):
            subject.validate_claims(run, {fixture.id: fixture})


if __name__ == "__main__":
    unittest.main()

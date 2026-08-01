#!/usr/bin/env python3
"""Run the predeclared post-submission WhatKey revision analyses.

The analysis contract is recorded in research/whatkey/PROTOCOL.md and log entry
2026-08-01-01. This tool verifies every frozen input before scoring, recomputes
primary quantities from event-level fixtures and claims, and writes only local
analysis artifacts. It never runs a detector or changes an archived report.
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import random
import shlex
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from statistics import fmean
from typing import Any

from reproducibility import canonical_sha256

REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_SCHEMA = "whatkey-revision-reanalysis/1"
DECLARED_SEED = 20260801
DECLARED_RESAMPLES = 20000
DECLARED_THRESHOLDS = (0, 12, 20, 32)

PINNED_SHA256 = {
    "isophonics_manifest": (
        "e9ae1f97a4d04b04a36dbb7468830923191b2e0281d129bf51dc814b063b48a5"
    ),
    "isophonics_split": (
        "9f766789c4beeda65d9229d7c77c11c7e2f9be04746fa9d8b321edaa2abfe970"
    ),
    "isophonics_paper_test_claims": (
        "401042ec2232fe3c5870af9b6ae78bea43760b5294e381a0b79b362d56e8671f"
    ),
    "isophonics_reflex_test_claims": (
        "c6e8dd76d837095c4e36126ad44acf520d2c776834a16cca0f73904e20704f5f"
    ),
    "overlap_manifest": (
        "32bb9edd0ab0ac861ad1a474d439cf32dce6139254922f62d3e9d454dbe128a1"
    ),
    "overlap_paper_claims": (
        "474a3497b30b2cd25f185821267cd9b49788de1b1b18a511c26d9be86daf8d99"
    ),
    "overlap_reflex_claims": (
        "e83a960eff6fadc77d1a2ffa47bfe8016e6aa2e2de967656bdd2d366d3adf079"
    ),
    "asap_annotations": (
        "02e4b80f0a78150d1bd0fc21c9cee72ed65a61710c1b1f84368c52216b3e0ff7"
    ),
    "when_in_rome_manifest": (
        "21a8130e4796bfd43db9be8189c2f2c4e8a98dea6b5835bc0c2d941f0f1d6683"
    ),
    "when_in_rome_split": (
        "4f55b18f88130fd62718c358b62a2c81302bbb11eede3c67d133f23161795684"
    ),
}

PINNED_FIXTURE_CONTENT_SHA256 = {
    "when_in_rome_manifest": (
        "0bc6551265f15bc397fa5cece06a909349ac35e27d3ff2891a3dc0e721bba224"
    ),
}

PC_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


class AnalysisError(RuntimeError):
    """An input violates the predeclared analysis contract."""


@dataclass(frozen=True)
class Fixture:
    id: str
    title: str
    events: list[dict[str, Any]]


@dataclass(frozen=True)
class FixtureSet:
    directory: Path
    manifest: dict[str, Any]
    fixtures: dict[str, Fixture]
    content_hash: str


@dataclass(frozen=True)
class ClaimRun:
    name: str
    path: Path
    detector: dict[str, Any]
    claims: dict[str, list[str | None]]


@dataclass(frozen=True)
class PieceScore:
    title: str
    eligible_events: int
    claims: int
    correct: int

    @property
    def coverage(self) -> float:
        return self.claims / self.eligible_events

    @property
    def accuracy(self) -> float | None:
        return self.correct / self.claims if self.claims else None

    def as_json(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "eligibleEvents": self.eligible_events,
            "claims": self.claims,
            "correct": self.correct,
            "coverage": self.coverage,
            "exactOnClaimed": self.accuracy,
        }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def require_hash(path: Path, pin: str, role: str) -> str:
    actual = sha256(path)
    expected = PINNED_SHA256[pin]
    if actual != expected:
        raise AnalysisError(
            f"{role} SHA-256 mismatch: expected {expected}, got {actual}: {path}"
        )
    return actual


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise AnalysisError(f"Could not read JSON input {path}: {error}") from error


def load_fixture_set(directory: Path, manifest_pin: str) -> FixtureSet:
    manifest_path = directory / "manifest.json"
    require_hash(manifest_path, manifest_pin, "fixture manifest")
    manifest = read_json(manifest_path)
    if manifest.get("schema") != "whatkey-manifest/1":
        raise AnalysisError(f"Unexpected fixture manifest schema: {manifest_path}")

    fixtures: dict[str, Fixture] = {}
    content_hashes: dict[str, str] = {}
    embedded_hashes = ["sha256" in entry for entry in manifest["fixtures"]]
    if any(embedded_hashes) and not all(embedded_hashes):
        raise AnalysisError("Fixture manifest mixes hashed and unhashed entries")
    has_embedded_hashes = bool(embedded_hashes) and all(embedded_hashes)
    for entry in manifest["fixtures"]:
        path = directory / entry["file"]
        raw = read_json(path)
        actual = canonical_sha256(raw)
        if has_embedded_hashes and actual != entry["sha256"]:
            raise AnalysisError(
                f"Fixture SHA-256 mismatch for {entry['id']}: "
                f"expected {entry['sha256']}, got {actual}"
            )
        content_hashes[entry["file"]] = actual
        if raw["id"] != entry["id"] or raw["title"] != entry["title"]:
            raise AnalysisError(f"Fixture identity differs from manifest: {path}")
        if len(raw["events"]) != entry["events"]:
            raise AnalysisError(f"Fixture event count differs from manifest: {path}")
        fixture = Fixture(raw["id"], raw["title"], raw["events"])
        if fixture.id in fixtures:
            raise AnalysisError(f"Duplicate fixture id: {fixture.id}")
        fixtures[fixture.id] = fixture
    payload = [
        {"file": name, "sha256": content_hashes[name]}
        for name in sorted(content_hashes)
    ]
    aggregate = canonical_sha256(payload)
    expected_aggregate = manifest.get("contentHash", {}).get(
        "value"
    ) or PINNED_FIXTURE_CONTENT_SHA256.get(manifest_pin)
    if expected_aggregate is None:
        raise AnalysisError("Fixture set has no declared or locked content hash")
    if aggregate != expected_aggregate:
        raise AnalysisError(
            "Fixture-set content SHA-256 mismatch: "
            f"expected {expected_aggregate}, got {aggregate}"
        )
    return FixtureSet(directory, manifest, fixtures, aggregate)


def select_split(
    fixture_set: FixtureSet,
    split_path: Path,
    split_name: str,
    split_pin: str,
) -> dict[str, Fixture]:
    require_hash(split_path, split_pin, "split file")
    split = read_json(split_path)
    try:
        selected_titles = {piece["id"] for piece in split["splits"][split_name]}
        all_titles = {
            piece["id"]
            for name in ("development", "test")
            for piece in split["splits"][name]
        }
    except KeyError as error:
        raise AnalysisError(f"Malformed split file: {split_path}") from error

    fixture_by_title = {piece.title: piece for piece in fixture_set.fixtures.values()}
    if len(fixture_by_title) != len(fixture_set.fixtures):
        raise AnalysisError("Fixture titles are not unique")
    if set(fixture_by_title) != all_titles:
        missing = sorted(all_titles - set(fixture_by_title))
        extra = sorted(set(fixture_by_title) - all_titles)
        raise AnalysisError(
            f"Split/fixture title mismatch: missing={missing}, extra={extra}"
        )
    return {
        fixture_by_title[title].id: fixture_by_title[title] for title in selected_titles
    }


def parse_claim_specs(specs: list[str]) -> dict[str, Path]:
    parsed: dict[str, Path] = {}
    for spec in specs:
        name, separator, raw_path = spec.partition("=")
        if not separator or not name or not raw_path:
            raise AnalysisError(f"Expected --claims name=path, got: {spec}")
        if name in parsed:
            raise AnalysisError(f"Duplicate claim run name: {name}")
        parsed[name] = Path(raw_path)
    return parsed


def load_claim_run(name: str, path: Path, pin: str | None = None) -> ClaimRun:
    if pin is not None:
        require_hash(path, pin, f"{name} claims")
    raw = read_json(path)
    if raw.get("schema") != "whatkey-claims/1":
        raise AnalysisError(f"Unexpected claims schema: {path}")
    claims = {fixture_id: data["events"] for fixture_id, data in raw["claims"].items()}
    return ClaimRun(name, path, raw["detector"], claims)


def require_named_claims(specs: list[str], pins: dict[str, str]) -> dict[str, ClaimRun]:
    paths = parse_claim_specs(specs)
    if set(paths) != set(pins):
        raise AnalysisError(
            f"Claim runs must be exactly {sorted(pins)}, got {sorted(paths)}"
        )
    return {
        name: load_claim_run(name, paths[name], pins[name]) for name in sorted(paths)
    }


def validate_claims(run: ClaimRun, fixtures: dict[str, Fixture]) -> None:
    if set(run.claims) != set(fixtures):
        missing = sorted(set(fixtures) - set(run.claims))
        extra = sorted(set(run.claims) - set(fixtures))
        raise AnalysisError(
            f"{run.name} claim/fixture mismatch: missing={missing}, extra={extra}"
        )
    for fixture_id, fixture in fixtures.items():
        if len(run.claims[fixture_id]) != len(fixture.events):
            raise AnalysisError(
                f"{run.name} has {len(run.claims[fixture_id])} claims for "
                f"{fixture_id}, expected {len(fixture.events)}"
            )


def mean_or_none(values: list[float]) -> float | None:
    return fmean(values) if values else None


def bootstrap_ci(
    values: list[float], resamples: int, seed: int | str
) -> list[float] | None:
    if not values:
        return None
    rng = random.Random(seed)
    count = len(values)
    means = sorted(
        fmean(rng.choice(values) for _ in range(count)) for _ in range(resamples)
    )
    low = means[max(0, int(0.025 * resamples) - 1)]
    high = means[min(resamples - 1, int(0.975 * resamples))]
    return [low, high]


def difference_summary(
    values: list[float], resamples: int, seed: int | str
) -> dict[str, Any]:
    return {
        "n": len(values),
        "mean": mean_or_none(values),
        "bootstrapCi95": bootstrap_ci(values, resamples, seed),
        "wins": sum(value > 1e-12 for value in values),
        "losses": sum(value < -1e-12 for value in values),
        "ties": sum(abs(value) <= 1e-12 for value in values),
    }


def score_piece(
    fixture: Fixture,
    claims: list[str | None],
    eligible: list[bool],
    truth: list[str | int | None],
    transform_claim=lambda claim: claim,
    transform_reference=lambda reference: reference,
) -> PieceScore | None:
    if not (len(fixture.events) == len(claims) == len(eligible) == len(truth)):
        raise AnalysisError(f"Event vector length mismatch: {fixture.id}")
    eligible_count = sum(eligible)
    if not eligible_count:
        return None
    claimed = 0
    correct = 0
    for use, claim, reference in zip(eligible, claims, truth, strict=True):
        if not use or claim is None:
            continue
        claimed += 1
        correct += transform_claim(claim) == transform_reference(reference)
    return PieceScore(fixture.title, eligible_count, claimed, correct)


def summarize_scores(scores: list[PieceScore]) -> dict[str, Any]:
    claims = sum(score.claims for score in scores)
    correct = sum(score.correct for score in scores)
    events = sum(score.eligible_events for score in scores)
    accuracies = [score.accuracy for score in scores if score.accuracy is not None]
    return {
        "pieces": len(scores),
        "piecesWithClaims": len(accuracies),
        "events": events,
        "claims": claims,
        "correct": correct,
        "macroCoverage": mean_or_none([score.coverage for score in scores]),
        "macroExactOnClaimed": mean_or_none(accuracies),
        "microCoverage": claims / events if events else None,
        "microExactOnClaimed": correct / claims if claims else None,
    }


def paired_score_difference(
    a_scores: dict[str, PieceScore],
    b_scores: dict[str, PieceScore],
    metric: str,
    resamples: int,
    seed: int | str,
) -> dict[str, Any]:
    shared = sorted(set(a_scores) & set(b_scores))
    values: list[float] = []
    excluded = 0
    for title in shared:
        a = getattr(a_scores[title], metric)
        b = getattr(b_scores[title], metric)
        if a is None or b is None:
            excluded += 1
            continue
        values.append(a - b)
    return {
        "direction": "paper-minus-reflex",
        "sharedPieces": len(shared),
        "excluded": excluded,
        **difference_summary(values, resamples, seed),
    }


def claim_switches(claims: list[str | None]) -> int:
    switches = 0
    previous = None
    for claim in claims:
        if claim is None:
            continue
        if previous is not None and claim != previous:
            switches += 1
        previous = claim
    return switches


def time_to_first_claim(claims: list[str | None]) -> int | None:
    return next(
        (index for index, claim in enumerate(claims) if claim is not None), None
    )


def scorable_mask(fixture: Fixture) -> list[bool]:
    return [event["labels"].get("localKey") is not None for event in fixture.events]


def local_truth(fixture: Fixture) -> list[str | None]:
    return [event["labels"].get("localKey") for event in fixture.events]


def analysis_r1(args: argparse.Namespace) -> dict[str, Any]:
    fixture_set = load_fixture_set(args.fixtures, "isophonics_manifest")
    fixtures = select_split(
        fixture_set, args.split_file, args.split, "isophonics_split"
    )
    runs = require_named_claims(
        args.claims,
        {
            "paper": "isophonics_paper_test_claims",
            "reflex": "isophonics_reflex_test_claims",
        },
    )
    for run in runs.values():
        validate_claims(run, fixtures)

    by_run: dict[str, Any] = {}
    score_maps: dict[str, dict[str, PieceScore]] = {}
    for name, run in runs.items():
        scores: dict[str, PieceScore] = {}
        for fixture_id, fixture in fixtures.items():
            score = score_piece(
                fixture,
                run.claims[fixture_id],
                scorable_mask(fixture),
                local_truth(fixture),
                transform_claim=parse_key,
                transform_reference=parse_key,
            )
            if score is not None:
                scores[fixture.title] = score
        score_maps[name] = scores
        by_run[name] = {
            "summary": summarize_scores(list(scores.values())),
            "perPiece": [scores[title].as_json() for title in sorted(scores)],
        }

    unscorable = []
    fully_unscorable = []
    for fixture_id, fixture in sorted(fixtures.items(), key=lambda item: item[1].title):
        mask = scorable_mask(fixture)
        if all(mask):
            continue
        row: dict[str, Any] = {
            "id": fixture_id,
            "title": fixture.title,
            "events": len(mask),
            "unscorableEvents": len(mask) - sum(mask),
            "runs": {},
        }
        for name, run in runs.items():
            claims = run.claims[fixture_id]
            row["runs"][name] = {
                "claimsOnUnscorableEvents": sum(
                    claim is not None
                    for use, claim in zip(mask, claims, strict=True)
                    if not use
                ),
                "allEventClaims": sum(claim is not None for claim in claims),
                "timeToFirstClaim": time_to_first_claim(claims),
                "switches": claim_switches(claims),
            }
        unscorable.append(row)
        if not any(mask):
            fully_unscorable.append(row)

    return {
        "analysis": "R1-isophonics-scorable-cohort",
        "inputSha256": {
            "fixtureManifest": PINNED_SHA256["isophonics_manifest"],
            "fixtureContent": fixture_set.content_hash,
            "split": PINNED_SHA256["isophonics_split"],
            "paperClaims": PINNED_SHA256["isophonics_paper_test_claims"],
            "reflexClaims": PINNED_SHA256["isophonics_reflex_test_claims"],
        },
        "cohort": {
            "rule": "fixture event labels.localKey is non-null",
            "selectedPieces": len(fixtures),
            "scorablePieces": len(score_maps["paper"]),
            "piecesWithAnyUnscorableEvents": len(unscorable),
            "fullyUnscorablePieces": len(fully_unscorable),
        },
        "runs": by_run,
        "paired": {
            "coverage": paired_score_difference(
                score_maps["paper"],
                score_maps["reflex"],
                "coverage",
                args.bootstrap_resamples,
                args.bootstrap_seed,
            ),
            "exactOnClaimed": paired_score_difference(
                score_maps["paper"],
                score_maps["reflex"],
                "accuracy",
                args.bootstrap_resamples,
                args.bootstrap_seed,
            ),
        },
        "piecesWithUnscorableEvents": unscorable,
        "fullyUnscorableBehavior": fully_unscorable,
    }


def segment_spans(events: list[dict[str, Any]]) -> list[int | None]:
    spans: list[int | None] = [None] * len(events)
    start = 0
    for index in range(1, len(events) + 1):
        if index < len(events) and (
            events[index]["labels"].get("localKey")
            == events[start]["labels"].get("localKey")
        ):
            continue
        measures = [
            event["labels"]["measure"]
            for event in events[start:index]
            if event["labels"].get("measure") is not None
        ]
        span = max(measures) - min(measures) + 1 if measures else None
        for position in range(start, index):
            spans[position] = span
        start = index
    return spans


def threshold_mask(fixture: Fixture, threshold: int) -> list[bool]:
    spans = segment_spans(fixture.events)
    return [
        event["labels"].get("localKey") is not None
        and (threshold == 0 or (span is not None and span >= threshold))
        for event, span in zip(fixture.events, spans, strict=True)
    ]


def analysis_r2(args: argparse.Namespace) -> dict[str, Any]:
    thresholds = tuple(int(value) for value in args.min_segment_measures.split(","))
    if thresholds != DECLARED_THRESHOLDS:
        raise AnalysisError(
            f"R2 thresholds must be {DECLARED_THRESHOLDS}, got {thresholds}"
        )
    fixture_set = load_fixture_set(args.fixtures, "overlap_manifest")
    fixtures = fixture_set.fixtures
    runs = require_named_claims(
        args.claims,
        {"paper": "overlap_paper_claims", "reflex": "overlap_reflex_claims"},
    )
    for run in runs.values():
        validate_claims(run, fixtures)

    threshold_results = []
    for threshold in thresholds:
        masks = {
            fixture_id: threshold_mask(fixture, threshold)
            for fixture_id, fixture in fixtures.items()
        }
        score_maps: dict[str, dict[str, PieceScore]] = {}
        run_results: dict[str, Any] = {}
        for name, run in runs.items():
            scores: dict[str, PieceScore] = {}
            for fixture_id, fixture in fixtures.items():
                score = score_piece(
                    fixture,
                    run.claims[fixture_id],
                    masks[fixture_id],
                    local_truth(fixture),
                    transform_claim=parse_key,
                    transform_reference=parse_key,
                )
                if score is not None:
                    scores[fixture.title] = score
            score_maps[name] = scores
            run_results[name] = {
                "summary": summarize_scores(list(scores.values())),
                "perPiece": [scores[title].as_json() for title in sorted(scores)],
            }

        common_scores: dict[str, dict[str, PieceScore]] = {
            "paper": {},
            "reflex": {},
        }
        eligible_events = 0
        common_claims = 0
        eligible_pieces = 0
        common_claim_fractions = []
        common_coverage_per_piece = []
        for fixture_id, fixture in fixtures.items():
            mask = masks[fixture_id]
            if not any(mask):
                continue
            eligible_pieces += 1
            piece_eligible_events = sum(mask)
            eligible_events += piece_eligible_events
            common_mask = [
                use and paper is not None and reflex is not None
                for use, paper, reflex in zip(
                    mask,
                    runs["paper"].claims[fixture_id],
                    runs["reflex"].claims[fixture_id],
                    strict=True,
                )
            ]
            piece_common_claims = sum(common_mask)
            common_claims += piece_common_claims
            piece_common_fraction = piece_common_claims / piece_eligible_events
            common_claim_fractions.append(piece_common_fraction)
            common_coverage_per_piece.append(
                {
                    "title": fixture.title,
                    "eligibleEvents": piece_eligible_events,
                    "commonClaims": piece_common_claims,
                    "commonClaimFraction": piece_common_fraction,
                }
            )
            for name, run in runs.items():
                score = score_piece(
                    fixture,
                    run.claims[fixture_id],
                    common_mask,
                    local_truth(fixture),
                    transform_claim=parse_key,
                    transform_reference=parse_key,
                )
                if score is not None:
                    common_scores[name][fixture.title] = score

        common_titles = sorted(
            set(common_scores["paper"]) & set(common_scores["reflex"])
        )
        common_per_piece = []
        for title in common_titles:
            paper = common_scores["paper"][title]
            reflex = common_scores["reflex"][title]
            common_per_piece.append(
                {
                    "title": title,
                    "events": paper.eligible_events,
                    "paperExact": paper.accuracy,
                    "reflexExact": reflex.accuracy,
                    "paperMinusReflex": paper.accuracy - reflex.accuracy,
                }
            )

        threshold_results.append(
            {
                "minimumSegmentMeasures": threshold,
                "eligiblePieces": eligible_pieces,
                "eligibleEvents": eligible_events,
                "runs": run_results,
                "ownClaimPaired": {
                    "coverage": paired_score_difference(
                        score_maps["paper"],
                        score_maps["reflex"],
                        "coverage",
                        args.bootstrap_resamples,
                        f"{args.bootstrap_seed}-r2-{threshold}-coverage",
                    ),
                    "exactOnClaimed": paired_score_difference(
                        score_maps["paper"],
                        score_maps["reflex"],
                        "accuracy",
                        args.bootstrap_resamples,
                        f"{args.bootstrap_seed}-r2-{threshold}-exact",
                    ),
                },
                "commonClaim": {
                    "events": common_claims,
                    "fractionOfEligibleEvents": (
                        common_claims / eligible_events if eligible_events else None
                    ),
                    "macroFractionOfEligibleEvents": mean_or_none(
                        common_claim_fractions
                    ),
                    "piecesWithCommonClaims": len(common_titles),
                    "piecesWithoutCommonClaims": eligible_pieces - len(common_titles),
                    "paperSummary": summarize_scores(
                        list(common_scores["paper"].values())
                    ),
                    "reflexSummary": summarize_scores(
                        list(common_scores["reflex"].values())
                    ),
                    "pairedExact": paired_score_difference(
                        common_scores["paper"],
                        common_scores["reflex"],
                        "accuracy",
                        args.bootstrap_resamples,
                        f"{args.bootstrap_seed}-r2-{threshold}-common",
                    ),
                    "perEligiblePieceCoverage": sorted(
                        common_coverage_per_piece, key=lambda row: row["title"]
                    ),
                    "perPieceAccuracy": common_per_piece,
                },
            }
        )
    return {
        "analysis": "R2-overlap-segments",
        "inputSha256": {
            "fixtureManifest": PINNED_SHA256["overlap_manifest"],
            "fixtureContent": fixture_set.content_hash,
            "paperClaims": PINNED_SHA256["overlap_paper_claims"],
            "reflexClaims": PINNED_SHA256["overlap_reflex_claims"],
        },
        "interpretation": "post-hoc descriptive; thresholds already inspected",
        "thresholds": threshold_results,
    }


def parse_key(key: str) -> tuple[int, str]:
    tonic, mode = key.split(":")
    if mode not in {"maj", "min"}:
        raise AnalysisError(f"Key is outside the 24-state ontology: {key}")
    pitch_class = PC_BASE[tonic[0]] + tonic.count("#") - tonic.count("b")
    return pitch_class % 12, mode


def diatonic_collection(key: str) -> int:
    pitch_class, mode = parse_key(key)
    return (pitch_class + (3 if mode == "min" else 0)) % 12


def signature_collections(
    key_signatures: dict[str, list[int | float]], timestamps_ms: list[int]
) -> list[int]:
    entries = sorted(
        (float(time), int(value[0])) for time, value in key_signatures.items()
    )
    if not entries:
        raise AnalysisError("Performance has no key-signature reference")
    times = [time for time, _ in entries]
    classes = [pitch_class for _, pitch_class in entries]
    return [
        classes[max(0, bisect.bisect_right(times, stamp / 1000) - 1)]
        for stamp in timestamps_ms
    ]


def accuracy_on_mask(
    claims: list[str | None],
    reference: list[int],
    mask: list[bool],
) -> tuple[int, int, float | None]:
    correct = 0
    count = 0
    for claim, truth, use in zip(claims, reference, mask, strict=True):
        if not use or claim is None:
            continue
        count += 1
        correct += diatonic_collection(claim) == truth
    return count, correct, correct / count if count else None


def analysis_r3(args: argparse.Namespace) -> dict[str, Any]:
    fixture_set = load_fixture_set(args.fixtures, "overlap_manifest")
    fixtures = fixture_set.fixtures
    require_hash(args.asap_annotations, "asap_annotations", "ASAP annotations")
    annotations = read_json(args.asap_annotations)
    runs = require_named_claims(
        args.claims,
        {"paper": "overlap_paper_claims", "reflex": "overlap_reflex_claims"},
    )
    for run in runs.values():
        validate_claims(run, fixtures)

    per_piece = []
    interaction_values = []
    analyst_differences = []
    signature_differences = []
    reference_agreement_values = []
    total_reference_events = 0
    total_reference_agreements = 0
    total_common_claims = 0
    common_claim_fractions = []
    common_accuracy_values = {
        "analyst": {"paper": [], "reflex": []},
        "keySignature": {"paper": [], "reflex": []},
    }
    common_correct = {
        "analyst": {"paper": 0, "reflex": 0},
        "keySignature": {"paper": 0, "reflex": 0},
    }
    secondary: dict[str, list[dict[str, Any]]] = {"paper": [], "reflex": []}

    for fixture_id, fixture in sorted(fixtures.items(), key=lambda item: item[1].title):
        annotation_key = f"{fixture.title}.mid"
        if annotation_key not in annotations:
            raise AnalysisError(f"ASAP annotations missing {annotation_key}")
        analyst = [
            diatonic_collection(reference)
            for reference in local_truth(fixture)
            if reference is not None
        ]
        if len(analyst) != len(fixture.events):
            raise AnalysisError(f"Analyst reference missing for {fixture.id}")
        signature = signature_collections(
            annotations[annotation_key]["perf_key_signatures"],
            [event["timestampMs"] for event in fixture.events],
        )
        agreement_count = sum(a == s for a, s in zip(analyst, signature, strict=True))
        reference_agreement = agreement_count / len(analyst)
        reference_agreement_values.append(reference_agreement)
        total_reference_events += len(analyst)
        total_reference_agreements += agreement_count

        common_mask = [
            paper is not None and reflex is not None
            for paper, reflex in zip(
                runs["paper"].claims[fixture_id],
                runs["reflex"].claims[fixture_id],
                strict=True,
            )
        ]
        common_count = sum(common_mask)
        total_common_claims += common_count
        common_claim_fractions.append(common_count / len(fixture.events))
        paper_a_count, paper_a_correct, paper_a = accuracy_on_mask(
            runs["paper"].claims[fixture_id], analyst, common_mask
        )
        reflex_a_count, reflex_a_correct, reflex_a = accuracy_on_mask(
            runs["reflex"].claims[fixture_id], analyst, common_mask
        )
        paper_s_count, paper_s_correct, paper_s = accuracy_on_mask(
            runs["paper"].claims[fixture_id], signature, common_mask
        )
        reflex_s_count, reflex_s_correct, reflex_s = accuracy_on_mask(
            runs["reflex"].claims[fixture_id], signature, common_mask
        )
        if {
            paper_a_count,
            reflex_a_count,
            paper_s_count,
            reflex_s_count,
        } != {common_count}:
            raise AnalysisError(f"Common-claim count mismatch for {fixture.id}")
        if None in (paper_a, reflex_a, paper_s, reflex_s):
            raise AnalysisError(f"No common claims for {fixture.id}")
        common_accuracy_values["analyst"]["paper"].append(paper_a)
        common_accuracy_values["analyst"]["reflex"].append(reflex_a)
        common_accuracy_values["keySignature"]["paper"].append(paper_s)
        common_accuracy_values["keySignature"]["reflex"].append(reflex_s)
        common_correct["analyst"]["paper"] += paper_a_correct
        common_correct["analyst"]["reflex"] += reflex_a_correct
        common_correct["keySignature"]["paper"] += paper_s_correct
        common_correct["keySignature"]["reflex"] += reflex_s_correct
        analyst_difference = paper_a - reflex_a
        signature_difference = paper_s - reflex_s
        interaction = signature_difference - analyst_difference
        analyst_differences.append(analyst_difference)
        signature_differences.append(signature_difference)
        interaction_values.append(interaction)
        per_piece.append(
            {
                "title": fixture.title,
                "events": len(fixture.events),
                "commonClaims": common_count,
                "commonClaimFraction": common_count / len(fixture.events),
                "referenceAgreement": reference_agreement,
                "analyst": {"paper": paper_a, "reflex": reflex_a},
                "keySignature": {"paper": paper_s, "reflex": reflex_s},
                "paperMinusReflexAnalyst": analyst_difference,
                "paperMinusReflexKeySignature": signature_difference,
                "interaction": interaction,
            }
        )

        for name, run in runs.items():
            own_mask = [True] * len(fixture.events)
            analyst_count, analyst_correct, analyst_accuracy = accuracy_on_mask(
                run.claims[fixture_id], analyst, own_mask
            )
            signature_count, signature_correct, signature_accuracy = accuracy_on_mask(
                run.claims[fixture_id], signature, own_mask
            )
            if analyst_count != signature_count:
                raise AnalysisError("Reference views produced different claim counts")
            secondary[name].append(
                {
                    "title": fixture.title,
                    "events": len(fixture.events),
                    "claims": analyst_count,
                    "coverage": analyst_count / len(fixture.events),
                    "analystCorrect": analyst_correct,
                    "analystAccuracy": analyst_accuracy,
                    "keySignatureCorrect": signature_correct,
                    "keySignatureAccuracy": signature_accuracy,
                }
            )

    secondary_summaries = {}
    for name, rows in secondary.items():
        claims = sum(row["claims"] for row in rows)
        events = sum(row["events"] for row in rows)
        secondary_summaries[name] = {
            "summary": {
                "pieces": len(rows),
                "events": events,
                "claims": claims,
                "macroCoverage": mean_or_none([row["coverage"] for row in rows]),
                "microCoverage": claims / events,
                "macroAnalystAccuracy": mean_or_none(
                    [
                        row["analystAccuracy"]
                        for row in rows
                        if row["analystAccuracy"] is not None
                    ]
                ),
                "microAnalystAccuracy": (
                    sum(row["analystCorrect"] for row in rows) / claims
                ),
                "macroKeySignatureAccuracy": mean_or_none(
                    [
                        row["keySignatureAccuracy"]
                        for row in rows
                        if row["keySignatureAccuracy"] is not None
                    ]
                ),
                "microKeySignatureAccuracy": (
                    sum(row["keySignatureCorrect"] for row in rows) / claims
                ),
            },
            "perPiece": rows,
        }

    return {
        "analysis": "R3-overlap-dual-reference",
        "inputSha256": {
            "fixtureManifest": PINNED_SHA256["overlap_manifest"],
            "fixtureContent": fixture_set.content_hash,
            "asapAnnotations": PINNED_SHA256["asap_annotations"],
            "paperClaims": PINNED_SHA256["overlap_paper_claims"],
            "reflexClaims": PINNED_SHA256["overlap_reflex_claims"],
        },
        "ontology": "12 diatonic collections; minor maps to relative major",
        "primary": {
            "pieces": len(per_piece),
            "events": total_reference_events,
            "commonClaims": total_common_claims,
            "commonClaimFraction": total_common_claims / total_reference_events,
            "macroCommonClaimFraction": fmean(common_claim_fractions),
            "commonClaimAccuracy": {
                reference: {
                    name: {
                        "macroMean": fmean(common_accuracy_values[reference][name]),
                        "micro": common_correct[reference][name] / total_common_claims,
                    }
                    for name in ("paper", "reflex")
                }
                for reference in ("analyst", "keySignature")
            },
            "referenceAgreement": {
                "macroMean": fmean(reference_agreement_values),
                "micro": total_reference_agreements / total_reference_events,
            },
            "paperMinusReflexAnalyst": difference_summary(
                analyst_differences,
                args.bootstrap_resamples,
                f"{args.bootstrap_seed}-r3-analyst",
            ),
            "paperMinusReflexKeySignature": difference_summary(
                signature_differences,
                args.bootstrap_resamples,
                f"{args.bootstrap_seed}-r3-signature",
            ),
            "interaction": {
                "direction": (
                    "(paper-reflex key-signature) minus (paper-reflex analyst)"
                ),
                **difference_summary(
                    interaction_values,
                    args.bootstrap_resamples,
                    f"{args.bootstrap_seed}-r3-interaction",
                ),
            },
            "perPiece": per_piece,
        },
        "secondaryOwnClaim": secondary_summaries,
        "interpretation": (
            "exploratory reference-construct sensitivity on Beethoven; not an "
            "isolated annotation-timescale test"
        ),
    }


def load_factorial_run(
    run_root: Path,
    corpus: str,
    half_life: int,
    functional: str,
    fixtures: dict[str, Fixture],
    fixture_set_name: str,
    fixture_content_hash: str,
) -> tuple[ClaimRun, dict[str, Any], dict[str, str]]:
    directory = run_root / f"grid-{corpus}-hl{half_life}-f{functional}"
    claims_path = directory / "claims.json"
    report_path = directory / "report.json"
    run = load_claim_run(f"{corpus}-hl{half_life}-f{functional}", claims_path)
    report = read_json(report_path)
    if report.get("schema") != "whatkey-harness-report/1":
        raise AnalysisError(f"Unexpected harness report schema: {report_path}")
    if report["fixtures"]["set"] != fixture_set_name:
        raise AnalysisError(f"Wrong fixture set in {report_path}")
    if report["fixtures"].get("contentSha256") != fixture_content_hash:
        raise AnalysisError(f"Wrong fixture content hash in {report_path}")
    if report.get("split", {}).get("name") != "development":
        raise AnalysisError(f"Factorial run is not development-only: {report_path}")
    if report["detector"] != run.detector:
        raise AnalysisError(f"Claims/report detector mismatch: {directory}")
    config = report["detector"]["configuration"]
    expected_fragments = (
        "selfTransition=0.9",
        "fifthsDecay=0.5",
        "modeSwitchFactor=0.5",
        "emissionTemperature=0.25",
        "minEvents=3",
        "marginFloor=0.3",
        "modeTilt=2.0",
        "relativeTilt=0.0",
        "relativeCadenceTilt=0.0",
        "relativeEvidenceTilt=0.0",
        "relativeEvidenceWindow=1",
        "cadenceBoost=0.0",
        "cadenceTriadBoost=0.0",
        "cadenceMarginFactor=1.0",
        "coldStartTonicPrior=0.0",
        "relativeSwitchFactor=1.0",
        f"functionalBlend={float(functional):.1f}",
        "progressionBlend=0.0",
        "profiles=albrechtShanahan",
        "durationWeighted=true",
        f"decayHalfLifeMs={half_life * 1000}",
        "confidenceWeighted=false",
    )
    missing = [fragment for fragment in expected_fragments if fragment not in config]
    if missing:
        raise AnalysisError(
            f"Factorial configuration mismatch in {report_path}: {missing}"
        )
    validate_claims(run, fixtures)
    return run, report, {"claims": sha256(claims_path), "report": sha256(report_path)}


def metric_effect(
    cell_scores: dict[tuple[int, str], dict[str, PieceScore]],
    metric: str,
    terms: list[tuple[float, tuple[int, str]]],
    resamples: int,
    seed: int | str,
) -> dict[str, Any]:
    titles = set.intersection(*(set(cell_scores[cell]) for _, cell in terms))
    values = []
    excluded = 0
    for title in sorted(titles):
        components = [
            (weight, getattr(cell_scores[cell][title], metric))
            for weight, cell in terms
        ]
        if any(value is None for _, value in components):
            excluded += 1
            continue
        values.append(sum(weight * value for weight, value in components))
    return {
        "coefficients": [
            {"weight": weight, "halfLifeSeconds": cell[0], "functionalBlend": cell[1]}
            for weight, cell in terms
        ],
        "candidatePieces": len(titles),
        "excluded": excluded,
        **difference_summary(values, resamples, seed),
    }


def factorial_effects(
    cell_scores: dict[tuple[int, str], dict[str, PieceScore]],
    metric: str,
    resamples: int,
    seed: int,
) -> dict[str, Any]:
    effects: dict[str, Any] = {}
    for functional in ("0", "0.1"):
        effects[f"memory30Minus1AtFunctional{functional}"] = metric_effect(
            cell_scores,
            metric,
            [(1, (30, functional)), (-1, (1, functional))],
            resamples,
            f"{seed}-{metric}-memory-{functional}",
        )
    for half_life in (1, 30):
        effects[f"functional0.1Minus0AtMemory{half_life}"] = metric_effect(
            cell_scores,
            metric,
            [(1, (half_life, "0.1")), (-1, (half_life, "0"))],
            resamples,
            f"{seed}-{metric}-functional-{half_life}",
        )
    effects["interaction"] = metric_effect(
        cell_scores,
        metric,
        [(1, (30, "0.1")), (-1, (30, "0")), (-1, (1, "0.1")), (1, (1, "0"))],
        resamples,
        f"{seed}-{metric}-interaction",
    )
    effects["paperMinusReflexPackage"] = metric_effect(
        cell_scores,
        metric,
        [(1, (30, "0")), (-1, (1, "0.1"))],
        resamples,
        f"{seed}-{metric}-package",
    )
    return effects


def analysis_r4(args: argparse.Namespace) -> dict[str, Any]:
    corpus_specs = {
        "wir": {
            "directory": args.when_in_rome_fixtures,
            "manifestPin": "when_in_rome_manifest",
            "split": REPO_ROOT / "research/whatkey/data/splits/when-in-rome-v1.json",
            "splitPin": "when_in_rome_split",
        },
        "iso": {
            "directory": args.isophonics_fixtures,
            "manifestPin": "isophonics_manifest",
            "split": REPO_ROOT / "research/whatkey/data/splits/isophonics-nc-v1.json",
            "splitPin": "isophonics_split",
        },
    }
    output: dict[str, Any] = {
        "analysis": "R4-development-factorial",
        "effectDirections": {
            "memory": "30-second minus 1-second",
            "functional": "0.1 minus 0",
            "interaction": (
                "functional effect at 30 seconds minus functional effect at 1 second"
            ),
        },
        "corpora": {},
    }
    for corpus, spec in corpus_specs.items():
        fixture_set = load_fixture_set(spec["directory"], spec["manifestPin"])
        fixtures = select_split(
            fixture_set, spec["split"], "development", spec["splitPin"]
        )
        content_hash = fixture_set.content_hash
        cell_scores: dict[tuple[int, str], dict[str, PieceScore]] = {}
        cells: dict[str, Any] = {}
        input_hashes: dict[str, Any] = {}
        for half_life in (1, 30):
            for functional in ("0", "0.1"):
                run, report, hashes = load_factorial_run(
                    args.run_root,
                    corpus,
                    half_life,
                    functional,
                    fixtures,
                    fixture_set.manifest["set"],
                    content_hash,
                )
                scores: dict[str, PieceScore] = {}
                for fixture_id, fixture in fixtures.items():
                    score = score_piece(
                        fixture,
                        run.claims[fixture_id],
                        scorable_mask(fixture),
                        local_truth(fixture),
                        transform_claim=parse_key,
                        transform_reference=parse_key,
                    )
                    if score is not None:
                        scores[fixture.title] = score
                cell = (half_life, functional)
                cell_scores[cell] = scores
                cell_name = f"hl{half_life}-f{functional}"
                cells[cell_name] = {
                    "halfLifeSeconds": half_life,
                    "functionalBlend": float(functional),
                    "primary": summarize_scores(list(scores.values())),
                    "secondaryHarnessSummary": report["summary"],
                    "perPiece": [scores[title].as_json() for title in sorted(scores)],
                }
                input_hashes[cell_name] = hashes
        output["corpora"][corpus] = {
            "fixtures": fixture_set.manifest["set"],
            "inputSha256": {
                "fixtureManifest": PINNED_SHA256[spec["manifestPin"]],
                "fixtureContent": fixture_set.content_hash,
                "split": PINNED_SHA256[spec["splitPin"]],
            },
            "selectedPieces": len(fixtures),
            "scorablePieces": len(cell_scores[(1, "0")]),
            "cells": cells,
            "effects": {
                "coverage": factorial_effects(
                    cell_scores,
                    "coverage",
                    args.bootstrap_resamples,
                    args.bootstrap_seed,
                ),
                "exactOnClaimed": factorial_effects(
                    cell_scores,
                    "accuracy",
                    args.bootstrap_resamples,
                    args.bootstrap_seed,
                ),
            },
            "runInputSha256": input_hashes,
        }
    return output


def validate_frozen_inputs() -> dict[str, int]:
    """Validate every predeclared frozen input without calculating an endpoint."""
    isophonics = load_fixture_set(
        REPO_ROOT / "build/whatkey-fixtures/isophonics-nc-v1",
        "isophonics_manifest",
    )
    isophonics_test = select_split(
        isophonics,
        REPO_ROOT / "research/whatkey/data/splits/isophonics-nc-v1.json",
        "test",
        "isophonics_split",
    )
    for name, path, pin in (
        (
            "paper",
            REPO_ROOT / "research/whatkey/results/test-split-2026-07-07/"
            "test-iso-hmm-shipped/claims.json",
            "isophonics_paper_test_claims",
        ),
        (
            "reflex",
            REPO_ROOT / "research/whatkey/results/test-split-2026-07-07/"
            "test-iso-hmm-reflex/claims.json",
            "isophonics_reflex_test_claims",
        ),
    ):
        validate_claims(load_claim_run(name, path, pin), isophonics_test)

    overlap = load_fixture_set(
        REPO_ROOT / "build/whatkey-fixtures/asap-wir-nc-v2", "overlap_manifest"
    )
    for name, path, pin in (
        (
            "paper",
            REPO_ROOT / "build/whatkey-harness/asap-wir-v2pw-paper/claims.json",
            "overlap_paper_claims",
        ),
        (
            "reflex",
            REPO_ROOT / "build/whatkey-harness/asap-wir-v2pw-reflex/claims.json",
            "overlap_reflex_claims",
        ),
    ):
        validate_claims(load_claim_run(name, path, pin), overlap.fixtures)
    require_hash(
        REPO_ROOT / "build/whatkey-corpora/asap-dataset/asap_annotations.json",
        "asap_annotations",
        "ASAP annotations",
    )

    when_in_rome = load_fixture_set(
        REPO_ROOT / "research/whatkey/data/fixtures/when-in-rome-v1",
        "when_in_rome_manifest",
    )
    when_in_rome_development = select_split(
        when_in_rome,
        REPO_ROOT / "research/whatkey/data/splits/when-in-rome-v1.json",
        "development",
        "when_in_rome_split",
    )
    return {
        "isophonicsFixtures": len(isophonics.fixtures),
        "isophonicsTestClaims": len(isophonics_test),
        "overlapFixturesAndClaims": len(overlap.fixtures),
        "whenInRomeDevelopmentFixtures": len(when_in_rome_development),
    }


def git_output(*arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        capture_output=True,
        check=True,
        text=True,
    ).stdout.strip()


def output_metadata(args: argparse.Namespace) -> dict[str, Any]:
    return {
        "schema": OUTPUT_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(
            ["python3", "tool/whatkey/revision_reanalysis.py", *sys.argv[1:]]
        ),
        "repositoryCommit": git_output("rev-parse", "HEAD"),
        "repositoryDirty": bool(git_output("status", "--porcelain")),
        "declaration": "research/whatkey/log/2026-08-01-01-revision-reanalysis-predeclaration.md",
        "bootstrap": {
            "seed": args.bootstrap_seed,
            "resamples": args.bootstrap_resamples,
        },
    }


def validate_common_args(args: argparse.Namespace) -> None:
    if args.bootstrap_seed != DECLARED_SEED:
        raise AnalysisError(
            f"Bootstrap seed must remain {DECLARED_SEED}, got {args.bootstrap_seed}"
        )
    if args.bootstrap_resamples != DECLARED_RESAMPLES:
        raise AnalysisError(
            f"Bootstrap resamples must remain {DECLARED_RESAMPLES}, "
            f"got {args.bootstrap_resamples}"
        )
    output = args.out.resolve()
    research = (REPO_ROOT / "research").resolve()
    if output == research or research in output.parents:
        raise AnalysisError(
            "License-gated revision results must not be written under research/"
        )


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--bootstrap-seed", type=int, required=True)
    parser.add_argument("--bootstrap-resamples", type=int, required=True)
    parser.add_argument("--out", type=Path, required=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("validate-frozen-inputs")

    r1 = subparsers.add_parser("isophonics-cohort")
    r1.add_argument("--fixtures", type=Path, required=True)
    r1.add_argument("--split-file", type=Path, required=True)
    r1.add_argument("--split", choices=("test",), required=True)
    r1.add_argument("--claims", action="append", required=True)
    add_common_arguments(r1)
    r1.set_defaults(run=analysis_r1)

    r2 = subparsers.add_parser("overlap-segments")
    r2.add_argument("--fixtures", type=Path, required=True)
    r2.add_argument("--claims", action="append", required=True)
    r2.add_argument("--min-segment-measures", required=True)
    add_common_arguments(r2)
    r2.set_defaults(run=analysis_r2)

    r3 = subparsers.add_parser("dual-reference")
    r3.add_argument("--fixtures", type=Path, required=True)
    r3.add_argument("--asap-annotations", type=Path, required=True)
    r3.add_argument("--claims", action="append", required=True)
    add_common_arguments(r3)
    r3.set_defaults(run=analysis_r3)

    r4 = subparsers.add_parser("factorial")
    r4.add_argument("--when-in-rome-fixtures", type=Path, required=True)
    r4.add_argument("--isophonics-fixtures", type=Path, required=True)
    r4.add_argument("--run-root", type=Path, required=True)
    add_common_arguments(r4)
    r4.set_defaults(run=analysis_r4)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "validate-frozen-inputs":
        try:
            validated = validate_frozen_inputs()
        except AnalysisError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
        print(json.dumps(validated, indent=2, sort_keys=True))
        return 0
    try:
        validate_common_args(args)
        result = {**output_metadata(args), **args.run(args)}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    except AnalysisError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    print(f"{result['analysis']} -> {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

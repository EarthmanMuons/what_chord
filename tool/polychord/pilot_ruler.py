#!/usr/bin/env python3
"""Validate the draft polychord pilot ruler's structural invariants."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from pathlib import Path

SCHEMA = "polychord-pilot-ruler/1"
REVIEW_SCHEMA = "polychord-pilot-review/1"
TAGS = {"positive", "boundary", "negative-guard"}
REVIEW_TAGS = {*TAGS, "abstain"}
ELIGIBILITY = {
    "eligible",
    "ambiguous",
    "ineligible",
    "research-candidate",
    "unknown",
}
INPUTS = {
    "adjacentRegisterSnapshot",
    "pitchRegisterSnapshot",
    "timestampedEventStream",
}
OBSERVATION_KINDS = {"snapshot", "event-window"}
CONFIDENCE = {"low", "medium", "high"}
REVIEW_ORDER_SEED = "polychord-pilot-v0-independent-review"
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GUIDE = ROOT / "research/polychord/pilot-annotation.md"


def require_assertions() -> None:
    if not __debug__:
        raise RuntimeError("pilot validation cannot run with Python -O")


def validate(payload: dict) -> None:
    require_assertions()
    assert payload["schema"] == SCHEMA
    assert payload["status"] == "draft-pilot"
    assert payload["scoringAllowed"] is False

    cases = payload["cases"]
    ids = [case["id"] for case in cases]
    assert len(ids) == len(set(ids)), "case ids must be unique"

    for case in cases:
        assert case["tag"] in TAGS, case["id"]
        assert case["independentReview"] == "pending", case["id"]
        assert set(case["inputEligibility"]) == INPUTS, case["id"]
        for judgment in case["inputEligibility"].values():
            assert judgment["status"] in ELIGIBILITY, case["id"]
            assert judgment["reason"], case["id"]

        observation = case["observation"]
        notes = observation.get("midiNotes")
        if notes is not None:
            assert notes == sorted(set(notes)), case["id"]
            for note in notes:
                assert 0 <= note <= 127, case["id"]

        layer_notes = [
            note for layer in case["layers"] for note in layer.get("midiNotes", [])
        ]
        if notes is not None and layer_notes:
            assert sorted(set(layer_notes)) == notes, case["id"]

        layer_pc_sets = [
            set(layer["pitchClasses"])
            for layer in case["layers"]
            if "pitchClasses" in layer
        ]
        shared = set()
        for index, left in enumerate(layer_pc_sets):
            for right in layer_pc_sets[index + 1 :]:
                shared.update(left & right)
        assert case["sharedPitchClasses"] == sorted(shared), case["id"]

        provenance = case["provenance"]
        if provenance["kind"] == "score":
            for field in ("sourceUrl", "sourceIdentifier", "sha256", "scoreLocation"):
                assert provenance[field], f"{case['id']}: missing {field}"
        else:
            assert provenance["kind"] == "synthetic", case["id"]
            assert provenance["generation"], case["id"]


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ordered_review_cases(payload: dict) -> list[dict]:
    def blind_order(case: dict) -> str:
        material = f"{REVIEW_ORDER_SEED}\0{case['id']}".encode()
        return hashlib.sha256(material).hexdigest()

    return sorted(payload["cases"], key=blind_order)


def blank_response() -> dict:
    return {
        "observationKind": None,
        "constructionTag": None,
        "layers": [],
        "sharedPitchClasses": [],
        "unassignedMidiNotes": [],
        "singleChordAlternatives": [],
        "inputEligibility": {
            input_name: {"status": None, "reason": ""} for input_name in sorted(INPUTS)
        },
        "confidence": None,
        "notes": "",
    }


def blinded_evidence(case: dict) -> dict:
    provenance = case["provenance"]
    if provenance["kind"] == "score":
        return {
            "kind": "score-source",
            "source": {
                field: provenance[field]
                for field in (
                    "work",
                    "edition",
                    "sourceUrl",
                    "sourceIdentifier",
                    "sha256",
                    "scoreLocation",
                )
            },
        }

    observation = case["observation"]
    return {
        "kind": "synthetic-midi",
        **{
            field: observation[field]
            for field in ("midiNotes", "onsetCohortsMs")
            if field in observation
        },
    }


def build_review_packet(
    payload: dict,
    *,
    ruler_sha256: str,
    guide_sha256: str,
) -> dict:
    validate(payload)
    cases = [
        {
            "reviewId": f"case-{index:03d}",
            "evidence": blinded_evidence(case),
            "response": blank_response(),
        }
        for index, case in enumerate(ordered_review_cases(payload), start=1)
    ]
    return {
        "schema": REVIEW_SCHEMA,
        "status": "template",
        "sourceRuler": {"schema": SCHEMA, "sha256": ruler_sha256},
        "annotationGuide": {
            "path": "research/polychord/pilot-annotation.md",
            "sha256": guide_sha256,
        },
        "blinding": {
            "caseIds": "neutral",
            "caseOrder": "deterministically shuffled",
            "initialLabelsAndRationales": "omitted",
            "syntheticGenerationIntent": "omitted",
        },
        "reviewMetadata": {"annotatorId": None, "completedOn": None},
        "cases": cases,
    }


def validate_review_packet(
    packet: dict,
    payload: dict,
    *,
    ruler_sha256: str,
    guide_sha256: str,
) -> None:
    require_assertions()
    expected = build_review_packet(
        payload,
        ruler_sha256=ruler_sha256,
        guide_sha256=guide_sha256,
    )
    assert set(packet) == set(expected)
    assert packet["schema"] == REVIEW_SCHEMA
    assert packet["status"] in {"template", "complete"}
    assert packet["sourceRuler"] == expected["sourceRuler"]
    assert packet["annotationGuide"] == expected["annotationGuide"]
    assert packet["blinding"] == expected["blinding"]
    assert len(packet["cases"]) == len(expected["cases"])

    original_ids = {case["id"] for case in payload["cases"]}
    serialized = json.dumps(packet["cases"], sort_keys=True)
    assert not any(case_id in serialized for case_id in original_ids)

    for case, expected_case in zip(packet["cases"], expected["cases"], strict=True):
        assert set(case) == {"reviewId", "evidence", "response"}
        assert case["reviewId"] == expected_case["reviewId"]
        assert case["evidence"] == expected_case["evidence"]
        validate_response(
            case["response"],
            evidence=case["evidence"],
            complete=packet["status"] == "complete",
        )

    metadata = packet["reviewMetadata"]
    assert set(metadata) == {"annotatorId", "completedOn"}
    if packet["status"] == "template":
        assert metadata == {"annotatorId": None, "completedOn": None}
    else:
        assert isinstance(metadata["annotatorId"], str) and metadata["annotatorId"]
        assert isinstance(metadata["completedOn"], str) and metadata["completedOn"]
        date.fromisoformat(metadata["completedOn"])


def validate_int_set(values: list, *, maximum: int) -> None:
    assert isinstance(values, list)
    assert values == sorted(set(values))
    assert all(isinstance(value, int) and 0 <= value <= maximum for value in values)


def validate_response(response: dict, *, evidence: dict, complete: bool) -> None:
    assert set(response) == set(blank_response())
    assert set(response["inputEligibility"]) == INPUTS

    if not complete:
        assert response == blank_response()
        return

    assert response["observationKind"] in OBSERVATION_KINDS
    assert response["constructionTag"] in REVIEW_TAGS
    assert response["confidence"] in CONFIDENCE
    assert isinstance(response["notes"], str)
    validate_int_set(response["sharedPitchClasses"], maximum=11)
    validate_int_set(response["unassignedMidiNotes"], maximum=127)

    tag = response["constructionTag"]
    layers = response["layers"]
    if tag in {"positive", "boundary"}:
        assert len(layers) >= 2
    elif tag == "negative-guard":
        assert len(layers) <= 1

    assigned_notes = []
    layer_pc_sets = []
    for layer in layers:
        if "midiNotes" in evidence:
            assert set(layer) == {"identity", "midiNotes", "pitchClasses"}
        else:
            assert set(layer) == {"identity", "pitchClasses"}
        assert isinstance(layer["identity"], str) and layer["identity"]
        validate_int_set(layer["pitchClasses"], maximum=11)
        assert layer["pitchClasses"], "layers must contain at least one pitch class"
        layer_pc_sets.append(set(layer["pitchClasses"]))
        if "midiNotes" in layer:
            validate_int_set(layer["midiNotes"], maximum=127)
            assert layer["midiNotes"], "synthetic layers must contain a MIDI note"
            assert layer["pitchClasses"] == sorted(
                {note % 12 for note in layer["midiNotes"]}
            )
            assigned_notes.extend(layer["midiNotes"])

    shared = set()
    for index, left in enumerate(layer_pc_sets):
        for right in layer_pc_sets[index + 1 :]:
            shared.update(left & right)
    assert response["sharedPitchClasses"] == sorted(shared)

    if "midiNotes" in evidence:
        assert len(assigned_notes) == len(set(assigned_notes))
        accounted = sorted(assigned_notes + response["unassignedMidiNotes"])
        assert accounted == evidence["midiNotes"]
    else:
        assert response["unassignedMidiNotes"] == []

    assert all(
        isinstance(alternative, str) and alternative
        for alternative in response["singleChordAlternatives"]
    )
    for judgment in response["inputEligibility"].values():
        assert judgment["status"] in ELIGIBILITY
        assert isinstance(judgment["reason"], str) and judgment["reason"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ruler", type=Path)
    parser.add_argument("--guide", type=Path, default=DEFAULT_GUIDE)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--review-packet-out", type=Path)
    action.add_argument("--validate-review", type=Path)
    args = parser.parse_args()
    payload = json.loads(args.ruler.read_text())
    validate(payload)

    ruler_sha256 = sha256_file(args.ruler)
    guide_sha256 = sha256_file(args.guide)
    if args.review_packet_out:
        packet = build_review_packet(
            payload,
            ruler_sha256=ruler_sha256,
            guide_sha256=guide_sha256,
        )
        rendered = json.dumps(packet, indent=2) + "\n"
        if args.review_packet_out.exists():
            assert json.loads(args.review_packet_out.read_text()) == packet
            print(f"unchanged: {args.review_packet_out}")
        else:
            args.review_packet_out.write_text(rendered)
            print(f"wrote: {args.review_packet_out}")
    elif args.validate_review:
        packet = json.loads(args.validate_review.read_text())
        validate_review_packet(
            packet,
            payload,
            ruler_sha256=ruler_sha256,
            guide_sha256=guide_sha256,
        )
        print(f"valid: {args.validate_review}")
    else:
        print(f"valid: {args.ruler}")


if __name__ == "__main__":
    main()

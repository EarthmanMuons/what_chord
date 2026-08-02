#!/usr/bin/env python3
"""Validate the draft polychord pilot ruler's structural invariants."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

SCHEMA = "polychord-pilot-ruler/1"
TAGS = {"positive", "boundary", "negative-guard"}
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


def validate(payload: dict) -> None:
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ruler", type=Path)
    args = parser.parse_args()
    validate(json.loads(args.ruler.read_text()))
    print(f"valid: {args.ruler}")


if __name__ == "__main__":
    main()

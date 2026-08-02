#!/usr/bin/env python3
"""Report pre-adjudication agreement for a completed polychord pilot review."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shlex
import sys
from functools import cache
from pathlib import Path

import pilot_ruler

REPORT_SCHEMA = "polychord-pilot-agreement/1"


def categorical_summary(pairs: list[tuple[str, str]]) -> dict:
    confusion: dict[str, dict[str, int]] = {}
    agreements = 0
    for initial, independent in pairs:
        confusion.setdefault(initial, {})
        confusion[initial][independent] = confusion[initial].get(independent, 0) + 1
        agreements += initial == independent
    total = len(pairs)
    return {
        "agreements": agreements,
        "total": total,
        "rate": agreements / total if total else None,
        "confusion": {
            initial: dict(sorted(row.items()))
            for initial, row in sorted(confusion.items())
        },
    }


def normalized_sets(layers: list[dict], field: str) -> tuple[tuple[int, ...], ...]:
    return tuple(sorted(tuple(layer.get(field, [])) for layer in layers))


def normalized_identity_text(
    layers: list[dict],
) -> tuple[tuple[str, tuple[int, ...]], ...]:
    return tuple(
        sorted((layer["identity"], tuple(layer["pitchClasses"])) for layer in layers)
    )


def set_jaccard(left: frozenset[int], right: frozenset[int]) -> float:
    if not left and not right:
        return 0.0
    return len(left & right) / len(left | right)


def best_layer_jaccard(
    initial: list[dict], independent: list[dict], field: str
) -> float:
    left = [frozenset(layer.get(field, [])) for layer in initial]
    right = [frozenset(layer.get(field, [])) for layer in independent]
    size = max(len(left), len(right))
    if size == 0:
        return 1.0
    left.extend([frozenset()] * (size - len(left)))
    right.extend([frozenset()] * (size - len(right)))

    @cache
    def best(index: int, used_mask: int) -> float:
        if index == size:
            return 0.0
        return max(
            set_jaccard(left[index], right[target])
            + best(index + 1, used_mask | (1 << target))
            for target in range(size)
            if not used_mask & (1 << target)
        )

    return best(0, 0) / size


def note_partition(layers: list[dict], unassigned: list[int]) -> dict:
    return {
        "layers": normalized_sets(layers, "midiNotes"),
        "unassigned": tuple(unassigned),
    }


def agreement_report(
    ruler: dict,
    review: dict,
    *,
    ruler_sha256: str,
    guide_sha256: str,
    review_sha256: str,
    tool_sha256: str,
    generating_command: str,
    working_directory: str,
    python_version: str,
) -> dict:
    pilot_ruler.validate_review_packet(
        review,
        ruler,
        ruler_sha256=ruler_sha256,
        guide_sha256=guide_sha256,
    )
    assert review["status"] == "complete"

    initial_cases = pilot_ruler.ordered_review_cases(ruler)
    review_cases = review["cases"]
    construction_pairs = []
    observation_pairs = []
    eligibility_pairs = {input_name: [] for input_name in pilot_ruler.INPUTS}
    case_results = []

    for initial, independent in zip(initial_cases, review_cases, strict=True):
        response = independent["response"]
        construction_pairs.append((initial["tag"], response["constructionTag"]))
        observation_pairs.append(
            (initial["observation"]["kind"], response["observationKind"])
        )
        for input_name in pilot_ruler.INPUTS:
            eligibility_pairs[input_name].append(
                (
                    initial["inputEligibility"][input_name]["status"],
                    response["inputEligibility"][input_name]["status"],
                )
            )

        initial_layer_pcs = normalized_sets(initial["layers"], "pitchClasses")
        independent_layer_pcs = normalized_sets(response["layers"], "pitchClasses")
        layer_exact = initial_layer_pcs == independent_layer_pcs
        identity_text_exact = normalized_identity_text(
            initial["layers"]
        ) == normalized_identity_text(response["layers"])
        layer_jaccard = best_layer_jaccard(
            initial["layers"], response["layers"], "pitchClasses"
        )
        shared_exact = initial["sharedPitchClasses"] == response["sharedPitchClasses"]

        note_partition_exact = None
        if "midiNotes" in independent["evidence"]:
            observed = set(independent["evidence"]["midiNotes"])
            initial_assigned = {
                note
                for layer in initial["layers"]
                for note in layer.get("midiNotes", [])
            }
            initial_unassigned = sorted(observed - initial_assigned)
            note_partition_exact = note_partition(
                initial["layers"], initial_unassigned
            ) == note_partition(response["layers"], response["unassignedMidiNotes"])

        case_results.append(
            {
                "reviewId": independent["reviewId"],
                "initialCaseId": initial["id"],
                "constructionTagExact": initial["tag"] == response["constructionTag"],
                "observationKindExact": initial["observation"]["kind"]
                == response["observationKind"],
                "layerPitchClassesExact": layer_exact,
                "layerIdentityTextExact": identity_text_exact,
                "layerPitchClassesBestMatchJaccard": layer_jaccard,
                "sharedPitchClassesExact": shared_exact,
                "syntheticNotePartitionExact": note_partition_exact,
                "inputEligibilityExact": {
                    input_name: initial["inputEligibility"][input_name]["status"]
                    == response["inputEligibility"][input_name]["status"]
                    for input_name in sorted(pilot_ruler.INPUTS)
                },
            }
        )

    synthetic_results = [
        result
        for result in case_results
        if result["syntheticNotePartitionExact"] is not None
    ]
    return {
        "schema": REPORT_SCHEMA,
        "status": "pre-adjudication",
        "sources": {
            "rulerSha256": ruler_sha256,
            "guideSha256": guide_sha256,
            "reviewSha256": review_sha256,
            "toolSha256": tool_sha256,
            "annotatorId": review["reviewMetadata"]["annotatorId"],
            "completedOn": review["reviewMetadata"]["completedOn"],
            "generatingCommand": generating_command,
            "workingDirectory": working_directory,
            "pythonVersion": python_version,
        },
        "method": {
            "constructionAndObservation": "raw exact agreement and confusion tables",
            "inputEligibility": "raw exact agreement per input and confusion tables",
            "layers": "order-invariant exact pitch-class sets and maximum-matched Jaccard",
            "identityText": "unnormalized exact diagnostic only; not a reliability metric",
            "syntheticNotes": "order-invariant exact layer partition including unassigned notes",
            "inference": "none; six pilot cases do not support a reliability claim",
            "adjudication": "excluded",
        },
        "constructionTag": {
            **categorical_summary(construction_pairs),
            "reviewerAbstentions": sum(
                independent == "abstain" for _, independent in construction_pairs
            ),
        },
        "observationKind": categorical_summary(observation_pairs),
        "inputEligibility": {
            input_name: categorical_summary(eligibility_pairs[input_name])
            for input_name in sorted(pilot_ruler.INPUTS)
        },
        "layerPitchClasses": {
            "exactAgreements": sum(
                result["layerPitchClassesExact"] for result in case_results
            ),
            "total": len(case_results),
            "meanBestMatchJaccard": sum(
                result["layerPitchClassesBestMatchJaccard"] for result in case_results
            )
            / len(case_results),
            "sharedPitchClassAgreements": sum(
                result["sharedPitchClassesExact"] for result in case_results
            ),
            "sharedPitchClassTotal": len(case_results),
            "identityTextExactAgreements": sum(
                result["layerIdentityTextExact"] for result in case_results
            ),
            "identityTextTotal": len(case_results),
        },
        "syntheticNotePartitions": {
            "exactAgreements": sum(
                result["syntheticNotePartitionExact"] for result in synthetic_results
            ),
            "total": len(synthetic_results),
        },
        "caseResults": case_results,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ruler", type=Path)
    parser.add_argument("review", type=Path)
    parser.add_argument("--guide", type=Path, default=pilot_ruler.DEFAULT_GUIDE)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    ruler = json.loads(args.ruler.read_text())
    review = json.loads(args.review.read_text())
    report = agreement_report(
        ruler,
        review,
        ruler_sha256=pilot_ruler.sha256_file(args.ruler),
        guide_sha256=pilot_ruler.sha256_file(args.guide),
        review_sha256=hashlib.sha256(args.review.read_bytes()).hexdigest(),
        tool_sha256=pilot_ruler.sha256_file(Path(__file__)),
        generating_command=shlex.join(["python3", *sys.argv]),
        working_directory=str(Path.cwd()),
        python_version=platform.python_version(),
    )
    rendered = json.dumps(report, indent=2) + "\n"
    if args.out.exists():
        assert json.loads(args.out.read_text()) == report
        print(f"unchanged: {args.out}")
    else:
        args.out.write_text(rendered)
        print(f"wrote: {args.out}")


if __name__ == "__main__":
    main()

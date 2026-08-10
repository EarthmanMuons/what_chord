"""Apply the fixed conservative onset-support ablation to candidates.

This research profile emits one-sided supporting evidence only. It does not
reject candidates, rank them, or decide whether they should be displayed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import onset_evidence

OUTPUT_SCHEMA = "polychord-onset-support/1"
ABLATION_ID = "coherent-separated-onsets-50-200ms/1"
WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS = 50
BETWEEN_LAYER_SEPARATION_MINIMUM_MS = 200


def interpretation_parameters() -> dict:
    """Return the immutable parameters named by this ablation."""

    return {
        "withinLayerCohortSpanMaximumMs": WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS,
        "betweenLayerSeparationMinimumMs": BETWEEN_LAYER_SEPARATION_MINIMUM_MS,
    }


def onset_interval_order_and_gap(lower: dict, upper: dict) -> tuple[str, int]:
    """Return the orientation-neutral order and distance of two known intervals."""

    lower_earliest = lower["earliestKnownOnsetMs"]
    lower_latest = lower["latestKnownOnsetMs"]
    upper_earliest = upper["earliestKnownOnsetMs"]
    upper_latest = upper["latestKnownOnsetMs"]

    if lower_latest < upper_earliest:
        return "lower-then-upper", upper_earliest - lower_latest
    if upper_latest < lower_earliest:
        return "upper-then-lower", lower_earliest - upper_latest
    return "overlapping", 0


def interpret_onset_evidence(evidence: dict) -> dict:
    """Interpret one raw evidence record without producing negative evidence."""

    if not evidence["allCandidateOnsetsKnown"]:
        return {
            "availability": "incomplete",
            "lowerWithinCohortSpanMaximum": None,
            "upperWithinCohortSpanMaximum": None,
            "layerOnsetOrder": None,
            "betweenLayerOnsetIntervalGapMs": None,
            "onsetCohortSupport": "neutral",
            "reasonCodes": ["onset-history-incomplete"],
        }

    lower = evidence["lower"]
    upper = evidence["upper"]
    lower_coherent = lower["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    upper_coherent = upper["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    layer_order, separation = onset_interval_order_and_gap(lower, upper)

    reasons = []
    if not lower_coherent:
        reasons.append("lower-span-exceeds-maximum")
    if not upper_coherent:
        reasons.append("upper-span-exceeds-maximum")
    if separation < BETWEEN_LAYER_SEPARATION_MINIMUM_MS:
        reasons.append("between-layer-separation-below-minimum")

    supports = not reasons
    return {
        "availability": "complete",
        "lowerWithinCohortSpanMaximum": lower_coherent,
        "upperWithinCohortSpanMaximum": upper_coherent,
        "layerOnsetOrder": layer_order,
        "betweenLayerOnsetIntervalGapMs": separation,
        "onsetCohortSupport": "positive" if supports else "neutral",
        "reasonCodes": (["separate-coherent-onset-cohorts"] if supports else reasons),
    }


def support_document(fixture_path: Path, after_event_index: int) -> dict:
    """Build the fixed onset-support ablation output for one replay frame."""

    source = onset_evidence.evidence_document(fixture_path, after_event_index)
    interpreted = []
    for item in source["candidateEvidence"]:
        interpreted.append(
            {
                "candidate": item["candidate"],
                "onsetEvidence": item["onsetEvidence"],
                "onsetInterpretation": interpret_onset_evidence(item["onsetEvidence"]),
            }
        )
    return {
        "schema": OUTPUT_SCHEMA,
        "ablationId": ABLATION_ID,
        "parameters": interpretation_parameters(),
        "sourceEvidenceSchema": source["schema"],
        "fixtureId": source["fixtureId"],
        "fixtureSha256": source["fixtureSha256"],
        "observationFrame": source["observationFrame"],
        "candidateInterpretations": interpreted,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--after-event-index", type=int, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    document = support_document(args.fixture, args.after_event_index)
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

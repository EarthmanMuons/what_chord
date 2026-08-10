"""Apply the fixed rigid-layer motion-support ablation to transitions.

This research profile recognizes exact set translations within candidate layers
and emits one-sided support only for oblique or contrary translation between the
layers. It does not infer monophonic voices, reject candidates, rank them, or
decide whether they should be displayed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import transition_evidence

OUTPUT_SCHEMA = "polychord-motion-support/1"
ABLATION_ID = "rigid-layers-oblique-or-contrary/1"
SUPPORTING_MOTION_CLASSES = ("oblique", "contrary")


def interpretation_parameters() -> dict:
    """Return the immutable policies named by this ablation."""

    return {
        "withinLayerTransform": "exact-midi-set-translation",
        "betweenLayerSupportClasses": list(SUPPORTING_MOTION_CLASSES),
        "retainedInstanceContradictionPolicy": "neutral",
        "nonRigidOrCardinalityChangePolicy": "neutral",
    }


def exact_layer_translation(relation: dict) -> dict:
    """Describe whether one source layer is an exact translated target set."""

    source_notes = relation["sourceMidiNotes"]
    target_notes = relation["targetMidiNotes"]
    same_cardinality = len(source_notes) == len(target_notes)
    delta = target_notes[0] - source_notes[0] if same_cardinality else None
    exact_translation = same_cardinality and target_notes == [
        note + delta for note in source_notes
    ]
    identity_consistent = (
        relation["sameQuality"]
        and relation["targetRootPc"] == (relation["sourceRootPc"] + delta) % 12
        if exact_translation
        else None
    )
    return {
        "relationId": relation["id"],
        "sourceLayer": relation["sourceLayer"],
        "targetLayer": relation["targetLayer"],
        "sourceMidiNotes": source_notes,
        "targetMidiNotes": target_notes,
        "sameCardinality": same_cardinality,
        "exactMidiSetTranslation": exact_translation,
        "translationSemitones": delta if exact_translation else None,
        "chordIdentityFollowsTranslation": identity_consistent,
    }


def retained_instance_evidence(hypothesis: dict) -> str:
    """Classify exact continuity relative to one correspondence hypothesis."""

    if hypothesis["retainedInstanceCountOutsideRelations"]:
        return "contradictory"
    if hypothesis["retainedInstanceCountFollowingRelations"]:
        return "consistent"
    return "none"


def between_layer_motion_class(
    lower_translation: int,
    upper_translation: int,
) -> str:
    """Classify two exact signed layer translations without thresholds."""

    if lower_translation == 0 and upper_translation == 0:
        return "static"
    if lower_translation == upper_translation:
        return "common-translation"
    if lower_translation == 0 or upper_translation == 0:
        return "oblique"
    if (lower_translation < 0 < upper_translation) or (
        upper_translation < 0 < lower_translation
    ):
        return "contrary"
    return "unequal-similar-direction"


def interpret_hypothesis(transition: dict, hypothesis: dict) -> dict:
    """Interpret one explicit layer-correspondence hypothesis."""

    relations_by_id = {
        relation["id"]: relation for relation in transition["layerRelations"]
    }
    translations = [
        exact_layer_translation(relations_by_id[relation_id])
        for relation_id in hypothesis["relationIds"]
    ]
    translations_by_source_layer = {
        translation["sourceLayer"]: translation for translation in translations
    }
    both_exact = all(
        translation["exactMidiSetTranslation"]
        and translation["chordIdentityFollowsTranslation"]
        for translation in translations
    )
    motion_class = None
    if both_exact:
        motion_class = between_layer_motion_class(
            translations_by_source_layer["lower"]["translationSemitones"],
            translations_by_source_layer["upper"]["translationSemitones"],
        )

    continuity = retained_instance_evidence(hypothesis)
    reasons = []
    if continuity == "contradictory":
        reasons.append("retained-instance-contradicts-correspondence")
    for translation in translations:
        if not translation["exactMidiSetTranslation"]:
            reasons.append(
                f"{translation['relationId']}-not-exact-midi-set-translation"
            )
        elif not translation["chordIdentityFollowsTranslation"]:
            reasons.append(
                f"{translation['relationId']}-chord-identity-does-not-follow-translation"
            )

    positive = not reasons and motion_class in SUPPORTING_MOTION_CLASSES
    if not reasons:
        if positive:
            reasons.append(f"rigid-layer-translations-{motion_class}")
        elif motion_class == "static":
            reasons.append("both-layer-translations-static")
        elif motion_class == "common-translation":
            reasons.append("whole-sonority-common-translation")
        elif motion_class == "unequal-similar-direction":
            reasons.append("layer-translations-unequal-similar-direction")

    return {
        "hypothesisId": hypothesis["id"],
        "relationIds": hypothesis["relationIds"],
        "retainedInstanceEvidence": continuity,
        "layerTranslations": translations,
        "bothLayersExactTranslations": both_exact,
        "betweenLayerMotionClass": motion_class,
        "motionSupport": "positive" if positive else "neutral",
        "reasonCodes": reasons,
    }


def interpret_transition(transition: dict) -> dict:
    """Interpret every unranked correspondence for one candidate pair."""

    return {
        "sourceCandidateIndex": transition["sourceCandidateIndex"],
        "targetCandidateIndex": transition["targetCandidateIndex"],
        "transitionEvidence": transition,
        "hypothesisInterpretations": [
            interpret_hypothesis(transition, hypothesis)
            for hypothesis in transition["layerCorrespondenceHypotheses"]
        ],
    }


def support_document(
    fixture_path: Path,
    from_after_event_index: int,
    to_after_event_index: int,
) -> dict:
    """Build the fixed motion-support output for one selected frame window."""

    source = transition_evidence.evidence_document(
        fixture_path,
        from_after_event_index,
        to_after_event_index,
    )
    return {
        "schema": OUTPUT_SCHEMA,
        "ablationId": ABLATION_ID,
        "parameters": interpretation_parameters(),
        "sourceEvidenceSchema": source["schema"],
        "fixtureId": source["fixtureId"],
        "fixtureSha256": source["fixtureSha256"],
        "window": source["window"],
        "sourceCandidates": source["sourceCandidates"],
        "targetCandidates": source["targetCandidates"],
        "candidateInterpretations": [
            interpret_transition(transition)
            for transition in source["candidateTransitions"]
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--from-after-event-index", type=int, required=True)
    parser.add_argument("--to-after-event-index", type=int, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    document = support_document(
        args.fixture,
        args.from_after_event_index,
        args.to_after_event_index,
    )
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

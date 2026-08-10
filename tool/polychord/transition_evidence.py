"""Describe exact candidate transitions without inferring voice assignment."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import frame_replay
import register_candidates
import release_pedal_evidence

OUTPUT_SCHEMA = "polychord-frame-transition-evidence/1"
LAYER_NAMES = ("lower", "upper")
LAYER_RELATIONS = (
    ("lower-to-lower", "lower", "lower"),
    ("lower-to-upper", "lower", "upper"),
    ("upper-to-lower", "upper", "lower"),
    ("upper-to-upper", "upper", "upper"),
)
CORRESPONDENCE_HYPOTHESES = (
    (
        "register-role-preserving",
        ("lower-to-lower", "upper-to-upper"),
    ),
    (
        "register-role-exchanging",
        ("lower-to-upper", "upper-to-lower"),
    ),
)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frame_at_index(fixture: dict, after_event_index: int) -> dict:
    if isinstance(after_event_index, bool) or not isinstance(after_event_index, int):
        raise TypeError("after-event indices must be integers")
    matches = [
        frame
        for frame in fixture["frames"]
        if frame["afterEventIndex"] == after_event_index
    ]
    if len(matches) != 1:
        raise ValueError(
            "each after-event index must identify exactly one replay frame"
        )
    return matches[0]


def evidence_frame_at_index(
    frames: tuple[release_pedal_evidence.ReleasePedalFrame, ...],
    after_event_index: int,
) -> release_pedal_evidence.ReleasePedalFrame:
    matches = [
        frame for frame in frames if frame.after_event_index == after_event_index
    ]
    if len(matches) != 1:
        raise ValueError(
            "each after-event index must identify exactly one evidence frame"
        )
    return matches[0]


def layer_for_note(
    candidate: register_candidates.RegisterCandidate,
    midi_note: int,
) -> str:
    for layer_name in LAYER_NAMES:
        if midi_note in getattr(candidate, layer_name).midi_notes:
            return layer_name
    raise ValueError(f"candidate does not assign sounding MIDI note {midi_note}")


def instance_key(
    note: release_pedal_evidence.SoundingNoteHistory,
) -> tuple[int, int | None]:
    return (
        note.midi_note,
        note.onset.event_index if note.onset is not None else None,
    )


def instance_identity(
    note: release_pedal_evidence.SoundingNoteHistory,
) -> dict:
    return {
        "midiNote": note.midi_note,
        "onsetEventIndex": (note.onset.event_index if note.onset is not None else None),
        "onsetTimestampMs": (
            note.onset.timestamp_ms if note.onset is not None else None
        ),
    }


def identity_sort_key(identity: tuple[int, int | None]) -> tuple[int, int]:
    midi_note, onset_event_index = identity
    return midi_note, -1 if onset_event_index is None else onset_event_index


def instance_continuity(
    source_candidate: register_candidates.RegisterCandidate,
    target_candidate: register_candidates.RegisterCandidate,
    source_frame: release_pedal_evidence.ReleasePedalFrame,
    target_frame: release_pedal_evidence.ReleasePedalFrame,
) -> dict:
    source_notes = {instance_key(note): note for note in source_frame.notes}
    target_notes = {instance_key(note): note for note in target_frame.notes}
    source_keys = set(source_notes)
    target_keys = set(target_notes)

    retained = []
    for key in sorted(source_keys & target_keys, key=identity_sort_key):
        source_note = source_notes[key]
        target_note = target_notes[key]
        retained.append(
            {
                **instance_identity(source_note),
                "sourceLayer": layer_for_note(source_candidate, source_note.midi_note),
                "targetLayer": layer_for_note(target_candidate, target_note.midi_note),
                "sourceSoundingState": source_note.sounding_state,
                "targetSoundingState": target_note.sounding_state,
            }
        )

    departed = []
    for key in sorted(source_keys - target_keys, key=identity_sort_key):
        note = source_notes[key]
        departed.append(
            {
                **instance_identity(note),
                "sourceLayer": layer_for_note(source_candidate, note.midi_note),
                "sourceSoundingState": note.sounding_state,
            }
        )

    arrived = []
    for key in sorted(target_keys - source_keys, key=identity_sort_key):
        note = target_notes[key]
        arrived.append(
            {
                **instance_identity(note),
                "targetLayer": layer_for_note(target_candidate, note.midi_note),
                "targetSoundingState": note.sounding_state,
            }
        )

    return {
        "retainedInstances": retained,
        "departedInstances": departed,
        "arrivedInstances": arrived,
    }


def layer_relation(
    relation_id: str,
    source_layer_name: str,
    target_layer_name: str,
    source_candidate: register_candidates.RegisterCandidate,
    target_candidate: register_candidates.RegisterCandidate,
    continuity: dict,
) -> dict:
    source_layer = getattr(source_candidate, source_layer_name)
    target_layer = getattr(target_candidate, target_layer_name)
    retained = [
        {
            "midiNote": note["midiNote"],
            "onsetEventIndex": note["onsetEventIndex"],
        }
        for note in continuity["retainedInstances"]
        if note["sourceLayer"] == source_layer_name
        and note["targetLayer"] == target_layer_name
    ]
    return {
        "id": relation_id,
        "sourceLayer": source_layer_name,
        "targetLayer": target_layer_name,
        "sourceMidiNotes": list(source_layer.midi_notes),
        "targetMidiNotes": list(target_layer.midi_notes),
        "sourceRootPc": source_layer.root_pitch_class,
        "targetRootPc": target_layer.root_pitch_class,
        "rootPitchClassDeltaMod12": (
            target_layer.root_pitch_class - source_layer.root_pitch_class
        )
        % 12,
        "sameRootPc": (source_layer.root_pitch_class == target_layer.root_pitch_class),
        "sourceQuality": source_layer.quality,
        "targetQuality": target_layer.quality,
        "sameQuality": source_layer.quality == target_layer.quality,
        "sourcePitchClasses": list(source_layer.pitch_classes),
        "targetPitchClasses": list(target_layer.pitch_classes),
        "samePitchClasses": source_layer.pitch_classes == target_layer.pitch_classes,
        "allPairTargetMinusSourceSemitones": [
            [target_note - source_note for target_note in target_layer.midi_notes]
            for source_note in source_layer.midi_notes
        ],
        "retainedInstances": retained,
        "retainedInstanceCount": len(retained),
    }


def correspondence_hypotheses(continuity: dict) -> list[dict]:
    hypotheses = []
    for hypothesis_id, relation_ids in CORRESPONDENCE_HYPOTHESES:
        mappings = {
            (source_layer, target_layer)
            for relation_id, source_layer, target_layer in LAYER_RELATIONS
            if relation_id in relation_ids
        }
        following = []
        outside = []
        for note in continuity["retainedInstances"]:
            identity = {
                "midiNote": note["midiNote"],
                "onsetEventIndex": note["onsetEventIndex"],
            }
            if (note["sourceLayer"], note["targetLayer"]) in mappings:
                following.append(identity)
            else:
                outside.append(identity)
        hypotheses.append(
            {
                "id": hypothesis_id,
                "relationIds": list(relation_ids),
                "retainedInstancesFollowingRelations": following,
                "retainedInstancesOutsideRelations": outside,
                "retainedInstanceCountFollowingRelations": len(following),
                "retainedInstanceCountOutsideRelations": len(outside),
            }
        )
    return hypotheses


def candidate_transition(
    source_candidate_index: int,
    target_candidate_index: int,
    source_candidate: register_candidates.RegisterCandidate,
    target_candidate: register_candidates.RegisterCandidate,
    source_frame: release_pedal_evidence.ReleasePedalFrame,
    target_frame: release_pedal_evidence.ReleasePedalFrame,
) -> dict:
    continuity = instance_continuity(
        source_candidate,
        target_candidate,
        source_frame,
        target_frame,
    )
    relations = [
        layer_relation(
            relation_id,
            source_layer_name,
            target_layer_name,
            source_candidate,
            target_candidate,
            continuity,
        )
        for relation_id, source_layer_name, target_layer_name in LAYER_RELATIONS
    ]
    return {
        "sourceCandidateIndex": source_candidate_index,
        "targetCandidateIndex": target_candidate_index,
        "sameSymbol": source_candidate.symbol == target_candidate.symbol,
        "sameExactCandidate": source_candidate == target_candidate,
        "instanceContinuity": continuity,
        "layerRelations": relations,
        "layerCorrespondenceHypotheses": correspondence_hypotheses(continuity),
    }


def evidence_document(
    fixture_path: Path,
    from_after_event_index: int,
    to_after_event_index: int,
) -> dict:
    """Build exact transition evidence between two caller-selected frames."""

    fixture = frame_replay.load_json(fixture_path)
    release_frames = release_pedal_evidence.replay_release_pedal_frames(fixture)
    source_replay_frame = frame_at_index(fixture, from_after_event_index)
    target_replay_frame = frame_at_index(fixture, to_after_event_index)
    if from_after_event_index >= to_after_event_index:
        raise ValueError("from-after-event-index must precede to-after-event-index")

    source_evidence_frame = evidence_frame_at_index(
        release_frames,
        from_after_event_index,
    )
    target_evidence_frame = evidence_frame_at_index(
        release_frames,
        to_after_event_index,
    )
    source_candidates = register_candidates.generate_register_candidates(
        source_replay_frame["soundingMidiNotes"]
    )
    target_candidates = register_candidates.generate_register_candidates(
        target_replay_frame["soundingMidiNotes"]
    )
    steps = [
        {"event": event, "frame": frame}
        for event, frame in zip(fixture["events"], fixture["frames"])
        if from_after_event_index < event["index"] <= to_after_event_index
    ]
    return {
        "schema": OUTPUT_SCHEMA,
        "fixtureId": fixture["id"],
        "fixtureSha256": sha256_file(fixture_path),
        "window": {
            "sourceFrame": source_replay_frame,
            "targetFrame": target_replay_frame,
            "elapsedMs": (
                target_replay_frame["timestampMs"] - source_replay_frame["timestampMs"]
            ),
            "transitionEventCount": len(steps),
            "interveningFrameCount": max(0, len(steps) - 1),
            "transitionSteps": steps,
        },
        "sourceCandidates": [candidate.as_dict() for candidate in source_candidates],
        "targetCandidates": [candidate.as_dict() for candidate in target_candidates],
        "candidateTransitions": [
            candidate_transition(
                source_index,
                target_index,
                source_candidate,
                target_candidate,
                source_evidence_frame,
                target_evidence_frame,
            )
            for source_index, source_candidate in enumerate(source_candidates)
            for target_index, target_candidate in enumerate(target_candidates)
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
    document = evidence_document(
        args.fixture,
        args.from_after_event_index,
        args.to_after_event_index,
    )
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

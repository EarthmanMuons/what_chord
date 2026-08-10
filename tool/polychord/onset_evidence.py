"""Attach exact note-on provenance to register-only polychord candidates."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

import frame_replay
import register_candidates

OUTPUT_SCHEMA = "polychord-onset-evidence/1"


@dataclass(frozen=True)
class OnsetOrigin:
    """The most recent attack that created one currently sounding note."""

    event_index: int
    timestamp_ms: int
    velocity: int


@dataclass(frozen=True)
class SoundingNoteOnset:
    """Onset provenance and current held state for one sounding MIDI note."""

    midi_note: int
    sounding_state: str
    origin: OnsetOrigin | None

    def as_dict(self) -> dict:
        return {
            "midiNote": self.midi_note,
            "soundingState": self.sounding_state,
            "onsetEventIndex": (
                self.origin.event_index if self.origin is not None else None
            ),
            "onsetTimestampMs": (
                self.origin.timestamp_ms if self.origin is not None else None
            ),
            "onsetVelocity": (
                self.origin.velocity if self.origin is not None else None
            ),
        }


@dataclass(frozen=True)
class OnsetFrame:
    """Exact onset provenance for one validated replay frame."""

    after_event_index: int
    timestamp_ms: int
    notes: tuple[SoundingNoteOnset, ...]

    def note_map(self) -> dict[int, SoundingNoteOnset]:
        return {note.midi_note: note for note in self.notes}


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replay_onset_frames(fixture: dict) -> tuple[OnsetFrame, ...]:
    """Replay the latest onset instance of every sounding note."""

    frame_replay.validate_fixture(fixture)
    initial = fixture["initialState"]
    origins: dict[int, OnsetOrigin | None] = {
        note: None
        for note in (initial["pressedMidiNotes"] + initial["sustainedMidiNotes"])
    }
    evidence_frames = []

    for event, frame in zip(fixture["events"], fixture["frames"]):
        event_type = event["type"]
        if event_type == "noteOn":
            origins[event["midiNote"]] = OnsetOrigin(
                event_index=event["index"],
                timestamp_ms=event["timestampMs"],
                velocity=event["velocity"],
            )

        sounding_notes = set(frame["soundingMidiNotes"])
        origins = {
            note: origin for note, origin in origins.items() if note in sounding_notes
        }
        missing = sounding_notes - set(origins)
        if missing:
            raise ValueError(
                "replayed onset state is missing sounding MIDI notes "
                f"{sorted(missing)} after event {event['index']}"
            )

        pressed = set(frame["pressedMidiNotes"])
        notes = tuple(
            SoundingNoteOnset(
                midi_note=note,
                sounding_state="pressed" if note in pressed else "sustained",
                origin=origins[note],
            )
            for note in frame["soundingMidiNotes"]
        )
        evidence_frames.append(
            OnsetFrame(
                after_event_index=frame["afterEventIndex"],
                timestamp_ms=frame["timestampMs"],
                notes=notes,
            )
        )

    return tuple(evidence_frames)


def summarize_layer(
    midi_notes: tuple[int, ...],
    onset_frame: OnsetFrame,
) -> dict:
    """Summarize raw known onset times for one exact candidate layer."""

    note_map = onset_frame.note_map()
    missing = set(midi_notes) - set(note_map)
    if missing:
        raise ValueError(
            f"layer contains notes absent from the frame: {sorted(missing)}"
        )
    notes = [note_map[midi_note] for midi_note in midi_notes]
    known_timestamps = [
        note.origin.timestamp_ms for note in notes if note.origin is not None
    ]
    known_count = len(known_timestamps)
    unknown_count = len(notes) - known_count
    earliest = min(known_timestamps) if known_timestamps else None
    latest = max(known_timestamps) if known_timestamps else None
    return {
        "notes": [note.as_dict() for note in notes],
        "knownOnsetCount": known_count,
        "unknownOnsetCount": unknown_count,
        "allOnsetsKnown": unknown_count == 0,
        "distinctKnownOnsetTimestampsMs": sorted(set(known_timestamps)),
        "earliestKnownOnsetMs": earliest,
        "latestKnownOnsetMs": latest,
        "knownOnsetSpanMs": latest - earliest if earliest is not None else None,
    }


def candidate_onset_evidence(
    candidate: register_candidates.RegisterCandidate,
    onset_frame: OnsetFrame,
) -> dict:
    """Attach threshold-free onset evidence to one structural candidate."""

    lower = summarize_layer(candidate.lower.midi_notes, onset_frame)
    upper = summarize_layer(candidate.upper.midi_notes, onset_frame)
    complete = lower["allOnsetsKnown"] and upper["allOnsetsKnown"]
    return {
        "candidate": candidate.as_dict(),
        "onsetEvidence": {
            "allCandidateOnsetsKnown": complete,
            "lower": lower,
            "upper": upper,
            "upperEarliestMinusLowerLatestMs": (
                upper["earliestKnownOnsetMs"] - lower["latestKnownOnsetMs"]
                if complete
                else None
            ),
            "upperLatestMinusLowerEarliestMs": (
                upper["latestKnownOnsetMs"] - lower["earliestKnownOnsetMs"]
                if complete
                else None
            ),
        },
    }


def evidence_document(fixture_path: Path, after_event_index: int) -> dict:
    """Build onset evidence for every candidate at one exact replay frame."""

    if isinstance(after_event_index, bool) or not isinstance(after_event_index, int):
        raise TypeError("after_event_index must be an integer")
    fixture = frame_replay.load_json(fixture_path)
    frames = fixture["frames"]
    onset_frames = replay_onset_frames(fixture)
    matching = [
        (frame, onset_frame)
        for frame, onset_frame in zip(frames, onset_frames)
        if frame["afterEventIndex"] == after_event_index
    ]
    if len(matching) != 1:
        raise ValueError("after_event_index must identify exactly one replay frame")
    frame, onset_frame = matching[0]
    candidates = register_candidates.generate_register_candidates(
        frame["soundingMidiNotes"]
    )
    return {
        "schema": OUTPUT_SCHEMA,
        "fixtureId": fixture["id"],
        "fixtureSha256": sha256_file(fixture_path),
        "observationFrame": frame,
        "candidateEvidence": [
            candidate_onset_evidence(candidate, onset_frame) for candidate in candidates
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--after-event-index", type=int, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    document = evidence_document(args.fixture, args.after_event_index)
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

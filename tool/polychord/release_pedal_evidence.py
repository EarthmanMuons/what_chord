"""Attach threshold-free release and pedal provenance to polychord candidates."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

import frame_replay
import register_candidates

OUTPUT_SCHEMA = "polychord-release-pedal-evidence/1"


@dataclass(frozen=True)
class NoteEventOrigin:
    """One normalized note event that established a current fact."""

    event_index: int
    timestamp_ms: int
    velocity: int


@dataclass(frozen=True)
class PedalTransition:
    """The latest observed transition into the current sustain-pedal state."""

    event_index: int
    timestamp_ms: int
    down: bool


@dataclass(frozen=True)
class SoundingNoteHistory:
    """Causal history for one currently sounding MIDI note."""

    midi_note: int
    sounding_state: str
    onset: NoteEventOrigin | None
    release: NoteEventOrigin | None
    current_state_since: NoteEventOrigin | None
    reattacked_from_sustain: bool | None
    prior_sustain_release: NoteEventOrigin | None

    def as_dict(
        self,
        timestamp_ms: int,
        pedal_down: bool,
        pedal_transition: PedalTransition | None,
    ) -> dict:
        pedal_relation = None
        if self.onset is not None and pedal_down and pedal_transition is not None:
            pedal_relation = (
                self.onset.timestamp_ms < pedal_transition.timestamp_ms
                or (
                    self.onset.timestamp_ms == pedal_transition.timestamp_ms
                    and self.onset.event_index < pedal_transition.event_index
                )
            )
        return {
            "midiNote": self.midi_note,
            "soundingState": self.sounding_state,
            "onsetEventIndex": (
                self.onset.event_index if self.onset is not None else None
            ),
            "onsetTimestampMs": (
                self.onset.timestamp_ms if self.onset is not None else None
            ),
            "onsetVelocity": (self.onset.velocity if self.onset is not None else None),
            "onsetAgeMs": (
                timestamp_ms - self.onset.timestamp_ms
                if self.onset is not None
                else None
            ),
            "releaseEventIndex": (
                self.release.event_index if self.release is not None else None
            ),
            "releaseTimestampMs": (
                self.release.timestamp_ms if self.release is not None else None
            ),
            "releaseVelocity": (
                self.release.velocity if self.release is not None else None
            ),
            "releaseAgeMs": (
                timestamp_ms - self.release.timestamp_ms
                if self.release is not None
                else None
            ),
            "currentStateSinceEventIndex": (
                self.current_state_since.event_index
                if self.current_state_since is not None
                else None
            ),
            "currentStateSinceTimestampMs": (
                self.current_state_since.timestamp_ms
                if self.current_state_since is not None
                else None
            ),
            "currentStateAgeMs": (
                timestamp_ms - self.current_state_since.timestamp_ms
                if self.current_state_since is not None
                else None
            ),
            "reattackedFromSustain": self.reattacked_from_sustain,
            "priorSustainReleaseEventIndex": (
                self.prior_sustain_release.event_index
                if self.prior_sustain_release is not None
                else None
            ),
            "priorSustainReleaseTimestampMs": (
                self.prior_sustain_release.timestamp_ms
                if self.prior_sustain_release is not None
                else None
            ),
            "priorSustainReleaseVelocity": (
                self.prior_sustain_release.velocity
                if self.prior_sustain_release is not None
                else None
            ),
            "priorSustainReleaseAgeMs": (
                timestamp_ms - self.prior_sustain_release.timestamp_ms
                if self.prior_sustain_release is not None
                else None
            ),
            "onsetBeforeCurrentPedalDown": pedal_relation,
        }


@dataclass(frozen=True)
class ReleasePedalFrame:
    """Release and pedal provenance after one validated replay event."""

    after_event_index: int
    timestamp_ms: int
    pedal_down: bool
    pedal_transition: PedalTransition | None
    notes: tuple[SoundingNoteHistory, ...]

    def note_map(self) -> dict[int, SoundingNoteHistory]:
        return {note.midi_note: note for note in self.notes}

    def pedal_as_dict(self) -> dict:
        transition = self.pedal_transition
        return {
            "down": self.pedal_down,
            "lastTransitionEventIndex": (
                transition.event_index if transition is not None else None
            ),
            "lastTransitionTimestampMs": (
                transition.timestamp_ms if transition is not None else None
            ),
            "lastTransitionDown": (transition.down if transition is not None else None),
            "currentStateAgeMs": (
                self.timestamp_ms - transition.timestamp_ms
                if transition is not None
                else None
            ),
        }


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def note_origin(event: dict) -> NoteEventOrigin:
    return NoteEventOrigin(
        event_index=event["index"],
        timestamp_ms=event["timestampMs"],
        velocity=event["velocity"],
    )


def replay_release_pedal_frames(fixture: dict) -> tuple[ReleasePedalFrame, ...]:
    """Replay release, restrike, note-state, and pedal provenance."""

    frame_replay.validate_fixture(fixture)
    initial = fixture["initialState"]
    notes: dict[int, SoundingNoteHistory] = {
        note: SoundingNoteHistory(
            midi_note=note,
            sounding_state="pressed",
            onset=None,
            release=None,
            current_state_since=None,
            reattacked_from_sustain=None,
            prior_sustain_release=None,
        )
        for note in initial["pressedMidiNotes"]
    }
    notes.update(
        {
            note: SoundingNoteHistory(
                midi_note=note,
                sounding_state="sustained",
                onset=None,
                release=None,
                current_state_since=None,
                reattacked_from_sustain=None,
                prior_sustain_release=None,
            )
            for note in initial["sustainedMidiNotes"]
        }
    )
    pedal_transition: PedalTransition | None = None
    evidence_frames = []

    for event, frame in zip(fixture["events"], fixture["frames"]):
        event_type = event["type"]
        if event_type == "noteOn":
            note = event["midiNote"]
            prior = notes.get(note)
            reattacked = prior is not None and prior.sounding_state == "sustained"
            origin = note_origin(event)
            notes[note] = SoundingNoteHistory(
                midi_note=note,
                sounding_state="pressed",
                onset=origin,
                release=None,
                current_state_since=origin,
                reattacked_from_sustain=reattacked,
                prior_sustain_release=prior.release if reattacked else None,
            )
        elif event_type == "noteOff":
            note = event["midiNote"]
            prior = notes[note]
            if frame["pedalDown"]:
                origin = note_origin(event)
                notes[note] = SoundingNoteHistory(
                    midi_note=note,
                    sounding_state="sustained",
                    onset=prior.onset,
                    release=origin,
                    current_state_since=origin,
                    reattacked_from_sustain=prior.reattacked_from_sustain,
                    prior_sustain_release=prior.prior_sustain_release,
                )
            else:
                del notes[note]
        else:
            pedal_transition = PedalTransition(
                event_index=event["index"],
                timestamp_ms=event["timestampMs"],
                down=event["down"],
            )
            if not event["down"]:
                notes = {
                    note: history
                    for note, history in notes.items()
                    if history.sounding_state == "pressed"
                }

        expected_sounding = set(frame["soundingMidiNotes"])
        if set(notes) != expected_sounding:
            raise ValueError(
                "release/pedal history does not match replayed sounding notes "
                f"after event {event['index']}"
            )
        pressed = set(frame["pressedMidiNotes"])
        state_mismatches = [
            note
            for note, history in notes.items()
            if (history.sounding_state == "pressed") != (note in pressed)
        ]
        if state_mismatches:
            raise ValueError(
                "release/pedal history does not match replayed note states after "
                f"event {event['index']}: {sorted(state_mismatches)}"
            )
        if pedal_transition is not None and pedal_transition.down != frame["pedalDown"]:
            raise ValueError(
                "release/pedal history does not match replayed pedal state after "
                f"event {event['index']}"
            )
        evidence_frames.append(
            ReleasePedalFrame(
                after_event_index=frame["afterEventIndex"],
                timestamp_ms=frame["timestampMs"],
                pedal_down=frame["pedalDown"],
                pedal_transition=pedal_transition,
                notes=tuple(notes[note] for note in frame["soundingMidiNotes"]),
            )
        )

    return tuple(evidence_frames)


def value_range(values: list[int]) -> dict | None:
    if not values:
        return None
    return {"minimum": min(values), "maximum": max(values)}


def summarize_layer(
    midi_notes: tuple[int, ...],
    evidence_frame: ReleasePedalFrame,
) -> dict:
    """Summarize exact causal facts for one candidate layer."""

    note_map = evidence_frame.note_map()
    missing = set(midi_notes) - set(note_map)
    if missing:
        raise ValueError(
            f"layer contains notes absent from the frame: {sorted(missing)}"
        )
    note_records = [
        note_map[midi_note].as_dict(
            evidence_frame.timestamp_ms,
            evidence_frame.pedal_down,
            evidence_frame.pedal_transition,
        )
        for midi_note in midi_notes
    ]
    sustained = [note for note in note_records if note["soundingState"] == "sustained"]
    release_timestamps = [
        note["releaseTimestampMs"]
        for note in sustained
        if note["releaseTimestampMs"] is not None
    ]
    onset_ages = [
        note["onsetAgeMs"] for note in note_records if note["onsetAgeMs"] is not None
    ]
    state_ages = [
        note["currentStateAgeMs"]
        for note in note_records
        if note["currentStateAgeMs"] is not None
    ]
    earliest_release = min(release_timestamps) if release_timestamps else None
    latest_release = max(release_timestamps) if release_timestamps else None
    return {
        "notes": note_records,
        "pressedNoteCount": len(note_records) - len(sustained),
        "sustainedNoteCount": len(sustained),
        "knownOnsetCount": len(onset_ages),
        "unknownOnsetCount": len(note_records) - len(onset_ages),
        "knownOnsetAgeRangeMs": value_range(onset_ages),
        "knownReleaseCount": len(release_timestamps),
        "unknownReleaseCount": len(sustained) - len(release_timestamps),
        "allSustainedReleasesKnown": len(release_timestamps) == len(sustained),
        "distinctKnownReleaseTimestampsMs": sorted(set(release_timestamps)),
        "earliestKnownReleaseMs": earliest_release,
        "latestKnownReleaseMs": latest_release,
        "knownReleaseSpanMs": (
            latest_release - earliest_release if earliest_release is not None else None
        ),
        "knownCurrentStateOriginCount": len(state_ages),
        "unknownCurrentStateOriginCount": len(note_records) - len(state_ages),
        "knownCurrentStateAgeRangeMs": value_range(state_ages),
        "reattackedFromSustainCount": sum(
            note["reattackedFromSustain"] is True for note in note_records
        ),
        "notReattackedFromSustainCount": sum(
            note["reattackedFromSustain"] is False for note in note_records
        ),
        "unknownReattackCount": sum(
            note["reattackedFromSustain"] is None for note in note_records
        ),
        "onsetBeforeCurrentPedalDownCount": sum(
            note["onsetBeforeCurrentPedalDown"] is True for note in note_records
        ),
        "onsetAtOrAfterCurrentPedalDownCount": sum(
            note["onsetBeforeCurrentPedalDown"] is False for note in note_records
        ),
        "unknownPedalRelationCount": sum(
            note["onsetBeforeCurrentPedalDown"] is None for note in note_records
        ),
    }


def candidate_release_pedal_evidence(
    candidate: register_candidates.RegisterCandidate,
    evidence_frame: ReleasePedalFrame,
) -> dict:
    """Attach threshold-free release and pedal evidence to one candidate."""

    lower = summarize_layer(candidate.lower.midi_notes, evidence_frame)
    upper = summarize_layer(candidate.upper.midi_notes, evidence_frame)
    return {
        "candidate": candidate.as_dict(),
        "releasePedalEvidence": {
            "pedal": evidence_frame.pedal_as_dict(),
            "lower": lower,
            "upper": upper,
            "pressedCandidateNoteCount": (
                lower["pressedNoteCount"] + upper["pressedNoteCount"]
            ),
            "sustainedCandidateNoteCount": (
                lower["sustainedNoteCount"] + upper["sustainedNoteCount"]
            ),
            "allSustainedReleasesKnown": (
                lower["allSustainedReleasesKnown"]
                and upper["allSustainedReleasesKnown"]
            ),
            "reattackedFromSustainCount": (
                lower["reattackedFromSustainCount"]
                + upper["reattackedFromSustainCount"]
            ),
            "onsetBeforeCurrentPedalDownCount": (
                lower["onsetBeforeCurrentPedalDownCount"]
                + upper["onsetBeforeCurrentPedalDownCount"]
            ),
            "onsetAtOrAfterCurrentPedalDownCount": (
                lower["onsetAtOrAfterCurrentPedalDownCount"]
                + upper["onsetAtOrAfterCurrentPedalDownCount"]
            ),
            "unknownPedalRelationCount": (
                lower["unknownPedalRelationCount"] + upper["unknownPedalRelationCount"]
            ),
        },
    }


def evidence_document(fixture_path: Path, after_event_index: int) -> dict:
    """Build release/pedal evidence for every candidate at one replay frame."""

    if isinstance(after_event_index, bool) or not isinstance(after_event_index, int):
        raise TypeError("after_event_index must be an integer")
    fixture = frame_replay.load_json(fixture_path)
    frames = fixture["frames"]
    evidence_frames = replay_release_pedal_frames(fixture)
    matching = [
        (frame, evidence_frame)
        for frame, evidence_frame in zip(frames, evidence_frames)
        if frame["afterEventIndex"] == after_event_index
    ]
    if len(matching) != 1:
        raise ValueError("after_event_index must identify exactly one replay frame")
    frame, evidence_frame = matching[0]
    candidates = register_candidates.generate_register_candidates(
        frame["soundingMidiNotes"]
    )
    return {
        "schema": OUTPUT_SCHEMA,
        "fixtureId": fixture["id"],
        "fixtureSha256": sha256_file(fixture_path),
        "observationFrame": frame,
        "candidateEvidence": [
            candidate_release_pedal_evidence(candidate, evidence_frame)
            for candidate in candidates
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

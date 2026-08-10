"""Validate and replay exact polychord temporal-evidence fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

FIXTURE_SCHEMA = "polychord-frame-replay/1"
MANIFEST_SCHEMA = "polychord-frame-replay-manifest/1"
REPO_ROOT = Path(__file__).parents[2]

TOP_LEVEL_FIELDS = {
    "schema",
    "id",
    "description",
    "timeBase",
    "initialState",
    "events",
    "frames",
    "endTimestampMs",
}
STATE_FIELDS = {"pressedMidiNotes", "sustainedMidiNotes", "pedalDown"}
FRAME_FIELDS = {
    "afterEventIndex",
    "timestampMs",
    "pressedMidiNotes",
    "sustainedMidiNotes",
    "soundingMidiNotes",
    "pedalDown",
}
EVENT_FIELDS = {
    "noteOn": {"index", "timestampMs", "type", "midiNote", "velocity"},
    "noteOff": {"index", "timestampMs", "type", "midiNote", "velocity"},
    "pedal": {"index", "timestampMs", "type", "down"},
}
MANIFEST_FIELDS = {
    "schema",
    "fixtureSchema",
    "framework",
    "schemaDocument",
    "validator",
    "fixtures",
}
MANIFEST_ENTRY_FIELDS = {"id", "file", "sha256"}
PIN_FIELDS = {"path", "sha256"}


@dataclass(frozen=True)
class ReplayState:
    pressed: frozenset[int]
    sustained: frozenset[int]
    pedal_down: bool

    @property
    def sounding(self) -> frozenset[int]:
        return self.pressed | self.sustained


def require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        details = []
        if missing:
            details.append(f"missing {missing}")
        if unknown:
            details.append(f"unknown {unknown}")
        raise ValueError(f"{context} fields are invalid: {', '.join(details)}")


def require_int(value: object, context: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{context} must be an integer")
    if value < minimum or value > maximum:
        raise ValueError(f"{context} must be from {minimum} through {maximum}")
    return value


def require_bool(value: object, context: str) -> bool:
    if not isinstance(value, bool):
        raise TypeError(f"{context} must be a boolean")
    return value


def midi_notes(value: object, context: str) -> frozenset[int]:
    if not isinstance(value, list):
        raise TypeError(f"{context} must be an array")
    notes = [
        require_int(note, f"{context}[{index}]", 0, 127)
        for index, note in enumerate(value)
    ]
    if notes != sorted(set(notes)):
        raise ValueError(f"{context} must be strictly increasing without duplicates")
    return frozenset(notes)


def parse_state(value: object, context: str) -> ReplayState:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    require_fields(value, STATE_FIELDS, context)
    pressed = midi_notes(value["pressedMidiNotes"], f"{context}.pressedMidiNotes")
    sustained = midi_notes(value["sustainedMidiNotes"], f"{context}.sustainedMidiNotes")
    pedal_down = require_bool(value["pedalDown"], f"{context}.pedalDown")
    overlap = pressed & sustained
    if overlap:
        raise ValueError(f"{context} has notes in both states: {sorted(overlap)}")
    if sustained and not pedal_down:
        raise ValueError(f"{context} has sustained notes while the pedal is up")
    return ReplayState(pressed, sustained, pedal_down)


def frame_for(event: dict, state: ReplayState) -> dict:
    return {
        "afterEventIndex": event["index"],
        "timestampMs": event["timestampMs"],
        "pressedMidiNotes": sorted(state.pressed),
        "sustainedMidiNotes": sorted(state.sustained),
        "soundingMidiNotes": sorted(state.sounding),
        "pedalDown": state.pedal_down,
    }


def apply_event(state: ReplayState, event: dict, context: str) -> ReplayState:
    event_type = event.get("type")
    if event_type not in EVENT_FIELDS:
        raise ValueError(f"{context}.type is not supported: {event_type!r}")
    require_fields(event, EVENT_FIELDS[event_type], context)

    if event_type == "pedal":
        down = require_bool(event["down"], f"{context}.down")
        if down == state.pedal_down:
            raise ValueError(f"{context} repeats the current pedal state")
        return ReplayState(
            state.pressed,
            state.sustained if down else frozenset(),
            down,
        )

    note = require_int(event["midiNote"], f"{context}.midiNote", 0, 127)
    velocity_minimum = 1 if event_type == "noteOn" else 0
    require_int(
        event["velocity"],
        f"{context}.velocity",
        velocity_minimum,
        127,
    )

    if event_type == "noteOn":
        if note in state.pressed:
            raise ValueError(f"{context} repeats noteOn for pressed note {note}")
        return ReplayState(
            state.pressed | {note},
            state.sustained - {note},
            state.pedal_down,
        )

    if note not in state.pressed:
        raise ValueError(f"{context} releases note {note}, which is not pressed")
    pressed = state.pressed - {note}
    sustained = state.sustained | {note} if state.pedal_down else state.sustained
    return ReplayState(pressed, sustained, state.pedal_down)


def replay_fixture(payload: dict) -> list[dict]:
    if not isinstance(payload, dict):
        raise TypeError("fixture must be an object")
    require_fields(payload, TOP_LEVEL_FIELDS, "fixture")
    if payload["schema"] != FIXTURE_SCHEMA:
        raise ValueError(f"fixture.schema must be {FIXTURE_SCHEMA!r}")
    if not isinstance(payload["id"], str) or not payload["id"].strip():
        raise ValueError("fixture.id must be a nonempty string")
    if (
        not isinstance(payload["description"], str)
        or not payload["description"].strip()
    ):
        raise ValueError("fixture.description must be a nonempty string")
    if payload["timeBase"] != "milliseconds":
        raise ValueError("fixture.timeBase must be 'milliseconds'")

    end_timestamp = require_int(
        payload["endTimestampMs"], "fixture.endTimestampMs", 0, 2**53 - 1
    )
    events = payload["events"]
    if not isinstance(events, list):
        raise TypeError("fixture.events must be an array")

    state = parse_state(payload["initialState"], "fixture.initialState")
    derived_frames = []
    last_timestamp = 0
    for index, event in enumerate(events):
        context = f"fixture.events[{index}]"
        if not isinstance(event, dict):
            raise TypeError(f"{context} must be an object")
        event_index = require_int(event.get("index"), f"{context}.index", 0, 2**53 - 1)
        if event_index != index:
            raise ValueError(f"{context}.index must equal {index}")
        timestamp = require_int(
            event.get("timestampMs"), f"{context}.timestampMs", 0, 2**53 - 1
        )
        if index and timestamp < last_timestamp:
            raise ValueError(f"{context}.timestampMs must be nondecreasing")
        if timestamp > end_timestamp:
            raise ValueError(f"{context} occurs after fixture.endTimestampMs")
        state = apply_event(state, event, context)
        derived_frames.append(frame_for(event, state))
        last_timestamp = timestamp
    return derived_frames


def validate_fixture(payload: dict) -> None:
    derived_frames = replay_fixture(payload)
    frames = payload["frames"]
    if not isinstance(frames, list):
        raise TypeError("fixture.frames must be an array")
    if len(frames) != len(derived_frames):
        raise ValueError(
            "fixture.frames must contain exactly one frame for every event"
        )
    for index, (actual, expected) in enumerate(zip(frames, derived_frames)):
        context = f"fixture.frames[{index}]"
        if not isinstance(actual, dict):
            raise TypeError(f"{context} must be an object")
        require_fields(actual, FRAME_FIELDS, context)
        if actual != expected:
            raise ValueError(
                f"{context} does not match replayed state: "
                f"expected {expected}, received {actual}"
            )


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_pin(value: object, context: str) -> Path:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    require_fields(value, PIN_FIELDS, context)
    relative = value["path"]
    digest = value["sha256"]
    if not isinstance(relative, str) or not relative:
        raise ValueError(f"{context}.path must be a nonempty string")
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"{context}.path must be relative to the repository root")
    if (
        not isinstance(digest, str)
        or len(digest) != 64
        or any(character not in "0123456789abcdef" for character in digest)
    ):
        raise ValueError(f"{context}.sha256 must be a lowercase SHA-256 digest")
    resolved = REPO_ROOT / path
    if sha256_file(resolved) != digest:
        raise ValueError(f"{context} digest does not match {resolved}")
    return resolved


def load_json(path: Path) -> dict:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return payload


def validate_manifest(path: Path) -> list[Path]:
    manifest = load_json(path)
    require_fields(manifest, MANIFEST_FIELDS, "manifest")
    if manifest["schema"] != MANIFEST_SCHEMA:
        raise ValueError(f"manifest.schema must be {MANIFEST_SCHEMA!r}")
    if manifest["fixtureSchema"] != FIXTURE_SCHEMA:
        raise ValueError(f"manifest.fixtureSchema must be {FIXTURE_SCHEMA!r}")
    validate_pin(manifest["framework"], "manifest.framework")
    validate_pin(manifest["schemaDocument"], "manifest.schemaDocument")
    validator = validate_pin(manifest["validator"], "manifest.validator")
    if validator.resolve() != Path(__file__).resolve():
        raise ValueError("manifest.validator must pin this validator")

    fixtures = manifest["fixtures"]
    if not isinstance(fixtures, list) or not fixtures:
        raise ValueError("manifest.fixtures must be a nonempty array")
    seen_ids = set()
    seen_files = set()
    validated = []
    for index, entry in enumerate(fixtures):
        context = f"manifest.fixtures[{index}]"
        if not isinstance(entry, dict):
            raise TypeError(f"{context} must be an object")
        require_fields(entry, MANIFEST_ENTRY_FIELDS, context)
        fixture_id = entry["id"]
        filename = entry["file"]
        digest = entry["sha256"]
        if not isinstance(fixture_id, str) or not fixture_id:
            raise ValueError(f"{context}.id must be a nonempty string")
        if fixture_id in seen_ids:
            raise ValueError(f"{context}.id is duplicated")
        if not isinstance(filename, str) or not filename:
            raise ValueError(f"{context}.file must be a nonempty string")
        relative = Path(filename)
        if relative.is_absolute() or relative.parent != Path("."):
            raise ValueError(
                f"{context}.file must be a filename in the manifest directory"
            )
        if filename in seen_files:
            raise ValueError(f"{context}.file is duplicated")
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)
        ):
            raise ValueError(f"{context}.sha256 must be a lowercase SHA-256 digest")

        fixture_path = path.parent / relative
        if sha256_file(fixture_path) != digest:
            raise ValueError(f"{context} digest does not match {fixture_path}")
        payload = load_json(fixture_path)
        if payload.get("id") != fixture_id:
            raise ValueError(f"{context}.id does not match {fixture_path}")
        validate_fixture(payload)
        seen_ids.add(fixture_id)
        seen_files.add(filename)
        validated.append(fixture_path)
    return validated


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixtures", nargs="*", type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if bool(args.manifest) == bool(args.fixtures):
        parser.error("provide either --manifest or one or more fixture paths")
    return args


def main() -> int:
    args = parse_args()
    if args.manifest:
        validated = validate_manifest(args.manifest)
        print(f"valid: {args.manifest} ({len(validated)} fixtures)")
        return 0
    for path in args.fixtures:
        validate_fixture(load_json(path))
        print(f"valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

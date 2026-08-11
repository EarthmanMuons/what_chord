#!/usr/bin/env python3
"""Run the preregistered polychord development-exposure measurement.

This harness has no test- or held-roster switch. It reads only the declared
development inputs, sends label-blind observation payloads to the pure-Dart
analysis batch, and writes detailed copyrighted or license-gated output under
build/. Do not run the official corpus command before the implementation commit.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import importlib.metadata
import json
import math
import platform
import shlex
import subprocess
import sys
from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from pathlib import Path
from typing import Self

REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_ROOT = REPO_ROOT / "build"
REPORT_SCHEMA = "polychord-development-exposure-report/1"
MANIFEST_SCHEMA = "polychord-development-exposure-manifest/1"
DART_PIECE_SCHEMA = "polychord-development-exposure-dart-piece/1"
DISPOSITION_SCHEMA = "polychord-development-fire-dispositions/1"
REVIEW_INDEX_SCHEMA = "polychord-development-review-index/1"

ASAP_SPLIT = REPO_ROOT / "research/performed-input/data/splits/asap-wir-nc-v2.json"
WIR_SPLIT = REPO_ROOT / "research/whatkey/data/splits/when-in-rome-v1.json"
POP909_ROSTER = REPO_ROOT / "research/performed-input/data/pop909-held-pool.json"
WIR_FIXTURE_ROOT = REPO_ROOT / "research/whatkey/data/fixtures/when-in-rome-v1"
DART_BATCH = REPO_ROOT / "tool/polychord/development_exposure_batch.dart"

ASAP_SPLIT_SHA256 = "240cab19043f8d4c1877a3d24c67a5a6ba7ddfc0058a29f4791209d0eeed440f"
WIR_SPLIT_SHA256 = "4f55b18f88130fd62718c358b62a2c81302bbb11eede3c67d133f23161795684"
POP909_ROSTER_SHA256 = (
    "b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781"
)
ASAP_COMMIT = "afc815c75c42e83a79c03feb6da8a35e77d4c6b8"
POP909_COMMIT = "d83e6edba6872a704f5d3b8b32f5cb540088dae6"

ASAP_MEASUREMENT_ID = "asap-wir-development-raw-midi-register-selector-display/1"
POP909_MEASUREMENT_ID = "pop909-sample-accompaniment-register-selector-display/1"
WIR_MEASUREMENT_ID = (
    "when-in-rome-development-committed-event-register-selector-proposals/1"
)
FULL_SELECTOR_ID = "polychord-register-policy/1"
SELECTOR_IDS = (
    FULL_SELECTOR_ID,
    "polychord-register-policy-without-integrated-tertian-veto/1",
    "polychord-register-policy-without-assignment-veto/1",
    "polychord-register-policy-without-gap-resolution/1",
)

ALLOWED_DISPOSITIONS = (
    "in-scope-polychord",
    "ordinary-integrated-harmony",
    "slash-or-bass-only-structure",
    "same-root-or-duplicated-harmony",
    "pedal-or-release-artifact",
    "transient-or-serialization-artifact",
    "other-out-of-scope",
    "unresolved",
)

PEDAL_CONTROLLER = 64
ALL_SOUND_OFF_CONTROLLER = 120
ALL_NOTES_OFF_CONTROLLER = 123
EXPECTED_POP909_TRACK_NAMES = ("MELODY", "BRIDGE", "PIANO")
SELECTED_POP909_TRACK_NAMES = ("BRIDGE", "PIANO")

CONTRACT_PATHS = (
    REPO_ROOT / "research/polychord/development-exposure-v1.md",
    REPO_ROOT / "research/polychord/output-evaluation-contract.md",
    REPO_ROOT / "research/polychord/register-selector-v1.md",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/models/polychord_candidate.dart",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_register_candidate_generator.dart",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_register_selector.dart",
    REPO_ROOT / "packages/whatchord/lib/src/polychord/services/"
    "polychord_stable_display_gate.dart",
    DART_BATCH,
    Path(__file__).resolve(),
    REPO_ROOT / "tool/polychord/validate_development_dispositions.py",
    ASAP_SPLIT,
    WIR_SPLIT,
    POP909_ROSTER,
)


@dataclass(frozen=True)
class RawMidiMessage:
    """One source-ordered message relevant to current WhatChord note state."""

    timestamp_ms: int
    type: str
    channel: int = 0
    midi_note: int | None = None
    velocity: int | None = None
    controller: int | None = None
    value: int | None = None


@dataclass(frozen=True)
class SourcePiece:
    """One allowed source path resolved before any analysis output exists."""

    corpus: str
    piece_id: str
    path: Path
    source_title: str
    source_sha256: str = ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asap-root", type=Path, required=True)
    parser.add_argument("--pop909-root", type=Path, required=True)
    parser.add_argument("--out-directory", type=Path, required=True)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_hash(path: Path, expected: str) -> None:
    actual = sha256_file(path)
    if actual != expected:
        raise ValueError(f"{path} SHA-256 is {actual}, expected {expected}")


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def require_clean_checkout(path: Path, expected_commit: str, name: str) -> None:
    actual = git(path, "rev-parse", "HEAD")
    if actual != expected_commit:
        raise ValueError(f"{name} commit is {actual}, expected {expected_commit}")
    dirty = git(path, "status", "--porcelain")
    if dirty:
        raise ValueError(f"{name} checkout is dirty")


def require_output_directory(path: Path) -> Path:
    resolved = path.resolve()
    if resolved == BUILD_ROOT.resolve() or BUILD_ROOT.resolve() not in resolved.parents:
        raise ValueError("output directory must be a new child of build/")
    if resolved.exists():
        raise FileExistsError(f"output directory already exists: {resolved}")
    return resolved


def _load_json(path: Path) -> dict:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return payload


def load_source_plan(
    asap_root: Path, pop909_root: Path
) -> dict[str, list[SourcePiece]]:
    """Resolve only the permitted rosters without opening any test MIDI."""

    require_hash(ASAP_SPLIT, ASAP_SPLIT_SHA256)
    require_hash(WIR_SPLIT, WIR_SPLIT_SHA256)
    require_hash(POP909_ROSTER, POP909_ROSTER_SHA256)
    require_clean_checkout(asap_root, ASAP_COMMIT, "ASAP")
    require_clean_checkout(pop909_root.parent, POP909_COMMIT, "POP909")

    asap_split = _load_json(ASAP_SPLIT)
    asap_development = asap_split["splits"]["development"]
    asap_test_ids = {entry["id"] for entry in asap_split["splits"]["test"]}
    asap_test_titles = {entry["title"] for entry in asap_split["splits"]["test"]}
    asap_pieces = []
    for entry in asap_development:
        title = entry["title"]
        if entry["id"] in asap_test_ids or title in asap_test_titles:
            raise ValueError(f"ASAP development/test overlap: {entry['id']} / {title}")
        path = asap_root / f"{title}.mid"
        asap_pieces.append(SourcePiece("asap", entry["id"], path, title))

    roster = _load_json(POP909_ROSTER)
    sample = roster.get("sample")
    held = roster.get("held")
    if not isinstance(sample, list) or not isinstance(held, list):
        raise TypeError("POP909 sample and held fields must be arrays")
    if set(sample) & set(held):
        raise ValueError("POP909 sample and held rosters overlap")
    pop909_pieces = [
        SourcePiece(
            "pop909",
            f"pop909/{song_id}",
            pop909_root / song_id / f"{song_id}.mid",
            song_id,
        )
        for song_id in sample
    ]

    wir_split = _load_json(WIR_SPLIT)
    wir_development = wir_split["splits"]["development"]
    wir_test_ids = {entry["id"] for entry in wir_split["splits"]["test"]}
    wir_pieces = []
    for entry in wir_development:
        piece_id = entry["id"]
        if piece_id in wir_test_ids:
            raise ValueError(f"When in Rome development/test overlap: {piece_id}")
        path = WIR_FIXTURE_ROOT / f"{piece_id}.json"
        wir_pieces.append(SourcePiece("when-in-rome", piece_id, path, piece_id))

    expected_counts = {"asap": 23, "pop909": 101, "when-in-rome": 59}
    plan = {
        "asap": asap_pieces,
        "pop909": pop909_pieces,
        "when-in-rome": wir_pieces,
    }
    for name, pieces in plan.items():
        if len(pieces) != expected_counts[name]:
            raise ValueError(
                f"{name} plan has {len(pieces)} pieces, expected {expected_counts[name]}"
            )
        ids = [piece.piece_id for piece in pieces]
        if len(ids) != len(set(ids)):
            raise ValueError(f"{name} plan contains duplicate piece IDs")
        paths = [piece.path.resolve() for piece in pieces]
        if len(paths) != len(set(paths)):
            raise ValueError(f"{name} plan contains duplicate source paths")
        missing = [str(piece.path) for piece in pieces if not piece.path.is_file()]
        if missing:
            raise FileNotFoundError(f"missing {name} source files: {missing}")
    return {
        name: [
            replace(piece, source_sha256=sha256_file(piece.path)) for piece in pieces
        ]
        for name, pieces in plan.items()
    }


def read_midi_messages(
    path: Path, *, selected_channels: set[int] | None = None
) -> tuple[list[RawMidiMessage], int, dict]:
    """Read relevant messages in Mido's deterministic merged order."""

    try:
        import mido
    except ImportError as error:
        raise RuntimeError("mido is required; use ./.venv/bin/python") from error

    midi = mido.MidiFile(path)
    messages = []
    counts: Counter[str] = Counter()
    clock_seconds = 0.0
    for message in midi:
        clock_seconds += message.time
        timestamp_ms = round(clock_seconds * 1000)
        if not hasattr(message, "channel"):
            continue
        if selected_channels is not None and message.channel not in selected_channels:
            if message.type in ("note_on", "note_off", "control_change"):
                counts["excludedChannelMessages"] += 1
            continue
        if message.type == "note_on":
            messages.append(
                RawMidiMessage(
                    timestamp_ms,
                    "noteOn" if message.velocity > 0 else "noteOff",
                    channel=message.channel,
                    midi_note=message.note,
                    velocity=message.velocity,
                )
            )
        elif message.type == "note_off":
            messages.append(
                RawMidiMessage(
                    timestamp_ms,
                    "noteOff",
                    channel=message.channel,
                    midi_note=message.note,
                    velocity=message.velocity,
                )
            )
        elif message.type == "control_change" and message.control in {
            PEDAL_CONTROLLER,
            ALL_SOUND_OFF_CONTROLLER,
            ALL_NOTES_OFF_CONTROLLER,
        }:
            messages.append(
                RawMidiMessage(
                    timestamp_ms,
                    "controlChange",
                    channel=message.channel,
                    controller=message.control,
                    value=message.value,
                )
            )
        elif message.type == "control_change":
            counts["ignoredOtherControlChanges"] += 1
    counts["relevantMessages"] = len(messages)
    return messages, round(clock_seconds * 1000), dict(sorted(counts.items()))


def pop909_projection(path: Path) -> tuple[set[int], dict]:
    """Resolve the frozen BRIDGE+PIANO projection without reading labels."""

    try:
        import mido
    except ImportError as error:
        raise RuntimeError("mido is required; use ./.venv/bin/python") from error

    midi = mido.MidiFile(path)
    named_tracks = []
    channels_by_track: dict[str, set[int]] = {}
    for track in midi.tracks:
        names = [message.name for message in track if message.type == "track_name"]
        if len(names) > 1:
            raise ValueError(f"{path} has multiple names on one track: {names}")
        if not names:
            continue
        name = names[0]
        named_tracks.append(name)
        channels_by_track[name] = {
            message.channel for message in track if hasattr(message, "channel")
        }
    if tuple(named_tracks) != EXPECTED_POP909_TRACK_NAMES:
        raise ValueError(
            f"{path} named tracks are {tuple(named_tracks)}, "
            f"expected {EXPECTED_POP909_TRACK_NAMES}"
        )
    if any(len(channels_by_track[name]) != 1 for name in named_tracks):
        raise ValueError(f"{path} named tracks must each use one channel")
    channel_owners: dict[int, list[str]] = {}
    for name, channels in channels_by_track.items():
        for channel in channels:
            channel_owners.setdefault(channel, []).append(name)
    shared = {key: value for key, value in channel_owners.items() if len(value) > 1}
    if shared:
        raise ValueError(f"{path} named tracks share channels: {shared}")
    selected = set().union(
        *(channels_by_track[name] for name in SELECTED_POP909_TRACK_NAMES)
    )
    return selected, {
        "namedTrackOrder": named_tracks,
        "channelsByTrack": {
            name: sorted(channels_by_track[name]) for name in named_tracks
        },
        "selectedTrackNames": list(SELECTED_POP909_TRACK_NAMES),
        "selectedChannels": sorted(selected),
        "excludedTrackNames": ["MELODY"],
        "channelHandling": "discarded after named-track selection",
    }


def normalize_midi_messages(
    messages: list[RawMidiMessage], end_timestamp_ms: int
) -> dict:
    """Mirror current MidiNoteState transitions and emit observable frames."""

    pressed: set[int] = set()
    sustained: set[int] = set()
    pedal_down = False
    events = []
    frames = []
    counts: Counter[str] = Counter(rawRelevantMessages=len(messages))
    last_timestamp = 0

    for raw_index, message in enumerate(messages):
        if message.timestamp_ms < last_timestamp:
            raise ValueError(f"raw message {raw_index} timestamps decrease")
        if message.timestamp_ms > end_timestamp_ms:
            raise ValueError(f"raw message {raw_index} occurs after MIDI end")
        last_timestamp = message.timestamp_ms
        before = (frozenset(pressed), frozenset(sustained), pedal_down)

        if message.type == "noteOn":
            _require_note_message(message, raw_index)
            if message.midi_note in pressed:
                counts["repeatedNoteOnMessages"] += 1
            pressed.add(message.midi_note)
            sustained.discard(message.midi_note)
            event_type = "noteOn"
        elif message.type == "noteOff":
            _require_note_message(message, raw_index)
            if message.midi_note not in pressed:
                counts["unmatchedNoteOffMessages"] += 1
            pressed.discard(message.midi_note)
            if pedal_down:
                sustained.add(message.midi_note)
            else:
                sustained.discard(message.midi_note)
            event_type = "noteOff"
        elif message.type == "controlChange":
            if message.controller == PEDAL_CONTROLLER:
                if message.value is None:
                    raise ValueError(f"raw message {raw_index} lacks a CC value")
                next_pedal = message.value >= 64
                if next_pedal == pedal_down:
                    counts["repeatedPedalMessages"] += 1
                if pedal_down and not next_pedal:
                    sustained.clear()
                pedal_down = next_pedal
                event_type = "pedal"
            elif message.controller == ALL_NOTES_OFF_CONTROLLER:
                pressed.clear()
                sustained.clear()
                event_type = "allNotesOff"
            elif message.controller == ALL_SOUND_OFF_CONTROLLER:
                counts["ignoredAllSoundOffMessages"] += 1
                event_type = "ignoredAllSoundOff"
            else:
                raise ValueError(
                    f"raw message {raw_index} has unsupported controller "
                    f"{message.controller}"
                )
        else:
            raise ValueError(f"raw message {raw_index} has type {message.type!r}")

        after = (frozenset(pressed), frozenset(sustained), pedal_down)
        if after == before:
            counts["noObservableChangeMessages"] += 1
            continue
        event = {
            "index": len(events),
            "rawMessageIndex": raw_index,
            "timestampMs": message.timestamp_ms,
            "type": event_type,
            "sourceChannel": message.channel,
        }
        if message.midi_note is not None:
            event["midiNote"] = message.midi_note
            event["velocity"] = message.velocity
        if message.controller == PEDAL_CONTROLLER:
            event["down"] = pedal_down
            event["controller"] = PEDAL_CONTROLLER
        elif message.controller == ALL_NOTES_OFF_CONTROLLER:
            event["controller"] = ALL_NOTES_OFF_CONTROLLER
        events.append(event)
        frames.append(
            {
                "afterEventIndex": len(frames),
                "timestampMs": message.timestamp_ms,
                "pressedMidiNotes": sorted(pressed),
                "sustainedMidiNotes": sorted(sustained),
                "soundingMidiNotes": sorted(pressed | sustained),
                "pedalDown": pedal_down,
            }
        )

    counts["normalizedEvents"] = len(events)
    return {
        "events": events,
        "frames": frames,
        "endTimestampMs": end_timestamp_ms,
        "normalization": dict(sorted(counts.items())),
    }


def _require_note_message(message: RawMidiMessage, index: int) -> None:
    if message.midi_note is None or not 0 <= message.midi_note <= 127:
        raise ValueError(f"raw message {index} lacks a valid MIDI note")
    if message.velocity is None or not 0 <= message.velocity <= 127:
        raise ValueError(f"raw message {index} lacks a valid velocity")


class DartBatch:
    """One persistent process for label-blind pure-Dart piece analysis."""

    def __init__(self) -> None:
        self.stderr_output = ""
        self.process = subprocess.Popen(
            ["dart", "run", str(DART_BATCH.relative_to(REPO_ROOT))],
            cwd=REPO_ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

    def analyze(self, request: dict) -> dict:
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("Dart batch streams are unavailable")
        self.process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            stderr = self.process.stderr.read() if self.process.stderr else ""
            raise RuntimeError(f"Dart batch ended before a response: {stderr}")
        result = json.loads(line)
        if result.get("schema") != DART_PIECE_SCHEMA:
            raise ValueError("Dart batch returned an unexpected schema")
        if result.get("id") != request.get("id"):
            raise ValueError("Dart batch response ID does not match its request")
        return result

    def close(self) -> str:
        if self.process.stdin is not None and not self.process.stdin.closed:
            try:
                self.process.stdin.close()
            except BrokenPipeError:
                pass
        stderr = self.process.stderr.read() if self.process.stderr else ""
        return_code = self.process.wait()
        if return_code:
            raise RuntimeError(f"Dart batch exited {return_code}: {stderr}")
        self.stderr_output = stderr
        return stderr

    def __enter__(self) -> Self:
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        if self.process.poll() is None:
            if exc_type is None:
                self.close()
            else:
                self.process.terminate()
                self.process.wait()


def event_stream_request(piece_id: str, normalized: dict) -> dict:
    """Create the exact label-free payload accepted by the Dart batch."""

    return {
        "kind": "eventStream",
        "id": piece_id,
        "endTimestampMs": normalized["endTimestampMs"],
        "frames": normalized["frames"],
    }


def validate_event_result(request: dict, result: dict) -> None:
    if result.get("kind") != "eventStream":
        raise ValueError("Dart batch returned the wrong piece kind")
    expected_frames = request["frames"]
    actual_frames = result.get("frames")
    if not isinstance(actual_frames, list) or len(actual_frames) != len(
        expected_frames
    ):
        raise ValueError("Dart event-frame accounting differs from its request")
    observation_fields = (
        "afterEventIndex",
        "timestampMs",
        "pressedMidiNotes",
        "sustainedMidiNotes",
        "soundingMidiNotes",
        "pedalDown",
    )
    for index, (expected, actual) in enumerate(zip(expected_frames, actual_frames)):
        for field in observation_fields:
            if actual.get(field) != expected[field]:
                raise ValueError(
                    f"Dart frame {index} changed observation field {field}"
                )
    profiles = result.get("profiles")
    if not isinstance(profiles, dict) or set(profiles) != set(SELECTOR_IDS):
        raise ValueError("Dart result does not contain the four frozen profiles")
    for selector_id, profile in profiles.items():
        if profile.get("selectorId") != selector_id:
            raise ValueError(f"Dart profile ID mismatch for {selector_id}")
        if profile["frameCounts"].get("total", 0) != len(actual_frames):
            raise ValueError(f"Dart frame total mismatch for {selector_id}")
        episodes = profile["stableEpisodes"]
        displayed_ms = sum(episode["durationMs"] for episode in episodes)
        if displayed_ms != profile["displayedMs"]:
            raise ValueError(f"Dart display-duration mismatch for {selector_id}")
        appearances = profile["transitionCounts"].get("appearance", 0)
        changes = profile["transitionCounts"].get("change", 0)
        if len(episodes) != appearances + changes:
            raise ValueError(
                f"Dart stable-episode accounting mismatch for {selector_id}"
            )
        for episode_index, episode in enumerate(episodes):
            if episode["episodeIndex"] != episode_index:
                raise ValueError(f"Dart episode indexes differ for {selector_id}")
            if episode["durationMs"] != episode["endMs"] - episode["startMs"]:
                raise ValueError(f"Dart episode duration differs for {selector_id}")
            assigned = sorted(
                episode["selected"]["lower"]["midiNotes"]
                + episode["selected"]["upper"]["midiNotes"]
            )
            if assigned != episode["soundingMidiNotes"]:
                raise ValueError(f"Dart episode assignment differs for {selector_id}")
            if episode.get("selectionEvidence") is None:
                raise ValueError(f"Dart episode lacks evidence for {selector_id}")


def validate_committed_result(request: dict, result: dict) -> None:
    if result.get("kind") != "committedEvents":
        raise ValueError("Dart batch returned the wrong piece kind")
    expected_events = request["events"]
    actual_events = result.get("events")
    if not isinstance(actual_events, list) or len(actual_events) != len(
        expected_events
    ):
        raise ValueError("Dart committed-event accounting differs from its request")
    observation_fields = ("id", "timestampMs", "durationMs", "midiNotes")
    for index, (expected, actual) in enumerate(zip(expected_events, actual_events)):
        for field in observation_fields:
            if actual.get(field) != expected[field]:
                raise ValueError(
                    f"Dart event {index} changed observation field {field}"
                )
        profiles = actual.get("profiles")
        if not isinstance(profiles, dict) or set(profiles) != set(SELECTOR_IDS):
            raise ValueError(f"Dart event {index} lacks the four frozen profiles")


def when_in_rome_request(piece: SourcePiece) -> tuple[dict, dict]:
    """Project one committed fixture without touching its labels or candidates."""

    _verify_piece_source(piece)
    fixture = _load_json(piece.path)
    if fixture.get("id") != f"when-in-rome-v1/{piece.piece_id}":
        raise ValueError(f"fixture ID does not match split entry: {piece.path}")
    events = []
    for index, event in enumerate(fixture.get("events", [])):
        events.append(
            {
                "id": f"{piece.piece_id}/event-{index}",
                "timestampMs": event["timestampMs"],
                "durationMs": event["durationMs"],
                "midiNotes": event["midiNotes"],
            }
        )
    return (
        {"kind": "committedEvents", "id": piece.piece_id, "events": events},
        {
            "sourcePath": str(piece.path.relative_to(REPO_ROOT)),
            "sourceSha256": piece.source_sha256,
            "fixtureSchema": fixture.get("schema"),
            "committedEventCount": len(events),
            "labelsSuppliedToDart": False,
            "storedCandidatesSuppliedToDart": False,
        },
    )


def _empty_aggregate_profile() -> dict:
    return {
        "frameCounts": Counter(),
        "dwellMs": Counter(),
        "transitionCounts": Counter(),
        "selectorReasonCounts": Counter(),
        "clearReasonCounts": Counter(),
        "traceCounts": Counter(),
        "suppressedUnstableSelections": 0,
        "appearanceLatenciesMs": [],
        "episodeDurationsMs": [],
        "displayedMs": 0,
        "stableEpisodes": 0,
        "distinctIdentities": {},
        "distinctAssignments": {},
    }


def add_profile_summary(total: dict, piece_id: str, profile: dict) -> None:
    for field in (
        "frameCounts",
        "dwellMs",
        "transitionCounts",
        "selectorReasonCounts",
        "clearReasonCounts",
        "traceCounts",
    ):
        total[field].update(profile[field])
    total["suppressedUnstableSelections"] += profile["suppressedUnstableSelections"]
    total["appearanceLatenciesMs"].extend(profile["appearanceLatenciesMs"])
    total["episodeDurationsMs"].extend(
        episode["durationMs"] for episode in profile["stableEpisodes"]
    )
    total["displayedMs"] += profile["displayedMs"]
    total["stableEpisodes"] += len(profile["stableEpisodes"])
    for identity in profile["distinctIdentities"]:
        total["distinctIdentities"][canonical_json(identity)] = identity
    for assignment in profile["distinctAssignments"]:
        total["distinctAssignments"][canonical_json(assignment)] = assignment


def finalize_profile_summary(total: dict) -> dict:
    latencies = total["appearanceLatenciesMs"]
    return {
        "frameCounts": dict(sorted(total["frameCounts"].items())),
        "dwellMs": dict(sorted(total["dwellMs"].items())),
        "transitionCounts": dict(sorted(total["transitionCounts"].items())),
        "selectorReasonCounts": dict(sorted(total["selectorReasonCounts"].items())),
        "clearReasonCounts": dict(sorted(total["clearReasonCounts"].items())),
        "traceCounts": dict(sorted(total["traceCounts"].items())),
        "suppressedUnstableSelections": total["suppressedUnstableSelections"],
        "appearanceLatencyMs": distribution(latencies),
        "episodeDurationMs": distribution(total["episodeDurationsMs"]),
        "displayedMs": total["displayedMs"],
        "stableEpisodes": total["stableEpisodes"],
        "distinctIdentities": [
            total["distinctIdentities"][key]
            for key in sorted(total["distinctIdentities"])
        ],
        "distinctAssignments": [
            total["distinctAssignments"][key]
            for key in sorted(total["distinctAssignments"])
        ],
    }


def distribution(values: list[int]) -> dict:
    if not values:
        return {"n": 0, "min": None, "median": None, "p90": None, "max": None}
    ordered = sorted(values)

    def nearest_rank(fraction: float) -> int:
        rank = max(1, math.ceil(fraction * len(ordered)))
        return ordered[rank - 1]

    return {
        "n": len(ordered),
        "min": ordered[0],
        "median": nearest_rank(0.5),
        "p90": nearest_rank(0.9),
        "max": ordered[-1],
    }


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def sha256_json(value: object) -> str:
    return hashlib.sha256(canonical_json(value).encode()).hexdigest()


def note_name(midi_note: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi_note % 12]}{midi_note // 12 - 1}"


def notes_text(notes: Iterable[int]) -> str:
    return " ".join(note_name(note) for note in notes)


def _layer_long(layer: dict) -> str:
    root = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")[
        layer["rootPc"]
    ]
    quality = {
        "major": "major",
        "minor": "minor",
        "dominant7": "dominant seventh",
        "major7": "major seventh",
        "minor7": "minor seventh",
    }[layer["quality"]]
    return f"{root} {quality}"


def _primary_text(primary: dict | None) -> str:
    if primary is None:
        return "Unavailable"
    symbol = primary.get("symbol")
    long_label = primary.get("longLabel")
    if isinstance(symbol, str) and isinstance(long_label, str):
        return f"{symbol} ({long_label})"
    return "Identity available in the machine record"


def _primary_timeline_text(item: dict) -> str:
    changes = item.get("surroundingPrimaryChanges", [])
    if not changes:
        return _primary_text(item.get("primary"))
    return "; ".join(
        f"{change['timestampMs']} ms: {_primary_text(change['primary'])}"
        for change in changes
    )


def render_timeline_svg(normalized: dict, episode: dict) -> str:
    """Render a time-scaled piano-roll view around one stable episode."""

    start_ms = max(0, episode["startMs"] - 1000)
    end_ms = min(normalized["endTimestampMs"], episode["endMs"] + 1000)
    if end_ms <= start_ms:
        end_ms = start_ms + 1
    frames = normalized["frames"]
    relevant = []
    for index, frame in enumerate(frames):
        frame_end = (
            frames[index + 1]["timestampMs"]
            if index + 1 < len(frames)
            else normalized["endTimestampMs"]
        )
        if frame_end >= start_ms and frame["timestampMs"] <= end_ms:
            relevant.append((frame, frame_end))
    notes = sorted(
        {note for frame, _ in relevant for note in frame["soundingMidiNotes"]},
        reverse=True,
    )
    if not notes:
        return '<p class="muted">No sounding-note timeline is available.</p>'

    width = 920
    left = 58
    plot_width = width - left - 10
    row_height = 18
    height = 38 + row_height * (len(notes) + 1)
    span = end_ms - start_ms

    def x(timestamp: int) -> float:
        return left + (timestamp - start_ms) * plot_width / span

    parts = [
        (
            f'<svg class="timeline" viewBox="0 0 {width} {height}" '
            'role="img" aria-label="Time-scaled note and pedal timeline">'
        ),
        f'<text x="{left}" y="14">{start_ms} ms</text>',
        f'<text x="{width - 10}" y="14" text-anchor="end">{end_ms} ms</text>',
    ]
    note_y = {note: 24 + row * row_height for row, note in enumerate(notes)}
    for note in notes:
        y = note_y[note]
        parts.append(f'<text x="2" y="{y + 12}">{html.escape(note_name(note))}</text>')
        parts.append(
            f'<line x1="{left}" x2="{width - 10}" y1="{y + 9}" '
            f'y2="{y + 9}" class="grid" />'
        )
    for frame, frame_end in relevant:
        interval_start = max(start_ms, frame["timestampMs"])
        interval_end = min(end_ms, frame_end)
        rectangle_width = max(0.8, x(interval_end) - x(interval_start))
        for note in frame["pressedMidiNotes"]:
            if note not in note_y:
                continue
            parts.append(
                f'<rect x="{x(interval_start):.2f}" y="{note_y[note] + 2}" '
                f'width="{rectangle_width:.2f}" height="14" class="pressed" />'
            )
        for note in frame["sustainedMidiNotes"]:
            if note not in note_y:
                continue
            parts.append(
                f'<rect x="{x(interval_start):.2f}" y="{note_y[note] + 2}" '
                f'width="{rectangle_width:.2f}" height="14" class="sustained" />'
            )
        if frame["pedalDown"]:
            pedal_y = 24 + len(notes) * row_height
            parts.append(
                f'<rect x="{x(interval_start):.2f}" y="{pedal_y + 2}" '
                f'width="{rectangle_width:.2f}" height="12" class="pedal" />'
            )
    pedal_y = 24 + len(notes) * row_height
    parts.append(f'<text x="2" y="{pedal_y + 12}">Pedal</text>')
    for event in normalized.get("events", []):
        timestamp = event["timestampMs"]
        if timestamp < start_ms or timestamp > end_ms:
            continue
        event_x = x(timestamp)
        midi_note = event.get("midiNote")
        if midi_note in note_y:
            event_y = note_y[midi_note] + 9
            css_class = "attack" if event["type"] == "noteOn" else "release"
            parts.append(
                f'<circle cx="{event_x:.2f}" cy="{event_y}" r="3.5" '
                f'class="{css_class}" />'
            )
        elif event["type"] == "pedal":
            parts.append(
                f'<circle cx="{event_x:.2f}" cy="{pedal_y + 8}" r="4" '
                'class="pedal-change" />'
            )
        elif event["type"] == "allNotesOff":
            parts.append(
                f'<line x1="{event_x:.2f}" x2="{event_x:.2f}" y1="18" '
                f'y2="{height - 2}" class="all-notes-off" />'
            )
    for timestamp, css_class, label in (
        (episode["startMs"], "appearance", "appears"),
        (episode["endMs"], "episode-end", "ends"),
    ):
        parts.append(
            f'<line x1="{x(timestamp):.2f}" x2="{x(timestamp):.2f}" y1="18" '
            f'y2="{height - 2}" class="{css_class}" />'
        )
        parts.append(
            f'<text x="{x(timestamp) + 3:.2f}" y="{height - 3}" '
            f'class="{css_class}-text">{label}</text>'
        )
    parts.append("</svg>")
    return "".join(parts)


def render_review_item(item: dict) -> str:
    selected = item["selected"]
    upper = selected["upper"]
    lower = selected["lower"]
    symbol = selected["symbol"]
    title = f"{item['corpus']} / {item['pieceId']} / {item['itemId']}"
    source_text = item["sourceTitle"]
    source_path = item["sourcePath"]
    primary_text = _primary_timeline_text(item)
    boundary_text = (
        f"lower ends at {note_name(selected['lowerTopMidi'])}; upper begins at "
        f"{note_name(selected['upperBottomMidi'])}; "
        f"{selected['gapSemitones']} semitones"
    )
    if item["kind"] == "stableDisplay":
        timeline = render_timeline_svg(item["normalized"], item["episode"])
        timing = (
            f"Appears at {item['episode']['startMs']} ms; ends at "
            f"{item['episode']['endMs']} ms; duration "
            f"{item['episode']['durationMs']} ms."
        )
    else:
        timeline = (
            '<p class="warning">This committed-event fixture has no note-event '
            "timeline. Its identity duration cannot establish that this exact "
            "assignment persisted.</p>"
        )
        timing = (
            f"Committed identity onset {item['timestampMs']} ms; duration-attributed "
            f"{item['durationMs']} ms. This is not display duration."
        )
    return f"""
<article id="{html.escape(item["itemId"])}">
  <h2>{html.escape(title)}</h2>
  <p><strong>Source:</strong> {html.escape(source_text)}<br>
    <strong>Source path:</strong> <code>{html.escape(source_path)}</code></p>
  <p class="symbol">{html.escape(symbol)}</p>
  <p>Upper chord: {html.escape(_layer_long(upper))}. Lower chord:
    {html.escape(_layer_long(lower))}.</p>
  <p><strong>Sounding notes:</strong>
    {html.escape(notes_text(item["soundingMidiNotes"]))}</p>
  <p><strong>Lower assignment:</strong>
    {html.escape(notes_text(lower["midiNotes"]))}<br>
    <strong>Upper assignment:</strong>
    {html.escape(notes_text(upper["midiNotes"]))}</p>
  <p><strong>Register boundary:</strong> {html.escape(boundary_text)}</p>
  <p><strong>Timing:</strong> {html.escape(timing)}</p>
  <p><strong>Default primary around this item:</strong>
    {html.escape(primary_text)}</p>
  {timeline}
  <dl class="review-fields">
    <dt>Disposition</dt><dd>____________________________</dd>
    <dt>Musical rationale</dt><dd>____________________________</dd>
    <dt>Evidence consulted</dt><dd>____________________________</dd>
    <dt>Reviewer and date</dt><dd>____________________________</dd>
  </dl>
</article>
"""


def render_review_html(items: list[dict]) -> str:
    body = "".join(render_review_item(item) for item in items)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Polychord development exposure review</title>
<style>
body {{ font: 17px/1.5 system-ui, sans-serif; max-width: 1100px; margin: auto;
  padding: 2rem; color: #202124; }}
article {{ border-top: 3px solid #333; margin: 3rem 0; padding-top: 1rem; }}
.symbol {{ font-size: 2rem; font-weight: 700; }}
.timeline {{ width: 100%; min-height: 260px; border: 1px solid #bbb;
  background: #fff; }}
.grid {{ stroke: #ddd; stroke-width: 1; }}
.pressed {{ fill: #2368b1; }} .sustained {{ fill: #d18b20; }}
.pedal {{ fill: #7b5ca5; opacity: .7; }}
.attack {{ fill: #198754; stroke: #fff; }}
.release {{ fill: #fff; stroke: #b02a37; stroke-width: 2; }}
.pedal-change {{ fill: #fff; stroke: #6f42c1; stroke-width: 2; }}
.all-notes-off {{ stroke: #b02a37; stroke-width: 2; stroke-dasharray: 4 3; }}
.appearance {{ stroke: #198754; stroke-width: 2; }}
.episode-end {{ stroke: #b02a37; stroke-width: 2; }}
.appearance-text {{ fill: #146c43; }} .episode-end-text {{ fill: #842029; }}
.warning {{ border-left: 5px solid #b26a00; padding: .75rem; background: #fff4dc; }}
.review-fields dt {{ font-weight: 700; margin-top: 1rem; }}
.review-fields dd {{ min-height: 2rem; margin-left: 0; }}
@media (prefers-color-scheme: dark) {{
  body {{ color: #eee; background: #171717; }} article {{ border-color: #ddd; }}
  .timeline {{ filter: invert(.88) hue-rotate(180deg); }}
  .warning {{ color: #202124; }}
}}
</style>
</head>
<body>
<h1>Polychord development exposure review</h1>
<p>This packet presents every full-selector stable display and every
proposal-only When in Rome event. It contains no suggested disposition.
The machine artifacts remain authoritative for exact values.</p>
<p>For each item, choose one frozen disposition and record a concise musical
rationale, the score, recording, or other evidence consulted, and your name and
review date. Copy <code>dispositions-template.json</code> to
<code>dispositions.json</code> before filling it; leave the template and
<code>review-index.json</code> unchanged. If later evidence changes a judgment,
append another complete judgment instead of replacing the first.</p>
<p>Legend: blue bars are physically held notes, amber bars are
pedal-sustained notes, and purple bars show the sustain pedal. Green dots mark
attacks, outlined red dots mark releases, and outlined purple dots mark pedal
changes. Green and red vertical lines mark annotation appearance and end; a
dashed red line marks an all-notes-off message.</p>
{body if body else "<p>No review items were generated.</p>"}
</body>
</html>
"""


def disposition_template(items: list[dict]) -> dict:
    return {
        "schema": DISPOSITION_SCHEMA,
        "allowedDispositions": list(ALLOWED_DISPOSITIONS),
        "items": [
            {
                "itemId": item["itemId"],
                "kind": item["kind"],
                "corpus": item["corpus"],
                "pieceId": item["pieceId"],
                "judgments": [_blank_judgment()],
            }
            for item in items
        ],
    }


def _blank_judgment() -> dict:
    return {
        "disposition": None,
        "musicalRationale": None,
        "evidenceConsulted": [],
        "reviewer": None,
        "reviewedAt": None,
    }


def review_index(items: list[dict]) -> dict:
    records = []
    for item in items:
        timing = (
            {
                "startMs": item["episode"]["startMs"],
                "endMs": item["episode"]["endMs"],
                "durationMs": item["episode"]["durationMs"],
            }
            if item["kind"] == "stableDisplay"
            else {
                "timestampMs": item["timestampMs"],
                "committedIdentityDurationAttributedMs": item["durationMs"],
            }
        )
        records.append(
            {
                "itemId": item["itemId"],
                "kind": item["kind"],
                "corpus": item["corpus"],
                "pieceId": item["pieceId"],
                "sourceTitle": item["sourceTitle"],
                "sourcePath": item["sourcePath"],
                "selected": item["selected"],
                "soundingMidiNotes": item["soundingMidiNotes"],
                "timing": timing,
            }
        )
    return {"schema": REVIEW_INDEX_SCHEMA, "items": records}


def validate_disposition_payload(
    payload: dict, expected_items: list[dict], *, require_complete: bool
) -> None:
    """Validate exact coverage while permitting append-only later judgments."""

    if not isinstance(expected_items, list):
        raise TypeError("expected review items must be an array")
    if payload.get("schema") != DISPOSITION_SCHEMA:
        raise ValueError("unexpected disposition schema")
    if payload.get("allowedDispositions") != list(ALLOWED_DISPOSITIONS):
        raise ValueError("allowed dispositions differ from the frozen schema")
    actual_items = payload.get("items")
    if not isinstance(actual_items, list):
        raise TypeError("disposition items must be an array")
    expected_by_id = {item["itemId"]: item for item in expected_items}
    if len(expected_by_id) != len(expected_items):
        raise ValueError("expected review items contain duplicate IDs")
    actual_by_id = {}
    for item in actual_items:
        if not isinstance(item, dict) or not isinstance(item.get("itemId"), str):
            raise TypeError("every disposition item must have a string itemId")
        item_id = item["itemId"]
        if item_id in actual_by_id:
            raise ValueError(f"duplicate disposition item: {item_id}")
        actual_by_id[item_id] = item
    if set(actual_by_id) != set(expected_by_id):
        missing = sorted(set(expected_by_id) - set(actual_by_id))
        extra = sorted(set(actual_by_id) - set(expected_by_id))
        raise ValueError(
            f"disposition coverage differs; missing={missing}, extra={extra}"
        )

    for item_id, expected in expected_by_id.items():
        actual = actual_by_id[item_id]
        if set(actual) != {"itemId", "kind", "corpus", "pieceId", "judgments"}:
            raise ValueError(f"{item_id} has unexpected or missing item fields")
        for field in ("kind", "corpus", "pieceId"):
            if actual.get(field) != expected[field]:
                raise ValueError(f"{item_id} {field} differs from the review index")
        judgments = actual.get("judgments")
        if not isinstance(judgments, list) or not judgments:
            raise ValueError(f"{item_id} must retain at least one judgment")
        for index, judgment in enumerate(judgments):
            _validate_judgment(
                judgment,
                context=f"{item_id}.judgments[{index}]",
                require_complete=require_complete or index > 0,
            )


def _validate_judgment(
    judgment: object, *, context: str, require_complete: bool
) -> None:
    if not isinstance(judgment, dict):
        raise TypeError(f"{context} must be an object")
    if set(judgment) != set(_blank_judgment()):
        raise ValueError(f"{context} has unexpected or missing fields")
    disposition = judgment["disposition"]
    if disposition is not None and disposition not in ALLOWED_DISPOSITIONS:
        raise ValueError(f"{context}.disposition is not frozen")
    for field in ("musicalRationale", "reviewer"):
        value = judgment[field]
        if value is not None and (not isinstance(value, str) or not value.strip()):
            raise TypeError(f"{context}.{field} must be a nonempty string or null")
    reviewed_at = judgment["reviewedAt"]
    if reviewed_at is not None:
        if not isinstance(reviewed_at, str) or not reviewed_at.strip():
            raise TypeError(f"{context}.reviewedAt must be a nonempty string or null")
        try:
            datetime.fromisoformat(reviewed_at.replace("Z", "+00:00"))
        except ValueError as error:
            raise ValueError(f"{context}.reviewedAt must be ISO 8601") from error
    evidence = judgment["evidenceConsulted"]
    if not isinstance(evidence, list) or any(
        not isinstance(value, str) or not value.strip() for value in evidence
    ):
        raise TypeError(f"{context}.evidenceConsulted must be a string array")
    if not require_complete:
        return
    for field in ("disposition", "musicalRationale", "reviewer", "reviewedAt"):
        value = judgment[field]
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{context}.{field} is required")
    if not evidence:
        raise ValueError(f"{context}.evidenceConsulted is required")


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def safe_piece_filename(piece_id: str) -> str:
    return hashlib.sha256(piece_id.encode()).hexdigest()[:16] + ".json"


def _verify_piece_source(piece: SourcePiece) -> None:
    actual = sha256_file(piece.path)
    if actual != piece.source_sha256:
        raise ValueError(
            f"{piece.corpus} source changed after plan resolution: {piece.path}"
        )


def _piece_source_record(piece: SourcePiece) -> dict:
    _verify_piece_source(piece)
    return {
        "pieceId": piece.piece_id,
        "sourceTitle": piece.source_title,
        "sourcePath": str(piece.path),
        "sourceSha256": piece.source_sha256,
    }


def source_plan_provenance(plan: dict[str, list[SourcePiece]]) -> dict:
    result = {}
    for corpus, pieces in plan.items():
        records = [
            {
                "pieceId": piece.piece_id,
                "sourceTitle": piece.source_title,
                "sourcePath": str(piece.path),
                "sourceSha256": piece.source_sha256,
            }
            for piece in pieces
        ]
        result[corpus] = {
            "pieceCount": len(records),
            "aggregateContentSha256": sha256_json(
                [
                    {key: value for key, value in record.items() if key != "sourcePath"}
                    for record in records
                ]
            ),
            "pieces": records,
        }
    result["asap"]["sourceCommit"] = ASAP_COMMIT
    result["asap"]["splitPath"] = str(ASAP_SPLIT.relative_to(REPO_ROOT))
    result["asap"]["splitSha256"] = ASAP_SPLIT_SHA256
    result["pop909"]["sourceCommit"] = POP909_COMMIT
    result["pop909"]["rosterPath"] = str(POP909_ROSTER.relative_to(REPO_ROOT))
    result["pop909"]["rosterSha256"] = POP909_ROSTER_SHA256
    result["when-in-rome"]["splitPath"] = str(WIR_SPLIT.relative_to(REPO_ROOT))
    result["when-in-rome"]["splitSha256"] = WIR_SPLIT_SHA256
    return result


def verify_source_plan(plan: dict[str, list[SourcePiece]]) -> None:
    for pieces in plan.values():
        for piece in pieces:
            _verify_piece_source(piece)


def _context_warnings(dart_result: dict) -> int:
    values = []
    if dart_result["kind"] == "eventStream":
        values = [frame.get("primaryContextAudit") for frame in dart_result["frames"]]
    else:
        values = [event.get("primaryContextAudit") for event in dart_result["events"]]
    return sum(
        audit is not None and not audit["availabilityInvariant"] for audit in values
    )


def _surrounding_primary_changes(dart_result: dict, episode: dict) -> list[dict]:
    start_ms = max(0, episode["startMs"] - 1000)
    end_ms = episode["endMs"] + 1000
    changes = []
    previous_identity = object()
    for frame in dart_result["frames"]:
        if frame["timestampMs"] < start_ms or frame["timestampMs"] > end_ms:
            continue
        primary = frame["primary"]
        identity = None if primary is None else primary["identity"]
        serialized = canonical_json(identity)
        if serialized == previous_identity:
            continue
        changes.append({"timestampMs": frame["timestampMs"], "primary": primary})
        previous_identity = serialized
    return changes


def _stable_review_items(
    piece: SourcePiece, normalized: dict, dart_result: dict
) -> list[dict]:
    items = []
    profile = dart_result["profiles"][FULL_SELECTOR_ID]
    for episode in profile["stableEpisodes"]:
        item_id = f"{piece.corpus}:{piece.piece_id}:display-{episode['episodeIndex']}"
        items.append(
            {
                "itemId": item_id,
                "kind": "stableDisplay",
                "corpus": piece.corpus,
                "pieceId": piece.piece_id,
                "sourceTitle": piece.source_title,
                "sourcePath": str(piece.path),
                "selected": episode["selected"],
                "soundingMidiNotes": episode["soundingMidiNotes"],
                "primary": episode["primary"],
                "surroundingPrimaryChanges": _surrounding_primary_changes(
                    dart_result, episode
                ),
                "episode": episode,
                "normalized": normalized,
            }
        )
    return items


def _wir_review_items(piece: SourcePiece, dart_result: dict) -> list[dict]:
    items = []
    for event in dart_result["events"]:
        profile = event["profiles"][FULL_SELECTOR_ID]
        selected = profile["decision"]["selected"]
        if selected is None or profile["outerReasonCodes"]:
            continue
        items.append(
            {
                "itemId": f"when-in-rome:{event['id']}",
                "kind": "committedEventProposal",
                "corpus": "when-in-rome",
                "pieceId": piece.piece_id,
                "sourceTitle": piece.source_title,
                "sourcePath": str(piece.path),
                "selected": selected,
                "soundingMidiNotes": event["midiNotes"],
                "primary": event["primary"],
                "timestampMs": event["timestampMs"],
                "durationMs": event["durationMs"],
            }
        )
    return items


def run_event_corpus(
    *,
    name: str,
    measurement_id: str,
    pieces: list[SourcePiece],
    output_root: Path,
    dart: DartBatch,
) -> tuple[dict, list[dict], list[dict]]:
    aggregates = {
        selector_id: _empty_aggregate_profile() for selector_id in SELECTOR_IDS
    }
    normalizations: Counter[str] = Counter()
    review_items = []
    piece_index = []
    context_warnings = 0
    for piece in pieces:
        projection = None
        if name == "pop909":
            selected_channels, projection = pop909_projection(piece.path)
            messages, end_timestamp_ms, read_counts = read_midi_messages(
                piece.path, selected_channels=selected_channels
            )
        else:
            messages, end_timestamp_ms, read_counts = read_midi_messages(piece.path)
        normalized = normalize_midi_messages(messages, end_timestamp_ms)
        request = event_stream_request(piece.piece_id, normalized)
        dart_result = dart.analyze(request)
        validate_event_result(request, dart_result)
        context_warnings += _context_warnings(dart_result)
        normalizations.update(read_counts)
        normalizations.update(normalized["normalization"])
        for selector_id in SELECTOR_IDS:
            add_profile_summary(
                aggregates[selector_id],
                piece.piece_id,
                dart_result["profiles"][selector_id],
            )
        review_items.extend(_stable_review_items(piece, normalized, dart_result))
        payload = {
            "schema": REPORT_SCHEMA,
            "measurementId": measurement_id,
            "source": {
                **_piece_source_record(piece),
                "projection": projection,
                "readCounts": read_counts,
                "normalization": normalized["normalization"],
                "events": normalized["events"],
                "endTimestampMs": normalized["endTimestampMs"],
                "labelsRead": False,
            },
            "analysis": dart_result,
        }
        relative = Path("pieces") / name / safe_piece_filename(piece.piece_id)
        write_json(output_root / relative, payload)
        piece_index.append(
            {
                "pieceId": piece.piece_id,
                "path": str(relative),
                "sha256": sha256_file(output_root / relative),
            }
        )
    summary = {
        "schema": REPORT_SCHEMA,
        "measurementId": measurement_id,
        "corpus": name,
        "pieceCount": len(pieces),
        "contextAvailabilityWarnings": context_warnings,
        "normalization": dict(sorted(normalizations.items())),
        "profiles": {
            selector_id: finalize_profile_summary(aggregates[selector_id])
            for selector_id in SELECTOR_IDS
        },
        "pieces": piece_index,
    }
    return summary, review_items, piece_index


def run_wir_corpus(
    pieces: list[SourcePiece], output_root: Path, dart: DartBatch
) -> tuple[dict, list[dict], list[dict]]:
    counts = {
        selector_id: {
            "committedEvents": 0,
            "committedEventDurationAttributedMs": 0,
            "committedEventsWithCandidates": 0,
            "committedEventProposals": 0,
            "committedIdentityDurationAttributedMs": 0,
            "selectorReasonCounts": Counter(),
        }
        for selector_id in SELECTOR_IDS
    }
    piece_index = []
    review_items = []
    context_warnings = 0
    for piece in pieces:
        request, source = when_in_rome_request(piece)
        dart_result = dart.analyze(request)
        _verify_piece_source(piece)
        validate_committed_result(request, dart_result)
        context_warnings += _context_warnings(dart_result)
        for event in dart_result["events"]:
            for selector_id in SELECTOR_IDS:
                profile = event["profiles"][selector_id]
                decision = profile["decision"]
                target = counts[selector_id]
                target["committedEvents"] += 1
                target["committedEventDurationAttributedMs"] += event["durationMs"]
                target["committedEventsWithCandidates"] += bool(decision["candidates"])
                for reason in decision["reasonCodes"]:
                    target["selectorReasonCounts"][reason] += 1
                if decision["selected"] is not None and not profile["outerReasonCodes"]:
                    target["committedEventProposals"] += 1
                    target["committedIdentityDurationAttributedMs"] += event[
                        "durationMs"
                    ]
        review_items.extend(_wir_review_items(piece, dart_result))
        payload = {
            "schema": REPORT_SCHEMA,
            "measurementId": WIR_MEASUREMENT_ID,
            "source": source,
            "analysis": dart_result,
        }
        relative = Path("pieces/when-in-rome") / safe_piece_filename(piece.piece_id)
        write_json(output_root / relative, payload)
        piece_index.append(
            {
                "pieceId": piece.piece_id,
                "path": str(relative),
                "sha256": sha256_file(output_root / relative),
            }
        )
    return (
        {
            "schema": REPORT_SCHEMA,
            "measurementId": WIR_MEASUREMENT_ID,
            "corpus": "when-in-rome",
            "role": "committed-event-proposals-only",
            "pieceCount": len(pieces),
            "contextAvailabilityWarnings": context_warnings,
            "profiles": {
                selector_id: {
                    **{
                        key: value
                        for key, value in target.items()
                        if key != "selectorReasonCounts"
                    },
                    "selectorReasonCounts": dict(
                        sorted(target["selectorReasonCounts"].items())
                    ),
                }
                for selector_id, target in counts.items()
            },
            "pieces": piece_index,
        },
        review_items,
        piece_index,
    )


def contract_pins() -> list[dict]:
    return [
        {
            "path": str(path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(path),
        }
        for path in CONTRACT_PATHS
    ]


def all_output_hashes(output_root: Path) -> dict[str, dict]:
    outputs = {}
    for path in sorted(output_root.rglob("*")):
        if not path.is_file() or path.name == "manifest.json":
            continue
        relative = str(path.relative_to(output_root))
        outputs[relative] = {"path": relative, "sha256": sha256_file(path)}
    return outputs


def repository_worktree_dirty() -> bool:
    return bool(git(REPO_ROOT, "status", "--porcelain"))


def main() -> int:
    args = parse_args()
    output_root = require_output_directory(args.out_directory)
    plan = load_source_plan(args.asap_root.resolve(), args.pop909_root.resolve())
    sources = source_plan_provenance(plan)
    if repository_worktree_dirty():
        raise SystemExit("repository is dirty; run only from the committed boundary")

    output_root.mkdir(parents=True)
    review_items = []
    with DartBatch() as dart:
        asap_summary, asap_review, _ = run_event_corpus(
            name="asap",
            measurement_id=ASAP_MEASUREMENT_ID,
            pieces=plan["asap"],
            output_root=output_root,
            dart=dart,
        )
        review_items.extend(asap_review)
        pop_summary, pop_review, _ = run_event_corpus(
            name="pop909",
            measurement_id=POP909_MEASUREMENT_ID,
            pieces=plan["pop909"],
            output_root=output_root,
            dart=dart,
        )
        review_items.extend(pop_review)
        wir_summary, wir_review, _ = run_wir_corpus(
            plan["when-in-rome"], output_root, dart
        )
        review_items.extend(wir_review)

    write_json(output_root / "asap-summary.json", asap_summary)
    write_json(output_root / "pop909-summary.json", pop_summary)
    write_json(output_root / "when-in-rome-summary.json", wir_summary)
    review_items.sort(key=lambda item: item["itemId"])
    (output_root / "review.html").write_text(render_review_html(review_items))
    index = review_index(review_items)
    template = disposition_template(review_items)
    validate_disposition_payload(template, index["items"], require_complete=False)
    write_json(output_root / "review-index.json", index)
    write_json(output_root / "dispositions-template.json", template)

    verify_source_plan(plan)
    repository_dirty = repository_worktree_dirty()
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(sys.orig_argv),
        "workingDirectory": str(Path.cwd()),
        "repositoryCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
        "repositoryDirty": repository_dirty,
        "runtime": {
            "pythonVersion": platform.python_version(),
            "dartVersion": subprocess.run(
                ["dart", "--version"], capture_output=True, text=True, check=True
            ).stderr.strip(),
            "midoVersion": importlib.metadata.version("mido"),
            "dartBatchStderr": dart.stderr_output.splitlines(),
        },
        "isolation": {
            "asapDevelopmentPieces": len(plan["asap"]),
            "asapTestMidiOpened": False,
            "pop909SampleSongs": len(plan["pop909"]),
            "pop909HeldSongsOpened": False,
            "whenInRomeDevelopmentPieces": len(plan["when-in-rome"]),
            "whenInRomeStableDisplayEligible": False,
            "corpusLabelsSuppliedToAnalysis": False,
        },
        "sources": sources,
        "contracts": contract_pins(),
        "reviewItemCount": len(review_items),
        "outputs": all_output_hashes(output_root),
    }
    write_json(output_root / "manifest.json", manifest)
    if repository_dirty:
        raise SystemExit("repository changed during measurement; output is invalid")
    print(
        f"{len(plan['asap'])} ASAP + {len(plan['pop909'])} POP909 + "
        f"{len(plan['when-in-rome'])} When in Rome pieces; "
        f"{len(review_items)} review items -> {output_root}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

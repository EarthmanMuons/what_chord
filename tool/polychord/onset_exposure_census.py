"""Measure fixed register and onset-support exposure on the POP909 sample.

The corpus report is descriptive and label-free. It always reads the previously
exposed ``sample`` roster and requires corpus-derived detail to remain under
``build/``. The held POP909 pool is not selectable by this tool.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import shlex
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import frame_replay
import onset_evidence
import onset_support
import register_candidates

REPO_ROOT = Path(__file__).parents[2]
REPORT_SCHEMA = "polychord-onset-exposure-census/1"
MEASUREMENT_ID = "pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1"
ROSTER_SCHEMA = "performed-input-held-pool/1"
FROZEN_ROSTER_SHA256 = (
    "b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781"
)
PEDAL_CONTROLLER = 64
UNSUPPORTED_RESET_CONTROLLERS = {120, 123}
EXPECTED_TRACK_NAMES = ("MELODY", "BRIDGE", "PIANO")
SELECTED_TRACK_NAMES = ("BRIDGE", "PIANO")

DEFAULT_POP909_ROOT = REPO_ROOT / "build/whatkey-corpora/POP909-Dataset/POP909"
DEFAULT_ROSTER = REPO_ROOT / "research/performed-input/data/pop909-held-pool.json"

CONTRACT_PATHS = (
    REPO_ROOT / "research/polychord/frame-replay-schema.md",
    REPO_ROOT / "tool/polychord/frame_replay.py",
    REPO_ROOT / "research/polychord/register-candidate-schema.md",
    REPO_ROOT / "tool/polychord/register_candidates.py",
    REPO_ROOT / "research/polychord/onset-evidence-schema.md",
    REPO_ROOT / "tool/polychord/onset_evidence.py",
    REPO_ROOT / "research/polychord/onset-support-ablation.md",
    REPO_ROOT / "tool/polychord/onset_support.py",
    REPO_ROOT / "research/polychord/onset-exposure-census.md",
    REPO_ROOT / "tool/polychord/onset_exposure_census.py",
)


@dataclass(frozen=True)
class MidiInputMessage:
    """One timestamped MIDI message relevant to the measurement substrate."""

    timestamp_ms: int
    type: str
    channel: int = 0
    midi_note: int | None = None
    velocity: int | None = None
    pedal_down: bool | None = None
    controller: int | None = None


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def aggregate_file_hash(paths: list[tuple[str, Path]]) -> str:
    """Hash logical names and exact file digests in declared order."""

    digest = hashlib.sha256()
    for logical_name, path in paths:
        digest.update(logical_name.encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def load_sample_song_ids(path: Path) -> list[str]:
    payload = json.loads(path.read_text())
    if payload.get("schema") != ROSTER_SCHEMA:
        raise ValueError(f"roster.schema must be {ROSTER_SCHEMA!r}")
    sample = payload.get("sample")
    held = payload.get("held")
    if not isinstance(sample, list) or not isinstance(held, list):
        raise TypeError("roster sample and held fields must be arrays")
    if any(
        not isinstance(song_id, str) or len(song_id) != 3 or not song_id.isdigit()
        for song_id in sample + held
    ):
        raise ValueError("roster song identifiers must be three decimal digits")
    if sample != sorted(set(sample)) or held != sorted(set(held)):
        raise ValueError("roster sample and held fields must be sorted and unique")
    overlap = set(sample) & set(held)
    if overlap:
        raise ValueError(f"roster sample and held fields overlap: {sorted(overlap)}")
    return sample


def load_frozen_sample_song_ids() -> list[str]:
    digest = sha256_file(DEFAULT_ROSTER)
    if digest != FROZEN_ROSTER_SHA256:
        raise ValueError(
            f"frozen POP909 roster digest is {digest}, expected {FROZEN_ROSTER_SHA256}"
        )
    return load_sample_song_ids(DEFAULT_ROSTER)


def read_midi_messages(path: Path) -> tuple[list[MidiInputMessage], int, dict]:
    """Read the declared POP909 accompaniment projection in merged order."""

    try:
        import mido
    except ImportError as error:
        raise RuntimeError(
            "mido is required; run this census with ./.venv/bin/python"
        ) from error

    midi = mido.MidiFile(path)
    named_tracks = []
    channels_by_track: dict[str, set[int]] = {}
    for track in midi.tracks:
        names = [message.name for message in track if message.type == "track_name"]
        if len(names) > 1:
            raise ValueError(f"{path} has a track with multiple names: {names}")
        if not names:
            continue
        name = names[0]
        named_tracks.append(name)
        channels_by_track[name] = {
            message.channel for message in track if hasattr(message, "channel")
        }

    if tuple(named_tracks) != EXPECTED_TRACK_NAMES:
        raise ValueError(
            f"{path} named tracks must be {EXPECTED_TRACK_NAMES}, "
            f"received {tuple(named_tracks)}"
        )
    invalid_channel_counts = {
        name: sorted(channels)
        for name, channels in channels_by_track.items()
        if len(channels) != 1
    }
    if invalid_channel_counts:
        raise ValueError(
            f"{path} named tracks must each use exactly one MIDI channel: "
            f"{invalid_channel_counts}"
        )
    channel_owners: dict[int, set[str]] = {}
    for name, channels in channels_by_track.items():
        for channel in channels:
            channel_owners.setdefault(channel, set()).add(name)
    shared_channels = {
        channel: sorted(owners)
        for channel, owners in channel_owners.items()
        if len(owners) > 1
    }
    if shared_channels:
        raise ValueError(f"{path} named tracks share MIDI channels: {shared_channels}")

    selected_channels = set().union(
        *(channels_by_track[name] for name in SELECTED_TRACK_NAMES)
    )
    excluded_channels = set(channel_owners) - selected_channels
    messages = []
    excluded_relevant_messages = 0
    selected_note_messages: Counter[int] = Counter()
    selected_pedal_messages: Counter[int] = Counter()
    channel_pedal_states = {channel: False for channel in selected_channels}
    channel_pedal_disagreement_ms = 0
    previous_timestamp_ms = 0
    clock_seconds = 0.0
    for message in midi:
        clock_seconds += message.time
        timestamp_ms = round(clock_seconds * 1000)
        if len(set(channel_pedal_states.values())) > 1:
            channel_pedal_disagreement_ms += timestamp_ms - previous_timestamp_ms
        previous_timestamp_ms = timestamp_ms
        relevant = message.type in ("note_on", "note_off") or (
            message.type == "control_change"
            and (
                message.control == PEDAL_CONTROLLER
                or message.control in UNSUPPORTED_RESET_CONTROLLERS
            )
        )
        if relevant and message.channel not in selected_channels:
            excluded_relevant_messages += 1
            continue
        if message.type == "note_on":
            selected_note_messages[message.channel] += 1
            messages.append(
                MidiInputMessage(
                    timestamp_ms=timestamp_ms,
                    type="noteOn" if message.velocity > 0 else "noteOff",
                    channel=message.channel,
                    midi_note=message.note,
                    velocity=message.velocity,
                )
            )
        elif message.type == "note_off":
            selected_note_messages[message.channel] += 1
            messages.append(
                MidiInputMessage(
                    timestamp_ms=timestamp_ms,
                    type="noteOff",
                    channel=message.channel,
                    midi_note=message.note,
                    velocity=message.velocity,
                )
            )
        elif message.type == "control_change" and message.control == PEDAL_CONTROLLER:
            selected_pedal_messages[message.channel] += 1
            channel_pedal_states[message.channel] = message.value >= 64
            messages.append(
                MidiInputMessage(
                    timestamp_ms=timestamp_ms,
                    type="pedal",
                    channel=message.channel,
                    pedal_down=message.value >= 64,
                    controller=message.control,
                )
            )
        elif (
            message.type == "control_change"
            and message.control in UNSUPPORTED_RESET_CONTROLLERS
        ):
            messages.append(
                MidiInputMessage(
                    timestamp_ms=timestamp_ms,
                    type="unsupportedReset",
                    channel=message.channel,
                    controller=message.control,
                )
            )
    projection = {
        "namedTrackOrder": named_tracks,
        "channelsByTrack": {
            name: sorted(channels_by_track[name]) for name in named_tracks
        },
        "selectedTrackNames": list(SELECTED_TRACK_NAMES),
        "selectedChannels": sorted(selected_channels),
        "excludedTrackNames": [
            name for name in EXPECTED_TRACK_NAMES if name not in SELECTED_TRACK_NAMES
        ],
        "excludedChannels": sorted(excluded_channels),
        "selectedRelevantMessages": len(messages),
        "excludedRelevantMessages": excluded_relevant_messages,
        "selectedNoteMessagesByChannel": {
            str(channel): selected_note_messages[channel]
            for channel in sorted(selected_channels)
        },
        "selectedPedalMessagesByChannel": {
            str(channel): selected_pedal_messages[channel]
            for channel in sorted(selected_channels)
        },
        "channelPedalDisagreementMs": channel_pedal_disagreement_ms,
        "channelHandling": "discarded after track selection",
    }
    return messages, round(clock_seconds * 1000), projection


def normalize_messages(
    song_id: str,
    messages: list[MidiInputMessage],
    end_timestamp_ms: int,
) -> tuple[dict, dict]:
    """Normalize multiplexed MIDI into the strict frame-replay contract.

    The selected channels are deliberately collapsed to the app's one pitch set
    and one sustain state before replay. A repeated attack on an already pressed
    pitch and a release of a pitch that is not pressed are state no-ops; both are
    omitted and counted. The first attack remains the onset origin until a
    state-changing release or pedal-sustained reattack.
    """

    pressed: set[int] = set()
    pedal_down = False
    last_pedal_timestamp: int | None = None
    events = []
    counts: Counter[str] = Counter()
    counts["rawRelevantMessages"] = len(messages)
    last_timestamp = 0

    def emit(message: dict) -> None:
        message["index"] = len(events)
        events.append(message)

    for raw_index, message in enumerate(messages):
        if message.timestamp_ms < last_timestamp:
            raise ValueError(f"raw message {raw_index} timestamps are decreasing")
        if message.timestamp_ms > end_timestamp_ms:
            raise ValueError(f"raw message {raw_index} occurs after the MIDI end")
        last_timestamp = message.timestamp_ms

        if message.type == "unsupportedReset":
            raise ValueError(
                f"song {song_id} uses unsupported controller {message.controller} "
                f"at {message.timestamp_ms} ms"
            )

        if message.type == "pedal":
            if message.pedal_down == pedal_down:
                counts["repeatedPedalMessages"] += 1
                last_pedal_timestamp = message.timestamp_ms
                continue
            if message.timestamp_ms == last_pedal_timestamp:
                counts["sameTimestampPedalReversals"] += 1
            pedal_down = bool(message.pedal_down)
            last_pedal_timestamp = message.timestamp_ms
            emit(
                {
                    "timestampMs": message.timestamp_ms,
                    "type": "pedal",
                    "down": pedal_down,
                }
            )
            continue

        if message.midi_note is None or message.velocity is None:
            raise ValueError(f"raw message {raw_index} lacks note data")
        if message.type == "noteOn":
            if message.midi_note in pressed:
                counts["repeatedNoteOnMessages"] += 1
                continue
            pressed.add(message.midi_note)
            emit(
                {
                    "timestampMs": message.timestamp_ms,
                    "type": "noteOn",
                    "midiNote": message.midi_note,
                    "velocity": message.velocity,
                }
            )
            continue

        if message.type != "noteOff":
            raise ValueError(
                f"raw message {raw_index} has unknown type {message.type!r}"
            )
        if message.midi_note not in pressed:
            counts["unmatchedNoteOffMessages"] += 1
            continue
        pressed.remove(message.midi_note)
        emit(
            {
                "timestampMs": message.timestamp_ms,
                "type": "noteOff",
                "midiNote": message.midi_note,
                "velocity": message.velocity,
            }
        )

    fixture = {
        "schema": frame_replay.FIXTURE_SCHEMA,
        "id": f"pop909/{song_id}",
        "description": (
            "Normalized pedal-aware event stream for a POP909 sample song."
        ),
        "timeBase": "milliseconds",
        "initialState": {
            "pressedMidiNotes": [],
            "sustainedMidiNotes": [],
            "pedalDown": False,
        },
        "events": events,
        "frames": [],
        "endTimestampMs": end_timestamp_ms,
    }
    fixture["frames"] = frame_replay.replay_fixture(fixture)
    frame_replay.validate_fixture(fixture)
    counts["normalizedEvents"] = len(events)
    normalization = {
        name: counts[name]
        for name in (
            "rawRelevantMessages",
            "normalizedEvents",
            "repeatedNoteOnMessages",
            "unmatchedNoteOffMessages",
            "repeatedPedalMessages",
            "sameTimestampPedalReversals",
        )
    }
    return fixture, normalization


def empty_metrics() -> dict:
    return {
        "eventFrames": {
            "total": 0,
            "zeroDwell": 0,
            "sounding": 0,
            "withCandidates": 0,
            "zeroDwellWithCandidates": 0,
            "withPositiveSupport": 0,
            "zeroDwellWithPositiveSupport": 0,
        },
        "dwellMs": {
            "sounding": 0,
            "withCandidates": 0,
            "withPositiveSupport": 0,
        },
        "candidateInstances": {
            "total": 0,
            "completeEvidence": 0,
            "incompleteEvidence": 0,
            "positiveSupport": 0,
            "neutral": 0,
            "neutralReasonCounts": {},
        },
    }


def ratio(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def finalize_metrics(metrics: dict) -> dict:
    event_frames = metrics["eventFrames"]
    dwell = metrics["dwellMs"]
    instances = metrics["candidateInstances"]
    event_frames["candidateShareOfSounding"] = ratio(
        event_frames["withCandidates"], event_frames["sounding"]
    )
    event_frames["positiveSupportShareOfCandidateFrames"] = ratio(
        event_frames["withPositiveSupport"], event_frames["withCandidates"]
    )
    dwell["candidateShareOfSounding"] = ratio(
        dwell["withCandidates"], dwell["sounding"]
    )
    dwell["positiveSupportShareOfCandidateTime"] = ratio(
        dwell["withPositiveSupport"], dwell["withCandidates"]
    )
    dwell["positiveSupportShareOfSounding"] = ratio(
        dwell["withPositiveSupport"], dwell["sounding"]
    )
    instances["completeEvidenceShare"] = ratio(
        instances["completeEvidence"], instances["total"]
    )
    instances["positiveSupportShare"] = ratio(
        instances["positiveSupport"], instances["total"]
    )
    instances["neutralReasonCounts"] = dict(
        sorted(instances["neutralReasonCounts"].items())
    )
    return metrics


def analyze_fixture(fixture: dict) -> tuple[dict, list[dict]]:
    """Measure every normalized event frame and its following dwell interval."""

    frame_replay.validate_fixture(fixture)
    onset_frames = onset_evidence.replay_onset_frames(fixture)
    metrics = empty_metrics()
    candidate_frames = []
    events = fixture["events"]

    for index, (frame, onset_frame) in enumerate(zip(fixture["frames"], onset_frames)):
        next_timestamp = (
            events[index + 1]["timestampMs"]
            if index + 1 < len(events)
            else fixture["endTimestampMs"]
        )
        dwell_ms = next_timestamp - frame["timestampMs"]
        candidates = register_candidates.generate_register_candidates(
            frame["soundingMidiNotes"]
        )
        interpretations = []
        positive_candidates = 0

        for candidate in candidates:
            evidence_item = onset_evidence.candidate_onset_evidence(
                candidate, onset_frame
            )
            interpretation = onset_support.interpret_onset_evidence(
                evidence_item["onsetEvidence"]
            )
            interpretations.append(
                {
                    **evidence_item,
                    "onsetInterpretation": interpretation,
                }
            )
            instances = metrics["candidateInstances"]
            instances["total"] += 1
            availability = interpretation["availability"]
            instances[
                "completeEvidence"
                if availability == "complete"
                else "incompleteEvidence"
            ] += 1
            if interpretation["onsetCohortSupport"] == "positive":
                instances["positiveSupport"] += 1
                positive_candidates += 1
            else:
                instances["neutral"] += 1
                reasons = instances["neutralReasonCounts"]
                for reason in interpretation["reasonCodes"]:
                    reasons[reason] = reasons.get(reason, 0) + 1

        event_frames = metrics["eventFrames"]
        event_frames["total"] += 1
        if dwell_ms == 0:
            event_frames["zeroDwell"] += 1
        if frame["soundingMidiNotes"]:
            event_frames["sounding"] += 1
            metrics["dwellMs"]["sounding"] += dwell_ms
        if candidates:
            event_frames["withCandidates"] += 1
            metrics["dwellMs"]["withCandidates"] += dwell_ms
            if dwell_ms == 0:
                event_frames["zeroDwellWithCandidates"] += 1
        if positive_candidates:
            event_frames["withPositiveSupport"] += 1
            metrics["dwellMs"]["withPositiveSupport"] += dwell_ms
            if dwell_ms == 0:
                event_frames["zeroDwellWithPositiveSupport"] += 1

        if interpretations:
            candidate_frames.append(
                {
                    "afterEventIndex": frame["afterEventIndex"],
                    "timestampMs": frame["timestampMs"],
                    "dwellMs": dwell_ms,
                    "observationFrame": frame,
                    "candidateInterpretations": interpretations,
                }
            )

    return finalize_metrics(metrics), candidate_frames


def add_metrics(total: dict, piece: dict) -> None:
    for section in ("eventFrames", "dwellMs"):
        for name, value in piece[section].items():
            if isinstance(value, int):
                total[section][name] += value
    total_instances = total["candidateInstances"]
    piece_instances = piece["candidateInstances"]
    for name in (
        "total",
        "completeEvidence",
        "incompleteEvidence",
        "positiveSupport",
        "neutral",
    ):
        total_instances[name] += piece_instances[name]
    reasons = total_instances["neutralReasonCounts"]
    for reason, count in piece_instances["neutralReasonCounts"].items():
        reasons[reason] = reasons.get(reason, 0) + count


def add_counts(total: Counter[str], values: dict) -> None:
    for name, value in values.items():
        total[name] += value


def summarize_projections(per_piece: list[dict]) -> dict:
    selected_note_messages: Counter[str] = Counter()
    selected_pedal_messages: Counter[str] = Counter()
    for piece in per_piece:
        projection = piece["projection"]
        add_counts(selected_note_messages, projection["selectedNoteMessagesByChannel"])
        add_counts(
            selected_pedal_messages, projection["selectedPedalMessagesByChannel"]
        )
    return {
        "selectedRelevantMessages": sum(
            piece["projection"]["selectedRelevantMessages"] for piece in per_piece
        ),
        "excludedRelevantMessages": sum(
            piece["projection"]["excludedRelevantMessages"] for piece in per_piece
        ),
        "channelPedalDisagreementMs": sum(
            piece["projection"]["channelPedalDisagreementMs"] for piece in per_piece
        ),
        "piecesWithChannelPedalDisagreement": sum(
            bool(piece["projection"]["channelPedalDisagreementMs"])
            for piece in per_piece
        ),
        "piecesWithPedalOnEverySelectedChannel": sum(
            all(piece["projection"]["selectedPedalMessagesByChannel"].values())
            for piece in per_piece
        ),
        "selectedNoteMessagesByChannel": dict(sorted(selected_note_messages.items())),
        "selectedPedalMessagesByChannel": dict(sorted(selected_pedal_messages.items())),
    }


def git(cwd: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def contract_pins() -> list[dict]:
    return [
        {
            "path": str(path.relative_to(REPO_ROOT)),
            "sha256": sha256_file(path),
        }
        for path in CONTRACT_PATHS
    ]


def build_report(pop909_root: Path) -> dict:
    song_ids = load_frozen_sample_song_ids()
    midi_paths = [
        (song_id, pop909_root / song_id / f"{song_id}.mid") for song_id in song_ids
    ]
    missing = [str(path) for _, path in midi_paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"missing POP909 MIDI files: {missing}")

    total_metrics = empty_metrics()
    total_normalization: Counter[str] = Counter()
    per_piece = []
    all_candidate_frames = []

    for song_id, midi_path in midi_paths:
        messages, end_timestamp_ms, projection = read_midi_messages(midi_path)
        fixture, normalization = normalize_messages(song_id, messages, end_timestamp_ms)
        metrics, candidate_frames = analyze_fixture(fixture)
        add_metrics(total_metrics, metrics)
        add_counts(total_normalization, normalization)
        per_piece.append(
            {
                "songId": song_id,
                "midiSha256": sha256_file(midi_path),
                "projection": projection,
                "normalization": normalization,
                "metrics": metrics,
            }
        )
        all_candidate_frames.extend(
            {"songId": song_id, **frame} for frame in candidate_frames
        )

    finalized_total = finalize_metrics(total_metrics)
    positive_ms = finalized_total["dwellMs"]["withPositiveSupport"]
    ranked_positive = sorted(
        (
            piece
            for piece in per_piece
            if piece["metrics"]["dwellMs"]["withPositiveSupport"]
        ),
        key=lambda piece: (
            -piece["metrics"]["dwellMs"]["withPositiveSupport"],
            piece["songId"],
        ),
    )
    piece_concentration = {
        "piecesWithCandidates": sum(
            bool(piece["metrics"]["eventFrames"]["withCandidates"])
            for piece in per_piece
        ),
        "piecesWithPositiveSupport": len(ranked_positive),
        "topPositiveSupportPieces": [
            {
                "songId": piece["songId"],
                "positiveSupportMs": piece["metrics"]["dwellMs"]["withPositiveSupport"],
                "shareOfCorpusPositiveSupportMs": ratio(
                    piece["metrics"]["dwellMs"]["withPositiveSupport"],
                    positive_ms,
                ),
            }
            for piece in ranked_positive[:20]
        ],
    }

    return {
        "schema": REPORT_SCHEMA,
        "measurementId": MEASUREMENT_ID,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(["./.venv/bin/python", *sys.argv]),
        "workingDirectory": str(Path.cwd()),
        "source": {
            "corpus": "POP909",
            "pop909Root": str(pop909_root),
            "pop909Commit": git(pop909_root.parent, "rev-parse", "HEAD"),
            "pop909Dirty": bool(git(pop909_root.parent, "status", "--porcelain")),
            "rosterPath": str(DEFAULT_ROSTER),
            "rosterSha256": sha256_file(DEFAULT_ROSTER),
            "rosterField": "sample",
            "songCount": len(song_ids),
            "songIds": song_ids,
            "midiContentSha256": aggregate_file_hash(midi_paths),
            "midiContentHashAlgorithm": (
                "sha256 over each song ID, NUL, and raw-file SHA-256 digest in "
                "roster order"
            ),
            "labelsRead": False,
            "trackProjection": {
                "selectedTrackNames": list(SELECTED_TRACK_NAMES),
                "excludedTrackNames": [
                    name
                    for name in EXPECTED_TRACK_NAMES
                    if name not in SELECTED_TRACK_NAMES
                ],
                "channelHandling": (
                    "track identity selects the accompaniment; channel identity "
                    "is then discarded to match WhatChord's pitch-set and global "
                    "sustain input"
                ),
            },
        },
        "runtime": {
            "pythonVersion": platform.python_version(),
            "midoVersion": importlib.metadata.version("mido"),
        },
        "contracts": {
            "repositoryCommit": git(REPO_ROOT, "rev-parse", "HEAD"),
            "repositoryMeasurementInputsDirty": bool(
                git(
                    REPO_ROOT,
                    "status",
                    "--porcelain",
                    "--",
                    "research/polychord",
                    "research/performed-input/data/pop909-held-pool.json",
                    "tool/polychord",
                )
            ),
            "frameReplaySchema": frame_replay.FIXTURE_SCHEMA,
            "registerCandidateSchema": register_candidates.OUTPUT_SCHEMA,
            "onsetEvidenceSchema": onset_evidence.OUTPUT_SCHEMA,
            "onsetSupportSchema": onset_support.OUTPUT_SCHEMA,
            "onsetSupportAblationId": onset_support.ABLATION_ID,
            "pins": contract_pins(),
        },
        "denominators": {
            "eventFrames": (
                "every normalized note or sustain transition; same-timestamp "
                "intermediate frames count and may have zero dwell"
            ),
            "dwellMs": (
                "time from a normalized event frame to the next event, or to "
                "MIDI end; shares use sounding time"
            ),
            "candidateInstances": (
                "every register candidate on every normalized event frame"
            ),
        },
        "summary": {
            **finalized_total,
            "pieceConcentration": piece_concentration,
        },
        "projection": summarize_projections(per_piece),
        "normalization": dict(sorted(total_normalization.items())),
        "perPiece": per_piece,
        "candidateFrames": all_candidate_frames,
    }


def output_is_allowed(path: Path) -> bool:
    resolved = path.resolve()
    build = (REPO_ROOT / "build").resolve()
    return resolved != build and build in resolved.parents


def format_ratio(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.6f}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pop909-root", type=Path, default=DEFAULT_POP909_ROOT)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not output_is_allowed(args.out):
        raise SystemExit(
            "POP909-derived detail must remain local under the repository build/ tree"
        )
    report = build_report(args.pop909_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{report['source']['songCount']} songs; "
        f"candidate sounding-time share "
        f"{format_ratio(summary['dwellMs']['candidateShareOfSounding'])}; "
        f"positive share of candidate time "
        f"{format_ratio(summary['dwellMs']['positiveSupportShareOfCandidateTime'])}; "
        f"report -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

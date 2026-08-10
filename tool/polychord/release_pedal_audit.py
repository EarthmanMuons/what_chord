"""Audit raw release and sustain history for disjoint POP909 candidates.

This is a label-free, post-result audit of the exact 59 pitch-class-disjoint
candidate instances retained in the pinned onset-exposure report. Corpus-derived
detail may be written only under ``build/``. The POP909 held pool is neither
selectable nor read.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import shlex
import statistics
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import frame_replay
import onset_evidence
import onset_exposure_census
import register_candidates

REPO_ROOT = Path(__file__).parents[2]
REPORT_SCHEMA = "polychord-release-pedal-audit/1"
MEASUREMENT_ID = "pop909-sample-disjoint-release-pedal-audit/1"
SOURCE_REPORT_SCHEMA = "polychord-onset-exposure-census/1"
SOURCE_MEASUREMENT_ID = (
    "pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1"
)
SOURCE_REPORT_SHA256 = (
    "60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9"
)
EXPECTED_INSTANCE_COUNT = 59
EXPECTED_SONG_IDS = (
    "010",
    "046",
    "064",
    "091",
    "163",
    "361",
    "487",
    "649",
    "685",
    "703",
    "721",
    "757",
)

DEFAULT_SOURCE_REPORT = (
    REPO_ROOT
    / "build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json"
)
DEFAULT_POP909_ROOT = onset_exposure_census.DEFAULT_POP909_ROOT

CONTRACT_PATHS = (
    REPO_ROOT / "research/polychord/frame-replay-schema.md",
    REPO_ROOT / "tool/polychord/frame_replay.py",
    REPO_ROOT / "research/polychord/register-candidate-schema.md",
    REPO_ROOT / "tool/polychord/register_candidates.py",
    REPO_ROOT / "research/polychord/onset-evidence-schema.md",
    REPO_ROOT / "tool/polychord/onset_evidence.py",
    REPO_ROOT / "research/polychord/onset-exposure-census.md",
    REPO_ROOT / "tool/polychord/onset_exposure_census.py",
    REPO_ROOT / "research/polychord/release-pedal-audit.md",
    REPO_ROOT / "tool/polychord/release_pedal_audit.py",
)


@dataclass(frozen=True)
class EventOrigin:
    """One exact normalized event that established a current fact."""

    event_index: int
    timestamp_ms: int
    velocity: int | None = None


@dataclass(frozen=True)
class SoundingNoteHistory:
    """Threshold-free causal history for one currently sounding pitch."""

    midi_note: int
    sounding_state: str
    onset: EventOrigin | None
    release: EventOrigin | None
    current_state_since: EventOrigin | None
    reattacked_from_sustain: bool | None
    prior_sustain_release: EventOrigin | None

    def as_dict(
        self,
        timestamp_ms: int,
        pedal_transition: EventOrigin | None,
        pedal_down: bool,
    ) -> dict:
        onset_before_pedal_down = None
        if self.onset is not None and pedal_down and pedal_transition is not None:
            onset_before_pedal_down = (
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
            "onsetBeforeCurrentPedalDown": onset_before_pedal_down,
        }


@dataclass(frozen=True)
class TemporalHistoryFrame:
    """Release and pedal provenance after one validated replay event."""

    after_event_index: int
    timestamp_ms: int
    pedal_down: bool
    pedal_transition: EventOrigin | None
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
            "currentStateAgeMs": (
                self.timestamp_ms - transition.timestamp_ms
                if transition is not None
                else None
            ),
        }


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def event_origin(event: dict) -> EventOrigin:
    return EventOrigin(
        event_index=event["index"],
        timestamp_ms=event["timestampMs"],
        velocity=event.get("velocity"),
    )


def replay_temporal_history_frames(
    fixture: dict,
) -> tuple[TemporalHistoryFrame, ...]:
    """Replay exact note state, release origin, restrike, and pedal origin."""

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
    pedal_transition: EventOrigin | None = None
    history_frames = []

    for event, frame in zip(fixture["events"], fixture["frames"]):
        event_type = event["type"]
        origin = event_origin(event)
        if event_type == "noteOn":
            note = event["midiNote"]
            prior = notes.get(note)
            reattacked = prior is not None and prior.sounding_state == "sustained"
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
            pedal_transition = origin
            if not event["down"]:
                notes = {
                    note: history
                    for note, history in notes.items()
                    if history.sounding_state == "pressed"
                }

        expected_sounding = set(frame["soundingMidiNotes"])
        if set(notes) != expected_sounding:
            raise ValueError(
                "temporal history does not match replayed sounding notes after "
                f"event {event['index']}"
            )
        pressed = set(frame["pressedMidiNotes"])
        state_mismatches = [
            note
            for note, history in notes.items()
            if (history.sounding_state == "pressed") != (note in pressed)
        ]
        if state_mismatches:
            raise ValueError(
                "temporal history does not match replayed note states after "
                f"event {event['index']}: {sorted(state_mismatches)}"
            )
        history_frames.append(
            TemporalHistoryFrame(
                after_event_index=frame["afterEventIndex"],
                timestamp_ms=frame["timestampMs"],
                pedal_down=frame["pedalDown"],
                pedal_transition=pedal_transition,
                notes=tuple(notes[note] for note in frame["soundingMidiNotes"]),
            )
        )

    return tuple(history_frames)


def summarize_layer(
    midi_notes: list[int],
    history_frame: TemporalHistoryFrame,
) -> dict:
    """Serialize threshold-free history for one exact candidate layer."""

    note_map = history_frame.note_map()
    missing = set(midi_notes) - set(note_map)
    if missing:
        raise ValueError(
            f"layer contains notes absent from the frame: {sorted(missing)}"
        )
    note_records = [
        note_map[midi_note].as_dict(
            history_frame.timestamp_ms,
            history_frame.pedal_transition,
            history_frame.pedal_down,
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
        "knownReleaseCount": len(release_timestamps),
        "unknownReleaseCount": len(sustained) - len(release_timestamps),
        "allSustainedReleasesKnown": len(release_timestamps) == len(sustained),
        "distinctKnownReleaseTimestampsMs": sorted(set(release_timestamps)),
        "earliestKnownReleaseMs": earliest_release,
        "latestKnownReleaseMs": latest_release,
        "knownReleaseSpanMs": (
            latest_release - earliest_release if earliest_release is not None else None
        ),
        "knownOnsetAgeRangeMs": (
            {"minimum": min(onset_ages), "maximum": max(onset_ages)}
            if onset_ages
            else None
        ),
        "knownCurrentStateAgeRangeMs": (
            {"minimum": min(state_ages), "maximum": max(state_ages)}
            if state_ages
            else None
        ),
        "reattackedFromSustainCount": sum(
            note["reattackedFromSustain"] is True for note in note_records
        ),
        "unknownReattackCount": sum(
            note["reattackedFromSustain"] is None for note in note_records
        ),
        "onsetBeforeCurrentPedalDownCount": sum(
            note["onsetBeforeCurrentPedalDown"] is True for note in note_records
        ),
        "unknownPedalRelationCount": sum(
            note["onsetBeforeCurrentPedalDown"] is None for note in note_records
        ),
    }


def candidate_release_pedal_evidence(
    candidate: dict,
    history_frame: TemporalHistoryFrame,
) -> dict:
    lower = summarize_layer(candidate["lower"]["midiNotes"], history_frame)
    upper = summarize_layer(candidate["upper"]["midiNotes"], history_frame)
    return {
        "pedal": history_frame.pedal_as_dict(),
        "lower": lower,
        "upper": upper,
        "pressedCandidateNoteCount": (
            lower["pressedNoteCount"] + upper["pressedNoteCount"]
        ),
        "sustainedCandidateNoteCount": (
            lower["sustainedNoteCount"] + upper["sustainedNoteCount"]
        ),
        "allSustainedReleasesKnown": (
            lower["allSustainedReleasesKnown"] and upper["allSustainedReleasesKnown"]
        ),
        "reattackedFromSustainCount": (
            lower["reattackedFromSustainCount"] + upper["reattackedFromSustainCount"]
        ),
        "onsetBeforeCurrentPedalDownCount": (
            lower["onsetBeforeCurrentPedalDownCount"]
            + upper["onsetBeforeCurrentPedalDownCount"]
        ),
    }


def validate_source_report(payload: dict, digest: str) -> None:
    if digest != SOURCE_REPORT_SHA256:
        raise ValueError(
            f"source report digest is {digest}, expected {SOURCE_REPORT_SHA256}"
        )
    if payload.get("schema") != SOURCE_REPORT_SCHEMA:
        raise ValueError(f"source report schema must be {SOURCE_REPORT_SCHEMA!r}")
    if payload.get("measurementId") != SOURCE_MEASUREMENT_ID:
        raise ValueError(f"source measurementId must be {SOURCE_MEASUREMENT_ID!r}")
    source = payload.get("source", {})
    if source.get("labelsRead") is not False:
        raise ValueError("source report must record labelsRead: false")
    if source.get("rosterField") != "sample":
        raise ValueError("source report must use only the sample roster field")
    if source.get("songIds") != onset_exposure_census.load_frozen_sample_song_ids():
        raise ValueError("source report song IDs do not match the frozen sample")


def extract_disjoint_instances(payload: dict) -> list[dict]:
    instances = []
    for candidate_frame in payload["candidateFrames"]:
        for interpretation in candidate_frame["candidateInterpretations"]:
            candidate = interpretation["candidate"]
            if candidate["sharedPitchClasses"]:
                continue
            instances.append(
                {
                    "songId": candidate_frame["songId"],
                    "afterEventIndex": candidate_frame["afterEventIndex"],
                    "timestampMs": candidate_frame["timestampMs"],
                    "dwellMs": candidate_frame["dwellMs"],
                    "observationFrame": candidate_frame["observationFrame"],
                    "candidate": candidate,
                    "onsetEvidence": interpretation["onsetEvidence"],
                }
            )
    return sorted(
        instances,
        key=lambda item: (
            item["songId"],
            item["afterEventIndex"],
            candidate_key(item["candidate"]),
        ),
    )


def candidate_key(candidate: dict) -> str:
    return json.dumps(candidate, sort_keys=True, separators=(",", ":"))


def validate_selected_subset(instances: list[dict]) -> None:
    if len(instances) != EXPECTED_INSTANCE_COUNT:
        raise ValueError(
            f"selected {len(instances)} instances, expected {EXPECTED_INSTANCE_COUNT}"
        )
    song_ids = tuple(sorted({instance["songId"] for instance in instances}))
    if song_ids != EXPECTED_SONG_IDS:
        raise ValueError(
            f"selected song IDs are {song_ids}, expected {EXPECTED_SONG_IDS}"
        )


def augment_instances(
    source_report: dict,
    instances: list[dict],
    pop909_root: Path,
) -> tuple[list[dict], dict[str, dict], list[tuple[str, Path]]]:
    """Reconstruct only selected sample songs and verify every source row."""

    piece_by_id = {piece["songId"]: piece for piece in source_report["perPiece"]}
    selected_by_song: dict[str, list[dict]] = {}
    for instance in instances:
        selected_by_song.setdefault(instance["songId"], []).append(instance)

    augmented = []
    fixture_by_song = {}
    selected_midi_paths = []
    for song_id in EXPECTED_SONG_IDS:
        midi_path = pop909_root / song_id / f"{song_id}.mid"
        if not midi_path.is_file():
            raise FileNotFoundError(f"missing POP909 MIDI file: {midi_path}")
        if sha256_file(midi_path) != piece_by_id[song_id]["midiSha256"]:
            raise ValueError(f"song {song_id} MIDI digest differs from source report")
        selected_midi_paths.append((song_id, midi_path))
        messages, end_timestamp_ms, _ = onset_exposure_census.read_midi_messages(
            midi_path
        )
        fixture, _ = onset_exposure_census.normalize_messages(
            song_id, messages, end_timestamp_ms
        )
        onset_frames = onset_evidence.replay_onset_frames(fixture)
        history_frames = replay_temporal_history_frames(fixture)
        fixture_by_song[song_id] = fixture

        for instance in selected_by_song[song_id]:
            index = instance["afterEventIndex"]
            frame = fixture["frames"][index]
            if frame != instance["observationFrame"]:
                raise ValueError(
                    f"song {song_id} frame {index} differs from source report"
                )
            candidates = register_candidates.generate_register_candidates(
                frame["soundingMidiNotes"]
            )
            matches = [
                candidate
                for candidate in candidates
                if candidate.as_dict() == instance["candidate"]
            ]
            if len(matches) != 1:
                raise ValueError(
                    f"song {song_id} frame {index} did not reproduce one candidate"
                )
            reproduced_onset = onset_evidence.candidate_onset_evidence(
                matches[0], onset_frames[index]
            )["onsetEvidence"]
            if reproduced_onset != instance["onsetEvidence"]:
                raise ValueError(f"song {song_id} frame {index} onset evidence differs")
            augmented.append(
                {
                    **instance,
                    "causingEvent": fixture["events"][index],
                    "releasePedalEvidence": candidate_release_pedal_evidence(
                        instance["candidate"], history_frames[index]
                    ),
                }
            )

    return augmented, fixture_by_song, selected_midi_paths


def group_candidate_runs(
    instances: list[dict], fixture_by_song: dict[str, dict]
) -> list[dict]:
    """Group one exact allocation across consecutive normalized frames."""

    by_candidate: dict[tuple[str, str], list[dict]] = {}
    for instance in instances:
        key = (instance["songId"], candidate_key(instance["candidate"]))
        by_candidate.setdefault(key, []).append(instance)

    raw_runs = []
    for candidate_instances in by_candidate.values():
        ordered = sorted(candidate_instances, key=lambda item: item["afterEventIndex"])
        current = [ordered[0]]
        for instance in ordered[1:]:
            if instance["afterEventIndex"] == current[-1]["afterEventIndex"] + 1:
                current.append(instance)
            else:
                raw_runs.append(current)
                current = [instance]
        raw_runs.append(current)

    raw_runs.sort(
        key=lambda run: (
            run[0]["songId"],
            run[0]["afterEventIndex"],
            candidate_key(run[0]["candidate"]),
        )
    )
    runs = []
    song_run_counts: Counter[str] = Counter()
    for raw_run in raw_runs:
        song_id = raw_run[0]["songId"]
        fixture = fixture_by_song[song_id]
        song_run_counts[song_id] += 1
        first_index = raw_run[0]["afterEventIndex"]
        last_index = raw_run[-1]["afterEventIndex"]
        terminator = (
            fixture["events"][last_index + 1]
            if last_index + 1 < len(fixture["events"])
            else None
        )
        exclusive_end = (
            terminator["timestampMs"]
            if terminator is not None
            else fixture["endTimestampMs"]
        )
        causal_indices = []
        for instance in raw_run:
            evidence = instance["releasePedalEvidence"]
            transition = evidence["pedal"]["lastTransitionEventIndex"]
            if transition is not None:
                causal_indices.append(transition)
            for layer_name in ("lower", "upper"):
                for note in evidence[layer_name]["notes"]:
                    for field in (
                        "onsetEventIndex",
                        "releaseEventIndex",
                        "currentStateSinceEventIndex",
                        "priorSustainReleaseEventIndex",
                    ):
                        if note[field] is not None:
                            causal_indices.append(note[field])
        history_start = min(causal_indices, default=first_index)
        history_end = last_index + (1 if terminator is not None else 0)
        observations = [
            {
                key: value
                for key, value in instance.items()
                if key not in ("songId", "candidate")
            }
            for instance in raw_run
        ]
        candidate_digest = hashlib.sha256(
            candidate_key(raw_run[0]["candidate"]).encode()
        ).hexdigest()[:12]
        runs.append(
            {
                "id": (
                    f"pop909/{song_id}/run-{song_run_counts[song_id]:03d}-"
                    f"candidate-{candidate_digest}"
                ),
                "songId": song_id,
                "candidate": raw_run[0]["candidate"],
                "firstAfterEventIndex": first_index,
                "lastAfterEventIndex": last_index,
                "startTimestampMs": raw_run[0]["timestampMs"],
                "exclusiveEndTimestampMs": exclusive_end,
                "observedDurationMs": sum(instance["dwellMs"] for instance in raw_run),
                "frameCount": len(raw_run),
                "zeroDwellFrameCount": sum(
                    instance["dwellMs"] == 0 for instance in raw_run
                ),
                "observations": observations,
                "terminatingEvent": terminator,
                "causalHistoryStartEventIndex": history_start,
                "causalHistoryEvents": fixture["events"][
                    history_start : history_end + 1
                ],
            }
        )
    return runs


def histogram(values: list[int | str]) -> dict[str, int]:
    counts = Counter(str(value) for value in values)
    return dict(
        sorted(
            counts.items(),
            key=lambda item: int(item[0]) if item[0].isdigit() else item[0],
        )
    )


def distribution(values: list[int]) -> dict | None:
    if not values:
        return None
    ordered = sorted(values)
    return {
        "count": len(ordered),
        "minimum": ordered[0],
        "median": statistics.median(ordered),
        "maximum": ordered[-1],
    }


def summarize_runs(runs: list[dict]) -> dict:
    observations = [observation for run in runs for observation in run["observations"]]
    evidences = [observation["releasePedalEvidence"] for observation in observations]
    sustained_counts = [
        evidence["sustainedCandidateNoteCount"] for evidence in evidences
    ]
    release_timestamp_counts = [
        len(
            set(
                evidence["lower"]["distinctKnownReleaseTimestampsMs"]
                + evidence["upper"]["distinctKnownReleaseTimestampsMs"]
            )
        )
        for evidence in evidences
    ]
    pedal_ages = [
        evidence["pedal"]["currentStateAgeMs"]
        for evidence in evidences
        if evidence["pedal"]["currentStateAgeMs"] is not None
    ]
    note_onset_ages = [
        note["onsetAgeMs"]
        for evidence in evidences
        for layer in (evidence["lower"], evidence["upper"])
        for note in layer["notes"]
        if note["onsetAgeMs"] is not None
    ]
    release_ages = [
        note["releaseAgeMs"]
        for evidence in evidences
        for layer in (evidence["lower"], evidence["upper"])
        for note in layer["notes"]
        if note["releaseAgeMs"] is not None
    ]
    return {
        "songCount": len({run["songId"] for run in runs}),
        "songIds": sorted({run["songId"] for run in runs}),
        "candidateRuns": len(runs),
        "candidateInstances": len(observations),
        "zeroDwellCandidateInstances": sum(
            observation["dwellMs"] == 0 for observation in observations
        ),
        "observedCandidateMs": sum(
            observation["dwellMs"] for observation in observations
        ),
        "instancesWithPedalDown": sum(
            evidence["pedal"]["down"] for evidence in evidences
        ),
        "instancesWithAnySustainedNote": sum(
            evidence["sustainedCandidateNoteCount"] > 0 for evidence in evidences
        ),
        "instancesWithAllCandidateNotesSustained": sum(
            evidence["pressedCandidateNoteCount"] == 0 for evidence in evidences
        ),
        "instancesWithCompleteSustainedReleaseOrigins": sum(
            evidence["allSustainedReleasesKnown"] for evidence in evidences
        ),
        "instancesWithAnyReattackFromSustain": sum(
            evidence["reattackedFromSustainCount"] > 0 for evidence in evidences
        ),
        "instancesWithAnyOnsetBeforeCurrentPedalDown": sum(
            evidence["onsetBeforeCurrentPedalDownCount"] > 0 for evidence in evidences
        ),
        "sustainedCandidateNoteOccurrences": sum(sustained_counts),
        "pressedCandidateNoteOccurrences": sum(
            evidence["pressedCandidateNoteCount"] for evidence in evidences
        ),
        "candidateInstancesPerSong": histogram(
            [run["songId"] for run in runs for _observation in run["observations"]]
        ),
        "candidateRunsPerSong": histogram([run["songId"] for run in runs]),
        "candidateRunFrameCount": {
            "histogram": histogram([run["frameCount"] for run in runs]),
            "distribution": distribution([run["frameCount"] for run in runs]),
        },
        "candidateRunDurationMs": distribution(
            [run["observedDurationMs"] for run in runs]
        ),
        "sustainedNoteCountPerInstance": {
            "histogram": histogram(sustained_counts),
            "distribution": distribution(sustained_counts),
        },
        "distinctReleaseTimestampsPerInstance": {
            "histogram": histogram(release_timestamp_counts),
            "distribution": distribution(release_timestamp_counts),
        },
        "pedalStateAgeMs": distribution(pedal_ages),
        "candidateNoteOnsetAgeMs": distribution(note_onset_ages),
        "sustainedNoteReleaseAgeMs": distribution(release_ages),
        "runStartingEventTypes": histogram(
            [run["observations"][0]["causingEvent"]["type"] for run in runs]
        ),
        "runTerminatingEventTypes": histogram(
            [
                run["terminatingEvent"]["type"]
                if run["terminatingEvent"] is not None
                else "midiEnd"
                for run in runs
            ]
        ),
    }


def build_report(source_report_path: Path, pop909_root: Path) -> dict:
    source_digest = sha256_file(source_report_path)
    source_report = json.loads(source_report_path.read_text())
    validate_source_report(source_report, source_digest)
    selected = extract_disjoint_instances(source_report)
    validate_selected_subset(selected)
    augmented, fixture_by_song, selected_midi_paths = augment_instances(
        source_report, selected, pop909_root
    )
    runs = group_candidate_runs(augmented, fixture_by_song)
    source_repo = pop909_root.parent
    return {
        "schema": REPORT_SCHEMA,
        "measurementId": MEASUREMENT_ID,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(["./.venv/bin/python", *sys.argv]),
        "workingDirectory": str(Path.cwd()),
        "source": {
            "corpus": "POP909",
            "sourceReportPath": str(source_report_path),
            "sourceReportSha256": source_digest,
            "sourceMeasurementId": source_report["measurementId"],
            "sourceReportLabelsRead": source_report["source"]["labelsRead"],
            "selection": "candidate.sharedPitchClasses is exactly empty",
            "songIds": list(EXPECTED_SONG_IDS),
            "songCount": len(EXPECTED_SONG_IDS),
            "candidateInstanceCount": EXPECTED_INSTANCE_COUNT,
            "pop909Root": str(pop909_root),
            "pop909Commit": git(source_repo, "rev-parse", "HEAD"),
            "pop909Dirty": bool(git(source_repo, "status", "--porcelain")),
            "selectedMidiContentSha256": (
                onset_exposure_census.aggregate_file_hash(selected_midi_paths)
            ),
            "labelsRead": False,
            "heldPoolRead": False,
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
                    *[str(path.relative_to(REPO_ROOT)) for path in CONTRACT_PATHS],
                )
            ),
            "frameReplaySchema": frame_replay.FIXTURE_SCHEMA,
            "registerCandidateSchema": register_candidates.OUTPUT_SCHEMA,
            "onsetEvidenceSchema": onset_evidence.OUTPUT_SCHEMA,
            "pins": contract_pins(),
        },
        "denominators": {
            "candidateInstance": (
                "one exact pitch-class-disjoint candidate on one normalized "
                "event frame; multiple candidates on a frame remain separate"
            ),
            "candidateRun": (
                "one exact candidate allocation on consecutive normalized event "
                "indices in one song; candidate symbol alone is insufficient"
            ),
            "observedCandidateMs": (
                "sum of each selected frame's source-report dwellMs; "
                "same-timestamp zero-dwell frames remain instances"
            ),
            "candidateNoteOccurrence": (
                "one assigned MIDI note in one candidate instance; repeated "
                "frames are repeated observations, not independent notes"
            ),
        },
        "summary": summarize_runs(runs),
        "runs": runs,
    }


def output_is_allowed(path: Path) -> bool:
    resolved = path.resolve()
    build = (REPO_ROOT / "build").resolve()
    return resolved != build and build in resolved.parents


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-report", type=Path, default=DEFAULT_SOURCE_REPORT)
    parser.add_argument("--pop909-root", type=Path, default=DEFAULT_POP909_ROOT)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not output_is_allowed(args.out):
        raise SystemExit(
            "POP909-derived detail must remain local under the repository build/ tree"
        )
    report = build_report(args.source_report, args.pop909_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{summary['candidateInstances']} instances in "
        f"{summary['candidateRuns']} exact-candidate runs across "
        f"{summary['songCount']} songs; report -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Measure fixed rigid-layer motion-support exposure on the POP909 sample.

The corpus report is descriptive and label-free. It always reads the previously
exposed ``sample`` roster, uses adjacent timestamp-terminal replay frames as
motion endpoints, and requires corpus-derived detail to remain under ``build/``.
The held POP909 pool is not selectable by this tool.
"""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import math
import platform
import shlex
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import frame_replay
import motion_support
import onset_exposure_census
import register_candidates
import release_pedal_evidence
import transition_evidence

REPO_ROOT = Path(__file__).parents[2]
REPORT_SCHEMA = "polychord-motion-exposure-census/1"
MEASUREMENT_ID = (
    "pop909-sample-accompaniment-channel-blind-timestamp-terminal-rigid-motion/1"
)

DEFAULT_POP909_ROOT = onset_exposure_census.DEFAULT_POP909_ROOT
DEFAULT_ROSTER = onset_exposure_census.DEFAULT_ROSTER

CONTRACT_PATHS = (
    REPO_ROOT / "research/polychord/frame-replay-schema.md",
    REPO_ROOT / "tool/polychord/frame_replay.py",
    REPO_ROOT / "research/polychord/register-candidate-schema.md",
    REPO_ROOT / "tool/polychord/register_candidates.py",
    REPO_ROOT / "research/polychord/onset-exposure-census.md",
    REPO_ROOT / "tool/polychord/onset_exposure_census.py",
    REPO_ROOT / "research/polychord/release-pedal-evidence-schema.md",
    REPO_ROOT / "tool/polychord/release_pedal_evidence.py",
    REPO_ROOT / "research/polychord/frame-transition-evidence-schema.md",
    REPO_ROOT / "tool/polychord/transition_evidence.py",
    REPO_ROOT / "research/polychord/motion-support-ablation.md",
    REPO_ROOT / "tool/polychord/motion_support.py",
    REPO_ROOT / "research/polychord/motion-exposure-census.md",
    REPO_ROOT / "tool/polychord/motion_exposure_census.py",
)


def ratio(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def distribution_summary(values: list[int]) -> dict:
    """Summarize integer observations with fixed nearest-rank percentiles."""

    ordered = sorted(values)
    if not ordered:
        return {
            "count": 0,
            "minimum": None,
            "medianNearestRank": None,
            "p90NearestRank": None,
            "maximum": None,
        }

    def nearest_rank(probability: float) -> int:
        return ordered[max(0, math.ceil(probability * len(ordered)) - 1)]

    return {
        "count": len(ordered),
        "minimum": ordered[0],
        "medianNearestRank": nearest_rank(0.5),
        "p90NearestRank": nearest_rank(0.9),
        "maximum": ordered[-1],
    }


def empty_metrics() -> dict:
    return {
        "endpointFrames": {
            "rawEventFrames": 0,
            "rawEventFramesWithCandidates": 0,
            "timestampTerminal": 0,
            "timestampTerminalSounding": 0,
            "timestampTerminalWithCandidates": 0,
            "timestampTerminalWithMotionEvaluablePredecessor": 0,
            "timestampTerminalWithPitchChangingMotionEvaluablePredecessor": 0,
            "timestampTerminalWithPositiveMotionSupport": 0,
            "excludedSameTimestampNonterminal": 0,
            "excludedSameTimestampNonterminalWithCandidates": 0,
        },
        "terminalDwellMs": {
            "sounding": 0,
            "withCandidates": 0,
            "withMotionEvaluablePredecessor": 0,
            "withPitchChangingMotionEvaluablePredecessor": 0,
            "withPositiveMotionSupport": 0,
        },
        "observationTransitions": {
            "total": 0,
            "sameSoundingSet": 0,
            "pitchChanging": 0,
            "neitherCandidateEndpoint": 0,
            "candidateEntry": 0,
            "candidateExit": 0,
            "candidateToCandidate": 0,
            "candidateToCandidateSameSoundingSet": 0,
            "pitchChangingCandidateToCandidate": 0,
            "withPositiveMotionSupport": 0,
        },
        "candidateInstances": {
            "timestampTerminalTotal": 0,
            "motionEvaluable": 0,
            "motionUnavailableWithoutCandidatePredecessor": 0,
            "withAnyPositiveIncomingHypothesis": 0,
            "withoutPositiveIncomingHypothesis": 0,
            "candidatePairs": 0,
            "candidatePairsWithAnyPositiveHypothesis": 0,
            "candidatePairsWithMultiplePositiveHypotheses": 0,
            "hypothesisInterpretations": 0,
            "positiveHypotheses": 0,
            "neutralHypotheses": 0,
            "neutralReasonCounts": {},
        },
        "_elapsedMsSamples": {
            "observationTransitions": [],
            "candidateToCandidate": [],
            "positiveMotionSupport": [],
        },
        "_countSamples": {
            "sourceCandidatesPerEvaluableWindow": [],
            "targetCandidatesPerEvaluableWindow": [],
            "candidatePairsPerEvaluableWindow": [],
            "hypothesisInterpretationsPerEvaluableWindow": [],
            "positiveHypothesesPerEvaluableWindow": [],
            "positiveTargetCandidatesPerEvaluableWindow": [],
        },
    }


def finalize_metrics(metrics: dict) -> dict:
    endpoints = metrics["endpointFrames"]
    dwell = metrics["terminalDwellMs"]
    transitions = metrics["observationTransitions"]
    instances = metrics["candidateInstances"]

    endpoints["candidateShareOfSoundingTerminalFrames"] = ratio(
        endpoints["timestampTerminalWithCandidates"],
        endpoints["timestampTerminalSounding"],
    )
    endpoints["motionEvaluableShareOfCandidateTerminalFrames"] = ratio(
        endpoints["timestampTerminalWithMotionEvaluablePredecessor"],
        endpoints["timestampTerminalWithCandidates"],
    )
    endpoints["positiveShareOfMotionEvaluableTerminalFrames"] = ratio(
        endpoints["timestampTerminalWithPositiveMotionSupport"],
        endpoints["timestampTerminalWithMotionEvaluablePredecessor"],
    )
    endpoints["positiveShareOfCandidateTerminalFrames"] = ratio(
        endpoints["timestampTerminalWithPositiveMotionSupport"],
        endpoints["timestampTerminalWithCandidates"],
    )
    dwell["candidateShareOfSounding"] = ratio(
        dwell["withCandidates"], dwell["sounding"]
    )
    dwell["motionEvaluableShareOfCandidateTime"] = ratio(
        dwell["withMotionEvaluablePredecessor"], dwell["withCandidates"]
    )
    dwell["positiveShareOfMotionEvaluableTime"] = ratio(
        dwell["withPositiveMotionSupport"],
        dwell["withMotionEvaluablePredecessor"],
    )
    dwell["positiveShareOfCandidateTime"] = ratio(
        dwell["withPositiveMotionSupport"], dwell["withCandidates"]
    )
    transitions["positiveShareOfCandidateToCandidate"] = ratio(
        transitions["withPositiveMotionSupport"],
        transitions["candidateToCandidate"],
    )
    transitions["positiveShareOfPitchChangingCandidateToCandidate"] = ratio(
        transitions["withPositiveMotionSupport"],
        transitions["pitchChangingCandidateToCandidate"],
    )
    instances["motionEvaluableShare"] = ratio(
        instances["motionEvaluable"], instances["timestampTerminalTotal"]
    )
    instances["positiveShareOfMotionEvaluable"] = ratio(
        instances["withAnyPositiveIncomingHypothesis"],
        instances["motionEvaluable"],
    )
    instances["positiveHypothesisShare"] = ratio(
        instances["positiveHypotheses"],
        instances["hypothesisInterpretations"],
    )
    instances["neutralReasonCounts"] = dict(
        sorted(instances["neutralReasonCounts"].items())
    )
    elapsed_samples = metrics.pop("_elapsedMsSamples")
    count_samples = metrics.pop("_countSamples")
    metrics["elapsedMsDistributions"] = {
        name: distribution_summary(values) for name, values in elapsed_samples.items()
    }
    metrics["countDistributions"] = {
        name: distribution_summary(values) for name, values in count_samples.items()
    }
    return metrics


def terminal_frame_records(fixture: dict) -> list[dict]:
    """Select the last replay frame at each distinct event timestamp."""

    records = []
    group_start = 0
    events = fixture["events"]
    frames = fixture["frames"]
    for index, (event, frame) in enumerate(zip(events, frames)):
        next_timestamp = (
            events[index + 1]["timestampMs"] if index + 1 < len(events) else None
        )
        if next_timestamp == event["timestampMs"]:
            continue
        records.append(
            {
                "ordinal": len(records),
                "timestampMs": event["timestampMs"],
                "firstEventIndex": events[group_start]["index"],
                "lastEventIndex": event["index"],
                "eventCount": index - group_start + 1,
                "frame": frame,
            }
        )
        group_start = index + 1
    return records


def terminal_dwell_ms(fixture: dict, terminals: list[dict], ordinal: int) -> int:
    next_timestamp = (
        terminals[ordinal + 1]["timestampMs"]
        if ordinal + 1 < len(terminals)
        else fixture["endTimestampMs"]
    )
    return next_timestamp - terminals[ordinal]["timestampMs"]


def window_classification(source_candidates: list, target_candidates: list) -> str:
    if source_candidates and target_candidates:
        return "candidate-to-candidate"
    if target_candidates:
        return "candidate-entry"
    if source_candidates:
        return "candidate-exit"
    return "neither-candidate-endpoint"


def candidate_interpretations(
    source_candidates: list,
    target_candidates: list,
    source_frame: release_pedal_evidence.ReleasePedalFrame,
    target_frame: release_pedal_evidence.ReleasePedalFrame,
) -> list[dict]:
    return [
        motion_support.interpret_transition(
            transition_evidence.candidate_transition(
                source_index,
                target_index,
                source_candidate,
                target_candidate,
                source_frame,
                target_frame,
            )
        )
        for source_index, source_candidate in enumerate(source_candidates)
        for target_index, target_candidate in enumerate(target_candidates)
    ]


def transition_window(
    fixture: dict,
    source_terminal: dict,
    target_terminal: dict,
) -> dict:
    steps = [
        {"event": event, "frame": frame}
        for event, frame in zip(fixture["events"], fixture["frames"])
        if source_terminal["lastEventIndex"]
        < event["index"]
        <= target_terminal["lastEventIndex"]
    ]
    return {
        "sourceFrame": source_terminal["frame"],
        "targetFrame": target_terminal["frame"],
        "elapsedMs": (target_terminal["timestampMs"] - source_terminal["timestampMs"]),
        "transitionEventCount": len(steps),
        "interveningFrameCount": max(0, len(steps) - 1),
        "transitionSteps": steps,
    }


def analyze_fixture(
    fixture: dict,
    *,
    finalize: bool = True,
) -> tuple[dict, dict]:
    """Apply the fixed endpoint enumeration to one normalized replay fixture."""

    frame_replay.validate_fixture(fixture)
    terminals = terminal_frame_records(fixture)
    terminal_indices = {record["lastEventIndex"] for record in terminals}
    candidates_by_index = {
        frame["afterEventIndex"]: register_candidates.generate_register_candidates(
            frame["soundingMidiNotes"]
        )
        for frame in fixture["frames"]
    }
    release_frames = {
        frame.after_event_index: frame
        for frame in release_pedal_evidence.replay_release_pedal_frames(fixture)
    }
    metrics = empty_metrics()
    details = {
        "initialCandidateEndpoints": [],
        "candidateEndpointWindows": [],
        "excludedSameTimestampCandidateFrames": [],
    }

    endpoint_metrics = metrics["endpointFrames"]
    endpoint_metrics["rawEventFrames"] = len(fixture["frames"])
    endpoint_metrics["timestampTerminal"] = len(terminals)
    endpoint_metrics["excludedSameTimestampNonterminal"] = len(fixture["frames"]) - len(
        terminals
    )

    for frame in fixture["frames"]:
        candidates = candidates_by_index[frame["afterEventIndex"]]
        if candidates:
            endpoint_metrics["rawEventFramesWithCandidates"] += 1
            if frame["afterEventIndex"] not in terminal_indices:
                endpoint_metrics["excludedSameTimestampNonterminalWithCandidates"] += 1
                details["excludedSameTimestampCandidateFrames"].append(
                    {
                        "observationFrame": frame,
                        "candidates": [candidate.as_dict() for candidate in candidates],
                    }
                )

    dwell_metrics = metrics["terminalDwellMs"]
    instance_metrics = metrics["candidateInstances"]
    for ordinal, terminal in enumerate(terminals):
        dwell_ms = terminal_dwell_ms(fixture, terminals, ordinal)
        frame = terminal["frame"]
        candidates = candidates_by_index[terminal["lastEventIndex"]]
        if frame["soundingMidiNotes"]:
            endpoint_metrics["timestampTerminalSounding"] += 1
            dwell_metrics["sounding"] += dwell_ms
        if candidates:
            endpoint_metrics["timestampTerminalWithCandidates"] += 1
            dwell_metrics["withCandidates"] += dwell_ms
            instance_metrics["timestampTerminalTotal"] += len(candidates)
            if ordinal == 0:
                instance_metrics["motionUnavailableWithoutCandidatePredecessor"] += len(
                    candidates
                )
                details["initialCandidateEndpoints"].append(
                    {
                        "timestampTerminalOrdinal": ordinal,
                        "dwellMs": dwell_ms,
                        "observationFrame": frame,
                        "candidates": [candidate.as_dict() for candidate in candidates],
                    }
                )

    transition_metrics = metrics["observationTransitions"]
    for target_ordinal in range(1, len(terminals)):
        source_terminal = terminals[target_ordinal - 1]
        target_terminal = terminals[target_ordinal]
        source_candidates = candidates_by_index[source_terminal["lastEventIndex"]]
        target_candidates = candidates_by_index[target_terminal["lastEventIndex"]]
        source_notes = source_terminal["frame"]["soundingMidiNotes"]
        target_notes = target_terminal["frame"]["soundingMidiNotes"]
        pitch_changing = source_notes != target_notes
        classification = window_classification(source_candidates, target_candidates)
        target_dwell = terminal_dwell_ms(fixture, terminals, target_ordinal)
        elapsed_ms = target_terminal["timestampMs"] - source_terminal["timestampMs"]

        transition_metrics["total"] += 1
        metrics["_elapsedMsSamples"]["observationTransitions"].append(elapsed_ms)
        transition_metrics[
            "pitchChanging" if pitch_changing else "sameSoundingSet"
        ] += 1
        transition_metrics[
            {
                "candidate-to-candidate": "candidateToCandidate",
                "candidate-entry": "candidateEntry",
                "candidate-exit": "candidateExit",
                "neither-candidate-endpoint": "neitherCandidateEndpoint",
            }[classification]
        ] += 1
        if classification == "candidate-to-candidate":
            if pitch_changing:
                transition_metrics["pitchChangingCandidateToCandidate"] += 1
            else:
                transition_metrics["candidateToCandidateSameSoundingSet"] += 1

        interpretations = []
        positive_pair_count = 0
        positive_hypothesis_count = 0
        positive_target_indices: set[int] = set()
        if source_candidates and target_candidates:
            endpoint_metrics["timestampTerminalWithMotionEvaluablePredecessor"] += 1
            dwell_metrics["withMotionEvaluablePredecessor"] += target_dwell
            instance_metrics["motionEvaluable"] += len(target_candidates)
            if pitch_changing:
                endpoint_metrics[
                    "timestampTerminalWithPitchChangingMotionEvaluablePredecessor"
                ] += 1
                dwell_metrics["withPitchChangingMotionEvaluablePredecessor"] += (
                    target_dwell
                )
            interpretations = candidate_interpretations(
                source_candidates,
                target_candidates,
                release_frames[source_terminal["lastEventIndex"]],
                release_frames[target_terminal["lastEventIndex"]],
            )
            metrics["_elapsedMsSamples"]["candidateToCandidate"].append(elapsed_ms)
            instance_metrics["candidatePairs"] += len(interpretations)
            for interpretation in interpretations:
                positive_hypotheses = [
                    hypothesis
                    for hypothesis in interpretation["hypothesisInterpretations"]
                    if hypothesis["motionSupport"] == "positive"
                ]
                hypothesis_count = len(interpretation["hypothesisInterpretations"])
                instance_metrics["hypothesisInterpretations"] += hypothesis_count
                instance_metrics["positiveHypotheses"] += len(positive_hypotheses)
                positive_hypothesis_count += len(positive_hypotheses)
                instance_metrics["neutralHypotheses"] += hypothesis_count - len(
                    positive_hypotheses
                )
                if positive_hypotheses:
                    positive_pair_count += 1
                    positive_target_indices.add(interpretation["targetCandidateIndex"])
                if len(positive_hypotheses) > 1:
                    instance_metrics[
                        "candidatePairsWithMultiplePositiveHypotheses"
                    ] += 1
                for hypothesis in interpretation["hypothesisInterpretations"]:
                    if hypothesis["motionSupport"] == "neutral":
                        reasons = instance_metrics["neutralReasonCounts"]
                        for reason in hypothesis["reasonCodes"]:
                            reasons[reason] = reasons.get(reason, 0) + 1

            instance_metrics["candidatePairsWithAnyPositiveHypothesis"] += (
                positive_pair_count
            )
            instance_metrics["withAnyPositiveIncomingHypothesis"] += len(
                positive_target_indices
            )
            instance_metrics["withoutPositiveIncomingHypothesis"] += len(
                target_candidates
            ) - len(positive_target_indices)
            count_samples = metrics["_countSamples"]
            count_samples["sourceCandidatesPerEvaluableWindow"].append(
                len(source_candidates)
            )
            count_samples["targetCandidatesPerEvaluableWindow"].append(
                len(target_candidates)
            )
            count_samples["candidatePairsPerEvaluableWindow"].append(
                len(interpretations)
            )
            count_samples["hypothesisInterpretationsPerEvaluableWindow"].append(
                sum(
                    len(interpretation["hypothesisInterpretations"])
                    for interpretation in interpretations
                )
            )
            count_samples["positiveHypothesesPerEvaluableWindow"].append(
                positive_hypothesis_count
            )
            count_samples["positiveTargetCandidatesPerEvaluableWindow"].append(
                len(positive_target_indices)
            )
        elif target_candidates:
            instance_metrics["motionUnavailableWithoutCandidatePredecessor"] += len(
                target_candidates
            )

        positive_window = bool(positive_target_indices)
        if positive_window:
            endpoint_metrics["timestampTerminalWithPositiveMotionSupport"] += 1
            dwell_metrics["withPositiveMotionSupport"] += target_dwell
            transition_metrics["withPositiveMotionSupport"] += 1
            metrics["_elapsedMsSamples"]["positiveMotionSupport"].append(elapsed_ms)

        if source_candidates or target_candidates:
            details["candidateEndpointWindows"].append(
                {
                    "sourceTimestampTerminalOrdinal": target_ordinal - 1,
                    "targetTimestampTerminalOrdinal": target_ordinal,
                    "classification": classification,
                    "pitchChanging": pitch_changing,
                    "targetDwellMs": target_dwell,
                    "window": transition_window(
                        fixture,
                        source_terminal,
                        target_terminal,
                    ),
                    "sourceCandidates": [
                        candidate.as_dict() for candidate in source_candidates
                    ],
                    "targetCandidates": [
                        candidate.as_dict() for candidate in target_candidates
                    ],
                    "candidateInterpretations": interpretations,
                    "positiveCandidatePairCount": positive_pair_count,
                    "positiveHypothesisCount": positive_hypothesis_count,
                    "positiveTargetCandidateIndices": sorted(positive_target_indices),
                }
            )

    return (finalize_metrics(metrics) if finalize else metrics), details


def add_metrics(total: dict, piece: dict) -> None:
    for section in (
        "endpointFrames",
        "terminalDwellMs",
        "observationTransitions",
    ):
        for name, value in piece[section].items():
            if isinstance(value, int):
                total[section][name] += value

    total_instances = total["candidateInstances"]
    piece_instances = piece["candidateInstances"]
    for name, value in piece_instances.items():
        if isinstance(value, int):
            total_instances[name] += value
    reasons = total_instances["neutralReasonCounts"]
    for reason, count in piece_instances["neutralReasonCounts"].items():
        reasons[reason] = reasons.get(reason, 0) + count
    for section in ("_elapsedMsSamples", "_countSamples"):
        for name, values in piece[section].items():
            total[section][name].extend(values)


def contract_pins() -> list[dict]:
    return [
        {
            "path": str(path.relative_to(REPO_ROOT)),
            "sha256": onset_exposure_census.sha256_file(path),
        }
        for path in CONTRACT_PATHS
    ]


def measurement_inputs_dirty() -> bool:
    return bool(
        onset_exposure_census.git(
            REPO_ROOT,
            "status",
            "--porcelain",
            "--",
            "research/polychord",
            "research/performed-input/data/pop909-held-pool.json",
            "tool/polychord",
        )
    )


def build_report(pop909_root: Path) -> dict:
    song_ids = onset_exposure_census.load_frozen_sample_song_ids()
    midi_paths = [
        (song_id, pop909_root / song_id / f"{song_id}.mid") for song_id in song_ids
    ]
    missing = [str(path) for _, path in midi_paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"missing POP909 MIDI files: {missing}")

    total_metrics = empty_metrics()
    total_normalization: Counter[str] = Counter()
    per_piece = []
    all_initial_endpoints = []
    all_candidate_windows = []
    all_excluded_frames = []

    for song_id, midi_path in midi_paths:
        messages, end_timestamp_ms, projection = (
            onset_exposure_census.read_midi_messages(midi_path)
        )
        fixture, normalization = onset_exposure_census.normalize_messages(
            song_id,
            messages,
            end_timestamp_ms,
        )
        raw_metrics, details = analyze_fixture(fixture, finalize=False)
        add_metrics(total_metrics, raw_metrics)
        metrics = finalize_metrics(raw_metrics)
        onset_exposure_census.add_counts(total_normalization, normalization)
        per_piece.append(
            {
                "songId": song_id,
                "midiSha256": onset_exposure_census.sha256_file(midi_path),
                "projection": projection,
                "normalization": normalization,
                "metrics": metrics,
            }
        )
        all_initial_endpoints.extend(
            {"songId": song_id, **item} for item in details["initialCandidateEndpoints"]
        )
        all_candidate_windows.extend(
            {"songId": song_id, **item} for item in details["candidateEndpointWindows"]
        )
        all_excluded_frames.extend(
            {"songId": song_id, **item}
            for item in details["excludedSameTimestampCandidateFrames"]
        )

    finalized_total = finalize_metrics(total_metrics)
    positive_ms = finalized_total["terminalDwellMs"]["withPositiveMotionSupport"]
    ranked_positive = sorted(
        (
            piece
            for piece in per_piece
            if piece["metrics"]["terminalDwellMs"]["withPositiveMotionSupport"]
        ),
        key=lambda piece: (
            -piece["metrics"]["terminalDwellMs"]["withPositiveMotionSupport"],
            piece["songId"],
        ),
    )
    piece_concentration = {
        "piecesWithTimestampTerminalCandidates": sum(
            bool(piece["metrics"]["endpointFrames"]["timestampTerminalWithCandidates"])
            for piece in per_piece
        ),
        "piecesWithMotionEvaluableEndpoints": sum(
            bool(
                piece["metrics"]["endpointFrames"][
                    "timestampTerminalWithMotionEvaluablePredecessor"
                ]
            )
            for piece in per_piece
        ),
        "piecesWithPositiveMotionSupport": len(ranked_positive),
        "topPositiveMotionPieces": [
            {
                "songId": piece["songId"],
                "positiveMotionSupportMs": piece["metrics"]["terminalDwellMs"][
                    "withPositiveMotionSupport"
                ],
                "shareOfCorpusPositiveMotionSupportMs": ratio(
                    piece["metrics"]["terminalDwellMs"]["withPositiveMotionSupport"],
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
            "pop909Commit": onset_exposure_census.git(
                pop909_root.parent,
                "rev-parse",
                "HEAD",
            ),
            "pop909Dirty": bool(
                onset_exposure_census.git(
                    pop909_root.parent,
                    "status",
                    "--porcelain",
                )
            ),
            "rosterPath": str(DEFAULT_ROSTER),
            "rosterSha256": onset_exposure_census.sha256_file(DEFAULT_ROSTER),
            "rosterField": "sample",
            "songCount": len(song_ids),
            "songIds": song_ids,
            "midiContentSha256": onset_exposure_census.aggregate_file_hash(midi_paths),
            "midiContentHashAlgorithm": (
                "sha256 over each song ID, NUL, and raw-file SHA-256 digest in "
                "roster order"
            ),
            "labelsRead": False,
            "trackProjection": {
                "selectedTrackNames": list(onset_exposure_census.SELECTED_TRACK_NAMES),
                "excludedTrackNames": [
                    name
                    for name in onset_exposure_census.EXPECTED_TRACK_NAMES
                    if name not in onset_exposure_census.SELECTED_TRACK_NAMES
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
            "repositoryCommit": onset_exposure_census.git(
                REPO_ROOT,
                "rev-parse",
                "HEAD",
            ),
            "repositoryMeasurementInputsDirty": measurement_inputs_dirty(),
            "frameReplaySchema": frame_replay.FIXTURE_SCHEMA,
            "registerCandidateSchema": register_candidates.OUTPUT_SCHEMA,
            "releasePedalEvidenceSchema": release_pedal_evidence.OUTPUT_SCHEMA,
            "transitionEvidenceSchema": transition_evidence.OUTPUT_SCHEMA,
            "motionSupportSchema": motion_support.OUTPUT_SCHEMA,
            "motionSupportAblationId": motion_support.ABLATION_ID,
            "motionSupportParameters": motion_support.interpretation_parameters(),
            "endpointPolicy": "adjacent-timestamp-terminal-frames/1",
            "pins": contract_pins(),
        },
        "denominators": {
            "endpointFrames": (
                "last normalized event frame at each distinct timestamp; "
                "same-timestamp nonterminal frames are excluded and reported"
            ),
            "observationTransitions": (
                "each adjacent pair of timestamp-terminal frames; no endpoint "
                "is skipped and no elapsed-time cutoff is applied"
            ),
            "terminalDwellMs": (
                "time from a timestamp-terminal frame to the next distinct "
                "event timestamp or MIDI end"
            ),
            "candidateInstances": (
                "every target register candidate on timestamp-terminal frames, "
                "plus every source-target candidate pair and correspondence "
                "hypothesis on candidate-to-candidate transitions"
            ),
        },
        "summary": {
            **finalized_total,
            "pieceConcentration": piece_concentration,
        },
        "projection": onset_exposure_census.summarize_projections(per_piece),
        "normalization": dict(sorted(total_normalization.items())),
        "perPiece": per_piece,
        "initialCandidateEndpoints": all_initial_endpoints,
        "candidateEndpointWindows": all_candidate_windows,
        "excludedSameTimestampCandidateFrames": all_excluded_frames,
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
    if measurement_inputs_dirty():
        raise SystemExit(
            "motion-exposure measurement inputs must be committed and clean"
        )
    report = build_report(args.pop909_root)
    if report["contracts"]["repositoryMeasurementInputsDirty"]:
        raise SystemExit("motion-exposure measurement inputs changed during execution")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{report['source']['songCount']} songs; "
        f"terminal candidate-time share "
        f"{format_ratio(summary['terminalDwellMs']['candidateShareOfSounding'])}; "
        f"positive share of motion-evaluable time "
        f"{format_ratio(summary['terminalDwellMs']['positiveShareOfMotionEvaluableTime'])}; "
        f"report -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

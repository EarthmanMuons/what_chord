"""Verify a frozen polychord motion-exposure report and its evidence trail."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).parents[2]
REPORT_SCHEMA = "polychord-motion-exposure-census/1"
REPORT_SHA256 = "3489da54e0c2b71ba0a9f1c17acb6678115eae07afacf280c8afef8b81a2a3b6"
MEASUREMENT_ID = (
    "pop909-sample-accompaniment-channel-blind-timestamp-terminal-rigid-motion/1"
)
ONSET_REPORT_SCHEMA = "polychord-onset-exposure-census/1"
ONSET_REPORT_SHA256 = "60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9"
ROSTER_RELATIVE_PATH = Path("research/performed-input/data/pop909-held-pool.json")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def git(cwd: Path, *arguments: str) -> bytes:
    return subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        capture_output=True,
        check=True,
    ).stdout


def distribution_summary(values: list[int]) -> dict:
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


def aggregate_file_hash(paths: list[tuple[str, Path]]) -> str:
    digest = hashlib.sha256()
    for logical_name, path in paths:
        digest.update(logical_name.encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def verify_repository_inputs(report: dict) -> dict:
    source = report["source"]
    contracts = report["contracts"]
    repository_commit = contracts["repositoryCommit"]
    git(REPO_ROOT, "cat-file", "-e", f"{repository_commit}^{{commit}}")

    for pin in contracts["pins"]:
        committed = git(REPO_ROOT, "show", f"{repository_commit}:{pin['path']}")
        if sha256_bytes(committed) != pin["sha256"]:
            raise ValueError(f"contract pin does not match commit: {pin['path']}")

    if (
        not Path(source["rosterPath"])
        .as_posix()
        .endswith(ROSTER_RELATIVE_PATH.as_posix())
    ):
        raise ValueError("report roster path does not name the frozen roster")
    roster_bytes = git(
        REPO_ROOT,
        "show",
        f"{repository_commit}:{ROSTER_RELATIVE_PATH}",
    )
    if sha256_bytes(roster_bytes) != source["rosterSha256"]:
        raise ValueError("roster hash does not match the measurement commit")
    roster = json.loads(roster_bytes)
    if source["songIds"] != roster["sample"] or len(roster["sample"]) != 101:
        raise ValueError("report song IDs do not equal the committed sample roster")
    if len(roster["held"]) != 808 or set(roster["sample"]) & set(roster["held"]):
        raise ValueError("held roster size or isolation is invalid")
    return roster


def verify_corpus_inputs(report: dict, pop909_root: Path) -> None:
    source = report["source"]
    corpus_commit = git(pop909_root.parent, "rev-parse", "HEAD").decode().strip()
    if corpus_commit != source["pop909Commit"]:
        raise ValueError("POP909 checkout commit does not match the report")
    if git(pop909_root.parent, "status", "--porcelain"):
        raise ValueError("POP909 checkout is dirty")

    midi_paths = [
        (song_id, pop909_root / song_id / f"{song_id}.mid")
        for song_id in source["songIds"]
    ]
    piece_hashes = {
        piece["songId"]: piece["midiSha256"] for piece in report["perPiece"]
    }
    for song_id, path in midi_paths:
        if sha256_file(path) != piece_hashes[song_id]:
            raise ValueError(f"MIDI hash does not match for song {song_id}")
    if aggregate_file_hash(midi_paths) != source["midiContentSha256"]:
        raise ValueError("aggregate MIDI-content hash does not match")


def verify_aggregate_sums(report: dict) -> None:
    summary = report["summary"]
    pieces = report["perPiece"]
    for section in (
        "endpointFrames",
        "terminalDwellMs",
        "observationTransitions",
        "candidateInstances",
    ):
        for name, value in summary[section].items():
            if isinstance(value, int) and value != sum(
                piece["metrics"][section][name] for piece in pieces
            ):
                raise ValueError(f"per-piece sum differs for {section}.{name}")

    for name, value in report["normalization"].items():
        if value != sum(piece["normalization"][name] for piece in pieces):
            raise ValueError(f"normalization sum differs for {name}")

    for section in ("elapsedMsDistributions", "countDistributions"):
        for name, distribution in summary[section].items():
            piece_count = sum(
                piece["metrics"][section][name]["count"] for piece in pieces
            )
            if distribution["count"] != piece_count:
                raise ValueError(f"distribution count differs for {section}.{name}")


def expected_classification(source_candidates: list, target_candidates: list) -> str:
    if source_candidates and target_candidates:
        return "candidate-to-candidate"
    if target_candidates:
        return "candidate-entry"
    if source_candidates:
        return "candidate-exit"
    raise ValueError("detailed windows must have a candidate at one endpoint")


def verify_detailed_windows(report: dict) -> dict:
    summary = report["summary"]
    windows = report["candidateEndpointWindows"]
    initial = report["initialCandidateEndpoints"]
    excluded = report["excludedSameTimestampCandidateFrames"]
    transitions = summary["observationTransitions"]
    endpoints = summary["endpointFrames"]
    dwell = summary["terminalDwellMs"]
    instances = summary["candidateInstances"]

    classes = Counter(window["classification"] for window in windows)
    expected_classes = Counter(
        {
            "candidate-entry": transitions["candidateEntry"],
            "candidate-exit": transitions["candidateExit"],
            "candidate-to-candidate": transitions["candidateToCandidate"],
        }
    )
    if classes != expected_classes:
        raise ValueError("detailed endpoint classes differ from the summary")
    if (
        sum(
            transitions[name]
            for name in (
                "neitherCandidateEndpoint",
                "candidateEntry",
                "candidateExit",
                "candidateToCandidate",
            )
        )
        != transitions["total"]
    ):
        raise ValueError("observation-transition classes do not partition total")
    if (
        transitions["sameSoundingSet"] + transitions["pitchChanging"]
        != transitions["total"]
    ):
        raise ValueError("pitch-change classes do not partition transitions")
    if (
        transitions["candidateToCandidateSameSoundingSet"]
        + transitions["pitchChangingCandidateToCandidate"]
        != transitions["candidateToCandidate"]
    ):
        raise ValueError("candidate pitch-change classes do not partition windows")
    if len(excluded) != endpoints["excludedSameTimestampNonterminalWithCandidates"]:
        raise ValueError("excluded candidate-frame detail count differs")
    if endpoints["rawEventFramesWithCandidates"] != (
        endpoints["timestampTerminalWithCandidates"] + len(excluded)
    ):
        raise ValueError("raw candidate frames do not partition by endpoint status")

    positive_hypotheses = 0
    neutral_hypotheses = 0
    positive_pairs = 0
    multiple_positive_pairs = 0
    positive_target_instances = 0
    neutral_reasons: Counter[str] = Counter()
    candidate_pairs = 0
    candidate_to_candidate_elapsed = []
    positive_elapsed = []
    count_samples: dict[str, list[int]] = defaultdict(list)

    for window in windows:
        source_candidates = window["sourceCandidates"]
        target_candidates = window["targetCandidates"]
        if window["classification"] != expected_classification(
            source_candidates,
            target_candidates,
        ):
            raise ValueError("window classification differs from candidate presence")

        source_frame = window["window"]["sourceFrame"]
        target_frame = window["window"]["targetFrame"]
        pitch_changing = (
            source_frame["soundingMidiNotes"] != target_frame["soundingMidiNotes"]
        )
        if window["pitchChanging"] != pitch_changing:
            raise ValueError("window pitch-changing flag differs from endpoint notes")
        if window["window"]["elapsedMs"] != (
            target_frame["timestampMs"] - source_frame["timestampMs"]
        ):
            raise ValueError("window elapsed time differs from endpoint timestamps")
        steps = window["window"]["transitionSteps"]
        if len(steps) != window["window"]["transitionEventCount"]:
            raise ValueError("window event count differs from detailed steps")
        if window["window"]["interveningFrameCount"] != max(0, len(steps) - 1):
            raise ValueError("window intervening-frame count differs")
        if not steps or steps[-1]["frame"] != target_frame:
            raise ValueError("window transition steps do not end at target frame")

        interpretations = window["candidateInterpretations"]
        if len(interpretations) != len(source_candidates) * len(target_candidates):
            raise ValueError("candidate interpretations are not a Cartesian product")
        candidate_index_pairs = [
            (
                interpretation["sourceCandidateIndex"],
                interpretation["targetCandidateIndex"],
            )
            for interpretation in interpretations
        ]
        expected_index_pairs = {
            (source_index, target_index)
            for source_index in range(len(source_candidates))
            for target_index in range(len(target_candidates))
        }
        if (
            len(set(candidate_index_pairs)) != len(candidate_index_pairs)
            or set(candidate_index_pairs) != expected_index_pairs
        ):
            raise ValueError("candidate interpretations do not cover each pair once")
        candidate_pairs += len(interpretations)
        target_positive: set[int] = set()
        window_positive_pairs = 0
        window_positive_hypotheses = 0

        for interpretation in interpretations:
            if not 0 <= interpretation["sourceCandidateIndex"] < len(source_candidates):
                raise ValueError("source candidate index is out of range")
            if not 0 <= interpretation["targetCandidateIndex"] < len(target_candidates):
                raise ValueError("target candidate index is out of range")
            hypotheses = interpretation["hypothesisInterpretations"]
            if {item["hypothesisId"] for item in hypotheses} != {
                "register-role-preserving",
                "register-role-exchanging",
            } or len(hypotheses) != 2:
                raise ValueError("candidate pair must contain both motion hypotheses")
            positives = [
                item for item in hypotheses if item["motionSupport"] == "positive"
            ]
            neutrals = [
                item for item in hypotheses if item["motionSupport"] == "neutral"
            ]
            positive_hypotheses += len(positives)
            neutral_hypotheses += len(neutrals)
            window_positive_hypotheses += len(positives)
            if positives:
                positive_pairs += 1
                window_positive_pairs += 1
                target_positive.add(interpretation["targetCandidateIndex"])
            if len(positives) > 1:
                multiple_positive_pairs += 1
            for item in neutrals:
                neutral_reasons.update(item["reasonCodes"])

        if window["positiveCandidatePairCount"] != window_positive_pairs:
            raise ValueError("positive candidate-pair count differs")
        if window["positiveHypothesisCount"] != window_positive_hypotheses:
            raise ValueError("positive hypothesis count differs")
        if window["positiveTargetCandidateIndices"] != sorted(target_positive):
            raise ValueError("positive target indices differ")
        positive_target_instances += len(target_positive)

        if window["classification"] == "candidate-to-candidate":
            elapsed = window["window"]["elapsedMs"]
            candidate_to_candidate_elapsed.append(elapsed)
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
                sum(len(item["hypothesisInterpretations"]) for item in interpretations)
            )
            count_samples["positiveHypothesesPerEvaluableWindow"].append(
                window_positive_hypotheses
            )
            count_samples["positiveTargetCandidatesPerEvaluableWindow"].append(
                len(target_positive)
            )
            if target_positive:
                positive_elapsed.append(elapsed)

    checks = {
        "candidatePairs": candidate_pairs,
        "candidatePairsWithAnyPositiveHypothesis": positive_pairs,
        "candidatePairsWithMultiplePositiveHypotheses": multiple_positive_pairs,
        "positiveHypotheses": positive_hypotheses,
        "neutralHypotheses": neutral_hypotheses,
        "withAnyPositiveIncomingHypothesis": positive_target_instances,
    }
    for name, value in checks.items():
        if instances[name] != value:
            raise ValueError(f"detailed evidence differs for candidateInstances.{name}")
    if dict(sorted(neutral_reasons.items())) != instances["neutralReasonCounts"]:
        raise ValueError("neutral reason counts differ from detailed hypotheses")
    if (
        positive_hypotheses + neutral_hypotheses
        != instances["hypothesisInterpretations"]
    ):
        raise ValueError("hypothesis support classes do not partition total")
    if instances["timestampTerminalTotal"] != (
        instances["motionEvaluable"]
        + instances["motionUnavailableWithoutCandidatePredecessor"]
    ):
        raise ValueError("target candidates do not partition by motion availability")
    if instances["motionEvaluable"] != (
        instances["withAnyPositiveIncomingHypothesis"]
        + instances["withoutPositiveIncomingHypothesis"]
    ):
        raise ValueError("evaluable candidates do not partition by positive support")

    target_candidate_total = sum(len(item["targetCandidates"]) for item in windows)
    target_candidate_total += sum(len(item["candidates"]) for item in initial)
    if instances["timestampTerminalTotal"] != target_candidate_total:
        raise ValueError("terminal candidate total differs from detailed endpoints")
    if instances["motionEvaluable"] != sum(
        len(item["targetCandidates"])
        for item in windows
        if item["classification"] == "candidate-to-candidate"
    ):
        raise ValueError("motion-evaluable candidate total differs from windows")
    unavailable = sum(
        len(item["targetCandidates"])
        for item in windows
        if item["classification"] == "candidate-entry"
    ) + sum(len(item["candidates"]) for item in initial)
    if instances["motionUnavailableWithoutCandidatePredecessor"] != unavailable:
        raise ValueError("motion-unavailable candidate total differs from windows")

    if endpoints["timestampTerminalWithCandidates"] != (
        sum(bool(item["targetCandidates"]) for item in windows) + len(initial)
    ):
        raise ValueError("terminal candidate-frame count differs from detail")
    if (
        endpoints["timestampTerminalWithMotionEvaluablePredecessor"]
        != classes["candidate-to-candidate"]
    ):
        raise ValueError("motion-evaluable endpoint count differs from detail")
    positive_windows = sum(
        bool(item["positiveTargetCandidateIndices"]) for item in windows
    )
    if endpoints["timestampTerminalWithPositiveMotionSupport"] != positive_windows:
        raise ValueError("positive endpoint count differs from detail")
    if transitions["withPositiveMotionSupport"] != positive_windows:
        raise ValueError("positive transition count differs from detail")

    candidate_dwell = sum(
        item["targetDwellMs"] for item in windows if item["targetCandidates"]
    ) + sum(item["dwellMs"] for item in initial)
    if dwell["withCandidates"] != candidate_dwell:
        raise ValueError("candidate dwell differs from detailed target states")
    evaluable_dwell = sum(
        item["targetDwellMs"]
        for item in windows
        if item["classification"] == "candidate-to-candidate"
    )
    if dwell["withMotionEvaluablePredecessor"] != evaluable_dwell:
        raise ValueError("motion-evaluable dwell differs from detailed windows")
    pitch_changing_dwell = sum(
        item["targetDwellMs"]
        for item in windows
        if item["classification"] == "candidate-to-candidate" and item["pitchChanging"]
    )
    if dwell["withPitchChangingMotionEvaluablePredecessor"] != pitch_changing_dwell:
        raise ValueError("pitch-changing motion dwell differs from detail")
    positive_dwell = sum(
        item["targetDwellMs"]
        for item in windows
        if item["positiveTargetCandidateIndices"]
    )
    if dwell["withPositiveMotionSupport"] != positive_dwell:
        raise ValueError("positive dwell differs from detailed windows")

    if (
        distribution_summary(candidate_to_candidate_elapsed)
        != summary["elapsedMsDistributions"]["candidateToCandidate"]
    ):
        raise ValueError("candidate-transition elapsed distribution differs")
    if (
        distribution_summary(positive_elapsed)
        != summary["elapsedMsDistributions"]["positiveMotionSupport"]
    ):
        raise ValueError("positive elapsed distribution differs")
    for name, values in count_samples.items():
        if distribution_summary(values) != summary["countDistributions"][name]:
            raise ValueError(f"count distribution differs for {name}")
    if (
        summary["elapsedMsDistributions"]["observationTransitions"]["count"]
        != transitions["total"]
    ):
        raise ValueError("observation-transition elapsed count differs")

    return {
        "positiveHypotheses": positive_hypotheses,
        "positiveCandidatePairs": positive_pairs,
        "positiveTargetCandidates": positive_target_instances,
        "positiveWindows": positive_windows,
        "positiveDwellMs": positive_dwell,
    }


def verify_piece_detail_alignment(report: dict) -> None:
    windows_by_song: dict[str, list[dict]] = defaultdict(list)
    initial_by_song: dict[str, list[dict]] = defaultdict(list)
    excluded_by_song: dict[str, list[dict]] = defaultdict(list)
    for window in report["candidateEndpointWindows"]:
        windows_by_song[window["songId"]].append(window)
    for item in report["initialCandidateEndpoints"]:
        initial_by_song[item["songId"]].append(item)
    for item in report["excludedSameTimestampCandidateFrames"]:
        excluded_by_song[item["songId"]].append(item)

    known_song_ids = set(report["source"]["songIds"])
    detailed_song_ids = (
        set(windows_by_song) | set(initial_by_song) | set(excluded_by_song)
    )
    if not detailed_song_ids <= known_song_ids:
        raise ValueError("detailed evidence names a song outside the sample roster")

    for piece in report["perPiece"]:
        song_id = piece["songId"]
        metrics = piece["metrics"]
        endpoints = metrics["endpointFrames"]
        dwell = metrics["terminalDwellMs"]
        transitions = metrics["observationTransitions"]
        instances = metrics["candidateInstances"]
        windows = windows_by_song[song_id]
        initial = initial_by_song[song_id]
        excluded = excluded_by_song[song_id]
        classes = Counter(window["classification"] for window in windows)

        if classes["candidate-entry"] != transitions["candidateEntry"]:
            raise ValueError(f"candidate-entry detail differs for song {song_id}")
        if classes["candidate-exit"] != transitions["candidateExit"]:
            raise ValueError(f"candidate-exit detail differs for song {song_id}")
        if classes["candidate-to-candidate"] != transitions["candidateToCandidate"]:
            raise ValueError(
                f"candidate-to-candidate detail differs for song {song_id}"
            )
        if len(excluded) != endpoints["excludedSameTimestampNonterminalWithCandidates"]:
            raise ValueError(f"excluded candidate frames differ for song {song_id}")

        target_frames = sum(bool(window["targetCandidates"]) for window in windows)
        if target_frames + len(initial) != endpoints["timestampTerminalWithCandidates"]:
            raise ValueError(f"terminal candidate frames differ for song {song_id}")
        if (
            endpoints["timestampTerminalWithCandidates"] + len(excluded)
            != endpoints["rawEventFramesWithCandidates"]
        ):
            raise ValueError(f"raw candidate frames differ for song {song_id}")

        target_candidates = sum(
            len(window["targetCandidates"]) for window in windows
        ) + sum(len(item["candidates"]) for item in initial)
        evaluable_candidates = sum(
            len(window["targetCandidates"])
            for window in windows
            if window["classification"] == "candidate-to-candidate"
        )
        unavailable_candidates = target_candidates - evaluable_candidates
        candidate_pairs = sum(
            len(window["candidateInterpretations"]) for window in windows
        )
        hypotheses = sum(
            len(interpretation["hypothesisInterpretations"])
            for window in windows
            for interpretation in window["candidateInterpretations"]
        )
        positive_hypotheses = sum(
            hypothesis["motionSupport"] == "positive"
            for window in windows
            for interpretation in window["candidateInterpretations"]
            for hypothesis in interpretation["hypothesisInterpretations"]
        )
        positive_targets = sum(
            len(window["positiveTargetCandidateIndices"]) for window in windows
        )
        piece_instance_checks = {
            "timestampTerminalTotal": target_candidates,
            "motionEvaluable": evaluable_candidates,
            "motionUnavailableWithoutCandidatePredecessor": unavailable_candidates,
            "candidatePairs": candidate_pairs,
            "hypothesisInterpretations": hypotheses,
            "positiveHypotheses": positive_hypotheses,
            "withAnyPositiveIncomingHypothesis": positive_targets,
        }
        for name, value in piece_instance_checks.items():
            if instances[name] != value:
                raise ValueError(
                    f"candidate instance detail differs for song {song_id}: {name}"
                )

        candidate_dwell = sum(
            window["targetDwellMs"] for window in windows if window["targetCandidates"]
        ) + sum(item["dwellMs"] for item in initial)
        evaluable_dwell = sum(
            window["targetDwellMs"]
            for window in windows
            if window["classification"] == "candidate-to-candidate"
        )
        pitch_changing_dwell = sum(
            window["targetDwellMs"]
            for window in windows
            if window["classification"] == "candidate-to-candidate"
            and window["pitchChanging"]
        )
        positive_dwell = sum(
            window["targetDwellMs"]
            for window in windows
            if window["positiveTargetCandidateIndices"]
        )
        piece_dwell_checks = {
            "withCandidates": candidate_dwell,
            "withMotionEvaluablePredecessor": evaluable_dwell,
            "withPitchChangingMotionEvaluablePredecessor": pitch_changing_dwell,
            "withPositiveMotionSupport": positive_dwell,
        }
        for name, value in piece_dwell_checks.items():
            if dwell[name] != value:
                raise ValueError(
                    f"candidate dwell detail differs for song {song_id}: {name}"
                )


def verify_onset_crosscheck(report: dict, onset_report_path: Path) -> None:
    if sha256_file(onset_report_path) != ONSET_REPORT_SHA256:
        raise ValueError("onset cross-check report hash is invalid")
    onset = json.loads(onset_report_path.read_text())
    if onset["schema"] != ONSET_REPORT_SCHEMA:
        raise ValueError("onset cross-check report schema is invalid")
    if report["source"]["songIds"] != onset["source"]["songIds"]:
        raise ValueError("onset report song roster differs")
    if report["source"]["midiContentSha256"] != onset["source"]["midiContentSha256"]:
        raise ValueError("onset report MIDI-content hash differs")
    if report["normalization"] != onset["normalization"]:
        raise ValueError("onset report normalization differs")
    if report["projection"] != onset["projection"]:
        raise ValueError("onset report projection differs")

    motion_summary = report["summary"]
    onset_summary = onset["summary"]
    checks = (
        (
            motion_summary["endpointFrames"]["rawEventFrames"],
            onset_summary["eventFrames"]["total"],
        ),
        (
            motion_summary["endpointFrames"]["rawEventFramesWithCandidates"],
            onset_summary["eventFrames"]["withCandidates"],
        ),
        (
            motion_summary["terminalDwellMs"]["sounding"],
            onset_summary["dwellMs"]["sounding"],
        ),
        (
            motion_summary["terminalDwellMs"]["withCandidates"],
            onset_summary["dwellMs"]["withCandidates"],
        ),
    )
    if any(left != right for left, right in checks):
        raise ValueError("onset report frame or dwell totals differ")

    excluded_instances = sum(
        len(item["candidates"])
        for item in report["excludedSameTimestampCandidateFrames"]
    )
    raw_instances = (
        motion_summary["candidateInstances"]["timestampTerminalTotal"]
        + excluded_instances
    )
    if raw_instances != onset_summary["candidateInstances"]["total"]:
        raise ValueError("onset report raw candidate-instance total differs")


def verify_report(
    report_path: Path,
    pop909_root: Path | None,
    onset_report_path: Path | None,
) -> dict:
    report_digest = sha256_file(report_path)
    if report_digest != REPORT_SHA256:
        raise ValueError(f"report digest is {report_digest}, expected {REPORT_SHA256}")
    report = json.loads(report_path.read_text())
    if report["schema"] != REPORT_SCHEMA:
        raise ValueError(f"report.schema must be {REPORT_SCHEMA!r}")
    if report["measurementId"] != MEASUREMENT_ID:
        raise ValueError(f"report.measurementId must be {MEASUREMENT_ID!r}")
    if report["source"]["labelsRead"] is not False:
        raise ValueError("report must record labelsRead false")
    if report["contracts"]["repositoryMeasurementInputsDirty"] is not False:
        raise ValueError("measurement inputs were dirty")
    if report["source"]["pop909Dirty"] is not False:
        raise ValueError("POP909 checkout was dirty during measurement")
    if report["source"]["songCount"] != len(report["source"]["songIds"]):
        raise ValueError("source song count differs from song roster")
    if report["source"]["songIds"] != [piece["songId"] for piece in report["perPiece"]]:
        raise ValueError("per-piece order differs from song roster")

    verify_repository_inputs(report)
    resolved_pop909 = pop909_root or Path(report["source"]["pop909Root"])
    verify_corpus_inputs(report, resolved_pop909)
    verify_aggregate_sums(report)
    positives = verify_detailed_windows(report)
    verify_piece_detail_alignment(report)
    if onset_report_path is not None:
        verify_onset_crosscheck(report, onset_report_path)
    return {
        "reportSha256": report_digest,
        "songCount": report["source"]["songCount"],
        **positives,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--pop909-root", type=Path)
    parser.add_argument("--onset-report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = verify_report(args.report, args.pop909_root, args.onset_report)
    print(
        f"valid: {args.report} ({result['songCount']} songs; "
        f"{result['positiveWindows']} positive windows; "
        f"sha256 {result['reportSha256']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

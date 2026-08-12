"""Run the preregistered automatic-polychord timing sensitivity study.

This tool reinterprets threshold-free onset evidence from the exposed POP909
sample and replays one pinned Liszt source case. It is exploratory: no profile
is selected or promoted to product policy.
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
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import development_exposure
import frame_replay
import onset_evidence
import onset_support
import register_candidates

REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_ROOT = REPO_ROOT / "build"
FIXTURE_ROOT = REPO_ROOT / "research/polychord/data/frame-replay"
REPORT_SCHEMA = "polychord-automatic-timing-sensitivity/1"
MEASUREMENT_ID = REPORT_SCHEMA

PREREGISTRATION = (
    REPO_ROOT / "research/polychord/automatic-timing-sensitivity-preregistration.md"
)
PREREGISTRATION_SHA256 = (
    "957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522"
)

SOURCE_REPORT_SCHEMA = "polychord-onset-exposure-census/1"
SOURCE_MEASUREMENT_ID = (
    "pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1"
)
SOURCE_REPORT_SHA256 = (
    "60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9"
)
POP909_COMMIT = "d83e6edba6872a704f5d3b8b32f5cb540088dae6"
POP909_MIDI_CONTENT_SHA256 = (
    "2aa21f03506d26ce256ed9d22eedc34a6f87694ef9ece389af198ff2e4440eb3"
)
POP909_ROSTER_SHA256 = (
    "b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781"
)
EXPECTED_POP909_TOTALS = {
    "candidateInstances": 3645,
    "candidateFrames": 2524,
    "candidateMs": 205302,
}

LISZT_SHA256 = "e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05"
LISZT_TARGET_SYMBOL = "F|B"
LISZT_LOWER_MIDI_NOTES = (75, 78, 83)
LISZT_UPPER_MIDI_NOTES = (84, 89, 93, 96)
EXPECTED_LISZT_POSITIVE_DWELL_ROWS = (
    (24404, 97, 96),
    (24792, 96, 97),
)

WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS = 50
ONSET_GAP_MINIMUMS_MS = (50, 80, 100, 200, 300)
APPEARANCE_DWELLS_MS = (0, 50, 100, 200, 300)

CONTRACT_PATHS = (
    PREREGISTRATION,
    REPO_ROOT / "research/polychord/frame-replay-schema.md",
    REPO_ROOT / "tool/polychord/frame_replay.py",
    REPO_ROOT / "research/polychord/register-candidate-schema.md",
    REPO_ROOT / "tool/polychord/register_candidates.py",
    REPO_ROOT / "research/polychord/onset-evidence-schema.md",
    REPO_ROOT / "tool/polychord/onset_evidence.py",
    REPO_ROOT / "research/polychord/onset-support-ablation.md",
    REPO_ROOT / "tool/polychord/onset_support.py",
    REPO_ROOT / "tool/polychord/development_exposure.py",
    FIXTURE_ROOT / "synchronous-six-note-cohort.json",
    FIXTURE_ROOT / "two-register-held-cohorts.json",
    Path(__file__).resolve(),
    Path(__file__).with_name("automatic_timing_sensitivity_test.py"),
)


def sha256_file(path: Path) -> str:
    """Return a lowercase SHA-256 digest for one file."""

    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_hash(path: Path, expected: str, label: str) -> None:
    """Fail when a local input differs from its preregistered digest."""

    if not path.is_file():
        raise FileNotFoundError(f"missing {label}: {path}")
    actual = sha256_file(path)
    if actual != expected:
        raise ValueError(f"{label} SHA-256 is {actual}, expected {expected}")


def git(*arguments: str) -> str:
    """Run one read-only Git query at the repository root."""

    return subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def git_blob_sha256(commit: str, relative: Path) -> str:
    """Hash a repository file exactly as recorded at one historical commit."""

    completed = subprocess.run(
        ["git", "show", f"{commit}:{relative.as_posix()}"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=True,
    )
    return hashlib.sha256(completed.stdout).hexdigest()


def profile_id(gap_minimum_ms: int) -> str:
    """Name one fixed onset-gap profile."""

    if gap_minimum_ms == onset_support.BETWEEN_LAYER_SEPARATION_MINIMUM_MS:
        return onset_support.ABLATION_ID
    return f"coherent-separated-onsets-50-{gap_minimum_ms}ms/sensitivity-1"


def profile_parameters(gap_minimum_ms: int) -> dict:
    """Serialize the one-variable onset profile family."""

    return {
        "id": profile_id(gap_minimum_ms),
        "withinLayerCohortSpanMaximumMs": (WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS),
        "betweenLayerSeparationMinimumMs": gap_minimum_ms,
        "comparisonRole": (
            "committed-baseline" if gap_minimum_ms == 200 else "exploratory"
        ),
    }


def dwell_profile(dwell_ms: int) -> dict:
    """Name one fixed appearance-dwell comparison row."""

    if dwell_ms not in APPEARANCE_DWELLS_MS:
        raise ValueError(f"unregistered appearance dwell: {dwell_ms}")
    return {
        "id": (
            "polychord-output/2"
            if dwell_ms == 200
            else f"authorization-dwell-{dwell_ms}ms/sensitivity-1"
        ),
        "appearanceDwellMs": dwell_ms,
        "comparisonRole": (
            "existing-presentation-baseline" if dwell_ms == 200 else "exploratory"
        ),
        "measures": "candidate-authorization-opportunity-survival",
    }


def interpret_onset_evidence(evidence: dict, gap_minimum_ms: int) -> dict:
    """Apply one frozen sensitivity profile to threshold-free evidence."""

    if gap_minimum_ms not in ONSET_GAP_MINIMUMS_MS:
        raise ValueError(f"unregistered onset-gap minimum: {gap_minimum_ms}")
    if not evidence["allCandidateOnsetsKnown"]:
        return {
            "availability": "incomplete",
            "lowerWithinCohortSpanMaximum": None,
            "upperWithinCohortSpanMaximum": None,
            "layerOnsetOrder": None,
            "betweenLayerOnsetIntervalGapMs": None,
            "onsetCohortSupport": "neutral",
            "reasonCodes": ["onset-history-incomplete"],
        }

    lower = evidence["lower"]
    upper = evidence["upper"]
    lower_coherent = lower["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    upper_coherent = upper["knownOnsetSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
    layer_order, separation = onset_support.onset_interval_order_and_gap(lower, upper)

    reasons = []
    if not lower_coherent:
        reasons.append("lower-span-exceeds-maximum")
    if not upper_coherent:
        reasons.append("upper-span-exceeds-maximum")
    if separation < gap_minimum_ms:
        reasons.append("between-layer-separation-below-minimum")

    supports = not reasons
    return {
        "availability": "complete",
        "lowerWithinCohortSpanMaximum": lower_coherent,
        "upperWithinCohortSpanMaximum": upper_coherent,
        "layerOnsetOrder": layer_order,
        "betweenLayerOnsetIntervalGapMs": separation,
        "onsetCohortSupport": "positive" if supports else "neutral",
        "reasonCodes": (["separate-coherent-onset-cohorts"] if supports else reasons),
    }


def signed_interval_gap_ms(evidence: dict) -> int | None:
    """Report orientation as sign while preserving interval distance."""

    if not evidence["allCandidateOnsetsKnown"]:
        return None
    order, gap = onset_support.onset_interval_order_and_gap(
        evidence["lower"], evidence["upper"]
    )
    if order == "upper-then-lower":
        return -gap
    return gap


def sounding_instance_binding(item: dict) -> dict:
    """Retain the exact onset instance assigned to each candidate note."""

    evidence = item["onsetEvidence"]

    def layer_binding(name: str) -> list[dict]:
        return [
            {
                "midiNote": note["midiNote"],
                "onsetEventIndex": note["onsetEventIndex"],
            }
            for note in evidence[name]["notes"]
        ]

    return {
        "lower": layer_binding("lower"),
        "upper": layer_binding("upper"),
    }


def opportunity_key(item: dict) -> dict:
    """Build the preregistered candidate-and-instance opportunity key."""

    binding = item.get("soundingInstanceBinding")
    if binding is None:
        binding = sounding_instance_binding(item)
    return {
        "candidate": item["candidate"],
        "soundingInstanceBinding": binding,
    }


def serialized_opportunity_key(item: dict) -> str:
    """Return a stable internal representation of an opportunity key."""

    return json.dumps(opportunity_key(item), sort_keys=True, separators=(",", ":"))


def serialize_key(key: dict) -> str:
    """Serialize an already constructed opportunity key for stable sorting."""

    return json.dumps(key, sort_keys=True, separators=(",", ":"))


def survival_by_dwell(duration_ms: int) -> dict[str, dict]:
    """Evaluate inclusive authorization-dwell survival for one episode."""

    if duration_ms < 0:
        raise ValueError("episode duration cannot be negative")
    return {
        str(dwell_ms): {
            "survives": duration_ms >= dwell_ms,
            "potentialPostDwellDurationMs": (
                duration_ms - dwell_ms if duration_ms >= dwell_ms else 0
            ),
        }
        for dwell_ms in APPEARANCE_DWELLS_MS
    }


def summarize_episode_survival(episodes: list[dict]) -> dict[str, dict]:
    """Aggregate opportunity survival without calling it product display time."""

    return {
        str(dwell_ms): {
            "survivingOpportunities": sum(
                episode["survivalByAppearanceDwellMs"][str(dwell_ms)]["survives"]
                for episode in episodes
            ),
            "sumOfPerOpportunityPotentialPostDwellMs": sum(
                episode["survivalByAppearanceDwellMs"][str(dwell_ms)][
                    "potentialPostDwellDurationMs"
                ]
                for episode in episodes
            ),
            "durationInterpretation": (
                "sum across independently tracked candidate opportunities; "
                "overlapping candidates are not merged or treated as product "
                "display time"
            ),
        }
        for dwell_ms in APPEARANCE_DWELLS_MS
    }


def authorization_episodes(frames: list[dict], profile: str) -> list[dict]:
    """Track exact positive opportunities across consecutive event frames."""

    active: dict[str, dict] = {}
    episodes = []
    previous_event_index = None

    def close(key: str) -> None:
        episode = active.pop(key)
        episode["survivalByAppearanceDwellMs"] = survival_by_dwell(
            episode["durationMs"]
        )
        episodes.append(episode)

    for frame in frames:
        event_index = frame["afterEventIndex"]
        if previous_event_index is not None and event_index != previous_event_index + 1:
            for key in list(active):
                close(key)

        positive: dict[str, dict] = {}
        for item in frame["candidateInterpretations"]:
            if (
                item["profileInterpretations"][profile]["onsetCohortSupport"]
                != "positive"
            ):
                continue
            key = serialized_opportunity_key(item)
            if key in positive:
                raise ValueError(
                    "one frame contains a duplicated exact authorization opportunity"
                )
            positive[key] = item

        for key in set(active) - set(positive):
            close(key)

        for key, item in positive.items():
            frame_reference = {
                "afterEventIndex": event_index,
                "timestampMs": frame["timestampMs"],
                "dwellMs": frame["dwellMs"],
                "sourceInstanceId": item["sourceInstanceId"],
            }
            if key in active:
                episode = active[key]
                episode["lastEventIndex"] = event_index
                episode["endTimestampMsExclusive"] = (
                    frame["timestampMs"] + frame["dwellMs"]
                )
                episode["durationMs"] += frame["dwellMs"]
                episode["frames"].append(frame_reference)
            else:
                active[key] = {
                    "profileId": profile,
                    "opportunityKey": opportunity_key(item),
                    "startEventIndex": event_index,
                    "lastEventIndex": event_index,
                    "startTimestampMs": frame["timestampMs"],
                    "endTimestampMsExclusive": (
                        frame["timestampMs"] + frame["dwellMs"]
                    ),
                    "durationMs": frame["dwellMs"],
                    "frames": [frame_reference],
                }

        previous_event_index = event_index

    for key in list(active):
        close(key)
    return sorted(
        episodes,
        key=lambda episode: (
            episode["startEventIndex"],
            serialize_key(episode["opportunityKey"]),
        ),
    )


def _load_json_object(path: Path) -> dict:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return payload


def validate_embedded_pins(pins: object, repository_commit: str) -> None:
    """Verify source-report contracts against its recorded repository commit."""

    if not isinstance(pins, list) or not pins:
        raise ValueError("source report must retain nonempty contract pins")
    seen = set()
    for index, pin in enumerate(pins):
        if not isinstance(pin, dict) or set(pin) != {"path", "sha256"}:
            raise ValueError(f"source contract pin {index} is malformed")
        relative = Path(pin["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"source contract pin {index} escapes the repository")
        if relative in seen:
            raise ValueError(f"source contract pin is duplicated: {relative}")
        seen.add(relative)
        actual = git_blob_sha256(repository_commit, relative)
        if actual != pin["sha256"]:
            raise ValueError(
                f"source pin {relative} at {repository_commit} is {actual}, "
                f"expected {pin['sha256']}"
            )


def validate_source_report(path: Path) -> dict:
    """Load only the exact exposed POP909 report and validate its provenance."""

    require_hash(path, SOURCE_REPORT_SHA256, "POP909 onset report")
    report = _load_json_object(path)
    if report.get("schema") != SOURCE_REPORT_SCHEMA:
        raise ValueError("POP909 onset report schema does not match")
    if report.get("measurementId") != SOURCE_MEASUREMENT_ID:
        raise ValueError("POP909 onset report measurement ID does not match")

    source = report.get("source")
    expected_source = {
        "pop909Commit": POP909_COMMIT,
        "pop909Dirty": False,
        "midiContentSha256": POP909_MIDI_CONTENT_SHA256,
        "rosterSha256": POP909_ROSTER_SHA256,
        "rosterField": "sample",
        "songCount": 101,
        "labelsRead": False,
    }
    if not isinstance(source, dict):
        raise TypeError("POP909 onset report source must be an object")
    for field, expected in expected_source.items():
        if source.get(field) != expected:
            raise ValueError(
                f"POP909 onset report source.{field} is {source.get(field)!r}, "
                f"expected {expected!r}"
            )
    song_ids = source.get("songIds")
    if not isinstance(song_ids, list) or len(song_ids) != 101:
        raise ValueError("POP909 onset report must expose exactly 101 sample IDs")

    contracts = report.get("contracts")
    expected_contracts = {
        "frameReplaySchema": frame_replay.FIXTURE_SCHEMA,
        "registerCandidateSchema": register_candidates.OUTPUT_SCHEMA,
        "onsetEvidenceSchema": onset_evidence.OUTPUT_SCHEMA,
        "onsetSupportSchema": onset_support.OUTPUT_SCHEMA,
        "onsetSupportAblationId": onset_support.ABLATION_ID,
    }
    if not isinstance(contracts, dict):
        raise TypeError("POP909 onset report contracts must be an object")
    for field, expected in expected_contracts.items():
        if contracts.get(field) != expected:
            raise ValueError(f"POP909 onset report contracts.{field} does not match")
    repository_commit = contracts.get("repositoryCommit")
    if not isinstance(repository_commit, str) or len(repository_commit) != 40:
        raise ValueError("POP909 onset report repository commit is malformed")
    if contracts.get("repositoryMeasurementInputsDirty") is not False:
        raise ValueError("POP909 onset report measurement inputs were dirty")
    validate_embedded_pins(contracts.get("pins"), repository_commit)

    summary = report.get("summary", {})
    actual_totals = {
        "candidateInstances": summary.get("candidateInstances", {}).get("total"),
        "candidateFrames": summary.get("eventFrames", {}).get("withCandidates"),
        "candidateMs": summary.get("dwellMs", {}).get("withCandidates"),
    }
    if actual_totals != EXPECTED_POP909_TOTALS:
        raise ValueError(
            f"POP909 baseline totals are {actual_totals}, "
            f"expected {EXPECTED_POP909_TOTALS}"
        )
    if (
        len(report.get("candidateFrames", []))
        != EXPECTED_POP909_TOTALS["candidateFrames"]
    ):
        raise ValueError("POP909 candidate-frame detail is incomplete")
    return report


def candidate_instance(
    *, source_prefix: str, frame: dict, item: dict, candidate_index: int
) -> dict:
    """Reinterpret and retain one complete threshold-free source instance."""

    stored = item.get("onsetInterpretation")
    evidence = item["onsetEvidence"]
    current_baseline = onset_support.interpret_onset_evidence(evidence)
    derived_baseline = interpret_onset_evidence(evidence, 200)
    if stored is not None and stored != current_baseline:
        raise ValueError("stored 200 ms interpretation does not match current code")
    if current_baseline != derived_baseline:
        raise ValueError("sensitivity 200 ms interpretation does not match baseline")

    source_id = (
        f"{source_prefix}/event-{frame['afterEventIndex']}/candidate-{candidate_index}"
    )
    interpretations = {
        profile_id(gap): interpret_onset_evidence(evidence, gap)
        for gap in ONSET_GAP_MINIMUMS_MS
    }
    notes = evidence["lower"]["notes"] + evidence["upper"]["notes"]
    layer_order = None
    interval_gap_ms = None
    if evidence["allCandidateOnsetsKnown"]:
        layer_order, interval_gap_ms = onset_support.onset_interval_order_and_gap(
            evidence["lower"], evidence["upper"]
        )
    return {
        "sourceInstanceId": source_id,
        "candidate": item["candidate"],
        "soundingInstanceBinding": sounding_instance_binding(item),
        "sharedPitchClasses": item["candidate"]["sharedPitchClasses"],
        "containsSustainedNote": any(
            note["soundingState"] == "sustained" for note in notes
        ),
        "rawOnset": {
            "allCandidateOnsetsKnown": evidence["allCandidateOnsetsKnown"],
            "lowerSpanMs": evidence["lower"]["knownOnsetSpanMs"],
            "upperSpanMs": evidence["upper"]["knownOnsetSpanMs"],
            "layerOnsetOrder": layer_order,
            "intervalGapMs": interval_gap_ms,
            "signedIntervalGapMs": signed_interval_gap_ms(evidence),
            "upperEarliestMinusLowerLatestMs": evidence[
                "upperEarliestMinusLowerLatestMs"
            ],
            "upperLatestMinusLowerEarliestMs": evidence[
                "upperLatestMinusLowerEarliestMs"
            ],
        },
        "onsetEvidence": evidence,
        "profileInterpretations": interpretations,
    }


def reinterpret_frames(source_frames: list[dict]) -> list[dict]:
    """Flatten and reinterpret every POP909 candidate without reading labels."""

    frames = []
    instance_count = 0
    for source_frame in source_frames:
        song_id = source_frame["songId"]
        items = [
            candidate_instance(
                source_prefix=f"pop909/{song_id}",
                frame=source_frame,
                item=item,
                candidate_index=index,
            )
            for index, item in enumerate(source_frame["candidateInterpretations"])
        ]
        instance_count += len(items)
        frames.append(
            {
                "songId": song_id,
                "afterEventIndex": source_frame["afterEventIndex"],
                "timestampMs": source_frame["timestampMs"],
                "dwellMs": source_frame["dwellMs"],
                "observationFrame": source_frame["observationFrame"],
                "candidateInterpretations": items,
            }
        )
    if instance_count != EXPECTED_POP909_TOTALS["candidateInstances"]:
        raise ValueError(
            f"reinterpreted {instance_count} POP909 instances, "
            f"expected {EXPECTED_POP909_TOTALS['candidateInstances']}"
        )
    return frames


def summarize_profile(frames: list[dict], profile: str) -> dict:
    """Summarize candidate, frame, duration, piece, and neutral-reason exposure."""

    positive_instances = 0
    positive_frames = 0
    positive_dwell_ms = 0
    positive_pieces = set()
    reasons: Counter[str] = Counter()
    newly_positive = []
    baseline_id = profile_id(200)

    for frame in frames:
        frame_positive = False
        for item in frame["candidateInterpretations"]:
            interpretation = item["profileInterpretations"][profile]
            if interpretation["onsetCohortSupport"] == "positive":
                positive_instances += 1
                frame_positive = True
                if (
                    item["profileInterpretations"][baseline_id]["onsetCohortSupport"]
                    != "positive"
                ):
                    newly_positive.append(
                        {
                            "sourceInstanceId": item["sourceInstanceId"],
                            "songId": frame.get("songId"),
                            "afterEventIndex": frame["afterEventIndex"],
                            "timestampMs": frame["timestampMs"],
                            "dwellMs": frame["dwellMs"],
                            "candidate": item["candidate"],
                            "soundingInstanceBinding": item["soundingInstanceBinding"],
                            "rawOnset": item["rawOnset"],
                        }
                    )
            else:
                reasons.update(interpretation["reasonCodes"])
        if frame_positive:
            positive_frames += 1
            positive_dwell_ms += frame["dwellMs"]
            if frame.get("songId") is not None:
                positive_pieces.add(frame["songId"])

    positive_piece_count = (
        len(positive_pieces) if all("songId" in frame for frame in frames) else None
    )
    return {
        "positiveCandidateInstances": positive_instances,
        "positiveEventFrames": positive_frames,
        "positiveDwellMs": positive_dwell_ms,
        "positivePieces": positive_piece_count,
        "neutralReasonCounts": dict(sorted(reasons.items())),
        "newlyPositiveRelativeTo200ms": {
            "candidateInstances": len(newly_positive),
            "instances": newly_positive,
        },
    }


def per_piece_summaries(
    frames: list[dict], source_per_piece: list[dict], song_ids: list[str]
) -> list[dict]:
    """Report each POP909 sample song under every registered profile."""

    frames_by_song: dict[str, list[dict]] = defaultdict(list)
    for frame in frames:
        frames_by_song[frame["songId"]].append(frame)

    rows = []
    baseline_id = profile_id(200)
    source_by_song = {row["songId"]: row for row in source_per_piece}
    if set(source_by_song) != set(song_ids):
        raise ValueError("POP909 source per-piece roster does not match source IDs")
    for song_id in song_ids:
        piece_frames = frames_by_song[song_id]
        profiles = {}
        for gap in ONSET_GAP_MINIMUMS_MS:
            profile = profile_id(gap)
            summary = summarize_profile(piece_frames, profile)
            new_time = sum(
                frame["dwellMs"]
                for frame in piece_frames
                if any(
                    item["profileInterpretations"][profile]["onsetCohortSupport"]
                    == "positive"
                    and item["profileInterpretations"][baseline_id][
                        "onsetCohortSupport"
                    ]
                    != "positive"
                    for item in frame["candidateInterpretations"]
                )
            )
            profiles[profile] = {
                "positiveCandidateInstances": summary["positiveCandidateInstances"],
                "positiveEventFrames": summary["positiveEventFrames"],
                "positiveDwellMs": summary["positiveDwellMs"],
                "newlyPositiveDwellMsRelativeTo200ms": new_time,
            }
        source_metrics = source_by_song[song_id]["metrics"]
        rows.append(
            {
                "songId": song_id,
                "baselineCandidateExposure": {
                    "candidateInstances": source_metrics["candidateInstances"]["total"],
                    "candidateEventFrames": source_metrics["eventFrames"][
                        "withCandidates"
                    ],
                    "candidateDwellMs": source_metrics["dwellMs"]["withCandidates"],
                },
                "profiles": profiles,
            }
        )
    return rows


def top_newly_positive_pieces(per_piece: list[dict], profile: str) -> dict:
    """Rank concentration of frame-level newly positive time."""

    ranked = sorted(
        (
            {
                "songId": row["songId"],
                "newlyPositiveDwellMs": row["profiles"][profile][
                    "newlyPositiveDwellMsRelativeTo200ms"
                ],
            }
            for row in per_piece
            if row["profiles"][profile]["newlyPositiveDwellMsRelativeTo200ms"]
        ),
        key=lambda row: (-row["newlyPositiveDwellMs"], row["songId"]),
    )
    total = sum(row["newlyPositiveDwellMs"] for row in ranked)
    top = ranked[:20]
    return {
        "totalNewlyPositiveDwellMs": total,
        "top20": [
            {
                **row,
                "shareOfTotalNewlyPositiveDwellMs": (
                    row["newlyPositiveDwellMs"] / total if total else None
                ),
            }
            for row in top
        ],
        "top20ShareOfTotalNewlyPositiveDwellMs": (
            sum(row["newlyPositiveDwellMs"] for row in top) / total if total else None
        ),
    }


def joint_distribution(frames: list[dict]) -> dict:
    """Retain joint onset-span/gap distributions for declared subsets."""

    categories: dict[str, Counter[tuple[int | None, int | None, int | None]]] = {
        name: Counter()
        for name in (
            "allCandidateInstances",
            "completeEvidence",
            "twoCompactLayers",
            "nonoverlappingIntervals",
            "sharedToneCandidates",
            "disjointCandidates",
            "candidatesContainingSustainedNotes",
        )
    }

    for frame in frames:
        for item in frame["candidateInterpretations"]:
            raw = item["rawOnset"]
            key = (
                raw["lowerSpanMs"],
                raw["upperSpanMs"],
                raw["signedIntervalGapMs"],
            )
            categories["allCandidateInstances"][key] += 1
            if raw["allCandidateOnsetsKnown"]:
                categories["completeEvidence"][key] += 1
                if (
                    raw["lowerSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
                    and raw["upperSpanMs"] <= WITHIN_LAYER_COHORT_SPAN_MAXIMUM_MS
                ):
                    categories["twoCompactLayers"][key] += 1
                if raw["signedIntervalGapMs"] != 0:
                    categories["nonoverlappingIntervals"][key] += 1
            if item["sharedPitchClasses"]:
                categories["sharedToneCandidates"][key] += 1
            else:
                categories["disjointCandidates"][key] += 1
            if item["containsSustainedNote"]:
                categories["candidatesContainingSustainedNotes"][key] += 1

    def serialize(counter: Counter) -> dict:
        rows = [
            {
                "lowerSpanMs": key[0],
                "upperSpanMs": key[1],
                "signedIntervalGapMs": key[2],
                "candidateInstances": count,
            }
            for key, count in sorted(
                counter.items(),
                key=lambda row: tuple(
                    -1 if value is None else value for value in row[0]
                ),
            )
        ]
        return {"candidateInstances": sum(counter.values()), "distribution": rows}

    return {
        "signedGapDefinition": (
            "positive when the upper onset interval follows the lower, negative "
            "when the lower follows the upper, zero when the intervals overlap"
        ),
        "categories": {
            name: serialize(counter) for name, counter in categories.items()
        },
    }


def episodes_by_profile_and_piece(
    frames: list[dict], song_ids: list[str]
) -> dict[str, dict]:
    """Retain every independent POP909 authorization opportunity."""

    frames_by_song: dict[str, list[dict]] = defaultdict(list)
    for frame in frames:
        frames_by_song[frame["songId"]].append(frame)
    result = {}
    for gap in ONSET_GAP_MINIMUMS_MS:
        profile = profile_id(gap)
        per_piece = []
        for song_id in song_ids:
            episodes = authorization_episodes(frames_by_song[song_id], profile)
            if episodes:
                per_piece.append({"songId": song_id, "episodes": episodes})
        result[profile] = {
            "episodeCount": sum(len(row["episodes"]) for row in per_piece),
            "zeroDurationEpisodeCount": sum(
                episode["durationMs"] == 0
                for row in per_piece
                for episode in row["episodes"]
            ),
            "survivalSummaryByAppearanceDwellMs": summarize_episode_survival(
                [episode for row in per_piece for episode in row["episodes"]]
            ),
            "perPiece": per_piece,
        }
    return result


def strict_fixture_from_normalized(
    normalized: dict, *, through_event_index: int | None = None
) -> dict:
    """Adapt a relevant normalization prefix to strict evidence replay."""

    source_events = normalized["events"]
    source_frames = normalized["frames"]
    if through_event_index is not None:
        if (
            isinstance(through_event_index, bool)
            or not isinstance(through_event_index, int)
            or through_event_index < 0
            or through_event_index >= len(source_events)
        ):
            raise ValueError("through_event_index must identify a normalized event")
        source_events = source_events[: through_event_index + 1]
        source_frames = source_frames[: through_event_index + 1]

    events = []
    for event in source_events:
        base = {
            "index": event["index"],
            "timestampMs": event["timestampMs"],
            "type": event["type"],
        }
        if event["type"] in {"noteOn", "noteOff"}:
            base.update({"midiNote": event["midiNote"], "velocity": event["velocity"]})
        elif event["type"] == "pedal":
            base["down"] = event["down"]
        else:
            raise ValueError(
                "Liszt normalization produced an unsupported observable event: "
                f"{event['type']}"
            )
        events.append(base)

    fixture = {
        "schema": frame_replay.FIXTURE_SCHEMA,
        "id": "source/liszt-malediction-laviano-2008",
        "description": "Pinned hand-sequenced Malediction source replay.",
        "timeBase": "milliseconds",
        "initialState": {
            "pressedMidiNotes": [],
            "sustainedMidiNotes": [],
            "pedalDown": False,
        },
        "events": events,
        "frames": [],
        "endTimestampMs": normalized["endTimestampMs"],
    }
    fixture["frames"] = frame_replay.replay_fixture(fixture)
    observed = [
        {
            name: frame[name]
            for name in (
                "afterEventIndex",
                "timestampMs",
                "pressedMidiNotes",
                "sustainedMidiNotes",
                "soundingMidiNotes",
                "pedalDown",
            )
        }
        for frame in source_frames
    ]
    if fixture["frames"] != observed:
        raise ValueError("strict Liszt replay differs from normalized observations")
    frame_replay.validate_fixture(fixture)
    return fixture


def liszt_source_case(path: Path) -> dict:
    """Replay and reinterpret the pinned Liszt target assignment."""

    require_hash(path, LISZT_SHA256, "Liszt MIDI")
    messages, end_timestamp_ms, read_counts = development_exposure.read_midi_messages(
        path
    )
    normalized = development_exposure.normalize_midi_messages(
        messages, end_timestamp_ms
    )
    target_locations = []
    for index, frame in enumerate(normalized["frames"]):
        target_candidates = [
            candidate
            for candidate in register_candidates.generate_register_candidates(
                frame["soundingMidiNotes"]
            )
            if candidate.symbol == LISZT_TARGET_SYMBOL
            and candidate.lower.midi_notes == LISZT_LOWER_MIDI_NOTES
            and candidate.upper.midi_notes == LISZT_UPPER_MIDI_NOTES
        ]
        if len(target_candidates) > 1:
            raise ValueError("Liszt frame contains a duplicated exact target")
        if target_candidates:
            target_locations.append((index, target_candidates[0]))
    if not target_locations:
        raise ValueError("Liszt replay contains no exact target opportunities")

    last_target_index = target_locations[-1][0]
    fixture = strict_fixture_from_normalized(
        normalized, through_event_index=last_target_index
    )
    onset_frames = onset_evidence.replay_onset_frames(fixture)
    target_frames = []

    for index, target_candidate in target_locations:
        frame = fixture["frames"][index]
        onset_frame = onset_frames[index]
        next_timestamp_ms = (
            normalized["frames"][index + 1]["timestampMs"]
            if index + 1 < len(normalized["frames"])
            else normalized["endTimestampMs"]
        )
        dwell_ms = next_timestamp_ms - frame["timestampMs"]
        evidence_item = onset_evidence.candidate_onset_evidence(
            target_candidate, onset_frame
        )
        target_frames.append(
            {
                "afterEventIndex": frame["afterEventIndex"],
                "timestampMs": frame["timestampMs"],
                "dwellMs": dwell_ms,
                "observationFrame": frame,
                "candidateInterpretations": [
                    candidate_instance(
                        source_prefix="liszt/malediction",
                        frame=frame,
                        item=evidence_item,
                        candidate_index=0,
                    )
                ],
            }
        )

    reproduced_rows = tuple(
        (
            frame["timestampMs"],
            frame["dwellMs"],
            frame["candidateInterpretations"][0]["rawOnset"]["signedIntervalGapMs"],
        )
        for frame in target_frames
        if frame["dwellMs"] > 0
    )
    if reproduced_rows != EXPECTED_LISZT_POSITIVE_DWELL_ROWS:
        raise ValueError(
            f"Liszt positive-dwell target rows are {reproduced_rows}, "
            f"expected {EXPECTED_LISZT_POSITIVE_DWELL_ROWS}"
        )

    profiles = {}
    for gap in ONSET_GAP_MINIMUMS_MS:
        profile = profile_id(gap)
        episodes = authorization_episodes(target_frames, profile)
        profiles[profile] = {
            "summary": summarize_profile(target_frames, profile),
            "episodes": episodes,
            "survivalSummaryByAppearanceDwellMs": summarize_episode_survival(episodes),
        }

    expected_opportunities = {
        profile_id(gap): (2 if gap in {50, 80} else 0) for gap in ONSET_GAP_MINIMUMS_MS
    }
    actual_opportunities = {
        profile: len(data["episodes"]) for profile, data in profiles.items()
    }
    if actual_opportunities != expected_opportunities:
        raise ValueError(
            f"Liszt opportunity outcomes are {actual_opportunities}, "
            f"expected {expected_opportunities}"
        )
    for profile in (profile_id(50), profile_id(80)):
        episodes = profiles[profile]["episodes"]
        if [episode["durationMs"] for episode in episodes] != [97, 96]:
            raise ValueError(f"Liszt {profile} episode durations do not reproduce")
        expected_survivors = {"0": 2, "50": 2, "100": 0, "200": 0, "300": 0}
        actual_survivors = {
            dwell: row["survivingOpportunities"]
            for dwell, row in profiles[profile][
                "survivalSummaryByAppearanceDwellMs"
            ].items()
        }
        if actual_survivors != expected_survivors:
            raise ValueError(
                f"Liszt {profile} dwell outcomes are {actual_survivors}, "
                f"expected {expected_survivors}"
            )

    return {
        "source": {
            "composer": "Franz Liszt",
            "work": "Malediction",
            "sequenceAuthor": "Antonio Laviano",
            "sequenceYear": 2008,
            "midiPath": str(path),
            "midiSha256": sha256_file(path),
        },
        "fixedConstructionLabel": "boundary",
        "constructionReading": (
            "rapid score-attested alternation that may blur; not a "
            "score-attested simultaneous static polychord"
        ),
        "normalization": {
            "readCounts": read_counts,
            **normalized["normalization"],
            "normalizedEvents": len(normalized["events"]),
            "strictOnsetReplayThroughEventIndex": last_target_index,
            "laterEventsExcludedFromOnsetReplay": (
                len(normalized["events"]) - last_target_index - 1
            ),
            "targetSearchReadEveryNormalizedFrame": True,
        },
        "target": {
            "symbol": LISZT_TARGET_SYMBOL,
            "lowerMidiNotes": list(LISZT_LOWER_MIDI_NOTES),
            "upperMidiNotes": list(LISZT_UPPER_MIDI_NOTES),
        },
        "frames": target_frames,
        "profiles": profiles,
    }


def synthetic_evidence(separation_ms: int) -> dict:
    """Construct two simultaneous-within-layer triads at a fixed gap."""

    def layer(notes: tuple[int, ...], timestamp_ms: int, event_offset: int) -> dict:
        note_rows = [
            {
                "midiNote": note,
                "soundingState": "pressed",
                "onsetEventIndex": event_offset + index,
                "onsetTimestampMs": timestamp_ms,
                "onsetVelocity": 96,
            }
            for index, note in enumerate(notes)
        ]
        return {
            "notes": note_rows,
            "knownOnsetCount": len(notes),
            "unknownOnsetCount": 0,
            "allOnsetsKnown": True,
            "distinctKnownOnsetTimestampsMs": [timestamp_ms],
            "earliestKnownOnsetMs": timestamp_ms,
            "latestKnownOnsetMs": timestamp_ms,
            "knownOnsetSpanMs": 0,
        }

    lower = layer((48, 52, 55), 0, 0)
    upper = layer((67, 70, 74), separation_ms, 3)
    return {
        "allCandidateOnsetsKnown": True,
        "lower": lower,
        "upper": upper,
        "upperEarliestMinusLowerLatestMs": separation_ms,
        "upperLatestMinusLowerEarliestMs": separation_ms,
    }


def matched_history_control(fixture_name: str) -> dict:
    """Replay one committed C|Gm matched-history mechanics fixture."""

    path = FIXTURE_ROOT / fixture_name
    fixture = _load_json_object(path)
    frame_replay.validate_fixture(fixture)
    full_frame = next(
        frame
        for frame in reversed(fixture["frames"])
        if register_candidates.generate_register_candidates(frame["soundingMidiNotes"])
    )
    after_event_index = full_frame["afterEventIndex"]
    document = onset_evidence.evidence_document(path, after_event_index)
    if len(document["candidateEvidence"]) != 1:
        raise ValueError(f"matched-history fixture {fixture_name} is ambiguous")
    item = document["candidateEvidence"][0]
    if item["candidate"]["symbol"] != "C|Gm":
        raise ValueError(f"matched-history fixture {fixture_name} lost C|Gm")
    return {
        "fixtureId": document["fixtureId"],
        "fixturePath": str(path.relative_to(REPO_ROOT)),
        "fixtureSha256": document["fixtureSha256"],
        "afterEventIndex": after_event_index,
        "candidate": item["candidate"],
        "onsetEvidence": item["onsetEvidence"],
        "interpretations": {
            profile_id(gap): interpret_onset_evidence(item["onsetEvidence"], gap)
            for gap in ONSET_GAP_MINIMUMS_MS
        },
    }


def mechanics_controls() -> dict:
    """Evaluate preregistered synthetic boundary mechanics outside source totals."""

    onset_rows = []
    for gap in ONSET_GAP_MINIMUMS_MS:
        for role, separation in (
            ("exact-threshold", gap),
            ("one-ms-below", gap - 1),
        ):
            interpretation = interpret_onset_evidence(
                synthetic_evidence(separation), gap
            )
            expected = role == "exact-threshold"
            actual = interpretation["onsetCohortSupport"] == "positive"
            if actual != expected:
                raise ValueError(
                    f"synthetic onset control failed at gap {gap}, role {role}"
                )
            onset_rows.append(
                {
                    "gapMinimumMs": gap,
                    "role": role,
                    "separationMs": separation,
                    "interpretation": interpretation,
                }
            )

    matched_history = [
        matched_history_control("synchronous-six-note-cohort.json"),
        matched_history_control("two-register-held-cohorts.json"),
    ]
    matched_gaps = [
        row["interpretations"][profile_id(50)]["betweenLayerOnsetIntervalGapMs"]
        for row in matched_history
    ]
    if matched_gaps != [0, 400]:
        raise ValueError(
            f"matched-history controls reproduced gaps {matched_gaps}, "
            "expected [0, 400]"
        )

    dwell_rows = []
    for dwell in APPEARANCE_DWELLS_MS:
        durations = (0,) if dwell == 0 else (dwell, dwell - 1)
        for duration in durations:
            result = survival_by_dwell(duration)[str(dwell)]
            expected = duration >= dwell
            if result["survives"] != expected:
                raise ValueError(
                    f"synthetic dwell control failed at dwell {dwell}, "
                    f"duration {duration}"
                )
            dwell_rows.append(
                {
                    "appearanceDwellMs": dwell,
                    "episodeDurationMs": duration,
                    **result,
                }
            )
    return {
        "excludedFromSourceAndCorpusTotals": True,
        "matchedHistoryControls": matched_history,
        "onsetBoundaryControls": onset_rows,
        "dwellBoundaryControls": dwell_rows,
    }


def assert_onset_monotonicity(frames: list[dict]) -> None:
    """Ensure lowering the gap cannot remove otherwise fixed support."""

    for frame in frames:
        for item in frame["candidateInterpretations"]:
            outcomes = [
                item["profileInterpretations"][profile_id(gap)]["onsetCohortSupport"]
                == "positive"
                for gap in ONSET_GAP_MINIMUMS_MS
            ]
            if any(
                outcomes[index] and not outcomes[index - 1]
                for index in range(1, len(outcomes))
            ):
                raise ValueError(
                    f"onset monotonicity failed for {item['sourceInstanceId']}"
                )


def assert_dwell_monotonicity(episodes: list[dict]) -> None:
    """Ensure shortening dwell cannot remove a surviving opportunity."""

    for episode in episodes:
        outcomes = [
            episode["survivalByAppearanceDwellMs"][str(dwell)]["survives"]
            for dwell in APPEARANCE_DWELLS_MS
        ]
        if any(
            outcomes[index] and not outcomes[index - 1]
            for index in range(1, len(outcomes))
        ):
            raise ValueError("authorization-dwell monotonicity failed")


def contract_pins() -> list[dict]:
    """Pin the complete implementation dependency surface."""

    return [
        {"path": str(path.relative_to(REPO_ROOT)), "sha256": sha256_file(path)}
        for path in CONTRACT_PATHS
    ]


def build_report(onset_report_path: Path, liszt_midi_path: Path) -> dict:
    """Build and validate the complete preregistered local report."""

    if Path.cwd().resolve() != REPO_ROOT.resolve():
        raise ValueError(f"run from repository root {REPO_ROOT}")
    require_hash(
        PREREGISTRATION,
        PREREGISTRATION_SHA256,
        "timing-sensitivity preregistration",
    )
    require_hash(liszt_midi_path, LISZT_SHA256, "Liszt MIDI")
    source_report = validate_source_report(onset_report_path)
    pop_frames = reinterpret_frames(source_report["candidateFrames"])
    assert_onset_monotonicity(pop_frames)

    profiles = {
        profile_id(gap): summarize_profile(pop_frames, profile_id(gap))
        for gap in ONSET_GAP_MINIMUMS_MS
    }
    for profile, summary in profiles.items():
        observed = (
            summary["positiveCandidateInstances"],
            summary["positiveEventFrames"],
            summary["positiveDwellMs"],
        )
        if observed != (0, 0, 0):
            raise ValueError(
                f"POP909 profile {profile} unexpectedly produced {observed}"
            )

    song_ids = source_report["source"]["songIds"]
    per_piece = per_piece_summaries(pop_frames, source_report["perPiece"], song_ids)
    concentration = {
        profile_id(gap): top_newly_positive_pieces(per_piece, profile_id(gap))
        for gap in ONSET_GAP_MINIMUMS_MS
    }
    pop_episodes = episodes_by_profile_and_piece(pop_frames, song_ids)
    for profile_data in pop_episodes.values():
        for row in profile_data["perPiece"]:
            assert_dwell_monotonicity(row["episodes"])

    liszt = liszt_source_case(liszt_midi_path)
    liszt_frames = liszt["frames"]
    assert_onset_monotonicity(liszt_frames)
    for profile_data in liszt["profiles"].values():
        assert_dwell_monotonicity(profile_data["episodes"])

    return {
        "schema": REPORT_SCHEMA,
        "measurementId": MEASUREMENT_ID,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "command": shlex.join(["./.venv/bin/python", *sys.argv]),
        "workingDirectory": str(Path.cwd()),
        "runtime": {
            "pythonVersion": platform.python_version(),
            "midoVersion": importlib.metadata.version("mido"),
        },
        "contracts": {
            "repositoryCommit": git("rev-parse", "HEAD"),
            "repositoryRelevantDirty": bool(
                git(
                    "status",
                    "--porcelain",
                    "--",
                    "research/polychord",
                    "tool/polychord",
                )
            ),
            "preregistrationSha256": sha256_file(PREREGISTRATION),
            "pins": contract_pins(),
        },
        "profiles": {
            "onset": [profile_parameters(gap) for gap in ONSET_GAP_MINIMUMS_MS],
            "appearanceDwell": [
                dwell_profile(dwell_ms) for dwell_ms in APPEARANCE_DWELLS_MS
            ],
        },
        "inputs": {
            "pop909OnsetReport": {
                "path": str(onset_report_path),
                "sha256": sha256_file(onset_report_path),
                "schema": source_report["schema"],
                "measurementId": source_report["measurementId"],
                "source": source_report["source"],
                "contracts": source_report["contracts"],
            },
            "lisztMidi": {
                "path": str(liszt_midi_path),
                "sha256": sha256_file(liszt_midi_path),
            },
        },
        "assertions": {
            "pop909BaselineTotalsReproduced": True,
            "stored200msInterpretationsReproduced": True,
            "pop909ExpectedAllProfilesZeroReproduced": True,
            "lisztExpectedRowsReproduced": True,
            "onsetMonotonicity": True,
            "appearanceDwellMonotonicity": True,
        },
        "pop909": {
            "interpretation": (
                "label-blind exposure only; neither precision nor recall"
            ),
            "baselineTotals": EXPECTED_POP909_TOTALS,
            "profiles": profiles,
            "jointRawDistribution": joint_distribution(pop_frames),
            "perPiece": per_piece,
            "newlyPositivePieceConcentration": concentration,
            "authorizationEpisodes": pop_episodes,
            "candidateFrames": pop_frames,
        },
        "lisztSourceCase": liszt,
        "mechanics": mechanics_controls(),
        "stoppingRuleReading": (
            "No profile is selected. POP909's all-zero result means the 200 ms "
            "gap did not cause this corpus null; it does not show that onset "
            "evidence is useless. Liszt remains a boundary even where its cue "
            "becomes positive."
        ),
    }


def output_is_allowed(path: Path) -> bool:
    """Keep copyrighted detail in a child of the repository build tree."""

    resolved = path.resolve()
    build = BUILD_ROOT.resolve()
    return resolved != build and build in resolved.parents


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--onset-report", type=Path, required=True)
    parser.add_argument("--liszt-midi", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not output_is_allowed(args.out):
        raise SystemExit("sensitivity detail must remain under repository build/")
    if args.out.exists():
        raise SystemExit(f"refusing to overwrite existing report: {args.out}")
    report = build_report(args.onset_report, args.liszt_midi)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(
        "POP909 remained zero at every onset gap; "
        f"Liszt opportunities reproduced; report -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Exercise the complete symmetric polychord register-candidate matrix."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from collections import Counter
from pathlib import Path

import register_candidates

OUTPUT_SCHEMA = "polychord-register-conformance/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
GENERATOR_PATH = Path(register_candidates.__file__).relative_to(REPO_ROOT)

QUALITY_INTERVALS = {
    quality: intervals
    for intervals, quality in register_candidates.COMMON_CHORD_TEMPLATES.items()
}
QUALITIES = tuple(
    sorted(QUALITY_INTERVALS, key=register_candidates.QUALITY_ORDER.__getitem__)
)
RELATIVE_ROOT_INTERVALS = tuple(range(1, 12))
TRANSPOSITIONS = tuple(range(12))


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_output(*args: str) -> str:
    return subprocess.run(
        ("git", *args),
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def root_position_notes(
    root_pc: int, quality: str, octave_base: int
) -> tuple[int, ...]:
    return tuple(
        octave_base + root_pc + interval for interval in QUALITY_INTERVALS[quality]
    )


def candidate_has_target(
    candidate: register_candidates.RegisterCandidate,
    *,
    lower_root_pc: int,
    lower_quality: str,
    lower_notes: tuple[int, ...],
    upper_root_pc: int,
    upper_quality: str,
    upper_notes: tuple[int, ...],
) -> bool:
    return (
        candidate.lower.root_pitch_class == lower_root_pc
        and candidate.lower.quality == lower_quality
        and candidate.lower.midi_notes == lower_notes
        and candidate.upper.root_pitch_class == upper_root_pc
        and candidate.upper.quality == upper_quality
        and candidate.upper.midi_notes == upper_notes
    )


def candidate_has_target_identity(
    candidate: register_candidates.RegisterCandidate,
    *,
    lower_root_pc: int,
    lower_quality: str,
    upper_root_pc: int,
    upper_quality: str,
) -> bool:
    return (
        candidate.lower.root_pitch_class == lower_root_pc
        and candidate.lower.quality == lower_quality
        and candidate.upper.root_pitch_class == upper_root_pc
        and candidate.upper.quality == upper_quality
    )


def distribution(counter: Counter[int]) -> dict[str, int]:
    return {str(value): counter[value] for value in sorted(counter)}


def build_core_matrix() -> dict:
    failures = []
    additional_cases = []
    candidate_count_distribution: Counter[int] = Counter()
    shared_pc_count_distribution: Counter[int] = Counter()
    target_gap_distribution: Counter[int] = Counter()
    total_candidates = 0
    total_additional_candidates = 0
    combinations_with_additional_identities = 0
    combinations_with_additional_target_assignments = 0
    combination_count = 0

    for lower_quality in QUALITIES:
        for upper_quality in QUALITIES:
            for relative_root_interval in RELATIVE_ROOT_INTERVALS:
                for transposition in TRANSPOSITIONS:
                    combination_count += 1
                    lower_root_pc = transposition
                    upper_root_pc = (transposition + relative_root_interval) % 12
                    lower_notes = root_position_notes(
                        lower_root_pc,
                        lower_quality,
                        36,
                    )
                    upper_notes = root_position_notes(
                        upper_root_pc,
                        upper_quality,
                        72,
                    )
                    midi_notes = tuple(sorted((*lower_notes, *upper_notes)))
                    candidates = register_candidates.generate_register_candidates(
                        midi_notes
                    )
                    target_indexes = [
                        index
                        for index, candidate in enumerate(candidates)
                        if candidate_has_target(
                            candidate,
                            lower_root_pc=lower_root_pc,
                            lower_quality=lower_quality,
                            lower_notes=lower_notes,
                            upper_root_pc=upper_root_pc,
                            upper_quality=upper_quality,
                            upper_notes=upper_notes,
                        )
                    ]
                    target_identity_indexes = [
                        index
                        for index, candidate in enumerate(candidates)
                        if candidate_has_target_identity(
                            candidate,
                            lower_root_pc=lower_root_pc,
                            lower_quality=lower_quality,
                            upper_root_pc=upper_root_pc,
                            upper_quality=upper_quality,
                        )
                    ]
                    expected_shared = len(
                        {note % 12 for note in lower_notes}
                        & {note % 12 for note in upper_notes}
                    )
                    expected_gap = upper_notes[0] - lower_notes[-1]
                    candidate_count_distribution[len(candidates)] += 1
                    shared_pc_count_distribution[expected_shared] += 1
                    target_gap_distribution[expected_gap] += 1
                    total_candidates += len(candidates)

                    case_key = {
                        "lowerQuality": lower_quality,
                        "upperQuality": upper_quality,
                        "relativeRootInterval": relative_root_interval,
                        "transposition": transposition,
                        "lowerRootPc": lower_root_pc,
                        "upperRootPc": upper_root_pc,
                        "midiNotes": list(midi_notes),
                    }
                    if len(target_indexes) != 1:
                        failures.append(
                            {
                                **case_key,
                                "targetExactMatchCount": len(target_indexes),
                                "candidates": [
                                    candidate.as_dict() for candidate in candidates
                                ],
                            }
                        )
                        continue

                    target_index = target_indexes[0]
                    additional = [
                        candidate.as_dict()
                        for index, candidate in enumerate(candidates)
                        if index != target_index
                    ]
                    if additional:
                        additional_identity_count = sum(
                            not candidate_has_target_identity(
                                candidate,
                                lower_root_pc=lower_root_pc,
                                lower_quality=lower_quality,
                                upper_root_pc=upper_root_pc,
                                upper_quality=upper_quality,
                            )
                            for index, candidate in enumerate(candidates)
                            if index != target_index
                        )
                        additional_target_assignment_count = (
                            len(target_identity_indexes) - 1
                        )
                        total_additional_candidates += len(additional)
                        combinations_with_additional_identities += (
                            additional_identity_count > 0
                        )
                        combinations_with_additional_target_assignments += (
                            additional_target_assignment_count > 0
                        )
                        additional_cases.append(
                            {
                                **case_key,
                                "target": candidates[target_index].as_dict(),
                                "additionalIdentityCount": additional_identity_count,
                                "additionalTargetAssignmentCount": (
                                    additional_target_assignment_count
                                ),
                                "additionalCandidates": additional,
                            }
                        )

    return {
        "combinationCount": combination_count,
        "intendedExactAssignmentCount": combination_count - len(failures),
        "failureCount": len(failures),
        "totalCandidateCount": total_candidates,
        "totalAdditionalCandidateCount": total_additional_candidates,
        "combinationsWithAdditionalCandidates": len(additional_cases),
        "combinationsWithAdditionalIdentities": (
            combinations_with_additional_identities
        ),
        "combinationsWithAdditionalTargetAssignments": (
            combinations_with_additional_target_assignments
        ),
        "maximumCandidatesPerCombination": max(candidate_count_distribution),
        "candidateCountDistribution": distribution(candidate_count_distribution),
        "targetSharedPitchClassCountDistribution": distribution(
            shared_pc_count_distribution
        ),
        "targetGapSemitoneDistribution": distribution(target_gap_distribution),
        "additionalCandidateCases": additional_cases,
        "failures": failures,
    }


FOCUSED_CONTROLS = (
    {
        "id": "inversions-and-octave-doubling",
        "midiNotes": [40, 43, 48, 52, 57, 62, 66],
        "expectedSymbols": ["D|C"],
        "expectedAssignments": [{"lower": [40, 43, 48, 52], "upper": [57, 62, 66]}],
        "expectedGaps": [5],
        "expectedSharedPitchClasses": [[]],
    },
    {
        "id": "zero-shared-pitch-classes",
        "midiNotes": [48, 52, 55, 66, 70, 73],
        "expectedSymbols": ["F#|C"],
        "expectedAssignments": [{"lower": [48, 52, 55], "upper": [66, 70, 73]}],
        "expectedGaps": [11],
        "expectedSharedPitchClasses": [[]],
    },
    {
        "id": "one-shared-pitch-class",
        "midiNotes": [43, 46, 50, 60, 64, 67],
        "expectedSymbols": ["C|Gm"],
        "expectedAssignments": [{"lower": [43, 46, 50], "upper": [60, 64, 67]}],
        "expectedGaps": [10],
        "expectedSharedPitchClasses": [[7]],
    },
    {
        "id": "multiple-shared-pitch-classes",
        "midiNotes": [50, 54, 57, 59, 62, 66],
        "expectedSymbols": ["Bm|D"],
        "expectedAssignments": [{"lower": [50, 54, 57], "upper": [59, 62, 66]}],
        "expectedGaps": [2],
        "expectedSharedPitchClasses": [[2, 6]],
    },
    {
        "id": "one-semitone-boundary",
        "midiNotes": [48, 52, 55, 56, 60, 63],
        "expectedSymbols": ["G#|C"],
        "expectedAssignments": [{"lower": [48, 52, 55], "upper": [56, 60, 63]}],
        "expectedGaps": [1],
        "expectedSharedPitchClasses": [[0]],
    },
    {
        "id": "wide-boundary",
        "midiNotes": [48, 52, 55, 78, 82, 85],
        "expectedSymbols": ["F#|C"],
        "expectedAssignments": [{"lower": [48, 52, 55], "upper": [78, 82, 85]}],
        "expectedGaps": [23],
        "expectedSharedPitchClasses": [[]],
    },
    {
        "id": "same-root-excluded",
        "midiNotes": [36, 40, 43, 60, 64, 67],
        "expectedSymbols": [],
        "expectedAssignments": [],
        "expectedGaps": [],
        "expectedSharedPitchClasses": [],
    },
    {
        "id": "incomplete-lower-shell-excluded",
        "midiNotes": [36, 52, 58, 62, 66, 69],
        "expectedSymbols": [],
        "expectedAssignments": [],
        "expectedGaps": [],
        "expectedSharedPitchClasses": [],
    },
    {
        "id": "one-note-overlapping-cover-excluded",
        "midiNotes": [40, 43, 47, 56, 63],
        "expectedSymbols": [],
        "expectedAssignments": [],
        "expectedGaps": [],
        "expectedSharedPitchClasses": [],
    },
    {
        "id": "multiple-candidate-identities",
        "midiNotes": [36, 40, 43, 59, 74, 78, 81],
        "expectedSymbols": ["Bm7|C", "D|Cmaj7"],
        "expectedAssignments": [
            {"lower": [36, 40, 43], "upper": [59, 74, 78, 81]},
            {"lower": [36, 40, 43, 59], "upper": [74, 78, 81]},
        ],
        "expectedGaps": [16, 15],
        "expectedSharedPitchClasses": [[], []],
    },
    {
        "id": "same-identity-multiple-assignments",
        "midiNotes": [48, 52, 55, 67, 71, 74, 79],
        "expectedSymbols": ["G|C", "G|C"],
        "expectedAssignments": [
            {"lower": [48, 52, 55], "upper": [67, 71, 74, 79]},
            {"lower": [48, 52, 55, 67], "upper": [71, 74, 79]},
        ],
        "expectedGaps": [12, 4],
        "expectedSharedPitchClasses": [[7], [7]],
    },
)


def build_focused_controls() -> list[dict]:
    results = []
    for control in FOCUSED_CONTROLS:
        candidates = register_candidates.generate_register_candidates(
            control["midiNotes"]
        )
        actual = {
            "symbols": [candidate.symbol for candidate in candidates],
            "assignments": [
                {
                    "lower": list(candidate.lower.midi_notes),
                    "upper": list(candidate.upper.midi_notes),
                }
                for candidate in candidates
            ],
            "gaps": [candidate.gap_semitones for candidate in candidates],
            "sharedPitchClasses": [
                list(candidate.shared_pitch_classes) for candidate in candidates
            ],
        }
        expected = {
            "symbols": control["expectedSymbols"],
            "assignments": control["expectedAssignments"],
            "gaps": control["expectedGaps"],
            "sharedPitchClasses": control["expectedSharedPitchClasses"],
        }
        results.append(
            {
                "id": control["id"],
                "midiNotes": control["midiNotes"],
                "passed": actual == expected,
                "expected": expected,
                "actual": actual,
                "candidates": [candidate.as_dict() for candidate in candidates],
            }
        )
    return results


def measurement_payload() -> dict:
    core = build_core_matrix()
    focused = build_focused_controls()
    return {
        "method": {
            "qualities": list(QUALITIES),
            "orderedQualityPairCount": len(QUALITIES) ** 2,
            "relativeRootIntervals": list(RELATIVE_ROOT_INTERVALS),
            "transpositions": list(TRANSPOSITIONS),
            "lowerRootPositionBaseMidi": 36,
            "upperRootPositionBaseMidi": 72,
            "targetRequirement": (
                "the intended ordered identity and exact lower/upper MIDI-note "
                "assignment must occur exactly once"
            ),
            "additionalCandidatePolicy": (
                "retain and report every additional mechanically valid candidate"
            ),
        },
        "coreMatrix": core,
        "focusedControls": focused,
        "summary": {
            "coreCombinationCount": core["combinationCount"],
            "coreFailureCount": core["failureCount"],
            "focusedControlCount": len(focused),
            "focusedFailureCount": sum(not result["passed"] for result in focused),
        },
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    return {
        "schema": OUTPUT_SCHEMA,
        "source": {
            "command": command,
            "workingDirectory": str(Path.cwd().resolve()),
            "repositoryCommit": git_output("rev-parse", "HEAD"),
            "repositoryDirty": bool(git_output("status", "--porcelain")),
            "pythonVersion": platform.python_version(),
            "generator": {
                "path": str(GENERATOR_PATH),
                "sha256": sha256_file(REPO_ROOT / GENERATOR_PATH),
                "schema": register_candidates.OUTPUT_SCHEMA,
            },
            "harness": {
                "path": str(HARNESS_PATH),
                "sha256": sha256_file(REPO_ROOT / HARNESS_PATH),
            },
        },
        **payload,
    }


def verify_report(path: Path) -> None:
    report = json.loads(path.read_text())
    if report.get("schema") != OUTPUT_SCHEMA:
        raise ValueError(f"report schema must be {OUTPUT_SCHEMA}")
    source = report.get("source")
    if not isinstance(source, dict):
        raise TypeError("report source must be an object")
    expected_pins = {
        "generator": (GENERATOR_PATH, register_candidates.OUTPUT_SCHEMA),
        "harness": (HARNESS_PATH, None),
    }
    for name, (relative_path, schema) in expected_pins.items():
        pin = source.get(name)
        if not isinstance(pin, dict) or pin.get("path") != str(relative_path):
            raise ValueError(f"report source {name} path is invalid")
        if pin.get("sha256") != sha256_file(REPO_ROOT / relative_path):
            raise ValueError(f"report source {name} digest is invalid")
        if schema is not None and pin.get("schema") != schema:
            raise ValueError(f"report source {name} schema is invalid")
    expected = measurement_payload()
    actual = {key: report.get(key) for key in expected}
    if actual != expected:
        raise ValueError("report measurement differs from current conformance run")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--out", type=Path, help="write a complete JSON report")
    action.add_argument("--verify", type=Path, help="verify a committed JSON report")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.verify is not None:
        verify_report(args.verify)
        print(f"valid: {args.verify}")
        return 0

    report = build_report([sys.executable, *sys.argv])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{summary['coreCombinationCount']} core combinations, "
        f"{summary['coreFailureCount']} core failures; "
        f"{summary['focusedControlCount']} focused controls, "
        f"{summary['focusedFailureCount']} focused failures -> {args.out}"
    )
    return int(summary["coreFailureCount"] > 0 or summary["focusedFailureCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

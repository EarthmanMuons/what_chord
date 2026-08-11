"""Apply the preregistered register-only polychord selector to one frame."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from collections.abc import Sequence
from dataclasses import dataclass

import register_candidates

OUTPUT_SCHEMA = "polychord-register-selector-decision/1"
FULL_SELECTOR_ID = "polychord-register-policy/1"
WITHOUT_INTEGRATED_TERTIAN_VETO_ID = (
    "polychord-register-policy-without-integrated-tertian-veto/1"
)
WITHOUT_ASSIGNMENT_VETO_ID = "polychord-register-policy-without-assignment-veto/1"
WITHOUT_GAP_RESOLUTION_ID = "polychord-register-policy-without-gap-resolution/1"

NO_STRUCTURAL_CANDIDATE = "no-structural-candidate"
NOT_SELECTED_BY_POLICY = "not-selected-by-policy"
MULTIPLE_UNRESOLVED_IDENTITIES = "multiple-unresolved-identities"

COMPACT_INTEGRATED_SHAPES = frozenset(
    {
        frozenset({0, 4, 7, 10}),
        frozenset({0, 4, 7, 11}),
        frozenset({0, 3, 7, 10}),
        frozenset({0, 4, 7, 9}),
        frozenset({0, 3, 7, 9}),
    }
)

ROOTED_NINTH_SHAPES = {
    "major": frozenset(
        {
            frozenset({0, 2, 4, 7, 10}),
            frozenset({0, 2, 4, 7, 11}),
        }
    ),
    "minor": frozenset({frozenset({0, 2, 3, 7, 10})}),
}

ROOTED_SEVENTH_EXTENSION_INTERVALS = {
    "dominant7": frozenset({1, 2, 3, 5, 6, 8, 9}),
    "major7": frozenset({2, 6, 9}),
    "minor7": frozenset({2, 5, 9}),
}


@dataclass(frozen=True)
class SelectorProfile:
    """One fixed full or leave-one-component-out selector profile."""

    selector_id: str
    assignment_veto: bool
    integrated_tertian_veto: bool
    gap_resolution: bool


SELECTOR_PROFILES = {
    profile.selector_id: profile
    for profile in (
        SelectorProfile(
            selector_id=FULL_SELECTOR_ID,
            assignment_veto=True,
            integrated_tertian_veto=True,
            gap_resolution=True,
        ),
        SelectorProfile(
            selector_id=WITHOUT_INTEGRATED_TERTIAN_VETO_ID,
            assignment_veto=True,
            integrated_tertian_veto=False,
            gap_resolution=True,
        ),
        SelectorProfile(
            selector_id=WITHOUT_ASSIGNMENT_VETO_ID,
            assignment_veto=False,
            integrated_tertian_veto=True,
            gap_resolution=True,
        ),
        SelectorProfile(
            selector_id=WITHOUT_GAP_RESOLUTION_ID,
            assignment_veto=True,
            integrated_tertian_veto=True,
            gap_resolution=False,
        ),
    )
}


def _relative_shape(pitch_classes: frozenset[int], root_pc: int) -> frozenset[int]:
    return frozenset((pitch_class - root_pc) % 12 for pitch_class in pitch_classes)


def _is_compact_integrated(pitch_classes: frozenset[int]) -> bool:
    return any(
        _relative_shape(pitch_classes, root_pc) in COMPACT_INTEGRATED_SHAPES
        for root_pc in range(12)
    )


def _is_rooted_ninth_integrated(
    pitch_classes: frozenset[int],
    candidate: register_candidates.RegisterCandidate,
) -> bool:
    shapes = ROOTED_NINTH_SHAPES.get(candidate.lower.quality)
    return shapes is not None and (
        _relative_shape(pitch_classes, candidate.lower.root_pitch_class) in shapes
    )


def _is_rooted_seventh_extension_integrated(
    pitch_classes: frozenset[int],
    candidate: register_candidates.RegisterCandidate,
) -> bool:
    allowed = ROOTED_SEVENTH_EXTENSION_INTERVALS.get(candidate.lower.quality)
    if allowed is None:
        return False
    lower_pitch_classes = frozenset(candidate.lower.pitch_classes)
    added = pitch_classes - lower_pitch_classes
    if not added:
        return False
    added_intervals = _relative_shape(added, candidate.lower.root_pitch_class)
    return added_intervals <= allowed


def integrated_tertian_tests(
    midi_notes: Sequence[int],
    candidate: register_candidates.RegisterCandidate,
) -> dict[str, bool]:
    """Return every named integrated-tertian test for one candidate."""

    notes = register_candidates.validate_midi_notes(midi_notes)
    pitch_classes = frozenset(note % 12 for note in notes)
    return {
        "compact": _is_compact_integrated(pitch_classes),
        "rootedNinth": _is_rooted_ninth_integrated(pitch_classes, candidate),
        "rootedSeventhExtension": (
            _is_rooted_seventh_extension_integrated(pitch_classes, candidate)
        ),
    }


def _identity_key(candidate: register_candidates.RegisterCandidate) -> tuple:
    return (
        candidate.upper.root_pitch_class,
        candidate.upper.quality,
        candidate.lower.root_pitch_class,
        candidate.lower.quality,
    )


def _validate_structural_candidates(
    midi_notes: tuple[int, ...],
    candidates: tuple[register_candidates.RegisterCandidate, ...],
) -> None:
    if len(candidates) != len(set(candidates)):
        raise ValueError("candidates must be distinct")
    for index, candidate in enumerate(candidates):
        split = candidate.split_after_index
        if split < 0 or split >= len(midi_notes) - 1:
            raise ValueError(f"candidates[{index}] split is outside the observation")
        lower_notes = midi_notes[: split + 1]
        upper_notes = midi_notes[split + 1 :]
        if candidate.lower.midi_notes != lower_notes:
            raise ValueError(f"candidates[{index}] lower assignment is not contiguous")
        if candidate.upper.midi_notes != upper_notes:
            raise ValueError(f"candidates[{index}] upper assignment is not contiguous")
        if candidate.lower_top_midi != lower_notes[-1]:
            raise ValueError(f"candidates[{index}] lower boundary note is invalid")
        if candidate.upper_bottom_midi != upper_notes[0]:
            raise ValueError(f"candidates[{index}] upper boundary note is invalid")
        if candidate.gap_semitones != upper_notes[0] - lower_notes[-1]:
            raise ValueError(f"candidates[{index}] register gap is invalid")
        for role, layer, notes in (
            ("lower", candidate.lower, lower_notes),
            ("upper", candidate.upper, upper_notes),
        ):
            expected_pitch_classes = tuple(sorted({note % 12 for note in notes}))
            if layer.pitch_classes != expected_pitch_classes:
                raise ValueError(
                    f"candidates[{index}] {role} pitch classes are invalid"
                )
            matches = register_candidates.chord_matches(notes)
            identity = (layer.root_pitch_class, layer.quality)
            if identity not in {
                (match.root_pitch_class, match.quality) for match in matches
            }:
                raise ValueError(f"candidates[{index}] {role} identity is invalid")
        expected_shared = tuple(
            sorted(
                set(candidate.lower.pitch_classes) & set(candidate.upper.pitch_classes)
            )
        )
        if candidate.shared_pitch_classes != expected_shared:
            raise ValueError(f"candidates[{index}] shared pitch classes are invalid")
    expected = set(register_candidates.generate_register_candidates(midi_notes))
    if set(candidates) != expected:
        raise ValueError("candidates must contain the complete generated candidate set")


def decision_document(
    midi_notes: Sequence[int],
    *,
    selector_id: str = FULL_SELECTOR_ID,
    candidates: Sequence[register_candidates.RegisterCandidate] | None = None,
) -> dict:
    """Return one deterministic raw decision and its complete diagnostics."""

    notes = register_candidates.validate_midi_notes(midi_notes)
    try:
        profile = SELECTOR_PROFILES[selector_id]
    except KeyError as error:
        raise ValueError(f"unsupported selector_id: {selector_id!r}") from error

    structural = tuple(
        register_candidates.generate_register_candidates(notes)
        if candidates is None
        else candidates
    )
    _validate_structural_candidates(notes, structural)
    identity_counts = Counter(_identity_key(candidate) for candidate in structural)
    traces = []
    survivors = []
    for candidate in structural:
        assignment_count = identity_counts[_identity_key(candidate)]
        integrated_tests = integrated_tertian_tests(notes, candidate)
        assignment_removed = profile.assignment_veto and assignment_count > 1
        integrated_removed = (
            not assignment_removed
            and profile.integrated_tertian_veto
            and any(integrated_tests.values())
        )
        survived = not assignment_removed and not integrated_removed
        if survived:
            survivors.append(candidate)
        traces.append(
            {
                "candidate": candidate.as_dict(),
                "identityAssignmentCount": assignment_count,
                "integratedTertian": integrated_tests,
                "removedByAssignmentVeto": assignment_removed,
                "removedByIntegratedTertianVeto": integrated_removed,
                "survived": survived,
            }
        )

    selected = None
    reason_codes = []
    if not structural:
        reason_codes = [NO_STRUCTURAL_CANDIDATE]
    elif not survivors:
        reason_codes = [NOT_SELECTED_BY_POLICY]
    elif not profile.gap_resolution:
        if len(survivors) == 1:
            selected = survivors[0]
        else:
            reason_codes = [MULTIPLE_UNRESOLVED_IDENTITIES]
    else:
        greatest_gap = max(candidate.gap_semitones for candidate in survivors)
        widest = [
            candidate
            for candidate in survivors
            if candidate.gap_semitones == greatest_gap
        ]
        if len(widest) == 1:
            selected = widest[0]
        else:
            reason_codes = [MULTIPLE_UNRESOLVED_IDENTITIES]

    return {
        "schema": OUTPUT_SCHEMA,
        "selectorId": selector_id,
        "midiNotes": list(notes),
        "candidates": [candidate.as_dict() for candidate in structural],
        "traces": traces,
        "selected": None if selected is None else selected.as_dict(),
        "reasonCodes": reason_codes,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--selector",
        choices=tuple(SELECTOR_PROFILES),
        default=FULL_SELECTOR_ID,
    )
    parser.add_argument(
        "midi_notes",
        metavar="MIDI_NOTE",
        type=int,
        nargs="*",
        help="strictly increasing sounding MIDI notes for one frame",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        document = decision_document(
            args.midi_notes,
            selector_id=args.selector,
        )
    except (TypeError, ValueError) as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

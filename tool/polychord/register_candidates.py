"""Enumerate conservative register-only polychord candidates for one frame.

This is research instrumentation for ``research/polychord/FRAMEWORK.md``. It
implements candidate generation only: it does not rank, score, or decide
whether a candidate should be displayed.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from dataclasses import dataclass

OUTPUT_SCHEMA = "polychord-register-candidates/1"

PITCH_CLASS_NAMES = (
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
)

COMMON_CHORD_TEMPLATES = {
    (0, 4, 7): "major",
    (0, 3, 7): "minor",
    (0, 4, 7, 10): "dominant7",
    (0, 4, 7, 11): "major7",
    (0, 3, 7, 10): "minor7",
}

QUALITY_ORDER = {
    "major": 0,
    "minor": 1,
    "dominant7": 2,
    "major7": 3,
    "minor7": 4,
}

CHORD_SUFFIXES = {
    "major": "",
    "minor": "m",
    "dominant7": "7",
    "major7": "maj7",
    "minor7": "m7",
}


@dataclass(frozen=True)
class ChordMatch:
    """One exact v0 chord identity for a contiguous register group."""

    root_pitch_class: int
    quality: str


@dataclass(frozen=True)
class LayerCandidate:
    """A recognized chord layer and its exact sounded-note assignment."""

    root_pitch_class: int
    quality: str
    midi_notes: tuple[int, ...]
    pitch_classes: tuple[int, ...]

    def as_dict(self) -> dict:
        return {
            "rootPc": self.root_pitch_class,
            "quality": self.quality,
            "midiNotes": list(self.midi_notes),
            "pitchClasses": list(self.pitch_classes),
        }


@dataclass(frozen=True)
class RegisterCandidate:
    """One exact two-layer decomposition at one adjacent-note boundary."""

    split_after_index: int
    lower_top_midi: int
    upper_bottom_midi: int
    gap_semitones: int
    lower: LayerCandidate
    upper: LayerCandidate
    shared_pitch_classes: tuple[int, ...]

    @property
    def symbol(self) -> str:
        return f"{chord_symbol(self.upper)}|{chord_symbol(self.lower)}"

    def as_dict(self) -> dict:
        return {
            "splitAfterIndex": self.split_after_index,
            "lowerTopMidi": self.lower_top_midi,
            "upperBottomMidi": self.upper_bottom_midi,
            "gapSemitones": self.gap_semitones,
            "lower": self.lower.as_dict(),
            "upper": self.upper.as_dict(),
            "sharedPitchClasses": list(self.shared_pitch_classes),
            "symbol": self.symbol,
        }


def validate_midi_notes(midi_notes: Sequence[int]) -> tuple[int, ...]:
    """Return a validated, immutable frame observation.

    Frame replay already emits strictly increasing notes. Rejecting other input
    avoids silently changing a recorded observation in research output.
    """

    notes = tuple(midi_notes)
    for index, note in enumerate(notes):
        if isinstance(note, bool) or not isinstance(note, int):
            raise TypeError(f"midi_notes[{index}] must be an integer")
        if note < 0 or note > 127:
            raise ValueError(f"midi_notes[{index}] must be from 0 through 127")
    if tuple(sorted(set(notes))) != notes:
        raise ValueError("midi_notes must be strictly increasing without duplicates")
    return notes


def chord_matches(midi_notes: tuple[int, ...]) -> tuple[ChordMatch, ...]:
    """Return every exact common-chord match for one register group."""

    pitch_classes = frozenset(note % 12 for note in midi_notes)
    matches = []
    for root_pitch_class in sorted(pitch_classes):
        shape = tuple(
            sorted(
                (pitch_class - root_pitch_class) % 12 for pitch_class in pitch_classes
            )
        )
        quality = COMMON_CHORD_TEMPLATES.get(shape)
        if quality is not None:
            matches.append(ChordMatch(root_pitch_class, quality))
    return tuple(
        sorted(
            matches,
            key=lambda match: (
                match.root_pitch_class,
                QUALITY_ORDER[match.quality],
            ),
        )
    )


def layer_candidate(
    midi_notes: tuple[int, ...],
    match: ChordMatch,
) -> LayerCandidate:
    return LayerCandidate(
        root_pitch_class=match.root_pitch_class,
        quality=match.quality,
        midi_notes=midi_notes,
        pitch_classes=tuple(sorted({note % 12 for note in midi_notes})),
    )


def chord_symbol(layer: LayerCandidate) -> str:
    return PITCH_CLASS_NAMES[layer.root_pitch_class] + CHORD_SUFFIXES[layer.quality]


def generate_register_candidates(
    midi_notes: Sequence[int],
) -> tuple[RegisterCandidate, ...]:
    """Enumerate every Framework-v0 contiguous split for one sounding frame."""

    notes = validate_midi_notes(midi_notes)
    candidates = []
    for split_after_index in range(len(notes) - 1):
        lower_notes = notes[: split_after_index + 1]
        upper_notes = notes[split_after_index + 1 :]
        lower_matches = chord_matches(lower_notes)
        upper_matches = chord_matches(upper_notes)

        for lower_match in lower_matches:
            for upper_match in upper_matches:
                if lower_match.root_pitch_class == upper_match.root_pitch_class:
                    continue
                lower = layer_candidate(lower_notes, lower_match)
                upper = layer_candidate(upper_notes, upper_match)
                candidates.append(
                    RegisterCandidate(
                        split_after_index=split_after_index,
                        lower_top_midi=lower_notes[-1],
                        upper_bottom_midi=upper_notes[0],
                        gap_semitones=upper_notes[0] - lower_notes[-1],
                        lower=lower,
                        upper=upper,
                        shared_pitch_classes=tuple(
                            sorted(set(lower.pitch_classes) & set(upper.pitch_classes))
                        ),
                    )
                )

    return tuple(
        sorted(
            candidates,
            key=lambda candidate: (
                candidate.split_after_index,
                candidate.upper.root_pitch_class,
                QUALITY_ORDER[candidate.upper.quality],
                candidate.lower.root_pitch_class,
                QUALITY_ORDER[candidate.lower.quality],
            ),
        )
    )


def candidate_document(midi_notes: Sequence[int]) -> dict:
    """Serialize one frame and all its structural candidates."""

    notes = validate_midi_notes(midi_notes)
    candidates = generate_register_candidates(notes)
    return {
        "schema": OUTPUT_SCHEMA,
        "midiNotes": list(notes),
        "candidates": [candidate.as_dict() for candidate in candidates],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
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
        document = candidate_document(args.midi_notes)
    except (TypeError, ValueError) as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(document, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

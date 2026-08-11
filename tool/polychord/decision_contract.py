"""Executable controls for the frozen polychord decision contract."""

from __future__ import annotations

from copy import deepcopy

CONTROL_SCHEMA = "polychord-decision-control/1"
STABILITY_DURATION_MS = 200

INPUT_MODES = {
    "pitch-class-only",
    "registered-event-stream",
    "registered-static-midi",
}
TEMPORAL_SUPPORT_RESULTS = {"positive", "neutral", "unavailable"}
RAW_EVIDENCE_RESULTS = {"available", "unavailable"}
QUALITY_INTERVALS = {
    "major": {0, 4, 7},
    "minor": {0, 3, 7},
    "dominant7": {0, 4, 7, 10},
    "major7": {0, 4, 7, 11},
    "minor7": {0, 3, 7, 10},
}
LAYER_QUALITIES = set(QUALITY_INTERVALS)
REASON_CODES = {
    "missing-register-evidence",
    "multiple-unresolved-identities",
    "no-structural-candidate",
    "not-selected-by-policy",
    "primary-not-displayable",
    "unstable-selection",
}

CANDIDATE_FIELDS = {
    "identity",
    "upperMidiNotes",
    "lowerMidiNotes",
}
IDENTITY_FIELDS = {"upper", "lower"}
LAYER_FIELDS = {"rootPc", "quality"}


def _require_dict(value: object, context: str) -> dict:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    return value


def _require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise ValueError(
            f"{context} fields are invalid: missing {missing}, unknown {unknown}"
        )


def _require_bool(value: object, context: str) -> bool:
    if not isinstance(value, bool):
        raise TypeError(f"{context} must be a boolean")
    return value


def _normalize_notes(value: object, context: str) -> list[int]:
    if not isinstance(value, list) or any(
        isinstance(note, bool) or not isinstance(note, int) for note in value
    ):
        raise TypeError(f"{context} must be an integer array")
    if any(note < 0 or note > 127 for note in value):
        raise ValueError(f"{context} notes must be from 0 through 127")
    if value != sorted(set(value)):
        raise ValueError(f"{context} must be sorted and distinct")
    return list(value)


def _normalize_layer(value: object, context: str) -> dict:
    layer = _require_dict(value, context)
    _require_fields(layer, LAYER_FIELDS, context)
    root_pc = layer["rootPc"]
    if isinstance(root_pc, bool) or not isinstance(root_pc, int):
        raise TypeError(f"{context}.rootPc must be an integer")
    if root_pc < 0 or root_pc > 11:
        raise ValueError(f"{context}.rootPc must be from 0 through 11")
    quality = layer["quality"]
    if quality not in LAYER_QUALITIES:
        raise ValueError(f"{context}.quality is unsupported: {quality!r}")
    return {"rootPc": root_pc, "quality": quality}


def normalize_candidate(value: object, context: str = "candidate") -> dict:
    candidate = _require_dict(value, context)
    _require_fields(candidate, CANDIDATE_FIELDS, context)
    identity = _require_dict(candidate["identity"], f"{context}.identity")
    _require_fields(identity, IDENTITY_FIELDS, f"{context}.identity")
    upper = _normalize_layer(identity["upper"], f"{context}.identity.upper")
    lower = _normalize_layer(identity["lower"], f"{context}.identity.lower")
    if upper["rootPc"] == lower["rootPc"]:
        raise ValueError(f"{context} layer roots must differ")
    upper_notes = _normalize_notes(
        candidate["upperMidiNotes"], f"{context}.upperMidiNotes"
    )
    lower_notes = _normalize_notes(
        candidate["lowerMidiNotes"], f"{context}.lowerMidiNotes"
    )
    if not upper_notes or not lower_notes:
        raise ValueError(f"{context} assignments must be nonempty")
    overlap = set(upper_notes) & set(lower_notes)
    if overlap:
        raise ValueError(f"{context} assignments overlap: {sorted(overlap)}")
    _validate_layer_notes(upper, upper_notes, f"{context}.identity.upper")
    _validate_layer_notes(lower, lower_notes, f"{context}.identity.lower")
    return {
        "identity": {"upper": upper, "lower": lower},
        "upperMidiNotes": upper_notes,
        "lowerMidiNotes": lower_notes,
    }


def assigned_notes(candidate: dict) -> set[int]:
    return set(candidate["upperMidiNotes"]) | set(candidate["lowerMidiNotes"])


def _validate_layer_notes(layer: dict, notes: list[int], context: str) -> None:
    expected_pitch_classes = {
        (layer["rootPc"] + interval) % 12
        for interval in QUALITY_INTERVALS[layer["quality"]]
    }
    actual_pitch_classes = {note % 12 for note in notes}
    if actual_pitch_classes != expected_pitch_classes:
        raise ValueError(f"{context} pitch classes do not match its root and quality")


def evaluate_decision(
    *,
    input_mode: str,
    sounding_midi_notes: list[int],
    structural_candidates: list[dict],
    policy_selection: dict | None,
    primary_displayable: bool,
    onset_support: str,
    motion_support: str,
    release_and_pedal: str = "unavailable",
) -> dict:
    """Attach evidence without inventing a selector or temporal veto."""

    if input_mode not in INPUT_MODES:
        raise ValueError(f"input_mode is unsupported: {input_mode!r}")
    notes = _normalize_notes(sounding_midi_notes, "sounding_midi_notes")
    candidates = [
        normalize_candidate(candidate, f"structural_candidates[{index}]")
        for index, candidate in enumerate(structural_candidates)
    ]
    if len({repr(candidate) for candidate in candidates}) != len(candidates):
        raise ValueError("structural_candidates must be distinct")
    for index, candidate in enumerate(candidates):
        if assigned_notes(candidate) != set(notes):
            raise ValueError(
                f"structural_candidates[{index}] must exhaust sounding_midi_notes"
            )
    selected = (
        None
        if policy_selection is None
        else normalize_candidate(policy_selection, "policy_selection")
    )
    if selected is not None and selected not in candidates:
        raise ValueError("policy_selection must be one structural candidate")
    if onset_support not in TEMPORAL_SUPPORT_RESULTS:
        raise ValueError(f"onset_support is unsupported: {onset_support!r}")
    if motion_support not in TEMPORAL_SUPPORT_RESULTS:
        raise ValueError(f"motion_support is unsupported: {motion_support!r}")
    if release_and_pedal not in RAW_EVIDENCE_RESULTS:
        raise ValueError(f"release_and_pedal is unsupported: {release_and_pedal!r}")
    _require_bool(primary_displayable, "primary_displayable")

    support = {
        "register": "exact-structural-candidate" if candidates else "unavailable",
        "onsetCohort": onset_support,
        "rigidLayerMotion": motion_support,
        "releaseAndPedal": release_and_pedal,
        "channelOrSource": "unavailable",
    }

    if input_mode == "pitch-class-only":
        if candidates or selected is not None:
            raise ValueError("pitch-class-only input cannot carry register candidates")
        reason = "missing-register-evidence"
        selected = None
    elif not primary_displayable:
        reason = "primary-not-displayable"
        selected = None
    elif selected is None:
        reason = (
            "no-structural-candidate" if not candidates else "not-selected-by-policy"
        )
    else:
        reason = None

    return {
        "schema": CONTROL_SCHEMA,
        "candidates": deepcopy(candidates),
        "selected": deepcopy(selected),
        "selectorId": "control-policy-input/1",
        "support": support,
        "reasonCodes": [] if reason is None else [reason],
    }


class StableDisplayGate:
    """Deterministic 200-ms appearance and immediate-clear state reducer."""

    def __init__(self) -> None:
        self._last_timestamp_ms: int | None = None
        self._pending: dict | None = None
        self._pending_since_ms: int | None = None
        self._displayed: dict | None = None

    def _reset_pending(self) -> None:
        self._pending = None
        self._pending_since_ms = None

    def _clear(self, reason: str) -> dict:
        transition = "clear" if self._displayed is not None else "none"
        self._displayed = None
        self._reset_pending()
        return self._result(transition, reason)

    def _result(self, transition: str, reason: str | None) -> dict:
        return {
            "displayed": deepcopy(self._displayed),
            "transition": transition,
            "reason": reason,
        }

    def step(
        self,
        *,
        timestamp_ms: int,
        raw_selected: dict | None,
        primary_displayable: bool,
        sounding_midi_notes: list[int],
    ) -> dict:
        if isinstance(timestamp_ms, bool) or not isinstance(timestamp_ms, int):
            raise TypeError("timestamp_ms must be an integer")
        if timestamp_ms < 0:
            raise ValueError("timestamp_ms must be nonnegative")
        if (
            self._last_timestamp_ms is not None
            and timestamp_ms < self._last_timestamp_ms
        ):
            raise ValueError("timestamp_ms must be nondecreasing")
        self._last_timestamp_ms = timestamp_ms
        _require_bool(primary_displayable, "primary_displayable")
        notes = _normalize_notes(sounding_midi_notes, "sounding_midi_notes")
        selected = (
            None
            if raw_selected is None
            else normalize_candidate(raw_selected, "raw_selected")
        )

        if not primary_displayable:
            return self._clear("primary-not-displayable")
        if not notes:
            return self._clear("silence")

        note_set = set(notes)
        displayed_invalid = (
            self._displayed is not None and assigned_notes(self._displayed) != note_set
        )
        if selected is not None and assigned_notes(selected) != note_set:
            raise ValueError("raw_selected must exhaust sounding_midi_notes")
        if displayed_invalid:
            self._displayed = None
            self._reset_pending()
            if selected is not None:
                self._pending = selected
                self._pending_since_ms = timestamp_ms
            return self._result("clear", "invalidated-assignment")
        if selected is None:
            return self._clear("abstention")
        if selected == self._displayed:
            self._reset_pending()
            return self._result("stable", None)

        if selected != self._pending:
            self._pending = selected
            self._pending_since_ms = timestamp_ms
            return self._result("pending", "unstable-selection")

        assert self._pending_since_ms is not None
        if timestamp_ms - self._pending_since_ms < STABILITY_DURATION_MS:
            return self._result("pending", "unstable-selection")

        transition = "appearance" if self._displayed is None else "change"
        self._displayed = selected
        self._reset_pending()
        return self._result(transition, None)

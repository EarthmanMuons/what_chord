"""Validate the frozen automatic polychord product-suite artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

import frame_replay
import onset_evidence
import register_candidates

PRODUCT_FIXTURE_MANIFEST_SCHEMA = "polychord-product-fixture-manifest/1"
PRODUCT_SUITE_SCHEMA = "polychord-product-suite/1"
REPO_ROOT = Path(__file__).parents[2]

VERSION_IDS = {
    "output": "polychord-output/3",
    "tracker": "polychord-onset-tracker/1",
    "candidateGenerator": "polychord-register-candidates/1",
    "cue": "coherent-separated-onsets-50-80ms/product-1",
    "selector": "polychord-onset-register-policy/1",
    "display": "polychord-continuous-authorization-200ms/1",
}
DEPENDENCY_FIELDS = {
    "outputContract",
    "selectorSpecification",
    "suiteSpecification",
    "internalSuite",
    "legacyReplayManifest",
    "productFixtureManifest",
    "validator",
    "scorer",
    "baselineContract",
    "baselineFreeze",
}
SUITE_FIELDS = {
    "schema",
    "status",
    "authority",
    "noteConvention",
    "versionIds",
    "dependencies",
    "inheritedCases",
    "cases",
    "baselineTargets",
}
STATUS_FIELDS = {"name", "scoringAllowed"}
INHERITED_CASE_FIELDS = {"id", "automaticRole"}
CASE_FIELDS = {
    "id",
    "title",
    "stratum",
    "purpose",
    "provenance",
    "constructionExpectation",
    "fixtureId",
    "initialPrimaryDisplayable",
    "expectedCandidates",
    "actions",
    "baselineTargetIds",
}
PROVENANCE_FIELDS = {"kind", "sourceId", "description"}
CONSTRUCTION_FIELDS = {"class", "candidateId", "reason"}
EXPECTED_CANDIDATE_FIELDS = {"id", "candidate"}
CANDIDATE_FIELDS = {"identity", "upperMidiNotes", "lowerMidiNotes"}
IDENTITY_FIELDS = {"upper", "lower"}
LAYER_FIELDS = {"rootPc", "quality"}
ACTION_FIELDS = {
    "id",
    "type",
    "timestampMs",
    "eventIndex",
    "displayable",
    "checkpoint",
}
CHECKPOINT_FIELDS = {
    "construction",
    "observationTimestampMs",
    "frame",
    "candidates",
    "cueRecords",
    "rawDecision",
    "authorization",
    "display",
}
FRAME_FIELDS = {
    "trackerEpoch",
    "afterEventIndex",
    "timestampMs",
    "pressedMidiNotes",
    "sustainedMidiNotes",
    "soundingMidiNotes",
    "pedalDown",
    "onsetNotes",
}
ONSET_NOTE_FIELDS = {"midiNote", "soundingState", "onsetEventIndex"}
CUE_FIELDS = {
    "candidateId",
    "binding",
    "availability",
    "support",
    "lower",
    "upper",
    "layerOnsetOrder",
    "betweenLayerGapMs",
    "reasonCodes",
}
CUE_LAYER_FIELDS = {
    "earliestOnsetMs",
    "latestOnsetMs",
    "spanMs",
    "withinMaximum",
}
BINDING_NOTE_FIELDS = {"midiNote", "onsetEventIndex"}
RAW_FIELDS = {
    "stageSurvivors",
    "candidateTraces",
    "selectedCandidateId",
    "reason",
}
STAGE_FIELDS = {"structural", "assignment", "integrated", "positiveSupport"}
TRACE_FIELDS = {
    "candidateId",
    "identityAssignmentCount",
    "integratedTertian",
    "aggregateSupport",
    "removedAt",
    "selected",
}
INTEGRATED_FIELDS = {"compact", "rootedNinth", "rootedSeventhExtension"}
AUTHORIZATION_FIELDS = {"key", "reason"}
KEY_FIELDS = {"trackerEpoch", "candidateId", "binding"}
DISPLAY_FIELDS = {"state", "transition", "key", "deadlineMs", "reason"}
BASELINE_FIELDS = {"namedSnapshots", "adaptedStreams"}
NAMED_BASELINE_FIELDS = {"id", "sourceKind", "sourceId", "actionId", "coverage"}
STREAM_BASELINE_FIELDS = {"id", "caseId"}

CASE_INVENTORY = (
    (
        "petrushka-r49-structural-abstention",
        "inherited-source",
        "stravinsky-petrushka-r49-arpeggios",
    ),
    (
        "shrovetide-integrated-boundary",
        "inherited-source",
        "stravinsky-shrovetide-oblique-motion",
    ),
    (
        "shared-lower-first-positive-and-release",
        "inherited-source",
        "two-register-held-cohorts",
    ),
    (
        "disjoint-upper-first-80-positive",
        "authored-musical-policy",
        "product-disjoint-upper-first-80",
    ),
    ("upper-seventh-positive", "authored-musical-policy", "product-upper-seventh-80"),
    (
        "lower-seventh-multiple-identities-positive",
        "authored-musical-policy",
        "product-lower-seventh-multiple-identities-80",
    ),
    (
        "assignment-ambiguity-before-cue",
        "authored-musical-policy",
        "product-assignment-ambiguity-80",
    ),
    (
        "compact-integrated-before-cue",
        "authored-musical-policy",
        "product-compact-integrated-80",
    ),
    ("rooted-ninth-before-cue", "authored-musical-policy", "product-rooted-ninth-80"),
    (
        "rooted-seventh-extension-before-cue",
        "authored-musical-policy",
        "product-rooted-seventh-extension-80",
    ),
    (
        "synchronous-cohorts-neutral",
        "authored-musical-policy",
        "synchronous-six-note-cohort",
    ),
    (
        "carried-in-onsets-incomplete",
        "authored-musical-policy",
        "product-carried-in-complete-candidate",
    ),
    (
        "cohort-50-gap-80-positive",
        "authored-musical-policy",
        "product-cohort-50-gap-80",
    ),
    ("cohort-51-neutral", "authored-musical-policy", "product-cohort-51-gap-80"),
    ("gap-79-neutral", "authored-musical-policy", "product-gap-79"),
    (
        "pedal-held-release-stable-then-silence",
        "authored-contract-mechanics",
        "product-pedal-held-release",
    ),
    (
        "reattack-invalidates-binding",
        "authored-contract-mechanics",
        "product-reattack-binding",
    ),
    (
        "primary-gate-clears-and-restarts",
        "authored-contract-mechanics",
        "product-basic-positive-80",
    ),
    (
        "tracker-reset-clears",
        "authored-contract-mechanics",
        "product-basic-positive-80",
    ),
    (
        "pending-key-change-restarts-deadline",
        "authored-contract-mechanics",
        "product-pending-key-change",
    ),
)

INHERITED_CASE_ROSTER = (
    (
        "hancock-maiden-voyage-a-minor-seven-over-d",
        "static-construction-and-named-snapshot",
    ),
    (
        "herrmann-pass-first-a-flat-minor-attack",
        "static-construction-and-named-snapshot",
    ),
    ("ives-psalm-67-opening", "static-construction-and-named-snapshot"),
    ("strauss-elektra-chord-overlap", "static-construction-and-named-snapshot"),
    ("stravinsky-augurs-r13", "static-construction-and-named-snapshot"),
    ("stravinsky-petrushka-r49-arpeggios", "source-replay-structural-abstention"),
    ("stravinsky-shrovetide-second-attack", "source-replay-integrated-abstention"),
    (
        "stravinsky-three-movements-g-over-a-flat-seven",
        "static-construction-and-named-snapshot",
    ),
    ("synthetic-c-major-nine-assignment-ambiguity", "static-guard-and-authored-timing"),
    ("synthetic-c-major-seven-accompaniment", "static-guard-and-authored-timing"),
    ("synthetic-d-over-c-major-seven", "static-boundary-and-authored-timing"),
    ("synthetic-d-over-c-seven-shell", "static-construction-and-named-snapshot"),
    ("synthetic-d-sharp-seven-over-e", "static-positive-and-authored-timing"),
    ("synthetic-integrated-d-six", "static-construction-and-named-snapshot"),
    ("synthetic-layered-c-over-g-minor", "authored-replay-positive-lifecycle"),
    ("synthetic-same-root-c-major-registers", "static-construction-and-named-snapshot"),
    ("synthetic-separated-f-sharp-over-c", "static-construction-and-named-snapshot"),
)

REASON_CODES = {
    "no-structural-candidate",
    "ambiguous-exact-assignment",
    "integrated-tertian-reading",
    "layer-separation-not-supported",
    "missing-layer-separation-history",
}
DISPLAY_REASONS = {
    "awaiting-display-stability",
    "raw-selector-abstention",
    "primary-not-displayable",
    "silence",
    "invalidated-support-binding",
    "authorization-key-changed",
    "tracker-reset",
}
DISPLAY_TRANSITIONS = {"none", "pending", "appearance", "stable", "clear"}

MANIFEST_FIELDS = {
    "schema",
    "fixtureSchema",
    "frameReplayValidator",
    "fixtures",
}
PIN_FIELDS = {"path", "sha256"}
FIXTURE_FIELDS = {"id", "path", "sha256", "origin"}
FIXTURE_ORIGINS = {"inherited-replay", "authored-product-realization"}


def require_dict(value: object, context: str) -> dict:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    return value


def require_list(value: object, context: str) -> list:
    if not isinstance(value, list):
        raise TypeError(f"{context} must be an array")
    return value


def require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise ValueError(
            f"{context} fields are invalid: missing {missing}, unknown {unknown}"
        )


def require_string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{context} must be a nonempty string")
    return value


def require_digest(value: object, context: str) -> str:
    digest = require_string(value, context)
    if (
        len(digest) != 64
        or digest.lower() != digest
        or any(character not in "0123456789abcdef" for character in digest)
    ):
        raise ValueError(f"{context} must be a lowercase SHA-256 digest")
    return digest


def repository_path(value: object, context: str) -> Path:
    relative = Path(require_string(value, context))
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"{context} must be relative to the repository root")
    return REPO_ROOT / relative


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_pin(value: object, context: str) -> Path:
    pin = require_dict(value, context)
    require_fields(pin, PIN_FIELDS, context)
    path = repository_path(pin["path"], f"{context}.path")
    digest = require_digest(pin["sha256"], f"{context}.sha256")
    if sha256_file(path) != digest:
        raise ValueError(f"{context}.sha256 does not match {path}")
    return path


def load_json(path: Path) -> dict:
    return require_dict(json.loads(path.read_text()), str(path))


def validate_fixture_manifest(path: Path) -> dict[str, dict]:
    """Validate all inherited and authored fixtures in the product manifest."""

    manifest = load_json(path)
    require_fields(manifest, MANIFEST_FIELDS, "fixtureManifest")
    if manifest["schema"] != PRODUCT_FIXTURE_MANIFEST_SCHEMA:
        raise ValueError(
            f"fixtureManifest.schema must be {PRODUCT_FIXTURE_MANIFEST_SCHEMA!r}"
        )
    if manifest["fixtureSchema"] != frame_replay.FIXTURE_SCHEMA:
        raise ValueError(
            f"fixtureManifest.fixtureSchema must be {frame_replay.FIXTURE_SCHEMA!r}"
        )
    replay_validator = validate_pin(
        manifest["frameReplayValidator"],
        "fixtureManifest.frameReplayValidator",
    )
    if replay_validator.resolve() != Path(frame_replay.__file__).resolve():
        raise ValueError(
            "fixtureManifest.frameReplayValidator must pin frame_replay.py"
        )

    entries = require_list(manifest["fixtures"], "fixtureManifest.fixtures")
    if not entries:
        raise ValueError("fixtureManifest.fixtures must not be empty")
    fixtures = {}
    seen_paths = set()
    for index, value in enumerate(entries):
        context = f"fixtureManifest.fixtures[{index}]"
        entry = require_dict(value, context)
        require_fields(entry, FIXTURE_FIELDS, context)
        fixture_id = require_string(entry["id"], f"{context}.id")
        if fixture_id in fixtures:
            raise ValueError(f"{context}.id is duplicated")
        fixture_path = repository_path(entry["path"], f"{context}.path")
        if fixture_path in seen_paths:
            raise ValueError(f"{context}.path is duplicated")
        digest = require_digest(entry["sha256"], f"{context}.sha256")
        if sha256_file(fixture_path) != digest:
            raise ValueError(f"{context}.sha256 does not match {fixture_path}")
        if entry["origin"] not in FIXTURE_ORIGINS:
            raise ValueError(f"{context}.origin is unsupported: {entry['origin']!r}")
        fixture = frame_replay.load_json(fixture_path)
        frame_replay.validate_fixture(fixture)
        if fixture["id"] != fixture_id:
            raise ValueError(f"{context}.id does not match {fixture_path}")
        fixtures[fixture_id] = {
            "path": fixture_path,
            "origin": entry["origin"],
            "fixture": fixture,
        }
        seen_paths.add(fixture_path)
    return fixtures


def require_bool(value: object, context: str) -> bool:
    if not isinstance(value, bool):
        raise TypeError(f"{context} must be a boolean")
    return value


def require_int(
    value: object,
    context: str,
    minimum: int = 0,
    maximum: int = 2**53 - 1,
) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{context} must be an integer")
    if value < minimum or value > maximum:
        raise ValueError(f"{context} must be from {minimum} through {maximum}")
    return value


def require_nullable_string(value: object, context: str) -> str | None:
    if value is None:
        return None
    return require_string(value, context)


def require_string_list(value: object, context: str) -> list[str]:
    values = require_list(value, context)
    strings = [
        require_string(item, f"{context}[{index}]") for index, item in enumerate(values)
    ]
    if len(strings) != len(set(strings)):
        raise ValueError(f"{context} must contain distinct values")
    return strings


def require_midi_notes(value: object, context: str) -> list[int]:
    values = require_list(value, context)
    notes = [
        require_int(note, f"{context}[{index}]", 0, 127)
        for index, note in enumerate(values)
    ]
    if notes != sorted(set(notes)):
        raise ValueError(f"{context} must be strictly increasing without duplicates")
    return notes


def validate_candidate(value: object, context: str) -> dict:
    candidate = require_dict(value, context)
    require_fields(candidate, CANDIDATE_FIELDS, context)
    identity = require_dict(candidate["identity"], f"{context}.identity")
    require_fields(identity, IDENTITY_FIELDS, f"{context}.identity")
    normalized_identity = {}
    for role in ("upper", "lower"):
        layer_context = f"{context}.identity.{role}"
        layer = require_dict(identity[role], layer_context)
        require_fields(layer, LAYER_FIELDS, layer_context)
        root_pc = require_int(layer["rootPc"], f"{layer_context}.rootPc", 0, 11)
        quality = layer["quality"]
        if quality not in register_candidates.QUALITY_ORDER:
            raise ValueError(f"{layer_context}.quality is unsupported: {quality!r}")
        normalized_identity[role] = {"rootPc": root_pc, "quality": quality}
    upper_notes = require_midi_notes(
        candidate["upperMidiNotes"], f"{context}.upperMidiNotes"
    )
    lower_notes = require_midi_notes(
        candidate["lowerMidiNotes"], f"{context}.lowerMidiNotes"
    )
    if not upper_notes or not lower_notes:
        raise ValueError(f"{context} assignments must be nonempty")
    if set(upper_notes) & set(lower_notes):
        raise ValueError(f"{context} assignments must be disjoint")
    return {
        "identity": normalized_identity,
        "upperMidiNotes": upper_notes,
        "lowerMidiNotes": lower_notes,
    }


def minimal_candidate(candidate: register_candidates.RegisterCandidate) -> dict:
    return {
        "identity": {
            "upper": {
                "rootPc": candidate.upper.root_pitch_class,
                "quality": candidate.upper.quality,
            },
            "lower": {
                "rootPc": candidate.lower.root_pitch_class,
                "quality": candidate.lower.quality,
            },
        },
        "upperMidiNotes": list(candidate.upper.midi_notes),
        "lowerMidiNotes": list(candidate.lower.midi_notes),
    }


def expected_frame(frame: dict, onset_frame: onset_evidence.OnsetFrame) -> dict:
    return {
        "trackerEpoch": 0,
        "afterEventIndex": frame["afterEventIndex"],
        "timestampMs": frame["timestampMs"],
        "pressedMidiNotes": frame["pressedMidiNotes"],
        "sustainedMidiNotes": frame["sustainedMidiNotes"],
        "soundingMidiNotes": frame["soundingMidiNotes"],
        "pedalDown": frame["pedalDown"],
        "onsetNotes": [
            {
                "midiNote": note.midi_note,
                "soundingState": note.sounding_state,
                "onsetEventIndex": (
                    None if note.origin is None else note.origin.event_index
                ),
            }
            for note in onset_frame.notes
        ],
    }


def validate_frame(value: object, expected: dict, context: str) -> None:
    frame = require_dict(value, context)
    require_fields(frame, FRAME_FIELDS, context)
    require_int(frame["trackerEpoch"], f"{context}.trackerEpoch")
    require_int(frame["afterEventIndex"], f"{context}.afterEventIndex")
    require_int(frame["timestampMs"], f"{context}.timestampMs")
    for field in ("pressedMidiNotes", "sustainedMidiNotes", "soundingMidiNotes"):
        require_midi_notes(frame[field], f"{context}.{field}")
    require_bool(frame["pedalDown"], f"{context}.pedalDown")
    onset_notes = require_list(frame["onsetNotes"], f"{context}.onsetNotes")
    for index, note_value in enumerate(onset_notes):
        note_context = f"{context}.onsetNotes[{index}]"
        note = require_dict(note_value, note_context)
        require_fields(note, ONSET_NOTE_FIELDS, note_context)
        require_int(note["midiNote"], f"{note_context}.midiNote", 0, 127)
        if note["soundingState"] not in {"pressed", "sustained"}:
            raise ValueError(f"{note_context}.soundingState is unsupported")
        if note["onsetEventIndex"] is not None:
            require_int(note["onsetEventIndex"], f"{note_context}.onsetEventIndex")
    if frame != expected:
        raise ValueError(f"{context} does not equal the independently replayed frame")


def validate_binding(value: object, context: str) -> list[dict]:
    binding = require_list(value, context)
    last_note = -1
    normalized = []
    for index, note_value in enumerate(binding):
        note_context = f"{context}[{index}]"
        note = require_dict(note_value, note_context)
        require_fields(note, BINDING_NOTE_FIELDS, note_context)
        midi_note = require_int(note["midiNote"], f"{note_context}.midiNote", 0, 127)
        if midi_note <= last_note:
            raise ValueError(f"{context} must be strictly ordered by MIDI note")
        event_index = note["onsetEventIndex"]
        if event_index is not None:
            event_index = require_int(event_index, f"{note_context}.onsetEventIndex")
        normalized.append({"midiNote": midi_note, "onsetEventIndex": event_index})
        last_note = midi_note
    return normalized


def validate_cue_record(
    value: object,
    candidate_ids: set[str],
    context: str,
) -> dict:
    cue = require_dict(value, context)
    require_fields(cue, CUE_FIELDS, context)
    candidate_id = require_string(cue["candidateId"], f"{context}.candidateId")
    if candidate_id not in candidate_ids:
        raise ValueError(f"{context}.candidateId is not defined by the case")
    validate_binding(cue["binding"], f"{context}.binding")
    availability = cue["availability"]
    if availability not in {"complete", "incomplete"}:
        raise ValueError(f"{context}.availability is unsupported")
    support = cue["support"]
    if support not in {"positive", "neutral", None}:
        raise ValueError(f"{context}.support is unsupported")
    if availability == "incomplete" and support is not None:
        raise ValueError(f"{context}.support must be null when incomplete")
    if availability == "complete" and support is None:
        raise ValueError(f"{context}.support must be nonnull when complete")
    for role in ("lower", "upper"):
        layer_context = f"{context}.{role}"
        layer = require_dict(cue[role], layer_context)
        require_fields(layer, CUE_LAYER_FIELDS, layer_context)
        for field in ("earliestOnsetMs", "latestOnsetMs", "spanMs"):
            if layer[field] is not None:
                require_int(layer[field], f"{layer_context}.{field}")
        if layer["withinMaximum"] is not None:
            require_bool(layer["withinMaximum"], f"{layer_context}.withinMaximum")
    if cue["layerOnsetOrder"] not in {
        "lower-then-upper",
        "upper-then-lower",
        "overlapping",
        None,
    }:
        raise ValueError(f"{context}.layerOnsetOrder is unsupported")
    if cue["betweenLayerGapMs"] is not None:
        require_int(cue["betweenLayerGapMs"], f"{context}.betweenLayerGapMs")
    reasons = require_string_list(cue["reasonCodes"], f"{context}.reasonCodes")
    if availability == "incomplete" and reasons != ["onset-history-incomplete"]:
        raise ValueError(f"{context}.reasonCodes must name incomplete history")
    return cue


def validate_raw_decision(
    value: object,
    candidate_order: list[str],
    cue_by_id: dict[str, dict],
    candidate_by_id: dict[str, dict],
    context: str,
) -> None:
    raw = require_dict(value, context)
    require_fields(raw, RAW_FIELDS, context)
    stages = require_dict(raw["stageSurvivors"], f"{context}.stageSurvivors")
    require_fields(stages, STAGE_FIELDS, f"{context}.stageSurvivors")
    stage_values = {}
    previous = candidate_order
    for stage in ("structural", "assignment", "integrated", "positiveSupport"):
        values = require_string_list(stages[stage], f"{context}.stageSurvivors.{stage}")
        if stage == "structural" and values != candidate_order:
            raise ValueError(f"{context}.stageSurvivors.structural is not exact")
        if [item for item in previous if item in values] != values:
            raise ValueError(f"{context}.stageSurvivors.{stage} changes order")
        if not set(values) <= set(previous):
            raise ValueError(f"{context}.stageSurvivors.{stage} is not a subset")
        previous = values
        stage_values[stage] = values

    traces = require_list(raw["candidateTraces"], f"{context}.candidateTraces")
    if len(traces) != len(candidate_order):
        raise ValueError(f"{context}.candidateTraces must cover every candidate")
    identity_counts = Counter(
        json.dumps(candidate_by_id[candidate_id]["identity"], sort_keys=True)
        for candidate_id in candidate_order
    )
    for index, trace_value in enumerate(traces):
        trace_context = f"{context}.candidateTraces[{index}]"
        trace = require_dict(trace_value, trace_context)
        require_fields(trace, TRACE_FIELDS, trace_context)
        candidate_id = require_string(
            trace["candidateId"], f"{trace_context}.candidateId"
        )
        if candidate_id != candidate_order[index]:
            raise ValueError(f"{trace_context}.candidateId is out of order")
        expected_count = identity_counts[
            json.dumps(candidate_by_id[candidate_id]["identity"], sort_keys=True)
        ]
        if trace["identityAssignmentCount"] != expected_count:
            raise ValueError(f"{trace_context}.identityAssignmentCount is incorrect")
        integrated = require_dict(
            trace["integratedTertian"], f"{trace_context}.integratedTertian"
        )
        require_fields(
            integrated, INTEGRATED_FIELDS, f"{trace_context}.integratedTertian"
        )
        for field in INTEGRATED_FIELDS:
            require_bool(
                integrated[field], f"{trace_context}.integratedTertian.{field}"
            )
        aggregate = trace["aggregateSupport"]
        cue = cue_by_id[candidate_id]
        expected_aggregate = (
            "unavailable" if cue["availability"] == "incomplete" else cue["support"]
        )
        if aggregate != expected_aggregate:
            raise ValueError(f"{trace_context}.aggregateSupport disagrees with cue")
        if trace["removedAt"] not in {"assignment", "integrated", "support", None}:
            raise ValueError(f"{trace_context}.removedAt is unsupported")
        require_bool(trace["selected"], f"{trace_context}.selected")

    expected_assignment = [
        candidate_id
        for candidate_id in candidate_order
        if identity_counts[
            json.dumps(candidate_by_id[candidate_id]["identity"], sort_keys=True)
        ]
        == 1
    ]
    if stage_values["assignment"] != expected_assignment:
        raise ValueError(f"{context}.stageSurvivors.assignment is incorrect")
    trace_by_id = {trace["candidateId"]: trace for trace in traces}
    expected_integrated = [
        candidate_id
        for candidate_id in expected_assignment
        if not any(trace_by_id[candidate_id]["integratedTertian"].values())
    ]
    if stage_values["integrated"] != expected_integrated:
        raise ValueError(f"{context}.stageSurvivors.integrated is incorrect")
    expected_positive = [
        candidate_id
        for candidate_id in expected_integrated
        if cue_by_id[candidate_id]["availability"] == "complete"
        and cue_by_id[candidate_id]["support"] == "positive"
    ]
    if stage_values["positiveSupport"] != expected_positive:
        raise ValueError(f"{context}.stageSurvivors.positiveSupport is incorrect")
    if len(expected_positive) > 1:
        raise ValueError(f"{context} violates positive-survivor uniqueness")

    for candidate_id in candidate_order:
        trace = trace_by_id[candidate_id]
        expected_removal = None
        if candidate_id not in expected_assignment:
            expected_removal = "assignment"
        elif candidate_id not in expected_integrated:
            expected_removal = "integrated"
        elif candidate_id not in expected_positive:
            expected_removal = "support"
        if trace["removedAt"] != expected_removal:
            raise ValueError(
                f"{context} candidate {candidate_id!r} has the wrong removal stage"
            )

    selected = require_nullable_string(
        raw["selectedCandidateId"], f"{context}.selectedCandidateId"
    )
    reason = require_nullable_string(raw["reason"], f"{context}.reason")
    expected_selected = expected_positive[0] if expected_positive else None
    if not candidate_order:
        expected_reason = "no-structural-candidate"
    elif not expected_assignment:
        expected_reason = "ambiguous-exact-assignment"
    elif not expected_integrated:
        expected_reason = "integrated-tertian-reading"
    elif not expected_positive:
        expected_reason = (
            "layer-separation-not-supported"
            if any(
                cue_by_id[candidate_id]["support"] == "neutral"
                for candidate_id in expected_integrated
            )
            else "missing-layer-separation-history"
        )
    else:
        expected_reason = None
    if selected != expected_selected or reason != expected_reason:
        raise ValueError(f"{context} violates selector outcome precedence")
    if sum(bool(trace["selected"]) for trace in traces) != int(selected is not None):
        raise ValueError(f"{context}.candidateTraces selection count is invalid")
    if any(trace["selected"] != (trace["candidateId"] == selected) for trace in traces):
        raise ValueError(f"{context}.candidateTraces selected flags are incorrect")


def validate_key(
    value: object,
    candidate_ids: set[str],
    context: str,
) -> None:
    key = require_dict(value, context)
    require_fields(key, KEY_FIELDS, context)
    require_int(key["trackerEpoch"], f"{context}.trackerEpoch")
    candidate_id = require_string(key["candidateId"], f"{context}.candidateId")
    if candidate_id not in candidate_ids:
        raise ValueError(f"{context}.candidateId is not defined by the case")
    validate_binding(key["binding"], f"{context}.binding")


def validate_checkpoint(
    value: object,
    *,
    context: str,
    observation_timestamp_ms: int,
    derived_frame: dict | None,
    generated_candidates: list[dict],
    candidate_by_id: dict[str, dict],
    construction: dict,
    reset: bool,
) -> dict:
    checkpoint = require_dict(value, context)
    require_fields(checkpoint, CHECKPOINT_FIELDS, context)
    if checkpoint["construction"] != construction:
        raise ValueError(f"{context}.construction does not match the case")
    if checkpoint["observationTimestampMs"] != observation_timestamp_ms:
        raise ValueError(f"{context}.observationTimestampMs is incorrect")
    if reset:
        if any(
            checkpoint[field] not in (None, [])
            for field in (
                "frame",
                "candidates",
                "cueRecords",
                "rawDecision",
                "authorization",
            )
        ):
            raise ValueError(f"{context} reset retains product observation state")
        candidate_order = []
    else:
        assert derived_frame is not None
        validate_frame(checkpoint["frame"], derived_frame, f"{context}.frame")
        candidate_order = require_string_list(
            checkpoint["candidates"], f"{context}.candidates"
        )
        try:
            expected_candidates = [candidate_by_id[item] for item in candidate_order]
        except KeyError as error:
            raise ValueError(
                f"{context}.candidates contains an undefined id"
            ) from error
        if expected_candidates != generated_candidates:
            raise ValueError(
                f"{context}.candidates does not equal the generated canonical list"
            )
        cue_values = require_list(checkpoint["cueRecords"], f"{context}.cueRecords")
        if len(cue_values) != len(candidate_order):
            raise ValueError(f"{context}.cueRecords must cover every candidate")
        cue_by_id = {}
        for index, cue_value in enumerate(cue_values):
            cue = validate_cue_record(
                cue_value, set(candidate_by_id), f"{context}.cueRecords[{index}]"
            )
            if cue["candidateId"] != candidate_order[index]:
                raise ValueError(f"{context}.cueRecords are out of order")
            cue_by_id[cue["candidateId"]] = cue
        onset_by_note = {
            note["midiNote"]: note["onsetEventIndex"]
            for note in checkpoint["frame"]["onsetNotes"]
        }
        for candidate_id in candidate_order:
            candidate = candidate_by_id[candidate_id]
            expected_binding = [
                {
                    "midiNote": midi_note,
                    "onsetEventIndex": onset_by_note[midi_note],
                }
                for midi_note in sorted(
                    candidate["lowerMidiNotes"] + candidate["upperMidiNotes"]
                )
            ]
            cue = cue_by_id[candidate_id]
            if cue["binding"] != expected_binding:
                raise ValueError(
                    f"{context}.cueRecords binding disagrees with the frame"
                )
            expected_availability = (
                "complete"
                if all(note["onsetEventIndex"] is not None for note in expected_binding)
                else "incomplete"
            )
            if cue["availability"] != expected_availability:
                raise ValueError(
                    f"{context}.cueRecords availability disagrees with its binding"
                )
        validate_raw_decision(
            checkpoint["rawDecision"],
            candidate_order,
            cue_by_id,
            candidate_by_id,
            f"{context}.rawDecision",
        )
        authorization = require_dict(
            checkpoint["authorization"], f"{context}.authorization"
        )
        require_fields(authorization, AUTHORIZATION_FIELDS, f"{context}.authorization")
        if authorization["key"] is not None:
            validate_key(
                authorization["key"],
                set(candidate_by_id),
                f"{context}.authorization.key",
            )
        authorization_reason = require_nullable_string(
            authorization["reason"], f"{context}.authorization.reason"
        )
        raw = checkpoint["rawDecision"]
        authorization_key = authorization["key"]
        if authorization_key is not None:
            if authorization_reason is not None:
                raise ValueError(f"{context}.authorization key cannot carry a reason")
            if authorization_key["candidateId"] != raw["selectedCandidateId"]:
                raise ValueError(
                    f"{context}.authorization key disagrees with raw selection"
                )
            if authorization_key["trackerEpoch"] != checkpoint["frame"]["trackerEpoch"]:
                raise ValueError(
                    f"{context}.authorization key has the wrong tracker epoch"
                )
            if (
                authorization_key["binding"]
                != cue_by_id[authorization_key["candidateId"]]["binding"]
            ):
                raise ValueError(
                    f"{context}.authorization key disagrees with the cue binding"
                )
        else:
            if authorization_reason not in REASON_CODES | {"primary-not-displayable"}:
                raise ValueError(f"{context}.authorization reason is unsupported")
            if (
                authorization_reason != "primary-not-displayable"
                and authorization_reason != raw["reason"]
            ):
                raise ValueError(
                    f"{context}.authorization reason disagrees with raw abstention"
                )

    display = require_dict(checkpoint["display"], f"{context}.display")
    require_fields(display, DISPLAY_FIELDS, f"{context}.display")
    if display["state"] not in {"absent", "pending", "visible"}:
        raise ValueError(f"{context}.display.state is unsupported")
    if display["transition"] not in DISPLAY_TRANSITIONS:
        raise ValueError(f"{context}.display.transition is unsupported")
    if display["key"] is not None:
        validate_key(display["key"], set(candidate_by_id), f"{context}.display.key")
    if display["deadlineMs"] is not None:
        require_int(display["deadlineMs"], f"{context}.display.deadlineMs")
    reason = require_nullable_string(display["reason"], f"{context}.display.reason")
    if reason is not None and reason not in DISPLAY_REASONS:
        raise ValueError(f"{context}.display.reason is unsupported")
    if display["state"] == "absent":
        if display["key"] is not None or display["deadlineMs"] is not None:
            raise ValueError(
                f"{context}.display absent state retains a key or deadline"
            )
    elif display["key"] is None:
        raise ValueError(f"{context}.display active state requires a key")
    if display["state"] == "pending" and display["deadlineMs"] is None:
        raise ValueError(f"{context}.display pending state requires a deadline")
    if display["state"] == "visible" and display["deadlineMs"] is not None:
        raise ValueError(f"{context}.display visible state cannot retain a deadline")
    if (
        display["transition"] in {"appearance", "stable"}
        and display["state"] != "visible"
    ):
        raise ValueError(f"{context}.display transition requires visible state")
    if display["transition"] == "pending" and display["state"] != "pending":
        raise ValueError(f"{context}.display pending transition has the wrong state")
    if display["transition"] == "clear" and display["state"] != "absent":
        raise ValueError(f"{context}.display clear transition has the wrong state")
    if (
        not reset
        and display["state"] in {"pending", "visible"}
        and checkpoint["authorization"]["key"] != display["key"]
    ):
        raise ValueError(f"{context}.display active key disagrees with authorization")
    return checkpoint


def validate_construction(
    value: object,
    candidate_ids: set[str],
    context: str,
) -> dict:
    construction = require_dict(value, context)
    require_fields(construction, CONSTRUCTION_FIELDS, context)
    if construction["class"] not in {
        "positive",
        "boundary",
        "negative-guard",
        "coverage-exclusion",
    }:
        raise ValueError(f"{context}.class is unsupported")
    candidate_id = require_nullable_string(
        construction["candidateId"], f"{context}.candidateId"
    )
    reason = require_string(construction["reason"], f"{context}.reason")
    if construction["class"] == "positive":
        if candidate_id not in candidate_ids:
            raise ValueError(f"{context}.candidateId must identify a case candidate")
    elif candidate_id is not None:
        raise ValueError(f"{context}.candidateId must be null for non-positive cases")
    return {
        "class": construction["class"],
        "candidateId": candidate_id,
        "reason": reason,
    }


def validate_case(
    value: object,
    *,
    expected_inventory: tuple[str, str, str],
    fixture_record: dict,
) -> dict:
    case_id, expected_stratum, expected_fixture_id = expected_inventory
    context = f"case {case_id!r}"
    case = require_dict(value, context)
    require_fields(case, CASE_FIELDS, context)
    if case["id"] != case_id:
        raise ValueError(f"{context}.id is out of order")
    if case["stratum"] != expected_stratum:
        raise ValueError(f"{context}.stratum is incorrect")
    if case["fixtureId"] != expected_fixture_id:
        raise ValueError(f"{context}.fixtureId is incorrect")
    require_string(case["title"], f"{context}.title")
    require_string(case["purpose"], f"{context}.purpose")
    provenance = require_dict(case["provenance"], f"{context}.provenance")
    require_fields(provenance, PROVENANCE_FIELDS, f"{context}.provenance")
    if provenance["kind"] not in {"inherited-case", "authored-recipe"}:
        raise ValueError(f"{context}.provenance.kind is unsupported")
    require_nullable_string(provenance["sourceId"], f"{context}.provenance.sourceId")
    require_string(provenance["description"], f"{context}.provenance.description")
    require_bool(
        case["initialPrimaryDisplayable"], f"{context}.initialPrimaryDisplayable"
    )

    candidate_values = require_list(
        case["expectedCandidates"], f"{context}.expectedCandidates"
    )
    candidate_by_id = {}
    for index, candidate_value in enumerate(candidate_values):
        candidate_context = f"{context}.expectedCandidates[{index}]"
        entry = require_dict(candidate_value, candidate_context)
        require_fields(entry, EXPECTED_CANDIDATE_FIELDS, candidate_context)
        candidate_id = require_string(entry["id"], f"{candidate_context}.id")
        if candidate_id in candidate_by_id:
            raise ValueError(f"{candidate_context}.id is duplicated")
        candidate_by_id[candidate_id] = validate_candidate(
            entry["candidate"], f"{candidate_context}.candidate"
        )
    construction = validate_construction(
        case["constructionExpectation"],
        set(candidate_by_id),
        f"{context}.constructionExpectation",
    )

    fixture = fixture_record["fixture"]
    onset_frames = onset_evidence.replay_onset_frames(fixture)
    actions = require_list(case["actions"], f"{context}.actions")
    if not actions:
        raise ValueError(f"{context}.actions must not be empty")
    action_ids = set()
    next_event_index = 0
    current_event_index = None
    last_timestamp = 0
    referenced_candidates = set()
    checkpoint_ids = set()
    reset_seen = False
    display_reasons = set()
    raw_reasons = set()
    transitions = set()
    for index, action_value in enumerate(actions):
        action_context = f"{context}.actions[{index}]"
        action = require_dict(action_value, action_context)
        require_fields(action, ACTION_FIELDS, action_context)
        action_id = require_string(action["id"], f"{action_context}.id")
        if action_id in action_ids:
            raise ValueError(f"{action_context}.id is duplicated")
        action_ids.add(action_id)
        action_type = action["type"]
        if action_type not in {
            "musicalEvent",
            "timer",
            "primaryAvailability",
            "trackerReset",
        }:
            raise ValueError(f"{action_context}.type is unsupported")
        timestamp = require_int(action["timestampMs"], f"{action_context}.timestampMs")
        if timestamp < last_timestamp:
            raise ValueError(f"{action_context}.timestampMs decreases")
        if reset_seen:
            raise ValueError(f"{action_context} follows trackerReset")
        if action_type == "musicalEvent":
            if action["eventIndex"] != next_event_index:
                raise ValueError(f"{action_context}.eventIndex is not consecutive")
            if action["displayable"] is not None:
                raise ValueError(f"{action_context}.displayable must be null")
            if next_event_index >= len(fixture["events"]):
                raise ValueError(f"{action_context}.eventIndex exceeds the fixture")
            event = fixture["events"][next_event_index]
            if timestamp != event["timestampMs"]:
                raise ValueError(
                    f"{action_context}.timestampMs differs from the fixture"
                )
            current_event_index = next_event_index
            next_event_index += 1
        elif action_type == "primaryAvailability":
            if action["eventIndex"] is not None:
                raise ValueError(f"{action_context}.eventIndex must be null")
            require_bool(action["displayable"], f"{action_context}.displayable")
        else:
            if action["eventIndex"] is not None or action["displayable"] is not None:
                raise ValueError(f"{action_context} has inapplicable action fields")
            if action_type == "trackerReset":
                reset_seen = True

        checkpoint = action["checkpoint"]
        if checkpoint is not False:
            if current_event_index is None and action_type != "trackerReset":
                raise ValueError(f"{action_context} checkpoints before a musical frame")
            reset = action_type == "trackerReset"
            if reset:
                derived = None
                generated = []
            else:
                frame = fixture["frames"][current_event_index]
                derived = expected_frame(frame, onset_frames[current_event_index])
                generated = [
                    minimal_candidate(candidate)
                    for candidate in register_candidates.generate_register_candidates(
                        frame["soundingMidiNotes"]
                    )
                ]
            validated = validate_checkpoint(
                checkpoint,
                context=f"{action_context}.checkpoint",
                observation_timestamp_ms=timestamp,
                derived_frame=derived,
                generated_candidates=generated,
                candidate_by_id=candidate_by_id,
                construction=construction,
                reset=reset,
            )
            checkpoint_ids.add(action_id)
            referenced_candidates.update(validated["candidates"])
            display_reasons.add(validated["display"]["reason"])
            if validated["rawDecision"] is not None:
                raw_reasons.add(validated["rawDecision"]["reason"])
            transitions.add(validated["display"]["transition"])
        last_timestamp = timestamp

    if set(candidate_by_id) != referenced_candidates | (
        {construction["candidateId"]} if construction["candidateId"] else set()
    ):
        raise ValueError(
            f"{context}.expectedCandidates has unreferenced or missing values"
        )
    baseline_ids = require_string_list(
        case["baselineTargetIds"], f"{context}.baselineTargetIds"
    )
    return {
        "case": case,
        "actionIds": action_ids,
        "checkpointIds": checkpoint_ids,
        "baselineTargetIds": baseline_ids,
        "displayReasons": display_reasons - {None},
        "rawReasons": raw_reasons - {None},
        "transitions": transitions,
    }


def validate_baseline_targets(
    value: object,
    *,
    cases: dict[str, dict],
    inherited_ids: set[str],
) -> None:
    targets = require_dict(value, "suite.baselineTargets")
    require_fields(targets, BASELINE_FIELDS, "suite.baselineTargets")
    named = require_list(
        targets["namedSnapshots"], "suite.baselineTargets.namedSnapshots"
    )
    named_ids = set()
    for index, target_value in enumerate(named):
        context = f"suite.baselineTargets.namedSnapshots[{index}]"
        target = require_dict(target_value, context)
        require_fields(target, NAMED_BASELINE_FIELDS, context)
        target_id = require_string(target["id"], f"{context}.id")
        if target_id in named_ids:
            raise ValueError(f"{context}.id is duplicated")
        named_ids.add(target_id)
        source_kind = target["sourceKind"]
        source_id = require_string(target["sourceId"], f"{context}.sourceId")
        action_id = target["actionId"]
        if source_kind == "internalSuiteCase":
            if source_id not in inherited_ids or action_id is not None:
                raise ValueError(f"{context} has an invalid inherited source")
        elif source_kind == "automaticCheckpoint":
            if source_id not in cases:
                raise ValueError(f"{context}.sourceId is not an automatic case")
            action_id = require_string(action_id, f"{context}.actionId")
            if action_id not in cases[source_id]["checkpointIds"]:
                raise ValueError(f"{context}.actionId is not a case checkpoint")
        else:
            raise ValueError(f"{context}.sourceKind is unsupported")
        if target["coverage"] not in {"eligible", "ordered-composite-exclusion"}:
            raise ValueError(f"{context}.coverage is unsupported")

    streams = require_list(
        targets["adaptedStreams"], "suite.baselineTargets.adaptedStreams"
    )
    stream_case_ids = []
    stream_ids = set()
    for index, target_value in enumerate(streams):
        context = f"suite.baselineTargets.adaptedStreams[{index}]"
        target = require_dict(target_value, context)
        require_fields(target, STREAM_BASELINE_FIELDS, context)
        target_id = require_string(target["id"], f"{context}.id")
        if target_id in stream_ids:
            raise ValueError(f"{context}.id is duplicated")
        stream_ids.add(target_id)
        case_id = require_string(target["caseId"], f"{context}.caseId")
        if case_id not in cases:
            raise ValueError(f"{context}.caseId is not an automatic case")
        stream_case_ids.append(case_id)
    if stream_case_ids != list(cases):
        raise ValueError(
            "suite.baselineTargets.adaptedStreams must cover cases in order"
        )

    declared = Counter(
        target_id
        for record in cases.values()
        for target_id in record["baselineTargetIds"]
    )
    if set(declared) - named_ids:
        raise ValueError("case baselineTargetIds contain undefined targets")
    automatic_named = {
        target["id"]
        for target in named
        if target["sourceKind"] == "automaticCheckpoint"
    }
    if set(declared) != automatic_named or any(
        count != 1 for count in declared.values()
    ):
        raise ValueError("automatic named targets must be referenced by one case")


def validate_suite(path: Path, *, require_scoring_allowed: bool = False) -> dict:
    """Validate the complete prospective product suite without scoring it."""

    text = path.read_text()
    suite = require_dict(json.loads(text), str(path))
    canonical = json.dumps(suite, indent=2) + "\n"
    if text != canonical:
        raise ValueError("suite JSON must use canonical two-space formatting")
    require_fields(suite, SUITE_FIELDS, "suite")
    if suite["schema"] != PRODUCT_SUITE_SCHEMA:
        raise ValueError(f"suite.schema must be {PRODUCT_SUITE_SCHEMA!r}")
    status = require_dict(suite["status"], "suite.status")
    require_fields(status, STATUS_FIELDS, "suite.status")
    if status not in (
        {"name": "preregistered-author-adjudicated", "scoringAllowed": False},
        {"name": "frozen-author-adjudicated", "scoringAllowed": True},
    ):
        raise ValueError("suite.status is inconsistent")
    if require_scoring_allowed and not status["scoringAllowed"]:
        raise ValueError("suite does not allow scoring")
    if suite["authority"] != "product-policy-only-not-independent-ground-truth":
        raise ValueError("suite.authority is incorrect")
    if suite["noteConvention"] != "MIDI 60 is C4; case spellings are authoritative":
        raise ValueError("suite.noteConvention is incorrect")
    if suite["versionIds"] != VERSION_IDS:
        raise ValueError("suite.versionIds do not match the frozen contract")

    dependencies = require_dict(suite["dependencies"], "suite.dependencies")
    require_fields(dependencies, DEPENDENCY_FIELDS, "suite.dependencies")
    dependency_paths = {
        name: validate_pin(pin, f"suite.dependencies.{name}")
        for name, pin in dependencies.items()
    }
    if dependency_paths["validator"].resolve() != Path(__file__).resolve():
        raise ValueError("suite.dependencies.validator must pin this file")
    if dependency_paths["productFixtureManifest"].name != "fixture-manifest.json":
        raise ValueError("suite.dependencies.productFixtureManifest is incorrect")
    if dependency_paths["scorer"].name != "product_suite_scorer.py":
        raise ValueError("suite.dependencies.scorer is incorrect")

    inherited_values = require_list(suite["inheritedCases"], "suite.inheritedCases")
    inherited = []
    for index, value in enumerate(inherited_values):
        context = f"suite.inheritedCases[{index}]"
        entry = require_dict(value, context)
        require_fields(entry, INHERITED_CASE_FIELDS, context)
        inherited.append((entry["id"], entry["automaticRole"]))
    if tuple(inherited) != INHERITED_CASE_ROSTER:
        raise ValueError("suite.inheritedCases does not match the frozen roster")

    fixtures = validate_fixture_manifest(dependency_paths["productFixtureManifest"])
    case_values = require_list(suite["cases"], "suite.cases")
    if len(case_values) != len(CASE_INVENTORY):
        raise ValueError("suite.cases does not match the frozen inventory length")
    cases = {}
    for value, inventory in zip(case_values, CASE_INVENTORY):
        fixture_id = inventory[2]
        if fixture_id not in fixtures:
            raise ValueError(f"suite fixture {fixture_id!r} is not pinned")
        record = validate_case(
            value,
            expected_inventory=inventory,
            fixture_record=fixtures[fixture_id],
        )
        cases[inventory[0]] = record
    if {inventory[2] for inventory in CASE_INVENTORY} != set(fixtures):
        raise ValueError("product fixture manifest contains unused or missing fixtures")

    validate_baseline_targets(
        suite["baselineTargets"],
        cases=cases,
        inherited_ids={item[0] for item in INHERITED_CASE_ROSTER},
    )
    reasons = set().union(*(record["displayReasons"] for record in cases.values()))
    if reasons != DISPLAY_REASONS:
        raise ValueError(
            f"suite display-reason coverage is incomplete: {sorted(reasons)}"
        )
    raw_reasons = set().union(*(record["rawReasons"] for record in cases.values()))
    if raw_reasons != REASON_CODES:
        raise ValueError(
            f"suite raw-reason coverage is incomplete: {sorted(raw_reasons)}"
        )
    transitions = set().union(*(record["transitions"] for record in cases.values()))
    if transitions != DISPLAY_TRANSITIONS:
        raise ValueError(
            f"suite transition coverage is incomplete: {sorted(transitions)}"
        )
    return suite


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--fixture-manifest", type=Path)
    group.add_argument("--suite", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.fixture_manifest is not None:
        fixtures = validate_fixture_manifest(args.fixture_manifest)
        print(f"valid: {args.fixture_manifest} ({len(fixtures)} fixtures)")
        return 0
    suite = validate_suite(args.suite)
    print(f"valid: {args.suite} ({len(suite['cases'])} cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

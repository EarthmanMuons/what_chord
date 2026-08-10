"""Validate the author-adjudicated polychord internal suite."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import frame_replay
import register_candidates

SUITE_SCHEMA = "polychord-internal-suite/1"
REPO_ROOT = Path(__file__).parents[2]

TOP_LEVEL_FIELDS = {
    "schema",
    "status",
    "scoringAllowed",
    "authority",
    "noteConvention",
    "dependencies",
    "cases",
}
DEPENDENCY_FIELDS = {
    "framework",
    "schemaDocument",
    "registerCandidateSchema",
    "frameReplayManifest",
    "validator",
}
PIN_FIELDS = {"path", "sha256"}
CASE_FIELDS = {
    "id",
    "title",
    "epistemicStatus",
    "scopeFeatures",
    "source",
    "observation",
    "construction",
    "productExpectation",
    "inputEligibility",
    "registerBaseline",
}
UNIT_FIELDS = {
    "id",
    "identity",
    "rootPc",
    "quality",
    "midiNotes",
    "spelledNotes",
    "pitchClasses",
}
ELIGIBILITY_FIELDS = {
    "adjacentRegisterSnapshot",
    "generalPitchRegisterSnapshot",
    "timestampedEventStream",
}
ELIGIBILITY_VALUE_FIELDS = {"status", "reason"}
PRODUCT_FIELDS = {
    "class",
    "expectedPolychords",
    "primarySingleChordAlternatives",
    "reason",
}
EXPECTED_POLYCHORD_FIELDS = {"unitIds", "symbol"}

EPISTEMIC_STATUSES = {
    "literature-attested-construction",
    "theory-derived-boundary",
    "synthetic-regression-guard",
    "unresolved-candidate",
}
PRODUCT_CLASSES = {"positive", "boundary", "negative-guard"}
ELIGIBILITY_STATUSES = {"eligible", "ineligible", "ambiguous", "not-available"}
CONSTRUCTION_KINDS = {
    "polychord",
    "integrated-chord",
    "upper-structure",
}
SCOPE_FEATURES = {
    "complete-triad-layers",
    "complete-seventh-layer",
    "shared-pitch-class-separate-notes",
    "integrated-sixth-chord",
    "incomplete-lower-shell",
    "same-root-register-groups",
    "overlapping-register-layers",
}
QUALITY_INTERVALS = {
    "major": (0, 4, 7),
    "minor": (0, 3, 7),
    "dominant7": (0, 4, 7, 10),
    "major7": (0, 4, 7, 11),
    "minor7": (0, 3, 7, 10),
    "major-sixth": (0, 4, 7, 9),
    "seventh-shell-third": (0, 4, 10),
}
POLYCHORD_QUALITIES = {"major", "minor", "dominant7", "major7", "minor7"}

NATURAL_PITCH_CLASSES = {
    "C": 0,
    "D": 2,
    "E": 4,
    "F": 5,
    "G": 7,
    "A": 9,
    "B": 11,
}
SPELLED_NOTE_PATTERN = re.compile(r"^([A-G])([#b]*)(-?\d+)$")


def require_fields(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        details = []
        if missing:
            details.append(f"missing {missing}")
        if unknown:
            details.append(f"unknown {unknown}")
        raise ValueError(f"{context} fields are invalid: {', '.join(details)}")


def require_dict(value: object, context: str) -> dict:
    if not isinstance(value, dict):
        raise TypeError(f"{context} must be an object")
    return value


def require_list(value: object, context: str) -> list:
    if not isinstance(value, list):
        raise TypeError(f"{context} must be an array")
    return value


def require_string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{context} must be a nonempty string")
    return value


def require_int(value: object, context: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{context} must be an integer")
    if value < minimum or value > maximum:
        raise ValueError(f"{context} must be from {minimum} through {maximum}")
    return value


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_pin(value: object, context: str) -> Path:
    pin = require_dict(value, context)
    require_fields(pin, PIN_FIELDS, context)
    relative = require_string(pin["path"], f"{context}.path")
    digest = require_string(pin["sha256"], f"{context}.sha256")
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"{context}.path must be relative to the repository root")
    if (
        len(digest) != 64
        or digest.lower() != digest
        or any(character not in "0123456789abcdef" for character in digest)
    ):
        raise ValueError(f"{context}.sha256 must be a lowercase SHA-256 digest")
    resolved = REPO_ROOT / path
    if sha256_file(resolved) != digest:
        raise ValueError(f"{context} digest does not match {resolved}")
    return resolved


def validate_midi_notes(value: object, context: str) -> tuple[int, ...]:
    notes = require_list(value, context)
    validated = tuple(
        require_int(note, f"{context}[{index}]", 0, 127)
        for index, note in enumerate(notes)
    )
    if tuple(sorted(set(validated))) != validated:
        raise ValueError(f"{context} must be strictly increasing without duplicates")
    return validated


def spelled_note_to_midi(value: object, context: str) -> int:
    note = require_string(value, context)
    match = SPELLED_NOTE_PATTERN.fullmatch(note)
    if match is None:
        raise ValueError(f"{context} must be a spelled note such as C4, F#3, or Bb2")
    letter, accidentals, octave_text = match.groups()
    accidental_offset = accidentals.count("#") - accidentals.count("b")
    return (
        12 * (int(octave_text) + 1) + NATURAL_PITCH_CLASSES[letter] + accidental_offset
    )


def validate_spellings(
    value: object,
    midi_notes: tuple[int, ...],
    context: str,
) -> tuple[str, ...]:
    spellings = require_list(value, context)
    if len(spellings) != len(midi_notes):
        raise ValueError(f"{context} must have one spelling for every MIDI note")
    validated = tuple(
        require_string(spelling, f"{context}[{index}]")
        for index, spelling in enumerate(spellings)
    )
    spelled_midi = tuple(
        spelled_note_to_midi(spelling, f"{context}[{index}]")
        for index, spelling in enumerate(validated)
    )
    if spelled_midi != midi_notes:
        raise ValueError(
            f"{context} does not match MIDI notes: expected {midi_notes}, "
            f"received {spelled_midi}"
        )
    return validated


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text())
    return require_dict(value, str(path))


def load_replay_fixtures(manifest_path: Path) -> dict[str, dict]:
    paths = frame_replay.validate_manifest(manifest_path)
    fixtures = {}
    for path in paths:
        fixture = frame_replay.load_json(path)
        frame_replay.validate_fixture(fixture)
        fixtures[fixture["id"]] = fixture
    return fixtures


def validate_source(value: object, epistemic_status: str, context: str) -> None:
    source = require_dict(value, context)
    kind = source.get("kind")
    if kind == "synthetic":
        require_fields(source, {"kind", "generation"}, context)
        require_string(source["generation"], f"{context}.generation")
        if epistemic_status == "literature-attested-construction":
            raise ValueError(f"{context} cannot support literature-attested status")
        return
    if kind == "score":
        require_fields(
            source,
            {
                "kind",
                "work",
                "edition",
                "sourceUrl",
                "sourceIdentifier",
                "sha256",
                "scoreLocation",
            },
            context,
        )
        for field in (
            "work",
            "edition",
            "sourceUrl",
            "sourceIdentifier",
            "scoreLocation",
        ):
            require_string(source[field], f"{context}.{field}")
        digest = require_string(source["sha256"], f"{context}.sha256")
        if len(digest) != 64 or any(
            character not in "0123456789abcdef" for character in digest
        ):
            raise ValueError(f"{context}.sha256 must be a lowercase SHA-256 digest")
        return
    raise ValueError(f"{context}.kind is unsupported: {kind!r}")


def observation_notes(
    value: object,
    replay_fixtures: dict[str, dict],
    context: str,
) -> tuple[int, ...]:
    observation = require_dict(value, context)
    kind = observation.get("kind")
    if kind == "snapshot":
        require_fields(
            observation,
            {"kind", "soundingMidiNotes", "spelledNotes"},
            context,
        )
        notes = validate_midi_notes(
            observation["soundingMidiNotes"], f"{context}.soundingMidiNotes"
        )
    elif kind == "frame-replay":
        require_fields(
            observation,
            {"kind", "fixtureId", "afterEventIndex", "spelledNotes"},
            context,
        )
        fixture_id = require_string(observation["fixtureId"], f"{context}.fixtureId")
        if fixture_id not in replay_fixtures:
            raise ValueError(f"{context}.fixtureId is not in the pinned manifest")
        event_index = require_int(
            observation["afterEventIndex"],
            f"{context}.afterEventIndex",
            0,
            2**53 - 1,
        )
        frames = replay_fixtures[fixture_id]["frames"]
        matching = [
            frame for frame in frames if frame["afterEventIndex"] == event_index
        ]
        if len(matching) != 1:
            raise ValueError(f"{context} must identify exactly one replay frame")
        notes = tuple(matching[0]["soundingMidiNotes"])
    else:
        raise ValueError(f"{context}.kind is unsupported: {kind!r}")
    validate_spellings(observation["spelledNotes"], notes, f"{context}.spelledNotes")
    return notes


def validate_unit(
    value: object,
    observation: tuple[int, ...],
    context: str,
) -> tuple[str, tuple[int, ...]]:
    unit = require_dict(value, context)
    require_fields(unit, UNIT_FIELDS, context)
    unit_id = require_string(unit["id"], f"{context}.id")
    require_string(unit["identity"], f"{context}.identity")
    root_pitch_class = require_int(unit["rootPc"], f"{context}.rootPc", 0, 11)
    quality = require_string(unit["quality"], f"{context}.quality")
    if quality not in QUALITY_INTERVALS:
        raise ValueError(f"{context}.quality is unsupported: {quality!r}")
    notes = validate_midi_notes(unit["midiNotes"], f"{context}.midiNotes")
    if not set(notes) <= set(observation):
        raise ValueError(f"{context}.midiNotes must be contained in the observation")
    validate_spellings(unit["spelledNotes"], notes, f"{context}.spelledNotes")
    pitch_classes = validate_midi_notes(unit["pitchClasses"], f"{context}.pitchClasses")
    if any(pitch_class > 11 for pitch_class in pitch_classes):
        raise ValueError(f"{context}.pitchClasses must be from 0 through 11")
    if pitch_classes != tuple(sorted({note % 12 for note in notes})):
        raise ValueError(f"{context}.pitchClasses do not match its MIDI notes")
    if root_pitch_class not in pitch_classes:
        raise ValueError(f"{context}.rootPc must be present in its pitch classes")
    shape = tuple(
        sorted((pitch_class - root_pitch_class) % 12 for pitch_class in pitch_classes)
    )
    if shape != QUALITY_INTERVALS[quality]:
        raise ValueError(
            f"{context}.quality does not match its root-relative pitch classes"
        )
    return unit_id, notes


def validate_construction(
    value: object,
    observation: tuple[int, ...],
    context: str,
) -> tuple[str, dict[str, tuple[int, ...]], dict]:
    construction = require_dict(value, context)
    require_fields(construction, {"kind", "description", "units", "notation"}, context)
    kind = construction["kind"]
    if kind not in CONSTRUCTION_KINDS:
        raise ValueError(f"{context}.kind is unsupported: {kind!r}")
    require_string(construction["description"], f"{context}.description")
    values = require_list(construction["units"], f"{context}.units")
    expected_count = 1 if kind == "integrated-chord" else 2
    if len(values) != expected_count:
        raise ValueError(f"{context}.units must contain {expected_count} units")
    units = {}
    assigned_notes = set()
    for index, unit_value in enumerate(values):
        unit_id, notes = validate_unit(
            unit_value,
            observation,
            f"{context}.units[{index}]",
        )
        if unit_id in units:
            raise ValueError(f"{context}.units contains duplicate id {unit_id!r}")
        overlap = assigned_notes & set(notes)
        if overlap:
            raise ValueError(f"{context}.units reuse MIDI notes {sorted(overlap)}")
        units[unit_id] = notes
        assigned_notes.update(notes)
    if assigned_notes != set(observation):
        raise ValueError(f"{context}.units must assign every observed MIDI note")
    if kind == "polychord":
        unsupported = {
            unit["quality"]
            for unit in values
            if unit["quality"] not in POLYCHORD_QUALITIES
        }
        if unsupported:
            raise ValueError(
                f"{context}.units use non-v0 polychord qualities: {sorted(unsupported)}"
            )

    notation = require_dict(construction["notation"], f"{context}.notation")
    status = notation.get("status")
    if status == "resolved":
        require_fields(
            notation,
            {"status", "symbol", "upperUnitId", "lowerUnitId"},
            f"{context}.notation",
        )
        symbol = require_string(notation["symbol"], f"{context}.notation.symbol")
        upper = require_string(
            notation["upperUnitId"], f"{context}.notation.upperUnitId"
        )
        lower = require_string(
            notation["lowerUnitId"], f"{context}.notation.lowerUnitId"
        )
        if kind != "polychord" or upper == lower or {upper, lower} != set(units):
            raise ValueError(f"{context}.notation does not identify both chord units")
        identities = {unit["id"]: unit["identity"] for unit in values}
        if symbol != f"{identities[upper]}|{identities[lower]}":
            raise ValueError(f"{context}.notation.symbol does not match its units")
    elif status in {"unresolved", "not-applicable"}:
        require_fields(notation, {"status", "reason"}, f"{context}.notation")
        require_string(notation["reason"], f"{context}.notation.reason")
        if status == "unresolved" and kind != "polychord":
            raise ValueError(
                f"{context}.notation may be unresolved only for a polychord"
            )
    else:
        raise ValueError(f"{context}.notation.status is unsupported: {status!r}")
    return kind, units, notation


def validate_product_expectation(
    value: object,
    construction_kind: str,
    unit_ids: set[str],
    notation: dict,
    context: str,
) -> str:
    product = require_dict(value, context)
    require_fields(product, PRODUCT_FIELDS, context)
    product_class = product["class"]
    if product_class not in PRODUCT_CLASSES:
        raise ValueError(f"{context}.class is unsupported: {product_class!r}")
    expected = require_list(
        product["expectedPolychords"], f"{context}.expectedPolychords"
    )
    alternatives = require_list(
        product["primarySingleChordAlternatives"],
        f"{context}.primarySingleChordAlternatives",
    )
    for index, alternative in enumerate(alternatives):
        require_string(
            alternative, f"{context}.primarySingleChordAlternatives[{index}]"
        )
    require_string(product["reason"], f"{context}.reason")

    if product_class == "positive":
        if construction_kind != "polychord" or not expected:
            raise ValueError(
                f"{context} positive cases require a polychord expectation"
            )
    elif expected:
        raise ValueError(f"{context} non-positive cases cannot expect a polychord")

    expected_symbols = set()
    for index, expected_value in enumerate(expected):
        expected_polychord = require_dict(
            expected_value, f"{context}.expectedPolychords[{index}]"
        )
        require_fields(
            expected_polychord,
            EXPECTED_POLYCHORD_FIELDS,
            f"{context}.expectedPolychords[{index}]",
        )
        expected_units = require_list(
            expected_polychord["unitIds"],
            f"{context}.expectedPolychords[{index}].unitIds",
        )
        expected_units = [
            require_string(
                unit_id,
                f"{context}.expectedPolychords[{index}].unitIds[{unit_index}]",
            )
            for unit_index, unit_id in enumerate(expected_units)
        ]
        if len(expected_units) != 2 or set(expected_units) != unit_ids:
            raise ValueError(
                f"{context}.expectedPolychords[{index}].unitIds must identify both units"
            )
        symbol = expected_polychord["symbol"]
        if symbol is not None:
            expected_symbols.add(
                require_string(symbol, f"{context}.expectedPolychords[{index}].symbol")
            )

    if (
        product_class == "positive"
        and notation["status"] == "resolved"
        and notation["symbol"] not in expected_symbols
    ):
        raise ValueError(f"{context} must include the resolved construction symbol")
    if notation["status"] == "unresolved" and expected_symbols:
        raise ValueError(f"{context} cannot invent a symbol for unresolved layer order")
    return product_class


def validate_eligibility(value: object, context: str) -> None:
    eligibility = require_dict(value, context)
    require_fields(eligibility, ELIGIBILITY_FIELDS, context)
    for condition in sorted(ELIGIBILITY_FIELDS):
        result = require_dict(eligibility[condition], f"{context}.{condition}")
        require_fields(result, ELIGIBILITY_VALUE_FIELDS, f"{context}.{condition}")
        if result["status"] not in ELIGIBILITY_STATUSES:
            raise ValueError(
                f"{context}.{condition}.status is unsupported: {result['status']!r}"
            )
        require_string(result["reason"], f"{context}.{condition}.reason")


def validate_case(
    value: object,
    replay_fixtures: dict[str, dict],
    context: str,
) -> str:
    case = require_dict(value, context)
    require_fields(case, CASE_FIELDS, context)
    case_id = require_string(case["id"], f"{context}.id")
    require_string(case["title"], f"{context}.title")
    epistemic_status = case["epistemicStatus"]
    if epistemic_status not in EPISTEMIC_STATUSES:
        raise ValueError(
            f"{context}.epistemicStatus is unsupported: {epistemic_status!r}"
        )
    features = require_list(case["scopeFeatures"], f"{context}.scopeFeatures")
    features = [
        require_string(feature, f"{context}.scopeFeatures[{index}]")
        for index, feature in enumerate(features)
    ]
    if not features or len(features) != len(set(features)):
        raise ValueError(f"{context}.scopeFeatures must be nonempty and unique")
    unknown_features = set(features) - SCOPE_FEATURES
    if unknown_features:
        raise ValueError(
            f"{context}.scopeFeatures are unsupported: {sorted(unknown_features)}"
        )
    validate_source(case["source"], epistemic_status, f"{context}.source")
    notes = observation_notes(
        case["observation"], replay_fixtures, f"{context}.observation"
    )
    construction_kind, units, notation = validate_construction(
        case["construction"], notes, f"{context}.construction"
    )
    validate_product_expectation(
        case["productExpectation"],
        construction_kind,
        set(units),
        notation,
        f"{context}.productExpectation",
    )
    validate_eligibility(case["inputEligibility"], f"{context}.inputEligibility")

    baseline = require_dict(case["registerBaseline"], f"{context}.registerBaseline")
    require_fields(baseline, {"expectedCandidates"}, f"{context}.registerBaseline")
    expected_candidates = require_list(
        baseline["expectedCandidates"],
        f"{context}.registerBaseline.expectedCandidates",
    )
    actual_candidates = [
        candidate.as_dict()
        for candidate in register_candidates.generate_register_candidates(notes)
    ]
    if expected_candidates != actual_candidates:
        raise ValueError(
            f"{context}.registerBaseline.expectedCandidates do not match generation: "
            f"expected {expected_candidates}, received {actual_candidates}"
        )
    return case_id


def validate_suite_payload(payload: dict) -> list[str]:
    require_fields(payload, TOP_LEVEL_FIELDS, "suite")
    if payload["schema"] != SUITE_SCHEMA:
        raise ValueError(f"suite.schema must be {SUITE_SCHEMA!r}")
    if payload["status"] != "active-author-adjudicated-seed":
        raise ValueError("suite.status must be 'active-author-adjudicated-seed'")
    if payload["scoringAllowed"] is not False:
        raise ValueError(
            "suite.scoringAllowed must remain false before evaluation freeze"
        )
    if payload["authority"] != "product-policy-only-not-independent-ground-truth":
        raise ValueError("suite.authority must state its product-policy limitation")
    if payload["noteConvention"] != "MIDI 60 is C4; spellings are case-specific":
        raise ValueError("suite.noteConvention is unsupported")

    dependencies = require_dict(payload["dependencies"], "suite.dependencies")
    require_fields(dependencies, DEPENDENCY_FIELDS, "suite.dependencies")
    resolved = {
        name: validate_pin(dependencies[name], f"suite.dependencies.{name}")
        for name in DEPENDENCY_FIELDS
    }
    if resolved["validator"].resolve() != Path(__file__).resolve():
        raise ValueError("suite.dependencies.validator must pin this validator")
    replay_fixtures = load_replay_fixtures(resolved["frameReplayManifest"])

    cases = require_list(payload["cases"], "suite.cases")
    if not cases:
        raise ValueError("suite.cases must not be empty")
    case_ids = [
        validate_case(case, replay_fixtures, f"suite.cases[{index}]")
        for index, case in enumerate(cases)
    ]
    if len(case_ids) != len(set(case_ids)):
        raise ValueError("suite.cases contains duplicate ids")
    if case_ids != sorted(case_ids):
        raise ValueError("suite.cases must be ordered by id")
    return case_ids


def validate_suite(path: Path) -> list[str]:
    return validate_suite_payload(load_json(path))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    case_ids = validate_suite(args.suite)
    print(f"valid: {args.suite} ({len(case_ids)} cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

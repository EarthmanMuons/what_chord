"""Faithful adapters and normalization for frozen polychord baselines."""

from __future__ import annotations

import hashlib
import json
import platform
import re
import subprocess
import time
from pathlib import Path

import register_selector

RESULT_SCHEMA = "polychord-prior-art-baseline-result/1"
REPO_ROOT = Path(__file__).parents[2]
RUNTIME_ROOT = Path("build/polychord/prior-art-env-v1")
RUNTIME_MANIFEST_PATH = RUNTIME_ROOT / "runtime-manifest-v1.json"
PYTHON_WORKER_PATH = Path("tool/polychord/prior_art_python_worker.py")
DART_WORKER_PATH = Path("tool/polychord/prior_art_whatchord_batch.dart")

WHATCHORD_ID = "whatchord-register-policy-1"
MUSICPY_ID = "musicpy-7.15-poly-chord-first"
MINGUS_ID = "python-mingus-6558cac-polychords"
CHORDRECGEN_ID = "chordrecgen-3790a4d-swift"
BASELINE_IDS = (WHATCHORD_ID, MUSICPY_ID, MINGUS_ID, CHORDRECGEN_ID)
BASELINE_PINS = {
    WHATCHORD_ID: "polychord-register-policy/1",
    MUSICPY_ID: "musicpy-7.15.tar.gz@sha256:b6e10025648632a666ce99b0647655158a87dc554ebd9edbb9547d87fbf2a3e1",
    MINGUS_ID: "6558cacffeaab4f084a3eedda12b0e86fd24c430",
    CHORDRECGEN_ID: "3790a4df5f1c3bbef4ff0a27c43ddacc020a6639",
}

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
ROOT_PITCH_CLASSES = {
    "C": 0,
    "B#": 0,
    "C#": 1,
    "Db": 1,
    "D": 2,
    "D#": 3,
    "Eb": 3,
    "E": 4,
    "Fb": 4,
    "E#": 5,
    "F": 5,
    "F#": 6,
    "Gb": 6,
    "G": 7,
    "G#": 8,
    "Ab": 8,
    "A": 9,
    "A#": 10,
    "Bb": 10,
    "B": 11,
    "Cb": 11,
}
MUSICPY_QUALITIES = {
    "major": "major",
    "minor": "minor",
    "7": "dominant7",
    "maj7": "major7",
    "m7": "minor7",
}
MINGUS_PATTERN = re.compile(r"^(?P<root>[A-G](?:#|b)?)(?P<quality>M7|m7|M|m|7)$")

RESULT_FIELDS = {
    "schema",
    "baseline",
    "observationId",
    "inputSha256",
    "adapterInput",
    "options",
    "runtime",
    "rawReturn",
    "rawStdout",
    "rawStderr",
    "elapsedMicroseconds",
    "status",
    "normalizedAlternatives",
}
ALTERNATIVE_FIELDS = {
    "nativeIndex",
    "classification",
    "upper",
    "lower",
    "components",
    "assignment",
    "rawLabel",
    "reason",
}
STATUSES = {
    "ok",
    "no-output",
    "exception",
    "timeout",
    "build-unavailable",
    "unparseable",
}
CLASSIFICATIONS = {
    "ordered-composite",
    "single-chord-output",
    "unsupported-composite",
    "unparseable",
}


def canonical_json(value: object) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def sha256_json(value: object) -> str:
    return hashlib.sha256(canonical_json(value).encode()).hexdigest()


def make_observation(observation_id: str, midi_notes: list[int]) -> dict:
    if not isinstance(observation_id, str) or not observation_id.strip():
        raise ValueError("observation_id must be a nonempty string")
    if any(
        type(note) is not int or note < 0 or note > 127 for note in midi_notes
    ) or midi_notes != sorted(set(midi_notes)):
        raise ValueError("midi_notes must be sorted, distinct MIDI integers")
    pitch_classes = [PITCH_CLASS_NAMES[note % 12] for note in midi_notes]
    return {
        "observationId": observation_id,
        "orderedMidiNotes": list(midi_notes),
        "scientificPitchSharps": [
            f"{PITCH_CLASS_NAMES[note % 12]}{note // 12 - 1}" for note in midi_notes
        ],
        "pitchClassSharps": pitch_classes,
    }


def validate_observation(value: object) -> dict:
    if not isinstance(value, dict):
        raise TypeError("neutral observation must be an object")
    expected = {
        "observationId",
        "orderedMidiNotes",
        "scientificPitchSharps",
        "pitchClassSharps",
    }
    if set(value) != expected:
        raise ValueError("neutral observation fields are invalid")
    regenerated = make_observation(value["observationId"], value["orderedMidiNotes"])
    if value != regenerated:
        raise ValueError("neutral observation spellings do not match MIDI notes")
    return regenerated


def _component(root: str, quality: str) -> dict | None:
    root_pc = ROOT_PITCH_CLASSES.get(root)
    if root_pc is None or quality not in {
        "major",
        "minor",
        "dominant7",
        "major7",
        "minor7",
    }:
        return None
    return {"rootPc": root_pc, "quality": quality}


def _alternative(
    *,
    native_index: int,
    classification: str,
    upper: dict | None = None,
    lower: dict | None = None,
    components: list[dict | None] | None = None,
    assignment: dict | None = None,
    raw_label: str | None = None,
    reason: str | None = None,
) -> dict:
    return {
        "nativeIndex": native_index,
        "classification": classification,
        "upper": upper,
        "lower": lower,
        "components": [] if components is None else components,
        "assignment": assignment,
        "rawLabel": raw_label,
        "reason": reason,
    }


def _musicpy_fields(value: object) -> dict | None:
    if not isinstance(value, dict) or not isinstance(value.get("fields"), dict):
        return None
    return value["fields"]


def _musicpy_component(value: object) -> dict | None:
    fields = _musicpy_fields(value)
    if fields is None:
        return None
    if (
        fields.get("type") != "chord"
        or fields.get("chord_speciality") != "root position"
        or fields.get("inversion") is not None
        or fields.get("omit") is not None
        or fields.get("altered") is not None
        or fields.get("non_chord_bass_note") is not None
    ):
        return None
    quality = MUSICPY_QUALITIES.get(fields.get("chord_type"))
    root = fields.get("root")
    return _component(root, quality) if isinstance(root, str) and quality else None


def normalize_musicpy(raw_return: object, midi_notes: list[int]) -> list[dict]:
    if not isinstance(raw_return, dict):
        return []
    raw_value = raw_return.get("value")
    raw_label = raw_return.get("toText")
    fields = _musicpy_fields(raw_value)
    if fields is None:
        return [
            _alternative(
                native_index=0,
                classification="unparseable",
                raw_label=raw_label if isinstance(raw_label, str) else None,
                reason="missing-public-chord-type-fields",
            )
        ]
    polychords = fields.get("polychords")
    if not polychords:
        component = _musicpy_component(raw_value)
        return [
            _alternative(
                native_index=0,
                classification="single-chord-output",
                components=[component],
                raw_label=raw_label if isinstance(raw_label, str) else None,
                reason=None if component else "unsupported-component",
            )
        ]
    if not isinstance(polychords, list) or len(polychords) != 2:
        return [
            _alternative(
                native_index=0,
                classification="unsupported-composite",
                raw_label=raw_label if isinstance(raw_label, str) else None,
                reason="native-polychord-arity-is-not-two",
            )
        ]
    lower = _musicpy_component(polychords[0])
    upper = _musicpy_component(polychords[1])
    components = [upper, lower]
    if upper is None or lower is None:
        return [
            _alternative(
                native_index=0,
                classification="unsupported-composite",
                components=components,
                raw_label=raw_label if isinstance(raw_label, str) else None,
                reason="unsupported-component",
            )
        ]
    split_index = len(midi_notes) // 2 if len(midi_notes) >= 6 else 1
    return [
        _alternative(
            native_index=0,
            classification="ordered-composite",
            upper=upper,
            lower=lower,
            components=components,
            assignment={
                "upperMidiNotes": midi_notes[split_index:],
                "lowerMidiNotes": midi_notes[:split_index],
            },
            raw_label=raw_label if isinstance(raw_label, str) else None,
        )
    ]


def _mingus_component(value: str) -> dict | None:
    match = MINGUS_PATTERN.fullmatch(value)
    if match is None:
        return None
    quality = {
        "M": "major",
        "m": "minor",
        "7": "dominant7",
        "M7": "major7",
        "m7": "minor7",
    }[match.group("quality")]
    return _component(match.group("root"), quality)


def normalize_mingus(raw_return: object) -> list[dict]:
    if not isinstance(raw_return, list):
        return []
    alternatives = []
    for index, label in enumerate(raw_return):
        if not isinstance(label, str):
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unparseable",
                    reason="native-alternative-is-not-text",
                )
            )
            continue
        parts = label.split("|")
        if len(parts) == 1:
            component = _mingus_component(label)
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="single-chord-output",
                    components=[component],
                    raw_label=label,
                    reason=None if component else "unsupported-component",
                )
            )
            continue
        components = [_mingus_component(part) for part in parts]
        if len(parts) == 2 and all(components):
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="ordered-composite",
                    upper=components[0],
                    lower=components[1],
                    components=components,
                    raw_label=label,
                )
            )
        else:
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unsupported-composite",
                    components=components,
                    raw_label=label,
                    reason=(
                        "native-polychord-arity-is-not-two"
                        if len(parts) != 2
                        else "unsupported-component"
                    ),
                )
            )
    return alternatives


def _chordrecgen_component(chord: object) -> dict | None:
    if not isinstance(chord, dict):
        return None
    root_pc = chord.get("rootPitchClass")
    notes = chord.get("notes")
    quality = chord.get("quality")
    factor_quality = chord.get("factorQuality")
    factors = chord.get("factors")
    if (
        type(root_pc) is not int
        or not isinstance(notes, list)
        or not isinstance(quality, dict)
        or not isinstance(factor_quality, dict)
        or not isinstance(factors, list)
        or chord.get("additions")
        or chord.get("alteredNotes")
        or chord.get("omission") is not None
        or chord.get("invertedNotes")
        or chord.get("inversion") != 0
    ):
        return None
    offsets = {(note - root_pc) % 12 for note in notes}
    factor_degrees = [item.get("degree", {}).get("name") for item in factors]
    native = (quality.get("name"), factor_quality.get("name"), factor_degrees)
    product_quality = {
        ("Maj", "dom", ()): ("major", {0, 4, 7}),
        ("min", "dom", ()): ("minor", {0, 3, 7}),
        ("Maj", "dom", ("7",)): ("dominant7", {0, 4, 7, 10}),
        ("Maj", "Maj", ("7",)): ("major7", {0, 4, 7, 11}),
        ("min", "dom", ("7",)): ("minor7", {0, 3, 7, 10}),
    }.get((native[0], native[1], tuple(native[2])))
    if product_quality is None or offsets != product_quality[1]:
        return None
    return {"rootPc": root_pc, "quality": product_quality[0]}


def normalize_chordrecgen(raw_return: object, midi_notes: list[int]) -> list[dict]:
    if not isinstance(raw_return, list):
        return []
    alternatives = []
    input_set = set(midi_notes)
    for index, group in enumerate(raw_return):
        if not isinstance(group, dict) or not isinstance(group.get("chords"), list):
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unparseable",
                    reason="native-group-shape-is-invalid",
                )
            )
            continue
        chords = group["chords"]
        raw_label = group.get("fullName")
        components = [_chordrecgen_component(chord) for chord in chords]
        if len(chords) == 1:
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="single-chord-output",
                    components=components,
                    raw_label=raw_label,
                    reason=None if components[0] else "unsupported-component",
                )
            )
            continue
        if len(chords) != 2 or any(component is None for component in components):
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unsupported-composite",
                    components=components,
                    raw_label=raw_label,
                    reason=(
                        "native-polychord-arity-is-not-two"
                        if len(chords) != 2
                        else "unsupported-component"
                    ),
                )
            )
            continue
        note_sets = [set(chord.get("notes", [])) for chord in chords]
        exact_partition = (
            all(note_sets)
            and note_sets[0].isdisjoint(note_sets[1])
            and note_sets[0] | note_sets[1] == input_set
        )
        if not exact_partition:
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unsupported-composite",
                    components=components,
                    raw_label=raw_label,
                    reason="component-notes-do-not-partition-input",
                )
            )
            continue
        if max(note_sets[0]) < min(note_sets[1]):
            lower_index, upper_index = 0, 1
        elif max(note_sets[1]) < min(note_sets[0]):
            lower_index, upper_index = 1, 0
        else:
            alternatives.append(
                _alternative(
                    native_index=index,
                    classification="unsupported-composite",
                    components=components,
                    raw_label=raw_label,
                    reason="component-registers-overlap",
                )
            )
            continue
        alternatives.append(
            _alternative(
                native_index=index,
                classification="ordered-composite",
                upper=components[upper_index],
                lower=components[lower_index],
                components=[components[upper_index], components[lower_index]],
                assignment={
                    "upperMidiNotes": sorted(note_sets[upper_index]),
                    "lowerMidiNotes": sorted(note_sets[lower_index]),
                },
                raw_label=raw_label,
            )
        )
    return alternatives


def normalize_whatchord(decision: dict) -> list[dict]:
    selected = decision.get("selected")
    if selected is None:
        return []
    upper = {
        "rootPc": selected["upper"]["rootPc"],
        "quality": selected["upper"]["quality"],
    }
    lower = {
        "rootPc": selected["lower"]["rootPc"],
        "quality": selected["lower"]["quality"],
    }
    return [
        _alternative(
            native_index=0,
            classification="ordered-composite",
            upper=upper,
            lower=lower,
            components=[upper, lower],
            assignment={
                "upperMidiNotes": selected["upper"]["midiNotes"],
                "lowerMidiNotes": selected["lower"]["midiNotes"],
            },
            raw_label=selected["symbol"],
        )
    ]


def _runtime_manifest(path: Path) -> dict:
    value = json.loads(path.read_text())
    if value.get("schema") != "polychord-prior-art-runtime-manifest/1":
        raise ValueError("prior-art runtime manifest has the wrong schema")
    return value


def _result(
    *,
    baseline_id: str,
    observation: dict,
    native: dict,
    runtime: object,
    normalized: list[dict],
) -> dict:
    return {
        "schema": RESULT_SCHEMA,
        "baseline": {"id": baseline_id, "pin": BASELINE_PINS[baseline_id]},
        "observationId": observation["observationId"],
        "inputSha256": sha256_json(observation),
        "adapterInput": native["adapterInput"],
        "options": native["options"],
        "runtime": runtime,
        "rawReturn": native["rawReturn"],
        "rawStdout": native["nativeStdout"],
        "rawStderr": native["nativeStderr"],
        "elapsedMicroseconds": native["elapsedMicroseconds"],
        "status": native["status"],
        "normalizedAlternatives": normalized,
    }


def _run_json_worker(
    *,
    command: list[str],
    observations: list[dict],
    inject_exception: bool,
) -> list[dict]:
    request_lines = [
        canonical_json(
            {
                "id": observation["observationId"],
                "observation": observation,
                "injectException": inject_exception,
            }
        )
        for observation in observations
    ]
    started = time.perf_counter_ns()
    try:
        process = subprocess.run(
            command,
            cwd=REPO_ROOT,
            input="\n".join(request_lines) + "\n",
            capture_output=True,
            text=True,
            timeout=max(30, 10 * len(observations)),
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        elapsed = (time.perf_counter_ns() - started) // 1000
        return [
            {
                "adapterInput": None,
                "options": None,
                "rawReturn": None,
                "nativeStdout": error.stdout or "",
                "nativeStderr": error.stderr or "",
                "elapsedMicroseconds": elapsed,
                "status": "timeout",
            }
            for _ in observations
        ]
    elapsed = (time.perf_counter_ns() - started) // 1000
    if process.returncode != 0:
        return [
            {
                "adapterInput": None,
                "options": None,
                "rawReturn": {"returnCode": process.returncode},
                "nativeStdout": process.stdout,
                "nativeStderr": process.stderr,
                "elapsedMicroseconds": elapsed,
                "status": "exception",
            }
            for _ in observations
        ]
    if process.stderr:
        raise RuntimeError(f"baseline worker wrote transport stderr: {process.stderr}")
    lines = process.stdout.splitlines()
    if len(lines) != len(observations):
        raise RuntimeError("baseline worker response count differs")
    responses = []
    for observation, line in zip(observations, lines):
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            value = {
                "id": observation["observationId"],
                "adapterInput": None,
                "options": None,
                "rawReturn": line,
                "nativeStdout": process.stdout,
                "nativeStderr": "",
                "status": "unparseable",
            }
        if value.get("id") != observation["observationId"]:
            raise RuntimeError("baseline worker response ID differs")
        value["elapsedMicroseconds"] = elapsed // max(1, len(observations))
        responses.append(value)
    return responses


def _run_python_baseline(
    baseline_id: str,
    observations: list[dict],
    runtime_manifest: dict,
    *,
    inject_exception: bool,
) -> list[dict]:
    runtime = runtime_manifest["runtimes"][baseline_id]
    command = [
        runtime["pythonPath"],
        str(REPO_ROOT / PYTHON_WORKER_PATH),
        "--baseline",
        baseline_id,
    ]
    native_values = _run_json_worker(
        command=command,
        observations=observations,
        inject_exception=inject_exception,
    )
    results = []
    for observation, native in zip(observations, native_values):
        normalized = []
        if native["status"] == "ok":
            if baseline_id == MUSICPY_ID:
                normalized = normalize_musicpy(
                    native["rawReturn"], observation["orderedMidiNotes"]
                )
            else:
                normalized = normalize_mingus(native["rawReturn"])
        results.append(
            _result(
                baseline_id=baseline_id,
                observation=observation,
                native=native,
                runtime=runtime,
                normalized=normalized,
            )
        )
    return results


def _run_chordrecgen(
    observations: list[dict],
    runtime_manifest: dict,
    *,
    inject_exception: bool,
) -> list[dict]:
    runtime = runtime_manifest["runtimes"][CHORDRECGEN_ID]
    native_values = _run_json_worker(
        command=[runtime["executablePath"]],
        observations=observations,
        inject_exception=inject_exception,
    )
    return [
        _result(
            baseline_id=CHORDRECGEN_ID,
            observation=observation,
            native=native,
            runtime=runtime,
            normalized=(
                normalize_chordrecgen(
                    native["rawReturn"], observation["orderedMidiNotes"]
                )
                if native["status"] == "ok"
                else []
            ),
        )
        for observation, native in zip(observations, native_values)
    ]


def _run_whatchord(observations: list[dict]) -> list[dict]:
    requests = [
        canonical_json(
            {
                "id": observation["observationId"],
                "orderedMidiNotes": observation["orderedMidiNotes"],
            }
        )
        for observation in observations
    ]
    process = subprocess.run(
        ["dart", "run", str(DART_WORKER_PATH)],
        cwd=REPO_ROOT,
        input="\n".join(requests) + "\n",
        capture_output=True,
        text=True,
        check=True,
    )
    unexpected_stderr = process.stderr.replace("Running build hooks...", "").strip()
    if unexpected_stderr:
        raise RuntimeError(f"WhatChord Dart worker stderr: {unexpected_stderr}")
    lines = process.stdout.splitlines()
    if len(lines) != len(observations):
        raise RuntimeError("WhatChord Dart response count differs")
    dart_version_process = subprocess.run(
        ["dart", "--version"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    runtime = {
        "pythonVersion": platform.python_version(),
        "dartVersion": (
            dart_version_process.stdout or dart_version_process.stderr
        ).strip(),
        "pythonSelector": str(Path(register_selector.__file__).relative_to(REPO_ROOT)),
        "dartWorker": str(DART_WORKER_PATH),
    }
    results = []
    for observation, line in zip(observations, lines):
        dart_value = json.loads(line)
        if dart_value.get("id") != observation["observationId"]:
            raise RuntimeError("WhatChord Dart response ID differs")
        started = time.perf_counter_ns()
        python_decision = register_selector.decision_document(
            observation["orderedMidiNotes"],
            selector_id="polychord-register-policy/1",
        )
        python_elapsed = (time.perf_counter_ns() - started) // 1000
        if python_decision != dart_value["decision"]:
            raise RuntimeError("WhatChord Python and Dart baseline decisions differ")
        status = "ok" if python_decision["selected"] is not None else "no-output"
        native = {
            "adapterInput": observation["orderedMidiNotes"],
            "options": {"selectorId": "polychord-register-policy/1"},
            "rawReturn": {"python": python_decision, "dart": dart_value["decision"]},
            "nativeStdout": "",
            "nativeStderr": "",
            "elapsedMicroseconds": python_elapsed + dart_value["elapsedMicroseconds"],
            "status": status,
        }
        results.append(
            _result(
                baseline_id=WHATCHORD_ID,
                observation=observation,
                native=native,
                runtime=runtime,
                normalized=(
                    normalize_whatchord(python_decision) if status == "ok" else []
                ),
            )
        )
    return results


def _injected_exception_results(
    baseline_id: str,
    observations: list[dict],
) -> list[dict]:
    return [
        _result(
            baseline_id=baseline_id,
            observation=observation,
            native={
                "adapterInput": (
                    observation["orderedMidiNotes"]
                    if baseline_id != MINGUS_ID
                    else observation["pitchClassSharps"]
                ),
                "options": {"control": "injected-adapter-exception"},
                "rawReturn": {
                    "exceptionType": "builtins.RuntimeError",
                    "message": "injected adapter exception",
                },
                "nativeStdout": "",
                "nativeStderr": "",
                "elapsedMicroseconds": 0,
                "status": "exception",
            },
            runtime={"control": "source-independent-transport-failure"},
            normalized=[],
        )
        for observation in observations
    ]


def run_baseline(
    baseline_id: str,
    observations: list[dict],
    *,
    runtime_manifest_path: Path = REPO_ROOT / RUNTIME_MANIFEST_PATH,
    inject_exception: bool = False,
) -> list[dict]:
    if baseline_id not in BASELINE_IDS:
        raise ValueError(f"unknown baseline: {baseline_id}")
    normalized_observations = [validate_observation(value) for value in observations]
    if baseline_id == WHATCHORD_ID and inject_exception:
        results = _injected_exception_results(
            baseline_id,
            normalized_observations,
        )
    elif baseline_id == WHATCHORD_ID:
        results = _run_whatchord(normalized_observations)
    else:
        runtime_manifest = _runtime_manifest(runtime_manifest_path)
        if baseline_id in {MUSICPY_ID, MINGUS_ID}:
            results = _run_python_baseline(
                baseline_id,
                normalized_observations,
                runtime_manifest,
                inject_exception=inject_exception,
            )
        else:
            results = _run_chordrecgen(
                normalized_observations,
                runtime_manifest,
                inject_exception=inject_exception,
            )
    for result in results:
        validate_result(result)
    return results


def validate_result(value: object) -> dict:
    if not isinstance(value, dict) or set(value) != RESULT_FIELDS:
        raise ValueError("baseline result fields are invalid")
    if value["schema"] != RESULT_SCHEMA:
        raise ValueError("baseline result schema is invalid")
    if value["status"] not in STATUSES:
        raise ValueError("baseline result status is invalid")
    if (
        type(value["elapsedMicroseconds"]) is not int
        or value["elapsedMicroseconds"] < 0
    ):
        raise ValueError("baseline elapsed time is invalid")
    alternatives = value["normalizedAlternatives"]
    if not isinstance(alternatives, list):
        raise TypeError("normalized alternatives must be an array")
    for alternative in alternatives:
        if not isinstance(alternative, dict) or set(alternative) != ALTERNATIVE_FIELDS:
            raise ValueError("normalized alternative fields are invalid")
        if alternative["classification"] not in CLASSIFICATIONS:
            raise ValueError("normalized alternative classification is invalid")
    if value["status"] != "ok" and alternatives:
        raise ValueError("a non-ok result cannot contain normalized alternatives")
    return value


def deterministic_projection(result: dict) -> dict:
    """Remove only elapsed-time diagnostics for repeatability controls."""

    return {key: value for key, value in result.items() if key != "elapsedMicroseconds"}

"""Persistent JSON-lines worker for the pinned Python prior-art baselines."""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import sys
from enum import Enum

MUSICPY_ID = "musicpy-7.15-poly-chord-first"
MINGUS_ID = "python-mingus-6558cac-polychords"

MUSICPY_OPTIONS = {
    "change_from_first": True,
    "original_first": True,
    "same_note_special": False,
    "whole_detect": True,
    "poly_chord_first": True,
    "root_preference": False,
    "show_degree": False,
    "get_chord_type": True,
    "original_first_ratio": 0.86,
    "similarity_ratio": 0.6,
    "custom_mapping": None,
    "standardize_note": False,
}
MINGUS_OPTIONS = {
    "shorthand": True,
    "no_inversions": False,
    "no_polychords": False,
}


def stable_value(value: object) -> object:
    """Serialize public native return fields without relying on repr()."""

    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, Enum):
        return {
            "enum": f"{type(value).__module__}.{type(value).__qualname__}",
            "name": value.name,
            "value": stable_value(value.value),
        }
    if isinstance(value, (list, tuple)):
        return [stable_value(item) for item in value]
    if isinstance(value, dict):
        return {
            str(key): stable_value(item)
            for key, item in sorted(value.items(), key=lambda pair: str(pair[0]))
        }
    fields = getattr(value, "__dict__", None)
    if isinstance(fields, dict):
        return {
            "class": f"{type(value).__module__}.{type(value).__qualname__}",
            "fields": {
                key: stable_value(item)
                for key, item in sorted(fields.items())
                if not key.startswith("_")
            },
        }
    return {
        "class": f"{type(value).__module__}.{type(value).__qualname__}",
        "text": str(value),
    }


def _musicpy_import() -> tuple[object, str, str]:
    os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "1"
    os.environ["SDL_AUDIODRIVER"] = "dummy"
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        import musicpy

    return musicpy, stdout.getvalue(), stderr.getvalue()


def _mingus_import() -> tuple[object, str, str]:
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        from mingus.core import chords

    return chords, stdout.getvalue(), stderr.getvalue()


def _musicpy_response(module: object, observation: dict) -> dict:
    notes = [module.degree_to_note(note) for note in observation["orderedMidiNotes"]]
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = module.alg.detect_chord_type(notes, **MUSICPY_OPTIONS)
            text_value = None if result is None else result.to_text()
    except Exception as error:  # noqa: BLE001 - native failures are result data.
        return _exception_response(
            error,
            adapter_input=[stable_value(note) for note in notes],
            options=MUSICPY_OPTIONS,
            stdout=stdout.getvalue(),
            stderr=stderr.getvalue(),
        )
    return {
        "adapterInput": [stable_value(note) for note in notes],
        "options": MUSICPY_OPTIONS,
        "rawReturn": (
            None
            if result is None
            else {"value": stable_value(result), "toText": text_value}
        ),
        "nativeStdout": stdout.getvalue(),
        "nativeStderr": stderr.getvalue(),
        "status": "no-output" if result is None else "ok",
    }


def _mingus_response(module: object, observation: dict) -> dict:
    notes = list(observation["pitchClassSharps"])
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = module.determine(notes, **MINGUS_OPTIONS)
    except Exception as error:  # noqa: BLE001 - native failures are result data.
        return _exception_response(
            error,
            adapter_input=notes,
            options=MINGUS_OPTIONS,
            stdout=stdout.getvalue(),
            stderr=stderr.getvalue(),
        )
    return {
        "adapterInput": notes,
        "options": MINGUS_OPTIONS,
        "rawReturn": stable_value(result),
        "nativeStdout": stdout.getvalue(),
        "nativeStderr": stderr.getvalue(),
        "status": "no-output" if not result else "ok",
    }


def _exception_response(
    error: BaseException,
    *,
    adapter_input: object,
    options: object,
    stdout: str,
    stderr: str,
) -> dict:
    return {
        "adapterInput": adapter_input,
        "options": options,
        "rawReturn": {
            "exceptionType": f"{type(error).__module__}.{type(error).__qualname__}",
            "message": str(error),
        },
        "nativeStdout": stdout,
        "nativeStderr": stderr,
        "status": "exception",
    }


def run(baseline_id: str) -> int:
    if baseline_id == MUSICPY_ID:
        module, import_stdout, import_stderr = _musicpy_import()
        invoke = _musicpy_response
    else:
        module, import_stdout, import_stderr = _mingus_import()
        invoke = _mingus_response

    for line in sys.stdin:
        if not line.strip():
            continue
        request = json.loads(line)
        try:
            if request.get("injectException"):
                raise RuntimeError("injected adapter exception")
            response = invoke(module, request["observation"])
            response["nativeStdout"] = import_stdout + response["nativeStdout"]
            response["nativeStderr"] = import_stderr + response["nativeStderr"]
        except Exception as error:  # noqa: BLE001 - native failures are result data.
            response = _exception_response(
                error,
                adapter_input=None,
                options=None,
                stdout=import_stdout,
                stderr=import_stderr,
            )
        print(json.dumps({"id": request["id"], **response}, sort_keys=True))
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", choices=(MUSICPY_ID, MINGUS_ID), required=True)
    return parser.parse_args()


def main() -> int:
    return run(parse_args().baseline)


if __name__ == "__main__":
    raise SystemExit(main())

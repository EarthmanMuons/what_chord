"""Compare Python and pure-Dart polychord decisions on the pinned matrix."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from collections import Counter
from collections.abc import Iterator
from pathlib import Path

import register_conformance
import register_selector

OUTPUT_SCHEMA = "polychord-register-selector-equivalence/1"
REPO_ROOT = Path(__file__).parents[2]
HARNESS_PATH = Path(__file__).relative_to(REPO_ROOT)
PYTHON_SELECTOR_PATH = Path(register_selector.__file__).relative_to(REPO_ROOT)
DART_BATCH_PATH = Path("tool/polychord/register_selector_batch.dart")
DART_MODEL_PATH = Path(
    "packages/whatchord/lib/src/polychord/models/polychord_candidate.dart"
)
DART_GENERATOR_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/"
    "polychord_register_candidate_generator.dart"
)
DART_SELECTOR_PATH = Path(
    "packages/whatchord/lib/src/polychord/services/polychord_register_selector.dart"
)
PREREGISTRATION_PATH = Path("research/polychord/register-selector-v1.md")

SELECTOR_IDS = tuple(register_selector.SELECTOR_PROFILES)


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


def dart_version() -> str:
    result = subprocess.run(
        ("dart", "--version"),
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return (result.stdout or result.stderr).strip()


def conformance_cases() -> Iterator[dict]:
    for lower_quality in register_conformance.QUALITIES:
        for upper_quality in register_conformance.QUALITIES:
            for relative_root_interval in register_conformance.RELATIVE_ROOT_INTERVALS:
                for transposition in register_conformance.TRANSPOSITIONS:
                    lower_root_pc = transposition
                    upper_root_pc = (transposition + relative_root_interval) % 12
                    lower_notes = register_conformance.root_position_notes(
                        lower_root_pc,
                        lower_quality,
                        36,
                    )
                    upper_notes = register_conformance.root_position_notes(
                        upper_root_pc,
                        upper_quality,
                        72,
                    )
                    yield {
                        "id": (
                            f"core/{lower_quality}/{upper_quality}/"
                            f"{relative_root_interval}/{transposition}"
                        ),
                        "kind": "core",
                        "midiNotes": sorted((*lower_notes, *upper_notes)),
                    }

    for control in register_conformance.FOCUSED_CONTROLS:
        yield {
            "id": f"focused/{control['id']}",
            "kind": "focused",
            "midiNotes": list(control["midiNotes"]),
        }


def _decision_outcome(decision: dict) -> str:
    selected = decision["selected"]
    if selected is not None:
        return "selected"
    return decision["reasonCodes"][0]


def measurement_payload() -> dict:
    cases = list(conformance_cases())
    process = subprocess.Popen(
        ("dart", "run", str(DART_BATCH_PATH)),
        cwd=REPO_ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    if process.stdin is None or process.stdout is None or process.stderr is None:
        raise RuntimeError("failed to open Dart batch process pipes")

    mismatches = []
    outcomes = {selector_id: Counter() for selector_id in SELECTOR_IDS}
    try:
        for case in cases:
            request = {
                "id": case["id"],
                "midiNotes": case["midiNotes"],
                "selectorIds": list(SELECTOR_IDS),
            }
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
            process.stdin.flush()
            response_line = process.stdout.readline()
            if not response_line:
                stderr = process.stderr.read()
                raise RuntimeError(f"Dart batch ended before {case['id']}: {stderr}")
            response = json.loads(response_line)
            if response.get("id") != case["id"]:
                raise ValueError(f"Dart response id differs for {case['id']}")

            for selector_id in SELECTOR_IDS:
                python_decision = register_selector.decision_document(
                    case["midiNotes"],
                    selector_id=selector_id,
                )
                dart_decision = response["decisions"][selector_id]
                outcomes[selector_id][_decision_outcome(python_decision)] += 1
                if dart_decision != python_decision:
                    mismatches.append(
                        {
                            "caseId": case["id"],
                            "kind": case["kind"],
                            "midiNotes": case["midiNotes"],
                            "selectorId": selector_id,
                            "python": python_decision,
                            "dart": dart_decision,
                        }
                    )
        process.stdin.close()
        return_code = process.wait()
        stderr = process.stderr.read()
        if return_code != 0:
            raise RuntimeError(f"Dart batch failed ({return_code}): {stderr}")
        unexpected_stderr = stderr.replace("Running build hooks...", "").strip()
        if unexpected_stderr:
            raise RuntimeError(
                f"Dart batch wrote unexpected stderr: {unexpected_stderr}"
            )
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()

    core_count = sum(case["kind"] == "core" for case in cases)
    focused_count = sum(case["kind"] == "focused" for case in cases)
    return {
        "method": {
            "matrixSchema": register_conformance.OUTPUT_SCHEMA,
            "selectorIds": list(SELECTOR_IDS),
            "comparison": "decoded complete decision-document equality",
            "caseOrder": "pinned core matrix followed by focused controls",
        },
        "summary": {
            "caseCount": len(cases),
            "coreCaseCount": core_count,
            "focusedCaseCount": focused_count,
            "decisionComparisonCount": len(cases) * len(SELECTOR_IDS),
            "mismatchCount": len(mismatches),
        },
        "outcomes": {
            selector_id: {key: counter[key] for key in sorted(counter)}
            for selector_id, counter in outcomes.items()
        },
        "mismatches": mismatches,
    }


def build_report(command: list[str]) -> dict:
    payload = measurement_payload()
    paths = {
        "preregistration": PREREGISTRATION_PATH,
        "pythonSelector": PYTHON_SELECTOR_PATH,
        "dartModel": DART_MODEL_PATH,
        "dartGenerator": DART_GENERATOR_PATH,
        "dartSelector": DART_SELECTOR_PATH,
        "dartBatch": DART_BATCH_PATH,
        "harness": HARNESS_PATH,
        "matrixHarness": Path(register_conformance.__file__).relative_to(REPO_ROOT),
    }
    return {
        "schema": OUTPUT_SCHEMA,
        "source": {
            "command": command,
            "workingDirectory": str(Path.cwd().resolve()),
            "repositoryCommit": git_output("rev-parse", "HEAD"),
            "repositoryDirty": bool(git_output("status", "--porcelain")),
            "pythonVersion": platform.python_version(),
            "dartVersion": dart_version(),
            "artifacts": {
                name: {"path": str(path), "sha256": sha256_file(REPO_ROOT / path)}
                for name, path in paths.items()
            },
        },
        **payload,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = build_report([sys.executable, *sys.argv])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = report["summary"]
    print(
        f"{summary['decisionComparisonCount']} decisions across "
        f"{summary['caseCount']} cases; {summary['mismatchCount']} mismatches "
        f"-> {args.out}"
    )
    return int(summary["mismatchCount"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())

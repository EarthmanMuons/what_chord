#!/usr/bin/env python3
"""Hash and verify WhatKey fixture sets and result artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

CANONICALIZATION = "whatkey-canonical-json-v1"
# The scored paper data; additive diagnostics and run metadata are not locked.
REPORT_DATA_KEYS = (
    "schema",
    "fixtures",
    "split",
    "detector",
    "restrictedTo",
    "summary",
    "perPiece",
)

# Chord-ranking policies the extract scripts may select. The default freezes on
# the WhatKey paper profile so a regenerated research set does not silently pick
# up later naming improvements. Shared by every extract script so the choice
# advances in one place.
ANALYSIS_PROFILES = ("current", "whatKeyPaper2026")
DEFAULT_ANALYSIS_PROFILE = "whatKeyPaper2026"

# Python and Dart emit identical plain-decimal text only for finite non-integer
# magnitudes in [1e-4, 1e16); outside that band one side switches to exponent
# notation (1e-05 vs 0.00001) and the shared SHA-256 diverges. Reject such
# values at hash time so a set generated here cannot fail to reproduce in Dart.
CANONICAL_FLOAT_MIN = 1e-4
CANONICAL_FLOAT_MAX = 1e16


def _assert_canonical_floats(value: object) -> None:
    if isinstance(value, dict):
        for item in value.values():
            _assert_canonical_floats(item)
    elif isinstance(value, (list, tuple)):
        for item in value:
            _assert_canonical_floats(item)
    elif isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError(
                f"Non-finite number is not canonically hashable: {value!r}"
            )
        magnitude = abs(value)
        if magnitude != 0 and (
            magnitude < CANONICAL_FLOAT_MIN or magnitude >= CANONICAL_FLOAT_MAX
        ):
            raise ValueError(
                f"Number {value!r} is outside the canonical-JSON range "
                f"[{CANONICAL_FLOAT_MIN}, {CANONICAL_FLOAT_MAX}); Python and "
                "Dart would format it differently and hash to different digests."
            )


def canonical_json(value: object) -> bytes:
    """Stable UTF-8 JSON encoding shared with the Dart harness."""
    _assert_canonical_floats(value)
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode()


def canonical_sha256(value: object) -> str:
    return hashlib.sha256(canonical_json(value)).hexdigest()


def fixture_hashes(set_dir: Path, files: list[str]) -> tuple[dict[str, str], str]:
    """Per-file and aggregate hashes, independent of JSON whitespace."""
    hashes = {
        name: canonical_sha256(json.loads((set_dir / name).read_text()))
        for name in sorted(files)
    }
    payload = [{"file": name, "sha256": hashes[name]} for name in sorted(hashes)]
    return hashes, canonical_sha256(payload)


def fixture_set_sha256(set_dir: Path) -> str:
    manifest = json.loads((set_dir / "manifest.json").read_text())
    files = [entry["file"] for entry in manifest["fixtures"]]
    return fixture_hashes(set_dir, files)[1]


def result_hashes(result_dir: Path) -> dict[str, str]:
    claims = json.loads((result_dir / "claims.json").read_text())
    report = json.loads((result_dir / "report.json").read_text())
    report_data = {key: report.get(key) for key in REPORT_DATA_KEYS}
    fixtures = report_data.get("fixtures")
    if isinstance(fixtures, dict):
        report_data["fixtures"] = {
            "set": fixtures.get("set"),
        }
    if report_data.get("restrictedTo") is not None:
        report_data["restrictedTo"] = True
    return {
        "claimsSha256": canonical_sha256(claims),
        "resultDataSha256": canonical_sha256(report_data),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    fixtures = subparsers.add_parser("fixtures")
    fixtures.add_argument("directories", nargs="+", type=Path)

    results = subparsers.add_parser("results")
    results.add_argument("directories", nargs="+", type=Path)

    verify = subparsers.add_parser("verify")
    verify.add_argument(
        "--lock",
        type=Path,
        default=Path("research/whatkey/results/reproduction-v2026.7.14.json"),
    )
    verify.add_argument("--fixture", action="append", default=[])
    verify.add_argument("--result", action="append", default=[])
    verify.add_argument("--fixture-root", type=Path)
    verify.add_argument("--result-root", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "fixtures":
        for directory in args.directories:
            print(f"{fixture_set_sha256(directory)}  {directory}")
        return 0
    if args.command == "results":
        for directory in args.directories:
            print(json.dumps({"directory": str(directory), **result_hashes(directory)}))
        return 0
    return verify_lock(
        args.lock,
        args.fixture,
        args.result,
        fixture_root=args.fixture_root,
        result_root=args.result_root,
    )


def verify_lock(
    lock_path: Path,
    fixtures: list[str],
    results: list[str],
    *,
    fixture_root: Path | None = None,
    result_root: Path | None = None,
) -> int:
    lock = json.loads(lock_path.read_text())
    if (
        lock.get("algorithm") != "sha256"
        or lock.get("canonicalization") != CANONICALIZATION
        or lock.get("resultDataFields") != list(REPORT_DATA_KEYS)
    ):
        raise SystemExit(f"{lock_path}: unsupported reproduction lock contract")
    selected_fixtures = fixtures or sorted(lock["fixtures"])
    selected_results = results or sorted(lock["results"])
    failed = False

    for name in selected_fixtures:
        expected = lock["fixtures"][name]
        directory = fixture_root / name if fixture_root else Path(expected["path"])
        actual = fixture_set_sha256(directory)
        ok = actual == expected["sha256"]
        print(f"{'ok' if ok else 'MISMATCH'} fixture {name}: {actual}")
        failed |= not ok

    for name in selected_results:
        expected = lock["results"][name]
        directory = result_root / name if result_root else Path(expected["path"])
        actual = result_hashes(directory)
        # expected.get: a lock entry missing a hash reports MISMATCH, not KeyError.
        ok = all(actual[key] == expected.get(key) for key in actual)
        print(
            f"{'ok' if ok else 'MISMATCH'} result {name}: "
            f"claims={actual['claimsSha256']} data={actual['resultDataSha256']}"
        )
        failed |= not ok

    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())

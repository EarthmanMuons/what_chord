#!/usr/bin/env python3
"""Verify or print the WhatKey headline result table.

The headline table in research/whatkey/README.md is intentionally reproducible
from committed result artifacts, without requiring access to the licensed
fixture corpora. This script reads those reports and checks the rounded table
values used on the landing page.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

DEFAULT_ROOT = Path("research/whatkey/results/test-split-2026-07-07")
DEFAULT_MANIFEST = DEFAULT_ROOT / "MANIFEST.json"


@dataclass(frozen=True)
class HeadlineRow:
    label: str
    report_dir: str
    expected: tuple[str, str, str] | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        help="Directory containing the headline report subdirectories.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Machine-readable result manifest with headline rows and expectations.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if the rounded table differs from README values.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    row_specs = load_rows(args.manifest)
    root = args.root or args.manifest.parent
    rows = tuple(read_row(root, row) for row in row_specs)
    print(render_markdown(rows))

    expected = tuple(
        (row.label, *row.expected) for row in row_specs if row.expected is not None
    )
    if args.check and expected and rows != expected:
        print("Headline table mismatch.", file=sys.stderr)
        print("Expected:", file=sys.stderr)
        print(render_markdown(expected), file=sys.stderr)
        return 1

    if args.check:
        print("Headline table matches expected report artifacts.")
    return 0


def load_rows(manifest_path: Path) -> tuple[HeadlineRow, ...]:
    try:
        manifest = json.loads(manifest_path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"Missing manifest: {manifest_path}") from None
    rows = []
    for row in manifest["headlineTable"]["rows"]:
        expected = row.get("expected")
        rows.append(
            HeadlineRow(
                label=row["label"],
                report_dir=row["reportDir"],
                expected=None
                if expected is None
                else (
                    expected["coverage"],
                    expected["exact"],
                    expected["mirex"],
                ),
            )
        )
    return tuple(rows)


def read_row(root: Path, row: HeadlineRow) -> tuple[str, str, str, str]:
    report_path = root / row.report_dir / "report.json"
    try:
        report = json.loads(report_path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"Missing report: {report_path}") from None

    summary = report["summary"]
    coverage = summary["coverage"]["meanPerPiece"]
    accuracy = summary["accuracyOnClaimed"]
    exact = accuracy["meanExactPerPiece"]
    mirex = accuracy["meanMirexPerPiece"]
    return (row.label, f"{coverage:.2f}", f"{exact:.3f}", f"{mirex:.3f}")


def render_markdown(rows: tuple[tuple[str, str, str, str], ...]) -> str:
    lines = [
        "| system                         | coverage | exact | MIREX |",
        "| ------------------------------ | -------- | ----- | ----- |",
    ]
    for label, coverage, exact, mirex in rows:
        lines.append(f"| {label:<30} | {coverage:<8} | {exact:<5} | {mirex:<5} |")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())

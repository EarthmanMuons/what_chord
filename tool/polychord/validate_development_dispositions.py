#!/usr/bin/env python3
"""Validate complete polychord development-fire dispositions."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import development_exposure


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-index", type=Path, required=True)
    parser.add_argument("--dispositions", type=Path, required=True)
    return parser.parse_args()


def load_object(path: Path) -> dict:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return payload


def main() -> int:
    args = parse_args()
    index = load_object(args.review_index)
    if index.get("schema") != development_exposure.REVIEW_INDEX_SCHEMA:
        raise ValueError("unexpected review-index schema")
    dispositions = load_object(args.dispositions)
    development_exposure.validate_disposition_payload(
        dispositions,
        index.get("items"),
        require_complete=True,
    )
    print(f"Validated {len(index['items'])} complete review items.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

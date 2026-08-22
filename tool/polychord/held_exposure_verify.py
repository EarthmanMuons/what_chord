#!/usr/bin/env python3
"""Verify a retained POP909 held-exposure result without rerunning analysis."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

import development_exposure as shared
import held_exposure as contract


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result-directory", type=Path, required=True)
    parser.add_argument("--require-pass", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> dict:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise TypeError(f"{path} must contain an object")
    return payload


def verify(result_directory: Path, *, require_pass: bool) -> dict:
    root = result_directory.resolve()
    manifest = load_json(root / "manifest.json")
    summary = load_json(root / "summary.json")
    review = load_json(root / "review.json")
    if manifest.get("schema") != contract.MANIFEST_SCHEMA:
        raise ValueError("unexpected manifest schema")
    if summary.get("schema") != contract.REPORT_SCHEMA:
        raise ValueError("unexpected summary schema")
    if manifest.get("measurementId") != contract.MEASUREMENT_ID:
        raise ValueError("unexpected manifest measurement ID")
    if summary.get("measurementId") != contract.MEASUREMENT_ID:
        raise ValueError("unexpected summary measurement ID")
    if manifest.get("repositoryDirty") is not False:
        raise ValueError("measurement repository was dirty")
    if manifest.get("isolation") != {
        "corpusLabelsSuppliedToAnalysis": False,
        "pop909HeldSongsOpened": 808,
        "pop909SampleSongsOpened": 0,
    }:
        raise ValueError("held/sample isolation record differs")

    declared = manifest.get("outputs")
    if not isinstance(declared, dict):
        raise TypeError("manifest outputs must be an object")
    actual_paths = {
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file() and path.name not in {"manifest.json", "review.json"}
    }
    if set(declared) != actual_paths:
        raise ValueError("manifest output inventory differs from files")
    for relative, expected_hash in declared.items():
        if shared.sha256_file(root / relative) != expected_hash:
            raise ValueError(f"output hash differs: {relative}")

    pieces = summary.get("pieces")
    if not isinstance(pieces, list) or len(pieces) != 808:
        raise ValueError("summary must index 808 pieces")
    if len({piece["pieceId"] for piece in pieces}) != 808:
        raise ValueError("piece IDs must be unique")

    counts: Counter[str] = Counter()
    displayed_ms = 0
    expected_review_items = []
    for piece in pieces:
        path = root / piece["path"]
        if shared.sha256_file(path) != piece["sha256"]:
            raise ValueError(f"piece index hash differs: {piece['pieceId']}")
        payload = load_json(path)
        if payload.get("schema") != contract.REPORT_SCHEMA:
            raise ValueError(f"piece report schema differs: {piece['pieceId']}")
        analysis = payload.get("analysis")
        if (
            not isinstance(analysis, dict)
            or analysis.get("schema") != contract.PIECE_SCHEMA
        ):
            raise ValueError(f"piece analysis schema differs: {piece['pieceId']}")
        if analysis.get("id") != f"pop909/{piece['pieceId']}":
            raise ValueError(f"piece analysis ID differs: {piece['pieceId']}")
        contract.add_counts(counts, analysis["counts"])
        displayed_ms += analysis["displayedMs"]
        source = payload.get("source")
        if not isinstance(source, dict) or source.get("pieceId") != piece["pieceId"]:
            raise ValueError(f"piece source differs: {piece['pieceId']}")
        expected_review_items.extend(
            contract.review_item(piece["pieceId"], Path(source["path"]), episode)
            for episode in analysis["stableEpisodes"]
        )

    if summary.get("counts") != dict(sorted(counts.items())):
        raise ValueError("summary counts do not reconstruct from pieces")
    if summary.get("displayedMs") != displayed_ms:
        raise ValueError("summary displayed time does not reconstruct")
    if summary.get("stableEpisodeCount") != len(expected_review_items):
        raise ValueError("summary stable-episode count does not reconstruct")

    if review.get("schema") != "polychord-held-exposure-review/1":
        raise ValueError("unexpected review schema")
    if review.get("allowedDispositions") != list(contract.ALLOWED_DISPOSITIONS):
        raise ValueError("review dispositions differ")
    items = review.get("items")
    if not isinstance(items, list):
        raise TypeError("review items must be an array")
    expected_review_items.sort(key=lambda item: item["itemId"])
    expected_template = {
        "schema": "polychord-held-exposure-review/1",
        "allowedDispositions": list(contract.ALLOWED_DISPOSITIONS),
        "items": expected_review_items,
    }
    expected_template_bytes = (
        json.dumps(expected_template, indent=2, sort_keys=True) + "\n"
    ).encode()
    if manifest.get("adjudicationTemplate") != {
        "path": "review.json",
        "sha256": hashlib.sha256(expected_template_bytes).hexdigest(),
    }:
        raise ValueError("adjudication template hash differs")
    if len(items) != len(expected_review_items):
        raise ValueError("review coverage differs from stable episodes")
    for actual, expected in zip(items, expected_review_items, strict=True):
        structural = {
            key: value
            for key, value in actual.items()
            if key not in {"disposition", "musicalRationale"}
        }
        expected_structural = {
            key: value
            for key, value in expected.items()
            if key not in {"disposition", "musicalRationale"}
        }
        if structural != expected_structural:
            raise ValueError(f"review evidence differs: {expected['itemId']}")
    if require_pass:
        allowed = set(review.get("allowedDispositions", []))
        for item in items:
            disposition = item.get("disposition")
            rationale = item.get("musicalRationale")
            if (
                disposition not in allowed
                or not isinstance(rationale, str)
                or not rationale
            ):
                raise ValueError(f"incomplete disposition: {item['itemId']}")
            if disposition != "in-scope-polychord":
                raise ValueError(f"out-of-scope held display: {item['itemId']}")

    return {
        "songCount": len(pieces),
        "stableEpisodeCount": len(expected_review_items),
        "displayedMs": displayed_ms,
        "pass": require_pass,
    }


def main() -> int:
    args = parse_args()
    result = verify(args.result_directory, require_pass=args.require_pass)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

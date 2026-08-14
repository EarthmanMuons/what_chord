"""Validate the frozen automatic polychord product-suite artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import frame_replay

PRODUCT_FIXTURE_MANIFEST_SCHEMA = "polychord-product-fixture-manifest/1"
REPO_ROOT = Path(__file__).parents[2]

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    fixtures = validate_fixture_manifest(args.fixture_manifest)
    print(f"valid: {args.fixture_manifest} ({len(fixtures)} fixtures)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

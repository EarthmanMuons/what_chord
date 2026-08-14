"""Build the hash-locked prior-art baseline runtimes without suite input."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import venv
from pathlib import Path

SCHEMA = "polychord-prior-art-runtime-manifest/1"
REPO_ROOT = Path(__file__).parents[2]
SOURCE_MANIFEST_PATH = Path("research/polychord/baselines/source-manifest-v1.json")
PYTHON_WORKER_PATH = Path("tool/polychord/prior_art_python_worker.py")
SWIFT_WRAPPER_PATH = Path("tool/polychord/chordrecgen_adapter/main.swift")
BUILDER_PATH = Path(__file__).relative_to(REPO_ROOT)
BASELINE_CONTRACT_PATH = Path("research/polychord/prior-art-baseline-contract-v1.md")
REQUIRED_PYTHON = "3.12.13"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(
    command: list[str],
    *,
    cwd: Path = REPO_ROOT,
    capture_output: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        capture_output=capture_output,
        text=True,
    )


def git_output(*args: str) -> str:
    return run(["git", *args]).stdout.strip()


def canonical_json(value: object) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def _download_verified(source: dict, cache_dir: Path) -> Path:
    archive = cache_dir / source["archiveName"]
    if not archive.exists():
        with urllib.request.urlopen(source["archiveUrl"], timeout=60) as response:
            archive.write_bytes(response.read())
    actual = sha256_file(archive)
    if actual != source["archiveSha256"]:
        raise ValueError(f"archive digest mismatch for {archive.name}: {actual}")
    return archive


def _python_inventory(python: Path) -> dict:
    code = """
import importlib.metadata
import json
import platform
import sys

print(json.dumps({
    "executable": sys.executable,
    "pythonVersion": platform.python_version(),
    "platform": platform.platform(),
    "distributions": [
        {"name": item.metadata["Name"], "version": item.version}
        for item in sorted(
            importlib.metadata.distributions(),
            key=lambda value: (value.metadata["Name"] or "").lower(),
        )
    ],
}, sort_keys=True))
"""
    return json.loads(run([str(python), "-c", code]).stdout)


def _build_python_environment(
    *,
    baseline_id: str,
    source: dict,
    archive: Path,
    output_root: Path,
) -> dict:
    environment = output_root / baseline_id
    venv.EnvBuilder(clear=True, with_pip=True).create(environment)
    python = environment / "bin" / "python"
    lock_path = REPO_ROOT / source["dependencyLock"]
    dependency_command = [
        str(python),
        "-m",
        "pip",
        "install",
        "--require-hashes",
        "--disable-pip-version-check",
        "-r",
        str(lock_path),
    ]
    run(dependency_command)
    source_command = [
        str(python),
        "-m",
        "pip",
        "install",
        "--no-build-isolation",
        "--no-deps",
        "--disable-pip-version-check",
        str(archive),
    ]
    run(source_command)
    inventory = _python_inventory(python)
    installed = {
        item["name"].lower(): item["version"] for item in inventory["distributions"]
    }
    if installed.get(source["distribution"].lower()) != source["distributionVersion"]:
        raise ValueError(f"{baseline_id} installed distribution does not match pin")
    return {
        "kind": "python",
        "archivePath": str(archive),
        "archiveSha256": sha256_file(archive),
        "dependencyLock": source["dependencyLock"],
        "dependencyLockSha256": sha256_file(lock_path),
        "installCommands": [dependency_command, source_command],
        "inventory": inventory,
        "pythonPath": str(python),
    }


def _build_chordrecgen(
    *,
    source: dict,
    archive: Path,
    output_root: Path,
) -> dict:
    environment = output_root / "chordrecgen-3790a4d-swift"
    source_output = environment / "source"
    source_output.mkdir(parents=True)
    with tarfile.open(archive, "r:gz") as tar:
        tar.extractall(source_output, filter="data")
    source_root = source_output / source["sourceRoot"]
    source_paths = []
    for filename, expected_sha256 in source["sourceFiles"].items():
        path = source_root / filename
        actual_sha256 = sha256_file(path)
        if actual_sha256 != expected_sha256:
            raise ValueError(f"ChordRecGen source digest mismatch: {filename}")
        source_paths.append(path)

    executable = environment / "chordrecgen-baseline"
    compile_command = [
        "swiftc",
        *[str(path) for path in source_paths],
        str(REPO_ROOT / SWIFT_WRAPPER_PATH),
        "-o",
        str(executable),
    ]
    run(compile_command)
    return {
        "kind": "swift",
        "archivePath": str(archive),
        "archiveSha256": sha256_file(archive),
        "compileCommand": compile_command,
        "executablePath": str(executable),
        "executableSha256": sha256_file(executable),
        "sourceFiles": {path.name: sha256_file(path) for path in source_paths},
        "swiftVersion": run(["swift", "--version"]).stdout.strip(),
    }


def build(output_root: Path) -> dict:
    if platform.python_version() != REQUIRED_PYTHON:
        raise RuntimeError(
            f"requires Python {REQUIRED_PYTHON}, got {platform.python_version()}"
        )
    source_manifest = json.loads((REPO_ROOT / SOURCE_MANIFEST_PATH).read_text())
    if source_manifest["pythonRuntime"] != REQUIRED_PYTHON:
        raise ValueError("source manifest Python runtime differs")
    output_root.mkdir(parents=True, exist_ok=True)
    cache_dir = output_root / "archives"
    cache_dir.mkdir()

    runtimes = {}
    for baseline_id in (
        "musicpy-7.15-poly-chord-first",
        "python-mingus-6558cac-polychords",
    ):
        source = source_manifest["sources"][baseline_id]
        archive = _download_verified(source, cache_dir)
        runtimes[baseline_id] = _build_python_environment(
            baseline_id=baseline_id,
            source=source,
            archive=archive,
            output_root=output_root,
        )

    chordrecgen_id = "chordrecgen-3790a4d-swift"
    chordrecgen_source = source_manifest["sources"][chordrecgen_id]
    chordrecgen_archive = _download_verified(chordrecgen_source, cache_dir)
    runtimes[chordrecgen_id] = _build_chordrecgen(
        source=chordrecgen_source,
        archive=chordrecgen_archive,
        output_root=output_root,
    )

    artifacts = {
        "builder": BUILDER_PATH,
        "sourceManifest": SOURCE_MANIFEST_PATH,
        "pythonWorker": PYTHON_WORKER_PATH,
        "swiftWrapper": SWIFT_WRAPPER_PATH,
        "baselineContract": BASELINE_CONTRACT_PATH,
    }
    report = {
        "schema": SCHEMA,
        "source": {
            "command": [sys.executable, *sys.argv],
            "workingDirectory": str(Path.cwd().resolve()),
            "repositoryCommit": git_output("rev-parse", "HEAD"),
            "repositoryDirty": bool(git_output("status", "--porcelain")),
            "artifacts": {
                key: {"path": str(path), "sha256": sha256_file(REPO_ROOT / path)}
                for key, path in artifacts.items()
            },
        },
        "runtimes": runtimes,
    }
    manifest_path = output_root / "runtime-manifest-v1.json"
    manifest_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("build/polychord/prior-art-env-v1"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_root = args.output_root.resolve()
    allowed_root = (REPO_ROOT / "build/polychord").resolve()
    if output_root == allowed_root or not output_root.is_relative_to(allowed_root):
        raise ValueError("output root must be a child of build/polychord")
    if output_root.exists():
        shutil.rmtree(output_root)
    report = build(output_root)
    print(
        f"built {len(report['runtimes'])} pinned prior-art runtimes -> "
        f"{output_root / 'runtime-manifest-v1.json'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Prepare WhatKey research corpora from pinned upstream checkouts.

The generated fixture sets stay under build/ because some upstream corpora are
license-gated. By default the script prepares the Isophonics/ChoCo data needed
to rerun the README headline table. Pass --all to prepare every documented
corpus path.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from reproducibility import CANONICALIZATION, fixture_set_sha256

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ROOT = REPO_ROOT / "build/whatkey-corpora"
FIXTURE_ROOT = REPO_ROOT / "build/whatkey-fixtures"
SPLIT_VERIFY_ROOT = REPO_ROOT / "build/whatkey-splits"
HEADLINE_ROOT = REPO_ROOT / "build/whatkey-headline-test"


@dataclass(frozen=True)
class GitSource:
    name: str
    url: str
    path_name: str
    commit: str


CONTRAPUNCTUS = GitSource(
    name="contrapunctus-bench",
    url="https://github.com/Tomczik76/contrapunctus-bench",
    path_name="contrapunctus-bench",
    commit="b9e011c8cf34c5e76691dcf2c835b8c99ebd9d59",
)
WHEN_IN_ROME_COMMIT = "aa7539f1cf480997a68998405c0783ebf6339c16"
ASAP = GitSource(
    name="asap-dataset",
    url="https://github.com/fosfrancesco/asap-dataset",
    path_name="asap-dataset",
    commit="afc815c75c42e83a79c03feb6da8a35e77d4c6b8",
)
CHOCO = GitSource(
    name="choco",
    url="https://github.com/smashub/choco",
    path_name="choco",
    commit="5fe168fd55be5c84512abcfbc4e6f1b1f8f0092a",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Ignored local directory for external corpus checkouts.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Confirm external downloads and license-gated fixture preparation.",
    )
    parser.add_argument(
        "--headline",
        action="store_true",
        help="Prepare only the Isophonics/ChoCo fixtures used by the README table.",
    )
    parser.add_argument("--when-in-rome", action="store_true")
    parser.add_argument("--asap", action="store_true")
    parser.add_argument("--isophonics", action="store_true")
    parser.add_argument("--overlap", action="store_true")
    parser.add_argument(
        "--all",
        action="store_true",
        help="Prepare When-in-Rome, ASAP, Isophonics, and their overlap set.",
    )
    parser.add_argument(
        "--verify-splits",
        action="store_true",
        help="Regenerate split files under build/whatkey-splits for comparison.",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Check existing checkout pins, fixture manifests, and split counts.",
    )
    parser.add_argument(
        "--run-headline",
        action="store_true",
        help="Prepare Isophonics fixtures and rerun the README headline table.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    selected = selected_sets(args)
    if args.verify_only:
        verify_prepared_data(args, selected)
        return 0

    confirm(args, selected)
    args.root.mkdir(parents=True, exist_ok=True)

    bench_root: Path | None = None
    asap_root: Path | None = None
    choco_root: Path | None = None

    if selected["when_in_rome"] or selected["overlap"]:
        bench_root = ensure_contrapunctus(args.root)
        prepare_when_in_rome(bench_root)
        if selected["when_in_rome"]:
            extract_when_in_rome(bench_root)
            if args.verify_splits:
                verify_when_in_rome_split(bench_root)

    if selected["asap"] or selected["overlap"]:
        asap_root = ensure_checkout(args.root, ASAP)
        if selected["asap"]:
            extract_asap(asap_root)
            if args.verify_splits:
                verify_asap_split()

    if selected["isophonics"]:
        choco_root = ensure_checkout(args.root, CHOCO)
        extract_isophonics(choco_root)
        if args.verify_splits:
            verify_isophonics_split()

    if selected["overlap"]:
        if asap_root is None:
            asap_root = ensure_checkout(args.root, ASAP)
        if bench_root is None:
            bench_root = ensure_contrapunctus(args.root)
        extract_overlap(asap_root, bench_root)

    if args.run_headline:
        run_headline()

    print("WhatKey data preparation complete.")
    return 0


def verify_prepared_data(args: argparse.Namespace, selected: dict[str, bool]) -> None:
    checks = 0
    if selected["when_in_rome"] or selected["overlap"]:
        bench_root = verify_checkout(args.root, CONTRAPUNCTUS)
        actual = git_output(bench_root / "corpus/When-in-Rome", "rev-parse", "HEAD")
        require(
            actual == WHEN_IN_ROME_COMMIT,
            "When-in-Rome submodule commit",
            f"expected {WHEN_IN_ROME_COMMIT}, got {actual}",
        )
        checks += 2
        if selected["when_in_rome"]:
            verify_fixture_set(
                "when-in-rome-v1",
                REPO_ROOT / "research/whatkey/data/splits/when-in-rome-v1.json",
            )
            checks += 1

    if selected["asap"] or selected["overlap"]:
        verify_checkout(args.root, ASAP)
        checks += 1
        if selected["asap"]:
            verify_fixture_set(
                "asap-nc-v2",
                REPO_ROOT / "research/whatkey/data/splits/asap-nc-v2.json",
            )
            checks += 1

    if selected["isophonics"]:
        verify_checkout(args.root, CHOCO)
        verify_fixture_set(
            "isophonics-nc-v1",
            REPO_ROOT / "research/whatkey/data/splits/isophonics-nc-v1.json",
        )
        checks += 2

    if selected["overlap"]:
        verify_fixture_set("asap-wir-nc-v1", None)
        checks += 1

    print(f"Verified prepared WhatKey data ({checks} checks).")


def selected_sets(args: argparse.Namespace) -> dict[str, bool]:
    explicit = args.when_in_rome or args.asap or args.isophonics or args.overlap
    headline = args.headline or args.run_headline or not (explicit or args.all)
    return {
        "when_in_rome": args.all or args.when_in_rome,
        "asap": args.all or args.asap,
        "isophonics": args.all or args.isophonics or headline,
        "overlap": args.all or args.overlap,
    }


def confirm(args: argparse.Namespace, selected: dict[str, bool]) -> None:
    if args.yes:
        return
    labels = [name.replace("_", "-") for name, enabled in selected.items() if enabled]
    message = (
        "This will download pinned external corpus checkouts into "
        f"{args.root} and generate license-gated fixtures under build/. "
        f"Selected sets: {', '.join(labels)}. Continue? [y/N] "
    )
    if not sys.stdin.isatty():
        raise SystemExit(
            "Refusing to download data without --yes in a non-interactive shell."
        )
    answer = input(message).strip().lower()
    if answer not in {"y", "yes"}:
        raise SystemExit("Canceled.")


def verify_checkout(root: Path, source: GitSource) -> Path:
    path = root / source.path_name
    require((path / ".git").exists(), source.name, f"missing checkout at {path}")
    actual = git_output(path, "rev-parse", "HEAD")
    require(
        actual == source.commit, source.name, f"expected {source.commit}, got {actual}"
    )
    print(f"ok: {source.name} at {actual}")
    return path


def ensure_contrapunctus(root: Path) -> Path:
    bench_root = ensure_checkout(root, CONTRAPUNCTUS)
    run(
        [
            "git",
            "-C",
            str(bench_root),
            "submodule",
            "update",
            "--init",
            "corpus/When-in-Rome",
        ]
    )
    actual = git_output(bench_root / "corpus/When-in-Rome", "rev-parse", "HEAD")
    if actual != WHEN_IN_ROME_COMMIT:
        raise SystemExit(
            "When-in-Rome submodule pin mismatch: "
            f"expected {WHEN_IN_ROME_COMMIT}, got {actual}"
        )
    return bench_root


def ensure_checkout(root: Path, source: GitSource) -> Path:
    path = root / source.path_name
    if not (path / ".git").exists():
        run(["git", "clone", source.url, str(path)])
    else:
        print(f"{source.name}: using existing checkout at {path}")
    run(["git", "-C", str(path), "fetch", "--tags", "origin"])
    run(["git", "-C", str(path), "checkout", source.commit])
    actual = git_output(path, "rev-parse", "HEAD")
    if actual != source.commit:
        raise SystemExit(
            f"{source.name} pin mismatch: expected {source.commit}, got {actual}"
        )
    return path


def verify_fixture_set(set_name: str, split_path: Path | None) -> None:
    manifest_path = FIXTURE_ROOT / set_name / "manifest.json"
    require(
        manifest_path.exists(), set_name, f"missing fixture manifest at {manifest_path}"
    )
    manifest = json.loads(manifest_path.read_text())
    require(manifest["set"] == set_name, set_name, f"manifest set is {manifest['set']}")

    fixture_count = 0
    event_count = 0
    for entry in manifest["fixtures"]:
        fixture_path = manifest_path.parent / entry["file"]
        require(fixture_path.exists(), set_name, f"missing fixture file {fixture_path}")
        fixture_count += 1
        event_count += int(entry["events"])

    content_hash = manifest.get("contentHash")
    if content_hash is not None:
        require(
            content_hash.get("algorithm") == "sha256"
            and content_hash.get("canonicalization") == CANONICALIZATION,
            set_name,
            "manifest uses an unsupported fixture hash contract",
        )
        actual_hash = fixture_set_sha256(manifest_path.parent)
        require(
            actual_hash == content_hash.get("value"),
            set_name,
            f"fixture content hash mismatch: {actual_hash}",
        )
        print(f"ok: {set_name} content hash {actual_hash}")

    if split_path is not None:
        split = json.loads(split_path.read_text())
        counts = split["counts"]["total"]
        require(
            fixture_count == counts["pieces"],
            set_name,
            f"manifest has {fixture_count} pieces, split expects {counts['pieces']}",
        )
        require(
            event_count == counts["events"],
            set_name,
            f"manifest has {event_count} events, split expects {counts['events']}",
        )
        print(
            f"ok: {set_name} manifest matches split total "
            f"({fixture_count} pieces, {event_count} events)"
        )
    else:
        print(
            f"ok: {set_name} manifest ({fixture_count} fixtures, {event_count} events)"
        )


def prepare_when_in_rome(bench_root: Path) -> None:
    run([sys.executable, "corpus/prep/fetch_tavern_scores.py"], cwd=bench_root)


def extract_when_in_rome(bench_root: Path) -> None:
    run(
        [
            sys.executable,
            "tool/whatkey/fixture_extract.py",
            "--set",
            "when-in-rome-v1",
            "--out",
            str(FIXTURE_ROOT),
            "--analysis-profile",
            "whatKeyPaper2026",
            "when-in-rome",
            "--bench-root",
            str(bench_root),
            "--groups",
            "bach-wtc",
            "brahms-lieder",
            "schubert-lieder",
            "tavern",
        ],
        cwd=REPO_ROOT,
    )


def extract_asap(asap_root: Path) -> None:
    run(
        [
            sys.executable,
            "tool/whatkey/asap_extract.py",
            "--asap-root",
            str(asap_root),
            "--set",
            "asap-nc-v2",
            "--max-performances",
            "60",
            "--analysis-profile",
            "whatKeyPaper2026",
        ],
        cwd=REPO_ROOT,
    )


def extract_isophonics(choco_root: Path) -> None:
    run(
        [
            sys.executable,
            "tool/whatkey/isophonics_extract.py",
            "--choco-root",
            str(choco_root),
            "--set",
            "isophonics-nc-v1",
            "--analysis-profile",
            "whatKeyPaper2026",
        ],
        cwd=REPO_ROOT,
    )


def extract_overlap(asap_root: Path, bench_root: Path) -> None:
    run(
        [
            sys.executable,
            "tool/whatkey/asap_wir_extract.py",
            "--asap-root",
            str(asap_root),
            "--bench-root",
            str(bench_root),
            "--analysis-profile",
            "whatKeyPaper2026",
        ],
        cwd=REPO_ROOT,
    )


def verify_when_in_rome_split(bench_root: Path) -> None:
    SPLIT_VERIFY_ROOT.mkdir(parents=True, exist_ok=True)
    run(
        [
            sys.executable,
            "tool/whatkey/freeze_split.py",
            "--bench-root",
            str(bench_root),
            "--fixtures-manifest",
            str(FIXTURE_ROOT / "when-in-rome-v1/manifest.json"),
            "--out",
            str(SPLIT_VERIFY_ROOT / "when-in-rome-v1.json"),
        ],
        cwd=REPO_ROOT,
    )


def verify_asap_split() -> None:
    SPLIT_VERIFY_ROOT.mkdir(parents=True, exist_ok=True)
    run(
        [
            sys.executable,
            "tool/whatkey/asap_split.py",
            "--fixtures-manifest",
            str(FIXTURE_ROOT / "asap-nc-v2/manifest.json"),
            "--seed",
            "whatkey-asap-nc-v2-split-2026-07-07",
            "--out",
            str(SPLIT_VERIFY_ROOT / "asap-nc-v2.json"),
        ],
        cwd=REPO_ROOT,
    )


def verify_isophonics_split() -> None:
    SPLIT_VERIFY_ROOT.mkdir(parents=True, exist_ok=True)
    run(
        [
            sys.executable,
            "tool/whatkey/asap_split.py",
            "--fixtures-manifest",
            str(FIXTURE_ROOT / "isophonics-nc-v1/manifest.json"),
            "--seed",
            "whatkey-isophonics-nc-v1-split-2026-07-07",
            "--out",
            str(SPLIT_VERIFY_ROOT / "isophonics-nc-v1.json"),
        ],
        cwd=REPO_ROOT,
    )


def run_headline() -> None:
    claims_root = HEADLINE_ROOT / "baseline-claims"
    run(
        [
            sys.executable,
            "tool/whatkey/external_baseline.py",
            "--fixtures",
            str(FIXTURE_ROOT / "isophonics-nc-v1"),
            "--split-file",
            "research/whatkey/data/splits/isophonics-nc-v1.json",
            "--split",
            "test",
            "--out",
            str(claims_root),
        ],
        cwd=REPO_ROOT,
    )
    run(
        [
            "dart",
            "run",
            "tool/whatkey/harness.dart",
            "--fixtures",
            str(FIXTURE_ROOT / "isophonics-nc-v1"),
            "--split-file",
            "research/whatkey/data/splits/isophonics-nc-v1.json",
            "--split",
            "test",
            "--recipe",
            "whatKeyPaper2026",
            "--out",
            str(HEADLINE_ROOT / "test-iso-hmm-shipped"),
        ],
        cwd=REPO_ROOT,
    )
    for analyzer in ("temperleykostkapayne", "krumhanslschmuckler", "aardenessen"):
        run(
            [
                "dart",
                "run",
                "tool/whatkey/harness.dart",
                "--fixtures",
                str(FIXTURE_ROOT / "isophonics-nc-v1"),
                "--split-file",
                "research/whatkey/data/splits/isophonics-nc-v1.json",
                "--split",
                "test",
                "--claims-file",
                str(claims_root / f"isophonics-nc-v1-test/{analyzer}.claims.json"),
                "--out",
                str(HEADLINE_ROOT / f"test-iso-m21-{analyzer}"),
            ],
            cwd=REPO_ROOT,
        )
    run(
        [
            sys.executable,
            "tool/whatkey/headline_table.py",
            "--root",
            str(HEADLINE_ROOT),
            "--check",
        ],
        cwd=REPO_ROOT,
    )
    run(
        [
            sys.executable,
            "tool/whatkey/reproducibility.py",
            "verify",
            "--fixture",
            "isophonics-nc-v1",
            "--fixture-root",
            str(FIXTURE_ROOT),
            "--result",
            "test-iso-hmm-shipped",
            "--result",
            "test-iso-m21-temperleykostkapayne",
            "--result",
            "test-iso-m21-krumhanslschmuckler",
            "--result",
            "test-iso-m21-aardenessen",
            "--result-root",
            str(HEADLINE_ROOT),
        ],
        cwd=REPO_ROOT,
    )


def git_output(path: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(path), *args], text=True).strip()


def run(command: list[str], cwd: Path | None = None) -> None:
    print("+ " + " ".join(command))
    subprocess.run(command, cwd=cwd, check=True)


def require(condition: bool, label: str, message: str) -> None:
    if not condition:
        raise SystemExit(f"{label}: {message}")


if __name__ == "__main__":
    raise SystemExit(main())

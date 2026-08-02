#!/usr/bin/env python3
"""Render the pinned score excerpts used by the polychord review instrument."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT_DIR = ROOT / "research/polychord/review-instrument/assets"
SCHEMA = "polychord-review-presentation/1"


@dataclass(frozen=True)
class Excerpt:
    identifier: str
    source_url: str
    pdf_url: str
    pdf_sha256: str
    pdf_page: int
    printed_page: int
    score_location: str
    dpi: int
    x: int
    y: int
    width: int
    height: int
    filename: str
    alt: str


EXCERPTS = {
    "ptrouchkascn00stra": Excerpt(
        identifier="ptrouchkascn00stra",
        source_url="https://archive.org/details/ptrouchkascn00stra",
        pdf_url=(
            "https://archive.org/download/ptrouchkascn00stra/ptrouchkascn00stra.pdf"
        ),
        pdf_sha256=("8c753ed9ddc37e61d7fb1a261fd350cbe7b529d9bc957e9c2efcfab953532d64"),
        pdf_page=66,
        printed_page=64,
        score_location=("second tableau, rehearsal 49, printed page 64, PDF page 66"),
        dpi=250,
        x=38,
        y=306,
        width=900,
        height=500,
        filename="petrushka-r49.png",
        alt=(
            "Unannotated score excerpt surrounding rehearsal 49 in Stravinsky's "
            "Petrouchka."
        ),
    ),
    "lesacreduprintem00stra_3": Excerpt(
        identifier="lesacreduprintem00stra_3",
        source_url="https://archive.org/details/lesacreduprintem00stra_3",
        pdf_url=(
            "https://archive.org/download/lesacreduprintem00stra_3/"
            "lesacreduprintem00stra_3.pdf"
        ),
        pdf_sha256=("6871f14d62c39eeaa7a1482c644947870bbb30b297f0ed2b89321dad85f35495"),
        pdf_page=18,
        printed_page=16,
        score_location=(
            "Les augures printaniers, rehearsal 13, printed page 16, PDF page 18"
        ),
        dpi=200,
        x=70,
        y=35,
        width=1580,
        height=700,
        filename="augurs-r13.png",
        alt=(
            "Unannotated score excerpt surrounding rehearsal 13 in Stravinsky's "
            "Le sacre du printemps."
        ),
    ),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    return struct.unpack(">II", data[16:24])


def pdftoppm_version() -> str:
    result = subprocess.run(
        ["pdftoppm", "-v"],
        check=True,
        capture_output=True,
        text=True,
    )
    output = result.stderr.strip() or result.stdout.strip()
    return output.splitlines()[0]


def render_excerpt(source: Path, excerpt: Excerpt, output: Path) -> None:
    prefix = output.with_suffix("")
    subprocess.run(
        [
            "pdftoppm",
            "-f",
            str(excerpt.pdf_page),
            "-l",
            str(excerpt.pdf_page),
            "-r",
            str(excerpt.dpi),
            "-x",
            str(excerpt.x),
            "-y",
            str(excerpt.y),
            "-W",
            str(excerpt.width),
            "-H",
            str(excerpt.height),
            "-png",
            "-singlefile",
            str(source),
            str(prefix),
        ],
        check=True,
    )


def install_if_unchanged_or_missing(generated: Path, destination: Path) -> None:
    if destination.exists():
        assert destination.read_bytes() == generated.read_bytes(), (
            f"generated output differs from {destination}; change the render recipe "
            "and provenance record explicitly"
        )
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(generated, destination)


def build_manifest(
    rendered: dict[str, Path], *, poppler_version: str
) -> dict[str, object]:
    entries = {}
    for identifier, path in rendered.items():
        excerpt = EXCERPTS[identifier]
        width, height = png_dimensions(path)
        entries[identifier] = {
            "source": {
                "sourceIdentifier": excerpt.identifier,
                "sourceUrl": excerpt.source_url,
                "pdfUrl": excerpt.pdf_url,
                "pdfSha256": excerpt.pdf_sha256,
                "pdfPage": excerpt.pdf_page,
                "printedPage": excerpt.printed_page,
                "scoreLocation": excerpt.score_location,
            },
            "render": {
                "tool": "pdftoppm",
                "version": poppler_version,
                "dpi": excerpt.dpi,
                "cropPixels": {
                    "x": excerpt.x,
                    "y": excerpt.y,
                    "width": excerpt.width,
                    "height": excerpt.height,
                },
            },
            "asset": {
                "file": excerpt.filename,
                "sha256": sha256(path),
                "width": width,
                "height": height,
                "alt": excerpt.alt,
            },
        }
    return {"schema": SCHEMA, "scoreExcerpts": entries}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--petrushka-pdf", required=True, type=Path)
    parser.add_argument("--augurs-pdf", required=True, type=Path)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    sources = {
        "ptrouchkascn00stra": args.petrushka_pdf,
        "lesacreduprintem00stra_3": args.augurs_pdf,
    }
    for identifier, source in sources.items():
        assert source.is_file(), source
        assert sha256(source) == EXCERPTS[identifier].pdf_sha256, source

    with tempfile.TemporaryDirectory(prefix="polychord-score-excerpts-") as temp:
        temp_dir = Path(temp)
        rendered = {}
        for identifier, source in sources.items():
            excerpt = EXCERPTS[identifier]
            output = temp_dir / excerpt.filename
            render_excerpt(source, excerpt, output)
            rendered[identifier] = output

        manifest = build_manifest(rendered, poppler_version=pdftoppm_version())
        manifest_path = temp_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

        for identifier, generated in rendered.items():
            destination = args.out_dir / EXCERPTS[identifier].filename
            install_if_unchanged_or_missing(generated, destination)
        install_if_unchanged_or_missing(manifest_path, args.out_dir / "manifest.json")

    print(f"valid: {args.out_dir}")


if __name__ == "__main__":
    main()

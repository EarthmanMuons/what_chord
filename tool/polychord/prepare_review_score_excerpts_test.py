"""Unit tests for the pinned polychord score-excerpt recipe."""

from __future__ import annotations

import struct
import tempfile
import unittest
from pathlib import Path

import prepare_review_score_excerpts as subject


def png_header(width: int, height: int) -> bytes:
    return (
        b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", width, height)
    )


class PrepareReviewScoreExcerptsTest(unittest.TestCase):
    def test_manifest_carries_source_render_and_asset_pins(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            rendered = {}
            for index, (identifier, excerpt) in enumerate(
                subject.EXCERPTS.items(), start=1
            ):
                path = directory / excerpt.filename
                path.write_bytes(png_header(index * 100, index * 200))
                rendered[identifier] = path

            manifest = subject.build_manifest(
                rendered, poppler_version="pdftoppm test version"
            )

        self.assertEqual(manifest["schema"], subject.SCHEMA)
        for identifier, excerpt in subject.EXCERPTS.items():
            with self.subTest(identifier=identifier):
                entry = manifest["scoreExcerpts"][identifier]
                self.assertEqual(entry["source"]["sourceIdentifier"], identifier)
                self.assertEqual(entry["source"]["pdfSha256"], excerpt.pdf_sha256)
                self.assertEqual(entry["source"]["pdfPage"], excerpt.pdf_page)
                self.assertEqual(entry["render"]["version"], "pdftoppm test version")
                self.assertEqual(entry["asset"]["file"], excerpt.filename)

    def test_existing_different_output_is_never_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            generated = directory / "generated.png"
            destination = directory / "destination.png"
            generated.write_bytes(b"new result")
            destination.write_bytes(b"pinned result")

            with self.assertRaises(AssertionError):
                subject.install_if_unchanged_or_missing(generated, destination)

            self.assertEqual(destination.read_bytes(), b"pinned result")


if __name__ == "__main__":
    unittest.main()

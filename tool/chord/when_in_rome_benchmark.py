#!/usr/bin/env python3
"""Benchmark WhatChord's isolated-voicing decisions on When-in-Rome events.

This intentionally does not score Roman numerals. Contrapunctus performs
contextual Roman-numeral analysis over complete scores; WhatChord names the
currently sounding voicing. The most comparable slice is therefore whether
WhatChord finds the analyst-annotated chord root and bass on events whose
sounding pitch classes exactly match the annotation.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import unquote, urlparse

from music21 import chord, converter, roman

CONTRAPUNCTUS_BENCH_URL = "https://github.com/Tomczik76/contrapunctus-bench"
SYMMETRIC_FAMILIES = {
    "augmented triad",
    "diminished seventh chord",
}
PC_NAMES = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "bench_root",
        type=Path,
        help="Checkout of contrapunctus-bench with its When-in-Rome submodule.",
    )
    parser.add_argument(
        "--max-pieces",
        type=int,
        default=0,
        help="Maximum common-subset pieces to inspect; 0 means all available.",
    )
    parser.add_argument(
        "--groups",
        nargs="+",
        help="Only inspect these manifest group IDs.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("build/when-in-rome-chord-benchmark"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    bench_root = args.bench_root.resolve()
    sys.path.insert(0, str(bench_root / "harness"))
    import music21_comparison as cbench  # type: ignore[import-not-found]

    manifest = json.loads((bench_root / "corpus/manifest.json").read_text())
    pieces = [
        piece
        for piece in manifest["pieces"]
        if piece["in_common_subset"]
        and (not args.groups or piece["genre"] in args.groups)
    ]
    if args.max_pieces:
        pieces = pieces[: args.max_pieces]

    events = []
    piece_counts = Counter()
    for piece in pieces:
        loaded = load_piece(bench_root, piece, cbench)
        if loaded is None:
            continue
        piece_events = loaded
        events.extend(piece_events)
        piece_counts[piece["genre"]] += 1
        print(
            f"{piece['id']}: {len(piece_events)} aligned chord events",
            file=sys.stderr,
        )

    predictions = analyze(events)
    rows = score(events, predictions)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "summary.json").write_text(
        json.dumps(
            build_summary(rows, piece_counts, bench_root),
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    write_csv(args.out_dir / "events.csv", rows)
    write_report(args.out_dir / "report.txt", rows, piece_counts)
    print_report(rows, piece_counts)
    return 0


def load_piece(bench_root: Path, piece: dict, cbench) -> list[dict] | None:
    corpus_root = bench_root / "corpus/When-in-Rome/Corpus"
    source_path = unquote(urlparse(piece["source_url"]).path)
    marker = "/Corpus/"
    if marker not in source_path:
        return None
    relative_path = Path(source_path.split(marker, 1)[1])
    piece_dir = corpus_root / relative_path
    local_dir = bench_root / "corpus/scores-local" / relative_path
    score_path = first_existing(
        local_dir / "score_kern.mxl",
        piece_dir / "score.mxl",
        local_dir / "score.mxl",
    )
    analysis_path = first_existing(
        piece_dir / "analysis.txt",
        local_dir / "analysis.txt",
    )
    if score_path is None or analysis_path is None:
        return None

    try:
        score = converter.parse(score_path)
    except Exception as error:  # noqa: BLE001
        score = parse_without_harmony(score_path)
        if score is None:
            print(f"{piece['id']}: score parse failed: {error}", file=sys.stderr)
            return None

    score_flat = score.flatten()
    spans, first_measure = cbench.build_measure_spans(score)
    out = []
    for index, (measure, beat, key, figure, time_sig) in enumerate(
        cbench.parse_rntxt(analysis_path)
    ):
        offset = cbench.rntxt_offset(measure, beat, time_sig, spans, first_measure)
        if offset is None:
            continue
        pitches = cbench.get_sounding_notes(score_flat, offset)
        if len(pitches) < 3:
            continue
        try:
            expected = roman.RomanNumeral(figure, cbench.make_m21_key(*key))
        except Exception:  # noqa: BLE001, S112
            continue

        sounding = chord.Chord(pitches)
        sounding_pcs = {pitch.pitchClass for pitch in pitches}
        if len(sounding_pcs) < 3:
            continue
        expected_pcs = {pitch.pitchClass for pitch in expected.pitches}
        bass_pc = min(pitches, key=lambda pitch: pitch.midi).pitchClass
        expected_root = expected.root()
        if expected_root is None:
            continue
        out.append(
            {
                "id": f"{piece['id']}:{index}",
                "piece": piece["id"],
                "group": piece["genre"],
                "measure": measure,
                "beat": beat,
                "offset": float(offset),
                "figure": figure,
                "key": key_to_wire(key),
                "pcMask": mask(sounding_pcs),
                "bassPc": bass_pc,
                "noteCount": len(pitches),
                "midiNotes": " ".join(str(pitch.midi) for pitch in sorted(pitches)),
                "expectedRootPc": expected_root.pitchClass,
                "expectedBassPc": expected.bass().pitchClass,
                "clean": sounding_pcs == expected_pcs,
                "soundingCommonName": sounding.commonName,
                "expectedCommonName": expected.commonName,
            }
        )
    return out


def first_existing(*paths: Path) -> Path | None:
    return next((path for path in paths if path.exists()), None)


def parse_without_harmony(score_path: Path):
    try:
        with zipfile.ZipFile(score_path) as archive:
            xml_name = next(
                name
                for name in archive.namelist()
                if name.endswith(".xml") and not name.startswith("META-INF")
            )
            xml = archive.read(xml_name).decode("utf-8")
        stripped = re.sub(r"<harmony[^>]*>.*?</harmony>", "", xml, flags=re.DOTALL)
        with tempfile.NamedTemporaryFile(
            suffix=".xml", mode="w", encoding="utf-8"
        ) as handle:
            handle.write(stripped)
            handle.flush()
            return converter.parse(handle.name)
    except Exception:  # noqa: BLE001
        return None


def analyze(events: list[dict]) -> dict[str, dict]:
    payload = "".join(
        json.dumps(
            {
                key: event[key]
                for key in (
                    "id",
                    "key",
                    "pcMask",
                    "bassPc",
                    "noteCount",
                    "expectedRootPc",
                )
            }
        )
        + "\n"
        for event in events
    )
    process = subprocess.run(
        ["dart", "run", "tool/chord/when_in_rome_batch.dart"],
        input=payload,
        capture_output=True,
        text=True,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr)
    predictions = {
        result["id"]: result
        for line in process.stdout.splitlines()
        if (result := json.loads(line))
    }
    return predictions


def score(events: list[dict], predictions: dict[str, dict]) -> list[dict]:
    rows = []
    for event in events:
        prediction = predictions[event["id"]]
        candidates = prediction["candidates"]
        top = candidates[0] if candidates else {}
        top_three_roots = {candidate["rootPc"] for candidate in candidates}
        candidate_roots = [candidate["rootPc"] for candidate in candidates]
        expected_root_alternative = prediction["expectedRootAlternative"]
        rows.append(
            {
                **event,
                "predictedRootPc": top.get("rootPc"),
                "predictedQuality": top.get("quality"),
                "candidateRoots": " ".join(str(root) for root in candidate_roots),
                "candidateSummaries": " | ".join(
                    f"{candidate['rootPc']}:{candidate['quality']}"
                    for candidate in candidates
                ),
                "expectedRootGenerated": prediction["expectedRootGenerated"],
                "expectedRootRank": prediction["expectedRootRank"],
                "rootExact": top.get("rootPc") == event["expectedRootPc"],
                "rootTop3": event["expectedRootPc"] in top_three_roots,
                "rootAlternative": expected_root_alternative,
                "rootVisible": (
                    top.get("rootPc") == event["expectedRootPc"]
                    or expected_root_alternative
                ),
                "bassMatchesAnnotation": event["bassPc"] == event["expectedBassPc"],
                "rootAndAnnotationBassExact": (
                    top.get("rootPc") == event["expectedRootPc"]
                    and event["bassPc"] == event["expectedBassPc"]
                ),
                "reviewFlag": review_flag(event, candidates, prediction),
            }
        )
    return rows


def review_flag(event: dict, candidates: list[dict], prediction: dict) -> str:
    if not event["clean"]:
        return "contextual-or-noisy"
    if not prediction["expectedRootGenerated"] and not (
        event["pcMask"] & (1 << event["expectedRootPc"])
    ):
        return "rootless-annotation"
    if "augmented sixth chord" in event["expectedCommonName"]:
        return "functional-label"
    if is_explicit_or_incomplete_annotation(event):
        return "explicit-or-incomplete-label"
    if event["expectedCommonName"] in SYMMETRIC_FAMILIES:
        return "symmetric-root"
    if candidates and candidates[0]["rootPc"] == event["expectedRootPc"]:
        if event["bassPc"] != event["expectedBassPc"]:
            return "annotation-bass-difference"
        return "agree"
    if prediction["expectedRootAlternative"]:
        return "visible-ranking-divergence"
    if prediction["expectedRootGenerated"]:
        return "hidden-ranking-divergence"
    return "candidate-gap"


def is_explicit_or_incomplete_annotation(event: dict) -> bool:
    common_name = event["expectedCommonName"]
    return (
        "[" in event["figure"]
        or common_name.startswith(("incomplete ", "enharmonic equivalent "))
        or any(
            token in common_name
            for token in ("tetrachord", "pentachord", "tetramirror")
        )
    )


def build_summary(rows: list[dict], piece_counts: Counter, bench_root: Path) -> dict:
    return {
        "source": CONTRAPUNCTUS_BENCH_URL,
        "bench_root": str(bench_root),
        "pieces_by_group": dict(piece_counts),
        "all_events": metrics(rows),
        "clean_events": metrics([row for row in rows if row["clean"]]),
        "clean_events_with_annotated_bass": metrics(
            [row for row in rows if row["clean"] and row["bassMatchesAnnotation"]]
        ),
        "groups": {
            group: {
                "all_events": metrics(group_rows),
                "clean_events": metrics([row for row in group_rows if row["clean"]]),
            }
            for group, group_rows in grouped(rows).items()
        },
    }


def metrics(rows: list[dict]) -> dict:
    total = len(rows)
    return {
        "events": total,
        "root_exact": ratio(rows, "rootExact"),
        "root_visible": ratio(rows, "rootVisible"),
        "root_top3": ratio(rows, "rootTop3"),
        "root_alternative": ratio(rows, "rootAlternative"),
        "root_and_annotation_bass_exact": ratio(rows, "rootAndAnnotationBassExact"),
    }


def ratio(rows: list[dict], key: str) -> float | None:
    if not rows:
        return None
    return round(100 * sum(bool(row[key]) for row in rows) / len(rows), 2)


def grouped(rows: list[dict]) -> dict[str, list[dict]]:
    out = defaultdict(list)
    for row in rows:
        out[row["group"]].append(row)
    return dict(out)


def print_report(rows: list[dict], piece_counts: Counter) -> None:
    print(f"Pieces: {sum(piece_counts.values())} {dict(piece_counts)}")
    for label, selected in (
        ("All aligned events", rows),
        ("Clean pitch-set events", [row for row in rows if row["clean"]]),
        (
            "Clean events with annotated bass",
            [row for row in rows if row["clean"] and row["bassMatchesAnnotation"]],
        ),
    ):
        result = metrics(selected)
        print(
            f"{label}: n={result['events']} "
            f"root exact={result['root_exact']}% "
            f"root+annotation bass={result['root_and_annotation_bass_exact']}% "
            f"visible={result['root_visible']}% "
            f"alternative={result['root_alternative']}% "
            f"top3 legacy={result['root_top3']}%"
        )


def write_csv(path: Path, rows: list[dict]) -> None:
    import csv

    if not rows:
        return
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, rows: list[dict], piece_counts: Counter) -> None:
    clean = [row for row in rows if row["clean"]]
    counts = Counter(row["reviewFlag"] for row in rows)
    lines = [
        "WhatChord When-in-Rome Chord Benchmark",
        "=======================================",
        "",
        f"Pieces: {sum(piece_counts.values())} {dict(piece_counts)}",
        f"Events: {len(rows)} aligned, {len(clean)} clean pitch-set",
        "",
        "Review flags",
        "------------",
    ]
    for flag in (
        "candidate-gap",
        "rootless-annotation",
        "hidden-ranking-divergence",
        "visible-ranking-divergence",
        "annotation-bass-difference",
        "symmetric-root",
        "functional-label",
        "explicit-or-incomplete-label",
        "agree",
        "contextual-or-noisy",
    ):
        lines.append(f"{flag.ljust(32)} {counts[flag]}")

    lines.extend(
        [
            "",
            "Review order",
            "------------",
            "1. Candidate gaps: analyst root is absent from WhatChord's candidate list.",
            "2. Rootless annotations: analyst root is absent from the sounding voicing by design.",
            "3. Hidden ranking divergences: analyst root exists but the app does not surface it.",
            "4. Visible ranking divergences: analyst root is an alternative.",
            "5. Annotation bass differences: root agrees, score bass and annotation inversion do not.",
            "6. Symmetric, functional, and explicit-label cases: classify, but do not optimize against blindly.",
            "",
        ]
    )
    for flag, title in (
        ("candidate-gap", "Candidate Gaps"),
        ("rootless-annotation", "Rootless Annotations"),
        ("hidden-ranking-divergence", "Hidden Ranking Divergences"),
        ("visible-ranking-divergence", "Visible Ranking Divergences"),
        ("annotation-bass-difference", "Annotation Bass Differences"),
        ("symmetric-root", "Symmetric Root Cases"),
        ("functional-label", "Functional Labels"),
        ("explicit-or-incomplete-label", "Explicit Or Incomplete Labels"),
    ):
        lines.extend(report_section(rows, flag, title))

    path.write_text("\n".join(lines).rstrip() + "\n")


def report_section(rows: list[dict], flag: str, title: str) -> list[str]:
    selected = [row for row in rows if row["reviewFlag"] == flag]
    grouped_cases: dict[tuple, list[dict]] = defaultdict(list)
    for row in selected:
        grouped_cases[
            (
                row["key"],
                row["pcMask"],
                row["bassPc"],
                row["noteCount"],
                row["expectedRootPc"],
                row["expectedBassPc"],
                row["expectedCommonName"],
                row["predictedRootPc"],
                row["predictedQuality"],
                row["candidateRoots"],
                row["candidateSummaries"],
            )
        ].append(row)

    out = [title, "-" * len(title)]
    if not grouped_cases:
        return [*out, "<none>", ""]

    ordered = sorted(
        grouped_cases.values(),
        key=lambda case_rows: (-len(case_rows), case_rows[0]["id"]),
    )
    for case_rows in ordered:
        row = case_rows[0]
        figures = ", ".join(
            figure
            for figure, _ in Counter(item["figure"] for item in case_rows).most_common(
                3
            )
        )
        locations = ", ".join(
            f"{item['piece']} m{item['measure']} b{item['beat']:g}"
            for item in case_rows[:3]
        )
        predicted = (
            f"{pc_name(row['predictedRootPc'])} {row['predictedQuality']}"
            if row["predictedRootPc"] is not None
            else "<none>"
        )
        candidates = ", ".join(
            f"{pc_name(root)} {quality}"
            for root, quality in (
                summary.split(":", 1)
                for summary in row["candidateSummaries"].split(" | ")
            )
        )
        out.extend(
            [
                (
                    f"[{len(case_rows)} occurrence{'s' if len(case_rows) != 1 else ''}] "
                    f"{row['expectedCommonName']} / figures: {figures}"
                ),
                f"  expected root: {pc_name(row['expectedRootPc'])}  chosen: {predicted}",
                f"  score bass: {pc_name(row['bassPc'])}  annotation bass: {pc_name(row['expectedBassPc'])}",
                f"  top candidates: {candidates}",
                f"  samples: {locations}",
                f"  command: {debug_command(row)}",
                "",
            ]
        )
    return out


def debug_command(row: dict) -> str:
    return f"bin/chord-debug {row['midiNotes']} --key={row['key']} --top=8 --verbose"


def pc_name(pc: int | str | None) -> str:
    if pc is None:
        return "?"
    return PC_NAMES[int(pc) % 12]


def key_to_wire(key: tuple[str, str, str]) -> str:
    letter, accidental, mode = key
    wire = f"{letter}{accidental}:{'min' if mode == 'minor' else 'maj'}"
    return {
        "Cb:min": "B:min",
        "Db:min": "C#:min",
        "D#:maj": "Eb:maj",
        "E#:maj": "F:maj",
        "Fb:min": "E:min",
        "Gb:min": "F#:min",
        "G#:maj": "Ab:maj",
        "A#:maj": "Bb:maj",
        "B#:maj": "C:maj",
    }.get(wire, wire)


def mask(pitch_classes: set[int]) -> int:
    return sum(1 << pitch_class for pitch_class in pitch_classes)


if __name__ == "__main__":
    raise SystemExit(main())

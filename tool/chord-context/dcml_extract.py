"""DCML distant-listening fixtures for the chord-context initiative.

Reads the corpus's concatenated Frictionless datapackage TSVs (expanded
harmonies + notes), converts each harmony span into a fixture event with
sounding notes and an expected identity derived from the annotation
standard's decomposed columns (chord_type, root, bass_note, chord_tones) by
line-of-fifths arithmetic only; no naming interpreter is involved. Emits a
whatkey-format fixture set (candidates attached under the neutral context)
plus a chord-context labels sidecar, for the pieces in the frozen split
(both splits are generated; the harness gates usage by split).

Ground-truth caveats encoded here:
- Rows with a non-empty `changes` field (suspensions, alterations) or whose
  chord_tones disagree with chord_type describe the functional chord, not
  the literal sonority; they are categorized explicit-or-incomplete.
- `Ger`/`It`/`Fr` chord types are functional-label; `o7`/`+` symmetric-root.
- Rows in first endings (empty quarterbeats) are skipped and counted.

The corpus is CC BY-NC-SA 4.0: output stays under build/ and is never
committed.

Usage:
  python tool/chord-context/dcml_extract.py \
    --data-root /private/tmp/dlc-data \
    --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
    --view span \
    --out build/chord-context/fixtures
"""

from __future__ import annotations

import argparse
import bisect
import csv
import json
import subprocess
import sys
from collections import Counter, defaultdict
from fractions import Fraction
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from labels_common import MASKS_BY_NAME, classify_figure

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SCHEMA = "whatkey-fixture/1"
MANIFEST_SCHEMA = "whatkey-manifest/1"
LABELS_SCHEMA = "chord-context-labels/1"
QB_MS = 500
# Chord-context studies the app's live naming, so candidates use the current
# production ranking. fixture_batch requires this to be explicit; if this
# initiative ever needs a frozen set, pin a paper profile here instead.
ANALYSIS_PROFILE = "current"

CHORD_TYPE_QUALITY = {
    "M": "major",
    "m": "minor",
    "o": "diminished",
    "+": "augmented",
    "Mm7": "dominant7",
    "mm7": "minor7",
    "MM7": "major7",
    "mM7": "minorMajor7",
    "o7": "diminished7",
    "%7": "halfDiminished7",
    "+7": "dominant7Sharp5",
    "+M7": "major7Sharp5",
}
FUNCTIONAL_TYPES = {"Ger", "It", "Fr"}
SYMMETRIC_TYPES = {"o7", "+"}

LETTER_TPC = {"F": -1, "C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5}
DEGREE_FIFTHS = {
    False: {1: 0, 2: 2, 3: 4, 4: -1, 5: 1, 6: 3, 7: 5},  # major
    True: {1: 0, 2: 2, 3: -3, 4: -1, 5: 1, 6: -4, 7: -2},  # natural minor
}
ROMAN_DEGREE = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7}


def tpc_to_pc(tpc: int) -> int:
    return (tpc * 7) % 12


def tpc_to_name(tpc: int) -> str:
    letter = "FCGDAEB"[(tpc + 1) % 7]
    accidentals = (tpc + 1) // 7
    return letter + ("#" * accidentals if accidentals > 0 else "b" * -accidentals)


# Wire tonic names keep the annotation's true spelling when it is a plain or
# single-accidental name the harness's parseTonality accepts (both sides of
# the 15 key signatures are supported, so G# minor stays G#, not Ab). Remote
# spellings with double accidentals (Bbb) fall back to the 12-entry pc table
# whatkey's KeyLabel uses; identity scoring compares tonic pc + mode only,
# and spelling scoring needs the true side wherever it exists.
_WIRE_TONIC_NAMES = [
    "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B",
]  # fmt: skip


def tpc_to_wire_tonic(tpc: int) -> str:
    name = tpc_to_name(tpc)
    if len(name) <= 2:
        return name
    return _WIRE_TONIC_NAMES[tpc_to_pc(tpc)]


def key_name_tpc(name: str) -> int:
    letter = name[0].upper()
    tpc = LETTER_TPC[letter]
    for accidental in name[1:]:
        if accidental == "#":
            tpc += 7
        elif accidental == "b":
            tpc -= 7
        else:
            raise ValueError(f"bad key name {name!r}")
    return tpc


def localkey_offset(numeral: str, global_minor: bool) -> int:
    """Fifths offset of the local tonic from the global tonic.

    Applied chains (V/V) resolve right to left; each component's degree is
    read in the mode of the key it is relative to, and its own case sets the
    mode for the next component leftward.
    """
    offset = 0
    minor = global_minor
    for component in reversed(numeral.split("/")):
        accidentals = 0
        body = component
        while body and body[0] in "#b":
            accidentals += 7 if body[0] == "#" else -7
            body = body[1:]
        degree = ROMAN_DEGREE.get(body.lower())
        if degree is None:
            raise ValueError(f"bad localkey numeral {numeral!r}")
        offset += DEGREE_FIFTHS[minor][degree] + accidentals
        minor = body.islower()
    return offset


def parse_bool(raw: str) -> bool:
    if raw in ("1", "True", "true"):
        return True
    if raw in ("0", "False", "false", ""):
        return False
    raise ValueError(f"bad boolean {raw!r}")


def parse_fraction(raw: str) -> Fraction | None:
    if raw in ("", "NA"):
        return None
    return Fraction(raw)


def parse_tones(raw: str) -> list[int]:
    if not raw:
        return []
    return [int(token) for token in raw.replace("(", "").replace(")", "").split(",")]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--split-file", type=Path, required=True)
    parser.add_argument("--view", choices=["span", "instant"], default="span")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--labels-out", type=Path, default=REPO_ROOT / "build/chord-context/labels"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    split = json.loads(args.split_file.read_text())
    set_name = f"{split['set']}-{args.view}"
    selected = {
        piece["id"]
        for side in ("development", "test")
        for piece in split["splits"][side]
    }

    harmonies, skipped_harmony_rows = load_rows(
        args.data_root / "distant_listening_corpus.expanded.tsv",
        selected,
        harmony_fields,
    )
    notes, skipped_note_rows = load_rows(
        args.data_root / "distant_listening_corpus.notes.tsv",
        selected,
        note_fields,
    )
    missing = selected - harmonies.keys()
    if missing:
        raise RuntimeError(f"split pieces missing from data: {sorted(missing)[:5]}")

    stats = Counter()
    stats["skippedFirstEndingHarmonyRows"] = skipped_harmony_rows
    stats["skippedFirstEndingNoteRows"] = skipped_note_rows
    categories = Counter()
    fixtures = []
    labeled_pieces = {}
    for piece_id in sorted(selected):
        fixture, labeled = build_piece(
            piece_id,
            harmonies[piece_id],
            notes.get(piece_id, []),
            set_name,
            args.view,
            stats,
        )
        fixtures.append(fixture)
        labeled_pieces[fixture["id"]] = labeled
        for entry in labeled:
            categories[entry["category"]] += 1

    attach_candidates(fixtures, "C:maj")

    out_dir = args.out / set_name
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_fixtures = []
    for fixture in fixtures:
        file_name = f"{fixture['title'].replace('/', '-')}.json"
        (out_dir / file_name).write_text(
            json.dumps(fixture, indent=1, sort_keys=True) + "\n"
        )
        manifest_fixtures.append(
            {
                "id": fixture["id"],
                "file": file_name,
                "title": fixture["title"],
                "events": len(fixture["events"]),
            }
        )
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "set": set_name,
        "context": "C:maj",
        "view": args.view,
        "qbMs": QB_MS,
        "generator": {
            "script": "tool/chord-context/dcml_extract.py",
            "arguments": sys.argv[1:],
        },
        "source": {
            "type": split["source"]["type"],
            "corpusRepository": split["source"]["corpusRepository"],
            "corpusCommit": split["source"]["corpusCommit"],
            "corpusTag": split["source"]["corpusTag"],
            "zenodoDoi": split["source"]["zenodoDoi"],
            "dataFile": "distant_listening_corpus.zip (datapackage TSVs)",
            "license": "CC BY-NC-SA 4.0; build-only, never committed",
        },
        "fixtures": manifest_fixtures,
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=1, sort_keys=True) + "\n"
    )

    args.labels_out.mkdir(parents=True, exist_ok=True)
    labels_path = args.labels_out / f"{set_name}.labels.json"
    labels_path.write_text(
        json.dumps(
            {
                "schema": LABELS_SCHEMA,
                "set": set_name,
                "fixtures": str(out_dir),
                "pieces": labeled_pieces,
            },
            indent=1,
            sort_keys=True,
        )
        + "\n"
    )

    total = sum(categories.values())
    print(f"{set_name}: {total} events across {len(fixtures)} pieces")
    for category, count in categories.most_common():
        print(f"  {category}: {count} ({count / total:.1%})")
    for key in sorted(stats):
        print(f"  [{key}] {stats[key]}")
    return 0


def harmony_fields(row: dict) -> tuple | None:
    qb = parse_fraction(row["quarterbeats"])
    dur = parse_fraction(row["duration_qb"])
    if qb is None or dur is None:
        return None
    return (
        qb,
        dur,
        row["chord"],
        row["chord_type"],
        row["root"],
        row["bass_note"],
        row["chord_tones"],
        row["added_tones"],
        row["changes"],
        row["globalkey"],
        parse_bool(row["globalkey_is_minor"]),
        row["localkey"],
        parse_bool(row["localkey_is_minor"]),
    )


def note_fields(row: dict) -> tuple | None:
    qb = parse_fraction(row["quarterbeats"])
    dur = parse_fraction(row["duration_qb"])
    if qb is None or dur is None:
        return None
    return (qb, dur, int(row["midi"]), int(row["tpc"]))


def load_rows(path: Path, selected: set[str], extract) -> tuple[dict, int]:
    csv.field_size_limit(10**7)
    by_piece: dict[str, list] = defaultdict(list)
    skipped = 0
    with path.open() as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            piece_id = f"{row['corpus']}/{row['piece']}"
            if piece_id not in selected:
                continue
            fields = extract(row)
            if fields is None:
                skipped += 1
                continue
            by_piece[piece_id].append(fields)
    return by_piece, skipped


def build_piece(
    piece_id: str,
    harmony_rows: list,
    note_rows: list,
    set_name: str,
    view: str,
    stats: Counter,
) -> tuple[dict, list]:
    harmony_rows.sort(key=lambda row: row[0])
    note_rows.sort(key=lambda row: row[0])
    span_starts = [row[0] for row in harmony_rows]
    span_notes: list[set[int]] = [set() for _ in harmony_rows]
    # Score-spelling ground truth: pitch class -> set of tpc spellings the
    # score uses for it within the span (DCML tpc: line of fifths, 0 = C).
    span_tpcs: list[dict[int, set[int]]] = [{} for _ in harmony_rows]
    for onset, dur, midi, tpc in note_rows:
        index = bisect.bisect_right(span_starts, onset) - 1
        index = max(index, 0)
        off = onset + dur
        while index < len(harmony_rows):
            start = harmony_rows[index][0]
            end = start + harmony_rows[index][1]
            if start >= off:
                break
            if onset < end and (view == "span" or onset <= start < off):
                span_notes[index].add(midi)
                span_tpcs[index].setdefault(midi % 12, set()).add(tpc)
            index += 1

    events = []
    labeled = []
    prev_chord = None
    for index, row in enumerate(harmony_rows):
        (qb, dur, chord, *_rest) = row
        midi_notes = sorted(span_notes[index])
        if not midi_notes:
            stats["skippedEmptySpans"] += 1
            prev_chord = chord or prev_chord
            continue
        entry = label_row(row, midi_notes, prev_chord, stats)
        entry["index"] = len(events)
        entry["spelling"] = {
            str(pc): sorted(tpcs) for pc, tpcs in sorted(span_tpcs[index].items())
        }
        labeled.append(entry)
        events.append(
            {
                "index": len(events),
                "timestampMs": round(float(qb) * QB_MS),
                "durationMs": round(float(dur) * QB_MS),
                "midiNotes": midi_notes,
                "pcMask": sum(1 << pc for pc in {note % 12 for note in midi_notes}),
                "bassPc": midi_notes[0] % 12,
                "noteCount": len(midi_notes),
                "labels": {
                    "localKey": entry["localKey"],
                    **({"figure": chord} if chord else {}),
                },
            }
        )
        prev_chord = chord or prev_chord
    fixture = {
        "schema": FIXTURE_SCHEMA,
        "id": f"{set_name}/{piece_id.replace('/', '-')}",
        "title": piece_id,
        "labels": {"group": piece_id.split("/")[0]},
        "provenance": {"corpus": piece_id.split("/")[0]},
        "events": events,
    }
    return fixture, labeled


def label_row(row, midi_notes: list[int], prev_chord, stats: Counter) -> dict:
    (
        _qb,
        _dur,
        chord,
        chord_type,
        root_raw,
        bass_raw,
        tones_raw,
        added_raw,
        changes,
        globalkey,
        gk_minor,
        localkey,
        lk_minor,
    ) = row
    entry: dict = {"figure": chord or None, "prevClass": classify_figure(prev_chord)}
    if gk_minor != globalkey[0].islower():
        stats["globalkeyModeDisagreements"] += 1
    try:
        global_tpc = key_name_tpc(globalkey)
        local_tpc = global_tpc + localkey_offset(localkey, gk_minor)
    except ValueError as exc:
        entry["localKey"] = None
        entry["category"] = "unrealized"
        entry["reason"] = str(exc)
        return entry
    entry["localKey"] = f"{tpc_to_wire_tonic(local_tpc)}:{'min' if lk_minor else 'maj'}"

    if not chord or chord == "@none":
        entry["category"] = "unlabeled"
        return entry

    try:
        root_pc = tpc_to_pc(local_tpc + int(root_raw))
        bass_pc = tpc_to_pc(local_tpc + int(bass_raw))
        tone_tpcs = parse_tones(tones_raw)
        added_tpcs = parse_tones(added_raw)
    except ValueError as exc:
        entry["category"] = "unrealized"
        entry["reason"] = f"bad decomposed columns: {exc}"
        return entry
    expected_pcs = {tpc_to_pc(local_tpc + tpc) for tpc in tone_tpcs + added_tpcs}
    quality = CHORD_TYPE_QUALITY.get(chord_type)
    entry["expected"] = {
        "rootPc": root_pc,
        "bassPc": bass_pc,
        "pcs": sorted(expected_pcs),
        "quality": quality,
        "commonName": chord_type,
    }

    core_intervals = frozenset(
        (tpc_to_pc(local_tpc + tpc) - root_pc) % 12 for tpc in tone_tpcs
    )
    consistent = quality is not None and (
        core_intervals <= MASKS_BY_NAME[quality]
        and MASKS_BY_NAME[quality] - core_intervals <= {7}
    )
    if quality is not None and not consistent:
        stats["tonesVsTypeDisagreements"] += 1

    sounding = {note % 12 for note in midi_notes}
    if chord_type in FUNCTIONAL_TYPES:
        category = "functional-label"
    elif changes or (quality is not None and not consistent):
        category = "explicit-or-incomplete"
    elif chord_type in SYMMETRIC_TYPES:
        category = "symmetric-root"
    elif not chord_type:
        category = "unmapped-quality"
    elif root_pc not in sounding:
        category = "rootless"
    elif sounding == expected_pcs:
        category = "ok"
    elif expected_pcs < sounding:
        category = "extra-tones"
    else:
        category = "mismatch"
    entry["category"] = category
    return entry


def attach_candidates(fixtures: list[dict], context: str) -> None:
    requests = []
    for fixture in fixtures:
        for event in fixture["events"]:
            requests.append(
                {
                    "id": f"{fixture['id']}#{event['index']}",
                    "midiNotes": event["midiNotes"],
                    "context": context,
                    "analysisProfile": ANALYSIS_PROFILE,
                }
            )
    payload = "".join(json.dumps(request) + "\n" for request in requests)
    process = subprocess.run(
        ["dart", "run", "tool/whatkey/fixture_batch.dart"],
        input=payload,
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr)
    results = {}
    for line in process.stdout.splitlines():
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        result = json.loads(line)
        results[result["id"]] = result["candidates"]
    for fixture in fixtures:
        for event in fixture["events"]:
            event["candidates"] = results[f"{fixture['id']}#{event['index']}"]


if __name__ == "__main__":
    raise SystemExit(main())

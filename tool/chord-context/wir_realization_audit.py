"""Second-interpreter audit of the When-in-Rome expected-identity labels.

The protocol requires the When-in-Rome realization and quality mapping to
pass a stratified audit with a recorded error rate before that ruler's
first frozen result (PROTOCOL.md, Ground truth). This tool provides the
mechanized half: an independent realizer for the common RomanText figure
grammar, built on the same line-of-fifths arithmetic as the DCML extractor
and deliberately not on music21, re-derives each labeled event's expected
root and quality from the figure and local key. Agreement is reported by
figure family; disagreements and figures outside the grammar are listed in
full as the manual-review residue.

Grammar covered: roman degrees I..VII/i..vii with leading accidentals,
quality marks o/%/ø/+, figured-bass 7/65/43/42/2/6/64 (plain triads
included), and applied chords X/Y with recursive keys. Not covered (listed
for manual review): bracket omissions, added/changed figures, Cad64,
Ger/It/Fr (functional-label category, excluded from scoring anyway), and
nonstandard figures.

Usage:
  python tool/chord-context/wir_realization_audit.py \
    --labels build/chord-context/labels/when-in-rome-v1.labels.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from labels_common import classify_figure

LETTER_TPC = {"F": -1, "C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5}
DEGREE_FIFTHS = {
    False: {1: 0, 2: 2, 3: 4, 4: -1, 5: 1, 6: 3, 7: 5},  # major
    True: {1: 0, 2: 2, 3: -3, 4: -1, 5: 1, 6: -4, 7: -2},  # natural minor
}
ROMAN_DEGREE = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7}

_FIGURE = re.compile(
    r"^(?P<accidentals>[#b]*)"
    r"(?P<roman>vii|vi|v|iv|iii|ii|i|VII|VI|V|IV|III|II|I)"
    r"(?P<quality>[o%ø+]?)"
    r"(?P<figbass>7|65|6/5|43|4/3|42|4/2|2|64|6)?$"
)


def tpc_to_pc(tpc: int) -> int:
    return (tpc * 7) % 12


def key_name_tpc(name: str) -> int:
    tpc = LETTER_TPC[name[0].upper()]
    for accidental in name[1:]:
        tpc += 7 if accidental == "#" else -7
    return tpc


class Unsupported(Exception):
    pass


def realize(figure: str, wire_key: str) -> tuple[int, str]:
    """Independently realize a figure to (root pc, ChordQuality name)."""
    tonic, _, mode = wire_key.partition(":")
    minor = mode == "min"
    tonic_tpc = key_name_tpc(tonic)

    parts = figure.split("/")
    # Slashed figured bass (6/4, 6/5, 4/3, 4/2) is not an applied chord:
    # re-join those digits onto the primary component.
    while len(parts) > 1 and parts[1] in ("2", "3", "4", "5"):
        parts = [parts[0] + parts[1], *parts[2:]]
    # Applied chords: resolve the key chain right to left.
    for component in reversed(parts[1:]):
        accidentals = 0
        body = component
        while body and body[0] in "#b":
            accidentals += 7 if body[0] == "#" else -7
            body = body[1:]
        degree = ROMAN_DEGREE.get(body.lower())
        if degree is None:
            raise Unsupported(f"applied component {component!r}")
        tonic_tpc += DEGREE_FIFTHS[minor][degree] + accidentals
        minor = body.islower()

    match = _FIGURE.match(parts[0])
    if match is None:
        raise Unsupported(parts[0])
    accidentals = sum(7 if c == "#" else -7 for c in match["accidentals"])
    roman = match["roman"]
    degree = ROMAN_DEGREE[roman.lower()]
    is_upper = roman[0].isupper()
    root_tpc = tonic_tpc + DEGREE_FIFTHS[minor][degree] + accidentals
    # RomanText dialect (as the corpus's analysts and music21 use it) in
    # minor: LOWERCASE vi and vii take the raised (melodic) degree, so the
    # submediant minor triad and leading-tone chords sit a chromatic
    # semitone above the natural-minor table; UPPERCASE VI/VII stay on the
    # natural degrees (subtonic VII). Explicit accidentals override.
    if minor and degree in (6, 7) and not is_upper and not match["accidentals"]:
        root_tpc += 7
    root_pc = tpc_to_pc(root_tpc)

    quality_mark = match["quality"]
    figbass = match["figbass"] or ""
    seventh = figbass in ("7", "65", "6/5", "43", "4/3", "42", "4/2", "2")

    if quality_mark == "o":
        quality = "diminished7" if seventh else "diminished"
    elif quality_mark in ("%", "ø"):
        if not seventh:
            raise Unsupported("half-diminished without seventh")
        quality = "halfDiminished7"
    elif quality_mark == "+":
        raise Unsupported("augmented family (symmetric-root category)")
    elif not seventh:
        quality = "major" if is_upper else "minor"
    else:
        # Diatonic seventh quality: derived from the third and seventh the
        # key supplies above the root. Third: major iff upper-case numeral.
        # Seventh: diatonic step below the root's octave in the local scale.
        seventh_tpc = _diatonic_seventh_tpc(root_tpc, tonic_tpc, minor)
        seventh_interval = (tpc_to_pc(seventh_tpc) - root_pc) % 12
        if is_upper:
            quality = "major7" if seventh_interval == 11 else "dominant7"
        else:
            quality = "minorMajor7" if seventh_interval == 11 else "minor7"
    return root_pc, quality


def _diatonic_seventh_tpc(root_tpc: int, tonic_tpc: int, minor: bool) -> int:
    """The scale tone a seventh above the root, in fifths, from the key's
    diatonic set. In minor the raised leading tone applies only on the
    dominant (V7); i7 keeps the natural seventh, per the RomanText dialect."""
    scale = {(tonic_tpc + offset) for offset in DEGREE_FIFTHS[minor].values()}
    if minor and root_tpc == tonic_tpc + 1:
        scale.add(tonic_tpc + 5)  # harmonic-minor leading tone under V7
    # The seventh above the root is the scale tone two letter-steps below
    # the root; in fifths arithmetic, candidates differ from root by -2
    # (minor seventh side, e.g. +10 semitones) or +5 (major seventh).
    for offset in (5, -2, -9):
        candidate = root_tpc + offset
        if candidate in scale:
            return candidate
    raise Unsupported("no diatonic seventh found")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels", type=Path, required=True)
    args = parser.parse_args()
    labels = json.loads(args.labels.read_text())

    by_family = defaultdict(lambda: [0, 0])  # family -> [agree, disagree]
    disagreements = []
    unsupported = Counter()
    skipped_categories = Counter()

    for pid, entries in labels["pieces"].items():
        for entry in entries:
            category = entry.get("category")
            if category not in ("ok", "extra-tones", "mismatch"):
                skipped_categories[category] += 1
                continue
            expected = entry.get("expected") or {}
            if expected.get("quality") is None:
                skipped_categories["no-quality"] += 1
                continue
            figure = entry["figure"]
            try:
                root_pc, quality = realize(figure, entry["localKey"])
            except Unsupported as exc:
                unsupported[f"{figure} ({exc})"] += 1
                continue
            except Exception as exc:  # noqa: BLE001 - audit must not die
                unsupported[f"{figure} (error: {exc})"] += 1
                continue
            family = classify_figure(figure)
            agree = root_pc == expected["rootPc"] and quality == expected["quality"]
            by_family[family][0 if agree else 1] += 1
            if not agree and len(disagreements) < 200:
                disagreements.append(
                    f"{pid} #{entry['index']} {figure} in {entry['localKey']}: "
                    f"audit={root_pc}/{quality} "
                    f"music21={expected['rootPc']}/{expected['quality']}"
                )

    total_agree = sum(v[0] for v in by_family.values())
    total_disagree = sum(v[1] for v in by_family.values())
    total = total_agree + total_disagree
    print(
        f"audited {total} events: {total_agree} agree, {total_disagree} "
        f"disagree ({total_disagree / total:.2%} disagreement)"
    )
    print("by figure family:")
    for family, (agree, disagree) in sorted(by_family.items()):
        print(f"  {family}: {agree} agree, {disagree} disagree")
    print(
        f"\nunsupported figures (manual-review residue): "
        f"{sum(unsupported.values())} events, "
        f"{len(unsupported)} distinct"
    )
    for item, count in unsupported.most_common(25):
        print(f"  {count:>4} {item}")
    if disagreements:
        print("\ndisagreements (first 200):")
        for line in disagreements[:40]:
            print(f"  {line}")
    print("\nskipped categories:", dict(skipped_categories))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

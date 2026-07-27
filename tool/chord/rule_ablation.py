#!/usr/bin/env python3
"""Would-the-outcome-differ ablation for ranking rules.

For each targeted rule, remove it from its list in ranking_rules.dart, re-run
the research pool, and diff the ranked output against the unmodified engine.
The file is always restored afterward. A rule whose removal changes no top
pick and no surfaced candidate set is retirable (alternatives order below the
top pick is not a contract); verify the full retirement batch with --joint
before deleting code, and re-verify spelling-sensitive results with
--all-transpositions.

The C-major pool cannot exercise tonality-gated rules (diatonic, tonic,
harmonic-minor); re-run with --key for those before trusting a zero.

Examples:
  python3 tool/chord/rule_ablation.py
  python3 tool/chord/rule_ablation.py --rules "prefer tonic chord" --key A:min
  python3 tool/chord/rule_ablation.py --joint --all-transpositions \\
      --rules "rule one" "rule two"
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from oracle_compare import generate_cases, run_whatchord_batch

REPO_ROOT = Path(__file__).resolve().parents[2]
CHORD_BATCH = REPO_ROOT / "tool" / "chord_oracle_batch.dart"
RULES_PATH = REPO_ROOT / "packages/whatchord/lib/analysis/ranking_rules.dart"
HARD_DECL = "final List<NamedRule> hardRules = <NamedRule>["
TIE_DECL = "final List<NamedRule> tieBreakerRules = <NamedRule>["

# Gated on register evidence the pool cannot supply.
VOICING_ONLY_RULES = {"prefer voicing-supported upper-structure slash"}


def surfaced_symbols(candidates: list[dict]) -> list[str | None]:
    if not candidates:
        return []
    return [
        candidates[0].get("symbol"),
        *[c.get("symbol") for c in candidates[1:] if c.get("alternative") is True],
    ]


def split_list_elements(src: str, list_decl: str) -> tuple[int, int, list[str]]:
    """Return (open_bracket, close_bracket, elements) for a Dart list literal."""
    start = src.index(list_decl)
    open_bracket = src.index("[", start)
    depth = 0
    elems: list[str] = []
    elem_start = open_bracket + 1
    for i in range(open_bracket, len(src)):
        ch = src[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                elems.append(src[elem_start:i])
                return open_bracket, i, [e for e in elems if e.strip()]
        elif ch == "," and depth == 1:
            elems.append(src[elem_start:i])
            elem_start = i + 1
    raise ValueError("unbalanced list literal")


def rule_names(elems: list[str]) -> list[str | None]:
    return [
        (m.group(1) if (m := re.search(r"NamedRule\(\s*'([^']+)'", e)) else None)
        for e in elems
    ]


def list_rules(src: str) -> dict[str, str]:
    """Map every rule name to the list declaration it lives in."""
    out: dict[str, str] = {}
    for decl in (HARD_DECL, TIE_DECL):
        _, _, elems = split_list_elements(src, decl)
        for name in rule_names(elems):
            if name:
                out[name] = decl
    return out


def remove_rules(src: str, names: list[str], decl_by_name: dict[str, str]) -> str:
    for name in names:
        decl = decl_by_name[name]
        lo, hi, elems = split_list_elements(src, decl)
        kept = [e for e, n in zip(elems, rule_names(elems)) if n != name]
        src = src[:lo] + "[" + ",".join(kept) + "," + src[hi:]
    return src


def run_pool(*, all_transpositions: bool, top: int, key: str) -> dict[str, dict]:
    cases = list(
        generate_cases(
            min_notes=3,
            max_notes=7,
            basses="all",
            canonical_transpositions=not all_transpositions,
        )
    )
    payloads = run_whatchord_batch(
        CHORD_BATCH, cases, top=top, repo_root=REPO_ROOT, key=key
    )
    out = {}
    for case, payload in zip(cases, payloads):
        candidates = payload.get("candidates") or []
        out[case.case_id] = {
            "symbols": [c.get("symbol") for c in candidates],
            "surfacedSymbols": surfaced_symbols(candidates),
        }
    return out


def diff_counts(
    ref: dict[str, dict], snap: dict[str, dict]
) -> tuple[int, int, int, list]:
    top1 = surfaced = order = 0
    examples = []
    for case_id, ref_case in ref.items():
        snap_case = snap.get(case_id, {})
        ref_symbols = ref_case.get("symbols") or []
        snap_symbols = snap_case.get("symbols") or []
        ref_surfaced = ref_case.get("surfacedSymbols") or ref_symbols
        snap_surfaced = snap_case.get("surfacedSymbols") or snap_symbols
        if ref_symbols == snap_symbols and ref_surfaced == snap_surfaced:
            continue
        if ref_symbols[:1] != snap_symbols[:1]:
            top1 += 1
            examples.append((case_id, ref_surfaced, snap_surfaced))
        elif set(ref_surfaced) != set(snap_surfaced):
            surfaced += 1
            examples.append((case_id, ref_surfaced, snap_surfaced))
        else:
            order += 1
    return top1, surfaced, order, examples[:5]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rules",
        nargs="+",
        metavar="NAME",
        help="rule names to ablate (default: every hard rule and tie-breaker)",
    )
    parser.add_argument(
        "--joint",
        action="store_true",
        help="remove all targeted rules at once instead of one at a time",
    )
    parser.add_argument("--all-transpositions", action="store_true")
    parser.add_argument("--top", type=int, default=5)
    parser.add_argument("--key", default="C:maj")
    parser.add_argument("--out", type=Path, help="also write results as JSON")
    args = parser.parse_args()

    original = RULES_PATH.read_text()
    decl_by_name = list_rules(original)
    targets = args.rules or [n for n in decl_by_name if n not in VOICING_ONLY_RULES]
    unknown = [n for n in targets if n not in decl_by_name]
    if unknown:
        sys.exit(f"unknown rule name(s): {unknown}")

    pool_args = {
        "all_transpositions": args.all_transpositions,
        "top": args.top,
        "key": args.key,
    }
    print(
        f"building reference over the {'full' if args.all_transpositions else 'canonical'} pool..."
    )
    ref = run_pool(**pool_args)
    print(f"reference: {len(ref)} cases")

    batches = [targets] if args.joint else [[name] for name in targets]
    results = {}
    try:
        for batch in batches:
            RULES_PATH.write_text(remove_rules(original, batch, decl_by_name))
            snap = run_pool(**pool_args)
            top1, surfaced, order, examples = diff_counts(ref, snap)
            label = " + ".join(batch) if args.joint else batch[0]
            results[label] = {
                "top1": top1,
                "surfaced_set": surfaced,
                "order_only": order,
            }
            print(f"{top1:4d} top1  {surfaced:4d} set  {order:4d} order  | {label}")
            for case_id, before, after in examples:
                print(f"        {case_id}: {before} -> {after}")
    finally:
        RULES_PATH.write_text(original)

    if args.out:
        json.dump(results, args.out.open("w"), indent=1)
        print(f"wrote {args.out}")


if __name__ == "__main__":
    main()

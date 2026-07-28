# Chord Naming Oracle Comparison

WhatChord needs a disciplined way to discover chord naming edge cases before
they appear as scattered bug reports or forum archaeology. The goal of this
research harness is not to outsource naming decisions to another library. The
goal is to find places where reasonable tools disagree, because those rows are
good candidates for closer musical review.

The comparison harness lives in
[`tool/chord/oracle_compare.py`](../tool/chord/oracle_compare.py).

It compares WhatChord against optional third-party libraries:

- `music21`
- `tonal` or `@tonaljs/tonal`
- `pychord`

The harness treats every external library as an advisory oracle. A disagreement
is a triage signal, not proof that WhatChord is wrong.

The advisory oracles, with the versions used during review:

| Project            | Version | License      |
| ------------------ | ------- | ------------ |
| [music21][music21] | 10.1.0  | BSD-3-Clause |
| [Tonal][tonal]     | 4.10.0  | MIT          |
| [pychord][pychord] | 1.4.0   | MIT          |

These libraries are comparison evidence, not runtime dependencies of WhatChord's
analysis engine. `mise run research:oracle-install` installs them into local
git-ignored directories: music21 and pychord into the project `.venv` via
`uv pip install`, and Tonal into `node_modules` via `npm install`.

For `music21`, the harness uses `harmony.chordSymbolFigureFromChord()` so
comparison uses chord-symbol figures such as `C7`, `Am7/C`, and `Cm9`, not prose
set-class descriptions. Using the generated figure directly also avoids music21
failures when it cannot parse one of its own generated labels.

For tools that return multiple labels, the harness compares and reports only the
first label. Tonal's `Chord.detect()` returns weighted results sorted by
descending weight, so the first label is its preferred reading.

## Why This Shape

Chord naming has no single universally authoritative answer. Different tools
optimize for different use cases:

- notation and analysis libraries often prefer theoretically complete names;
- JavaScript harmony helpers often prefer compact chord-symbol detection;
- interactive MIDI tools need stable, musician-expected labels for the observed
  voicing.

That means `music21` is useful as the most analysis-oriented comparison point,
but it should not be treated as a golden oracle. The most valuable cases are
where mature tools disagree with WhatChord's primary label.

## What Gets Generated

The harness generates pitch-class sets rather than scraping named chord lists.
It builds a deterministic candidate pool:

1. Enumerates chromatic pitch-class sets of size 3 through 7.
2. Canonicalizes transpositions so equivalent shapes are tested once.
3. Tests every pitch class in the set as the bass.

The harness always runs this entire pool in stable enumeration order. With the
default 3- to 7-note range, canonical transposition handling, and all bass
choices, that is currently around sixteen hundred cases. The pool is much
smaller than every raw note-name combination because transposition-equivalent
pitch-class sets are collapsed before bass choices are expanded.

Every run covers this same complete pool, so results are deterministic and the
reviewed-entry audit always reflects every reviewed case.

Use `--all-transpositions` when spelling or key-specific behavior is the thing
being investigated. The default canonical mode is better for finding structural
naming disagreements.

## WhatChord Entry Point

By default the harness analyzes every case in a single warm Dart VM through a
persistent batch process:

```sh
dart run tool/chord/oracle_batch.dart
```

It reads one JSON request per line and emits one chord-debug-shaped payload per
line, so a full ~1600-case pass completes in a few tens of seconds. The batch
entry point shares its input parsing and JSON payload with `bin/chord-debug`
(via `prepareChordDebugInput` and `chordDebugJsonPayload`), so its output is
byte-identical to the per-case CLI.

For single-case parity checks or debugging, the harness can also analyze one
case at a time through the CLI:

```sh
bin/chord-debug C E G --bass=C --format=json
```

Use `--whatchord-mode=cli` to force the per-case path; the default is
`--whatchord-mode=batch`.

The JSON output keeps the comparison script from scraping human-readable debug
text. Each WhatChord row includes:

- display symbol;
- Harte-style label;
- quality token;
- cost;
- second-ranked candidate;
- alternative flag for diagnostics.

## Running

Install whichever advisory oracles you want to compare:

```sh
uv pip install music21 pychord
npm install --no-package-lock
```

If you use `mise`, `mise run research:oracle-install` handles this into local
ignored directories: the project `.venv` for the Python oracles and
`node_modules` for Tonal.

Then run the full comparison pass:

```sh
mise run research:oracle-compare
# equivalent to:
python3 tool/chord/oracle_compare.py
```

This runs the entire canonical pool (around sixteen hundred cases) in a few tens
of seconds and produces the complete reviewed-entry audit.

To include every transposition instead of canonical representatives:

```sh
python3 tool/chord/oracle_compare.py --all-transpositions
```

For quick manual exploration of a single voicing:

```sh
bin/chord-oracle C D E A --bass=E
```

It accepts the same note and option style as `bin/chord-debug`, then prints
WhatChord's top label plus available oracle labels.

The `--bass` pitch selects the lowest sounding note. When it is omitted from the
note list, the research CLI adds it automatically.

Outputs are written to:

```text
build/oracle-compare/chord_oracle_comparison.csv
build/oracle-compare/chord_oracle_summary.json
build/oracle-compare/chord_oracle_report.txt
```

Start with `chord_oracle_report.txt`. It has four parts: a review-flag legend, a
Reviewed Audit, Disagreement Patterns, and the per-row Attention Queue. The
queue gives copy/pasteable `bin/chord-debug` commands for each case, while the
two sections above it are the better entry points for broad work.

### Reviewed Audit

The audit re-evaluates every `tool/chord/oracle_reviewed.json` entry against the
current engine and sorts them into buckets:

- `resolved` -- the case now agrees with the oracles; remove it from the JSON.
- `no-longer-comparable` -- no longer flagged, but not a clean agree (oracles
  stopped returning a comparable label); usually removable.
- `drifted` -- still flagged, but WhatChord's current top symbol is no longer
  mentioned in the stored note; re-read the note before trusting it.
- `still-valid` -- still flagged and consistent with the note; keep.
- `orphaned` -- the `case_id` is not in the generated pool at all; remove.

The audit tells you which entries to prune; it is report-only and never edits
the JSON.

### Disagreement Patterns

This section groups open (non-reviewed) disagreements by a
`whatchord-quality vs oracle-quality` signature, largest cluster first. A large
cluster means many cases share one naming-rule disagreement, so a single ranking
change can resolve them together. Each cluster lists a few example cases with
ready-to-run `bin/chord-debug` commands. The same clusters appear as a
machine-readable `patterns` array in `chord_oracle_summary.json`.

## Reading The CSV

The most important columns are:

| Column              | Meaning                                                     |
| ------------------- | ----------------------------------------------------------- |
| `notes`             | Canonical pitch names sent to every tool                    |
| `bass`              | Bass note passed to WhatChord and oracle inputs             |
| `whatchord_symbol`  | WhatChord's top display label                               |
| `whatchord_harte`   | WhatChord's top Harte-style label                           |
| `whatchord_second`  | WhatChord's second-ranked label, surfaced or not            |
| `alternative`       | Whether a WhatChord candidate is surfaced as an alternative |
| `*_labels`          | Raw labels returned by each external oracle                 |
| `review_flag`       | High-level triage classification                            |
| `normalized_labels` | Simple normalized labels used for comparison                |

The current review flags are:

| Flag                         | Meaning                                               |
| ---------------------------- | ----------------------------------------------------- |
| `agree`                      | Available tools normalized to the same primary label  |
| `oracle-split`               | At least one oracle matched WhatChord and one did not |
| `disagreement`               | Comparable oracle labels did not match WhatChord      |
| `oracle-error`               | An external tool failed on the row                    |
| `no-whatchord-candidate`     | WhatChord did not produce a candidate                 |
| `insufficient-oracle-labels` | Not enough comparable oracle labels were available    |

Rows marked `disagreement` should be sorted by musical importance before they
become implementation work. A dense chromatic cluster disagreement is less
important than a common shell voicing or altered dominant that appears in normal
playing.

## Recommended Review Workflow

Since the engine moved to explanation-cost pricing, the preferred lever for a
naming change is a price, not a rule. Every price in `chord_analyzer.dart` is a
one-line musical statement (vocabulary rarity, a color tone's tension, a
structural surcharge, a bass-placement cost), so most conventions can be
expressed where they generalize instead of as a pairwise exception.

1. Confirm the disagreement is semantic, not only spelling or parser behavior.
2. Judge the candidates against WhatChord's goal: the musician-expected name of
   the observed voicing. Treat oracles and ChoCo frequency as evidence, not
   authority.
3. Decide whether the case is clearly wrong, clearly correct, genuinely
   ambiguous, context-dependent, voicing-dependent, or an oracle limitation.
4. Change the engine only when a reusable musical principle explains the
   preferred answer, and reach for levers in this order: a general price or
   structural surcharge in the cost model first; a tie-breaker (which only acts
   inside the near-tie window) when the principle is genuinely about ordering
   close readings rather than changing prices; a hard rule only for a
   cost-independent convention that cannot be priced. Add positive and negative
   boundary tests; do not encode one exact pitch set.
5. Measure the blast radius of any price change against the full canonical pool
   before trusting it, using `tool/chord/pool_diff.py` (see below). Zero flips
   on `clearly-correct` reviewed entries is a hard constraint. Agreement changes
   on 3-5 note cases are trusted signal; 6-7 note flips need musical eyeballing
   rather than tally-keeping, because the previous engine's dense-voicing output
   is itself part of what these changes exist to fix. Do not tune to maximize
   agreement with any single oracle, including the engine's own previous
   behavior.
6. Run focused tests and the full chord golden suite. Golden expectations are a
   snapshot of the engine, not ground truth: re-carve a changed golden when the
   new reading is musically defensible, and record the justification in its
   description. In analyzer goldens, `expectedAlternatives` means surfaced
   near-tie alternatives (`ChordCandidateRanking.alternatives`), not every
   lower-ranked candidate the engine can produce. Do not add an
   `expectedAlternatives` entry only because the label appears somewhere in the
   raw ranked list. Spelling-dependent changes also need an all-transpositions
   pass, since the canonical pool only sees one spelling per shape.
7. After retiring or adding rules, re-run the per-rule ablation
   (`mise run research:rule-ablation`): remove each rule, re-run the pool, and
   diff the top pick and surfaced alternative set. Rules whose removal changes
   neither (alternatives order below the top pick is not a contract) should be
   deleted, verified as a joint removal across all transpositions.
8. Add unresolved-but-reviewed cases to `tool/chord/oracle_reviewed.json`. Prune
   entries the Reviewed Audit lists as `resolved`, `no-longer-comparable`, or
   `orphaned`, and re-check anything it lists as `drifted`.

Reviewed entries use this shape:

```json
{
  "case-id": {
    "label": "genuine-ambiguity",
    "note": "Why the current result is acceptable and no engine change is needed."
  }
}
```

Allowed labels are:

- `clearly-correct`: WhatChord's result is the expected isolated-voicing name.
- `genuine-ambiguity`: multiple names are comparably defensible.
- `context-dependent`: harmonic or tonal context could legitimately change the
  answer.
- `voicing-dependent`: octave placement, doubling, or register would be needed
  to choose confidently.
- `oracle-limitation`: the disagreement primarily comes from an oracle's
  vocabulary, parsing, spelling, or missing-label limitation.

The main engineering value is prioritization. The harness should help answer:

- Which ambiguous pitch-class sets produce fragile names?
- Which inversions change external-tool naming unexpectedly?
- Which surfaced WhatChord alternatives are more plausible than the primary
  label on rows where oracles disagree?
- Which external disagreements are actually notation differences rather than
  analysis differences?

## Blast Radius And Rule Ablation Tools

Two companion tools reuse the same batch entry point and pool generation to make
the workflow's measurement steps one-command operations.

`tool/chord/pool_diff.py` measures a change's blast radius. Snapshot the pool
before and after an engine change, then diff:

```sh
python3 tool/chord/pool_diff.py snapshot --out build/pool-diff/before.json
# ...make the engine change...
python3 tool/chord/pool_diff.py snapshot --out build/pool-diff/after.json
python3 tool/chord/pool_diff.py diff build/pool-diff/before.json \
  build/pool-diff/after.json
```

The diff classifies each changed case as a top-pick change, a surfaced-set
change, or an order-only change below the top pick, stratified by note count.
The `census` subcommand counts which rule decides each case's top pair, which
shows where the rule layer still carries load.

Both tools also report each stratum's exposure: its share of real playing time,
from the committed POP909 exposure-weight table
(`tool/chord/pop909_exposure_weights.json`, regenerated by
`tool/chord/pop909_exposure.py`; provenance and validation in
research/performed-input/ logs 2026-07-28-03 and -04). Real playing concentrates
on about a hundred canonical shapes, so the weighted view answers "how much
playing time does this change touch" while the unweighted counts, which the
exposure column supplements and never replaces, keep the deterministic full-pool
contract: the zero-flips-on-clearly-correct constraint stays count-based.

`tool/chord/rule_ablation.py` (also `mise run research:rule-ablation`) answers
whether each ranking rule still changes any outcome: it removes one rule at a
time from `ranking_rules.dart`, re-runs the pool, and diffs against the
unmodified engine, always restoring the file. Rules whose removal changes no top
pick and no surfaced set are retirable; verify the batch with `--joint` and
`--all-transpositions` before deleting code, and use `--key` before trusting a
zero on a tonality-gated rule.

## Limitations

The harness intentionally compares labels, not truth. Label normalization is
simple and conservative; it will flag some harmless spelling differences as
disagreements. That is acceptable for discovery because the output is meant to
be reviewed, not accepted automatically.

External libraries may also ignore bass, octave, or spelling in ways that differ
from WhatChord's real-time MIDI use case. This is another reason to treat the
report as an edge-case finder rather than a conformance suite.

Finally, generated pitch-class sets are not weighted by musical frequency. Use
the ChoCo coverage work alongside this harness: ChoCo helps identify which chord
vocabulary appears in real annotations, while oracle comparison helps identify
where naming and ranking are debatable.

[music21]: https://github.com/cuthbertLab/music21
[tonal]: https://github.com/tonaljs/tonal
[pychord]: https://github.com/yuma-m/pychord

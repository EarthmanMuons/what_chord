# 2026-08-10: Freeze polychord output and evaluation

**Goal.** Fix the secondary-output representation, presentation semantics,
stability behavior, scoring model, adoption bar, and performance budget before
designing or evaluating a selector. Keep the established single-chord analyzer
and its downstream consumers outside the feature's blast radius.

**Setup.** Work began from clean repository commit `3b168aed`. This was an
architecture and methods decision, not an engine experiment. The review traced
the existing data flow through:

- `ChordIdentity`, `ChordCandidate`, and `ChordPresentation` in the pure-Dart
  package;
- `CaptureFrame`, `ChordEventSegmenter`, and `ChordEvent`;
- the candidate, display-gate, presentation, identity-display, and history
  providers;
- the primary identity card and alternative-candidate list;
- the recent-chords strip and key-history consumers;
- analysis-details diagnostics; and
- `ChordLink` and the share-link provider.

The relevant current contracts are consequential. `ChordCandidate` is one ranked
single-chord identity with a comparable cost. Its selected identity and near-tie
alternatives feed the primary card, history, and key inference.
`ChordEventSegmenter` compares the primary identity and snapshots its frame at
identity onset; same-primary changes do not update that snapshot. Current share
links parse note tokens to ordered pitch classes and therefore do not preserve
octave register.

The notation decision reused the prior-art record in log 2026-08-02-05: current
engraving software accepts an upper-chord-first pipe, while a slash denotes a
chord over a bass note. The performance budget follows the repository's existing
context-layer precedent: primary `tool/benchmark.sh --check` remains green, and
the added pure-Dart layer receives at most 5% of cold normalized snapshot time
outside the combined uncertainty window, plus a no-dropped-frames device gate.

The contract and record were checked with:

```sh
npx prettier --write --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/FRAMEWORK.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/log/2026-08-10-18-output-and-evaluation-freeze.md
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/FRAMEWORK.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/log/2026-08-10-18-output-and-evaluation-freeze.md
git diff --check
```

The formatted decision files were pinned before the final read-through:

| File                            | SHA-256                                                            |
| ------------------------------- | ------------------------------------------------------------------ |
| `PROTOCOL.md`                   | `70a3c81adfd4bc8966ab4e1ffa5348a9b2aa6a1d8a96a2858fadf54f4ece270f` |
| `FRAMEWORK.md`                  | `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615` |
| `internal-suite-schema.md`      | `f296ffbe400b8b8d34cb2346fbee2dd5cbdf9ccbdf5150e0b67a883e85b92ca1` |
| `output-evaluation-contract.md` | `881e8cb0355a857ddf044900fa480a0d4e2313c6330fe8c6466bb4040a505a58` |

## What happened

The frozen output is parallel to primary analysis. A `PolychordIdentity` is an
ordered upper and lower pair of root pitch class plus common quality. Exact
MIDI-note assignments and evidence belong to a candidate or decision, not to
identity equality. Several assignments may survive diagnostics, but product
selection exposes at most one deduplicated identity and must abstain on an
unresolved tie.

The combined presentation is one required existing `ChordPresentation` plus one
optional `PolychordPresentation`. The secondary is never inserted into the
single-chord ranking, never receives a comparable cost, and cannot change the
primary card, key inference, event segmentation, recent history, or Explore
seed.

V0 uses no scalar confidence. Register is necessary candidate evidence; the
frozen onset and rigid-motion interpretations remain one-sided positive support.
Neutral, incomplete, or absent temporal history does not reject a static
selection. Release/pedal evidence remains uninterpreted, and a future selector
that gives any temporal or source cue decision weight requires a preregistered
amendment.

The user-facing forms distinguish the result from a slash chord and from a
primary-ranking alternative. `C|Gm` is the canonical plain-text form. The long
form is “Polychord: C major above G minor.” The semantic and spoken form is
“Polychord. Upper chord: C major. Lower chord: G minor.” Screen readers never
receive a raw pipe, and the visual secondary region must support stacked layout
and platform text scaling without ellipsis or horizontal scrolling.

The stable display requires an unchanged selected identity and exact assignment
for 200 milliseconds before appearance. A changed valid selection restarts the
timer. An invalid assignment, abstention, absent primary, or silence clears the
secondary immediately, so stability cannot leave a decomposition visible after
its notes stop sounding.

History and sharing are deliberately narrow in v0. `ChordEvent` remains
single-chord-only, and secondary changes do not segment or relabel it. Existing
links remain input/primary-only because their pitch-class grammar cannot
reproduce register evidence. The app must not serialize an inferred polychord
label as though it were input evidence. A later register-preserving link and
event-history design require their own versioned contracts.

The scorer separates ordered composite identity, exact note assignment,
unordered layer partial credit, orientation, note-assignment accuracy, and
correct abstention. Partial credit supports error analysis but cannot pass the
adoption gate. Every eligible positive must match both ordered identity and
assignment exactly, and every boundary and negative guard must abstain.
Synthetic and literature strata report separately, and ineligible positives are
explicit coverage exclusions rather than misses.

The corpus gate requires proposal and stable-display counts and durations,
latency and churn distributions, reason-code counts, and a complete disposition
of every development stable-display fire. Zero displayed ordinary integrated,
slash, same-root, or other out-of-scope cases are allowed under the
author-adjudicated framework. These are conservative product-policy checks, not
population accuracy estimates.

**Plain-English reading.** A polychord will be an extra explanation beside the
chord WhatChord already names, not a rival answer mixed into the existing list.
The app will say which chord is upper and which is lower, will wait for a stable
reading before showing it, and will remove it as soon as its supporting notes no
longer sound. Shipping requires every positive example to be exactly right and
every known trap to stay quiet; a good average is not enough.

**Decisions.** Adopt `output-evaluation-contract.md` as the active v0 contract.
Keep the primary analysis path invariant. Use order-sensitive composite identity
and exact assignments; expose zero or one secondary annotation; use explicit
abstention reasons and no numeric confidence. Freeze the presentation, 200-ms
appearance/immediate-invalidation rule, single-chord-only history and links,
exact and partial metrics, all-cases-exact adoption gate, complete corpus-fire
disposition, 5% normalized-time budget, and device accessibility and note-storm
checks.

The active ten-case seed remains `scoringAllowed: false`. This contract fixes
how a complete suite will be scored; it does not declare that the current source
coverage is sufficient or authorize reading selector outcomes.

**Next.** Audit the internal suite against the frozen output contract and
preregister the missing adoption strata before adding or evaluating a selector.
At minimum, address the dependence on synthetic eligible positives by seeking
more score-verified recoverable constructions, including structural coverage not
supplied by the Ives triad-over-triad case. Do not spend the held POP909
reserve.

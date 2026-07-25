# Ensemble Mode: Design and Integration Plan

Status: adopted 2026-07-25 (log entry 2026-07-25-01). This is the working plan;
phases land as logically separate commits, and the Progress section tracks where
we are. Course corrections get dated log entries and an edit here, not a rewrite
of history.

## Inherited constraints

Four conclusions from the chord-context investigation bind this plan:

1. **The mode is explicit.** Auto-detection from pitch content is impossible in
   principle (6/6 solo cases admit a ghost-root competitor, log entry
   2026-07-20-16). Any design that infers the mode is rejected in advance.
2. **The implementation stack is sized.** Ghost-root templates reach the
   identity (12/12); a diatonic key filter makes it unique ~82% under the
   inferred key; a guide-tone/dominant-color tiebreak has ~93% headroom (entry
   2026-07-20-19).
3. **The tiebreak is the one unmeasured component.** It must be built and
   measured against the same rootless synthesis before shipping.
4. **Solo mode must not move.** The tiebreak has essentially zero addressable
   headroom in solo mode; with the mode off, engine output must be
   bit-identical. The comping suite's 6 solo and guard cases plus the full solo
   golden suite are the regression fence.

## Core architectural decision

The mode is a field on `AnalysisContext`
(`packages/whatchord/lib/src/models/analysis_context.dart`), which documents
itself as the insertion point for new bias sources:

```dart
enum PlayingContext { solo, ensemble }
```

with default `solo`. Rationale:

- The app uses one shared `ChordAnalyzer` instance; a per-call context keeps
  that, and the analyzer's LRU cache already hashes the context. Extending
  `AnalysisContext.==`/`hashCode` is a correctness requirement (solo and
  ensemble results must never alias in the cache) and gets its own test.
- The name avoids "mode" because the app already has an unrelated `AnalysisMode`
  enum (a note-count classifier in
  `lib/features/theory/state/providers/analysis_mode_provider.dart`). UI copy
  still says "Ensemble mode".

## Phase 1: Engine contract change, zero behavior change

- Add `PlayingContext` and the `AnalysisContext` field with a `solo` default;
  extend equality and hash.
- Touch every construction site: `analysisContextProvider`, the screenshot
  seed's private context (`key_screenshot_seed_notifier.dart`), the tool facade
  (`tool/src/chord_id_engine.dart`), and the research harness contexts.
- Add the cache-aliasing test (same input, different `PlayingContext`, distinct
  cache entries).
- All golden tests pass unchanged.

## Phase 2: Ensemble candidate generation and pricing (engine)

All gated on `context.playingContext == PlayingContext.ensemble`; solo behavior
stays bit-identical.

**Ghost-root generation.** The no-ghost-roots rule is enforced in three places
in `chord_analyzer.dart` (the sounding-root loop guard, the root-bit check in
`_priceTemplate`, and root always joining `requiredMask`). In ensemble mode, a
second root loop runs over absent pitch classes, restricted to seventh-family
templates marked ensemble-eligible (a new `allowsMissingRoot` flag on
`ChordTemplate`). For these candidates:

- Both guide tones (3 and 7) are strictly required; the one-missing-essential
  allowance does not apply. This matches the acceptance rule the prototype used
  (`tool/chord-context/comping_gate.dart`, `_rootlessHypotheses`): guide tones
  mandatory, colors restricted to the legal set.
- Diatonic ghost-root filter at generation time: only hypothesize absent roots
  where `tonality.containsPitchClass(root)` holds. With no usable tonality,
  generate no ghost roots (graceful degradation to solo behavior). This filter
  is exactly what the 82-89% numbers assume.
- Symmetric dim7 ghost hypotheses are excluded (four equal roots), as in the
  corpus harness.

**Pricing.** Three adjustments for rootless candidates, per
`rootless-voicings-notes.md` items 2-4:

- A missing-root cost (new `CostReason`), calibrated so a rootless reading with
  both guide tones beats the "complete cheaper chord" trap (the rootless Cm9
  that reads as a 0.00-cost Ebmaj7 today) while plain voicings played in
  ensemble mode still resolve sensibly.
- Bass semantics: neutralize `_bassPlacementCost` for rootless candidates. A
  guide tone in the bass is the definition of the form, not an inversion signal.
  This is the playedBass/functionalBass distinction from the notes, scoped to
  rootless candidates rather than a global rework.
- A mild counterweight on slash readings whose bass is a guide tone, applied
  only when a rootless candidate is live, kept gentle: sometimes the slash chord
  is exactly what the music is doing.

**Model surface.** `ChordCandidate` (and the identity it carries) gains an
implied-root marker so downstream layers know the root was not sounded.
`explain()` reports the missing-root cost like any other `CostReason`.

## Phase 3: Guide-tone/dominant-color tiebreak, then measure everything

- Implement the tiebreak as new `tieBreakerRules` entries
  (`packages/whatchord/lib/src/analysis/ranking_rules.dart`), gated to fire only
  between rootless candidates: reward complete guide tones plus color tones;
  prefer dominant-type readings carrying classic dominant colors. The ambiguous
  bucket it must resolve is dominated by dominant7 versus halfDiminished7 pairs.
- Measurement before ship (protocol obligation): extend
  `tool/chord-context/rootless_corpus.dart` with a real-engine arm that calls
  `analyze()` under an ensemble context, replacing the hand-rolled hypothesis
  simulation. Targets: at least match the 81.9% simulated inferred-key number
  (stable preset), quantify how much of the 93.0% ceiling the tiebreak recovers,
  then confirm on the held-out split per the protocol's spend-it-once rule.
- Run the comping gate through the real engine: 12/12 on rootless and shell
  cases; the 6 solo and guard cases unchanged; full solo golden suite unchanged.
- Encode the 18 suite cases as package unit tests so the acceptance ruler runs
  in CI, not just in the harness.
- Performance: `tool/benchmark.sh --check` against the committed baseline; the
  solo path must show unchanged analyze-call and operation counts.

## Phase 4: App integration

**State and settings.** An `EnsembleModeNotifier` in the theory feature (this is
an analysis-level concept, not a key-detection one), modeled on
`KeyBehaviorNotifier`: prefs-backed, string key in
`theory_preferences_keys.dart`, default solo. `analysisContextProvider` watches
it. Settings page gets a Solo/Ensemble segmented control near the Key Detection
section, with a subtitle stating the assumption plainly ("Assumes a bassist
covers the root; names rootless comping voicings"). Add the prefs key and
provider invalidation to `settings_reset_service.dart`.

**Presentation.**

- `secondaryLabel` in `identity_display_provider.dart` becomes
  `Chord · rootless` for implied-root identities.
- The members list and tone ledger mark the root as implied rather than
  sounding.
- `normalizedVoicingForIdentity` synthesizes from the root, which is wrong for a
  rootless identity; v1 shows the actually played notes on the keyboard and
  skips ghost-key rendering (a hollow implied-root key is later polish, not a
  launch requirement).
- Tier wording (Chosen/Possible/Unlikely) is unchanged.
- A persistent "Ensemble" indicator is visible on the home screen whenever the
  mode is on; a forgotten toggle would look like a broken analyzer. The tonality
  bar is the natural host. Launch scope, not polish.

**Coupled features.**

- History: `ChordEvent` stores tonality because ranking is tonality-gated;
  playing context is a second gating input, so the event records it too (package
  temporal model plus the capture provider).
- Key detection loop: rootless readings feed the chord stream that feeds
  WhatKey, which feeds the diatonic filter. The closed loop is what the
  inferred-key arms measured (~82-83%), so it is validated at corpus scale, but
  it gets an on-device sanity pass. The reactive preset scored highest here; no
  coupling change, just documentation.
- Deep links: encode the mode in the link grammar
  (`lib/features/links/models/chord_link.dart`), parse tolerant of absence; a
  shared rootless voicing resolves differently without it.
- Lookup pad: honors the global mode.
- Demo/tour: pinned to solo so scripted sequences stay stable.
- Web /try and CLI: `identifyChord()` gains a mode parameter plus a wire field
  for parity; the web bundle is regenerated before release as usual.

## Phase 5: Docs and release

- Update the chord recognition algorithm article (required by the NOTE comments
  in `chord_analyzer.dart`, `chord_templates.dart`, and
  `chord_candidate_ranking.dart`).
- `CHANGELOG.md` entry (Added) and `docs/whatsnew/unreleased/` bullets.
- Closing log entry with the final measured numbers.

## Risks

- **Cache aliasing** if `AnalysisContext` equality is not extended: silent and
  wrong. Phase 1 covers it with a dedicated test.
- **The tiebreak is only estimated.** If measurement disappoints, the mode still
  ships usefully at ~82% against 0% today; the tiebreak is separable.
- **Corpus genre skew.** The 13,197 events are classical seventh chords with the
  root stripped. Jazz repertoire should do as well or better (richer tensions
  constrain more), but no jazz-comping corpus is pinned; the 18-case Levine-form
  suite is the jazz-flavored guard until one exists.
- **Mode confusion UX.** The failure mode of an explicit toggle is forgetting it
  is on; the persistent home-screen indicator is the mitigation.

## Progress

- [x] Phase 1: engine contract (`PlayingContext`, cache key, construction sites,
      aliasing test)
- [ ] Phase 2: ghost-root generation, diatonic filter, missing-root pricing,
      bass semantics, implied-root marker
- [ ] Phase 3: guide-tone/dominant-color tiebreak; real-engine corpus
      measurement; comping suite as CI tests; benchmark check; holdout
      confirmation
- [ ] Phase 4: settings toggle and notifier; presentation (rootless label,
      implied root, home indicator); history event field; deep links; lookup;
      demo pin; web/CLI parity
- [ ] Phase 5: algorithm article, changelog, whatsnew, closing log entry

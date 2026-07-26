# 2026-07-26: Internal key and history relabel implemented

**Goal.** Implement the two adopted mechanisms per the design decisions in entry
-09: the internal ensemble naming key (decisions 2-3) and the one-event history
relabel (decision 1).

**Setup.** App-side change only; the engines are untouched. Measured ceilings
being implemented: ensemble naming 93.5% under the reactive key against 92.8%
under stable (entry -07), history record 94.7% with the one-event relabel at
reactive (entries -07/-08).

**What happened.** Implementation, following the app's existing write-back and
lifecycle patterns:

- `InternalKeyNotifier` (key feature): a second `HmmKeyDetector` running the
  same lifecycle as the display detector but with the behavior hooks pinned to
  the reactive preset. `InferredKeyNotifier` gained two protected hooks
  (`watchBehavior`, `staleAfter`) so the subclass pins them; everything else is
  shared.
- `InternalKeyCoordinator` (key feature): listens to the internal key and the
  key mode. It pushes the internal claim into the theory-side
  `ensembleNamingTonalityProvider` in auto key mode (null in manual mode), and
  performs the relabel: when the event just processed moves the internal claim,
  the second-newest history entry is re-analyzed under that claim (full context:
  tonality, its key signature, its spelling policy, the entry's own playing
  context) and swapped in place. Both writes land through microtasks, per the
  same-frame write-back rule.
- `analysisContextProvider` (theory): under `PlayingContext.ensemble`, the
  ranking tonality follows `ensembleNamingTonalityProvider` when set, while
  keySignature and spellingPolicy stay with the selected key (decision 3's
  identity/spelling split; `AnalysisContext` already documents its fields with
  exactly that separation of concerns). Solo and demo analysis never read it.
- `ChordHistoryNotifier.replace` (history): identity-keyed in-place swap, no-op
  when the original is gone; callers never replace the newest entry.
- Detector-feedback hardening: `InferredKeyNotifier` now tracks the processed
  tail itself (marked at build from the current history, cleared on reset)
  instead of trusting the listener's previous value, so a record-only history
  mutation can never re-feed the causal detectors, across rebuilds included.
- Lifecycle: `appInternalKeyLifecycleProvider` watched from `MyApp` alongside
  the existing hooks.

Tests (8 new; suite 237 green): internal key claims independently of the display
preset switch; relabel applies one deep under the moved claim with re-ranked
candidates while the newest entry and warmup-era entries stay untouched; relabel
is record-only (display detector state identical across the write); naming
tonality follows the claim only in auto mode and clears on manual; `replace`
no-ops when the original is gone; ensemble context follows the naming tonality
while the key signature stays with the display; solo context ignores it.

**Plain-English reading.** The app now keeps a second, quicker opinion about the
current key that never appears on screen. When Ensemble mode names a
bassist-covered voicing, it asks that quicker opinion, so the name keeps up with
a modulation even while the visible key indicator stays deliberately calm. And
once the next chord reveals where the key actually settled, the previous entry
in the recent-chords list is quietly renamed under that key. Both behaviors
follow the measured numbers: they are the two mechanisms worth about one and a
half points of ensemble accuracy on the record.

**Decisions.** Implemented as designed in entry -09; no deviations. One addition
surfaced by a test: the processed-tail tracking in `InferredKeyNotifier`, which
turns the "record-only mutations never re-feed detectors" contract from an
emergent property of listener semantics into an explicit invariant.

**Next.** The minor-evidence asymmetry design (entry -07) is the remaining open
avenue before the holdout.

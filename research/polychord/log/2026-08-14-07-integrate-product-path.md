# 2026-08-14: Integrate the automatic product path

**Goal.** Connect the already-equivalent `polychord-output/3` pure-Dart policy
to the real app input and presentation paths without changing primary chord
analysis, history, key inference, Explore, or sharing.

**Setup.** Work began from clean commit
`13316b7afad9c58c568c22452b9129c2d978b27b`, which records the passing frozen
product and baseline results. No development or held corpus was read during this
integration. In particular, the 808-song POP909 reserve remained untouched.

The final validation commands were:

```sh
dart format .
cd packages/whatchord
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..
dart run import_order_lint:import_order
flutter analyze
flutter test --reporter compact
tool/benchmark.sh --check
npx prettier --write --prose-wrap always \
  CHANGELOG.md \
  research/polychord/PROTOCOL.md \
  research/polychord/product-completion-plan.md \
  research/polychord/log/2026-08-14-07-integrate-product-path.md
git diff --check
```

The principal integration file pins are:

- normalized temporal input model:
  `3707ebd4d7e07f9cd078015a8fc342177f529eda9ca15afa1d8e929eb4da3b2b`;
- real MIDI temporal adapter:
  `6802c9aef7a7079ffec3616567adc479c3843db6af89c35546faf094b72e2112`;
- app product coordinator:
  `96786a8443b4b5868efa4b45167ccb42ccd082a22679ca9848bc0de644b8efa8`; and
- layer presentation builder:
  `193c32c0a29aa1089bb945bf55f0358434b8b8483c9f95dc82458d5fb9822813`.

**What happened.** The input feature now exposes an ordered normalized stream of
note-on, note-off, adopted sustain-pedal, and explicit reset events on one
shared monotonic elapsed clock. The MIDI adapter converts velocity-zero note-ons
to note-offs, ignores invalid duplicate note messages, follows the pedal state
the app actually adopted (including touch latching), and emits resets for
all-notes-off, connection changes, and source replacement. Reset snapshots may
carry notes but never fabricate their missing onset authority. The demo adapter
uses the same app boundary and repairs state changes that its intentionally
simplified pedal model cannot express as literal MIDI releases.

Pre-commit review identified a startup race in the first version of that
adapter: the source snapshot was read before the raw-event stream attached, so
an event arriving in the intervening subscription turn could be lost. This was
corrected before final validation. Each source now captures its initial state,
attaches its listeners, and buffers an explicit reset as the stream's first
event in one synchronous provider build. Source selection merely forwards that
ordered stream. The adapter test asserts the initial reset before exercising
live events.

The Riverpod coordinator feeds those events to the unchanged
`PolychordProductEngine`. Input and primary-availability notifications caused by
one MIDI message can arrive through different provider microtasks, so the
adapter orders queued commands by monotonic timestamp and authoritative arrival
order before calling the engine. This prevents a later primary notification from
overtaking the note event that caused it. The primary gate uses the exact
definition frozen for development replay: the live path can produce a raw
`CaptureFrame`. It does not wait for the primary card's separate 200-millisecond
stability timer, so the primary and secondary timers mature in parallel rather
than accidentally imposing roughly 400 milliseconds on polychords.

The selected decomposition is rendered through the existing chord spelling,
notation, and note-name systems. Its visual is a labeled, upper-first secondary
region before ordinary alternatives. It wraps or vertically scrolls instead of
truncating, overlapping, or introducing horizontal scrolling, and its semantics
use the frozen explicit upper/lower wording. The primary card remains the only
Explore target. History, key inference, and links remain single-chord-only.

The complete package suite passed 642 tests. The complete app suite passed 258
tests with the repository's existing 6 skips. New non-widget tests cover the
five registered layer qualities, enharmonic presentation, raw CC64 and sustain
ordering, velocity-zero and duplicate normalization, all-notes-off reset, stable
appearance by input and by timer, complete diagnostic serialization, raw-primary
parallel timing, primary-gate clearing with the raw decision retained, reset
authority, and history isolation.

Both analyzers reported no issues, and both import-order runs completed. The
unchanged primary benchmark passed: deterministic counters were identical;
oracle cold time changed +0.3%, common cold time +0.4%, allocation churn +1.9%,
and retained memory +0.1% against the committed baseline. This confirms that the
integration did not add another `ChordAnalyzer.analyze()` call or change its
measured engine path. It is not the still-required dedicated polychord-path
benchmark or on-device note-storm result.

**Plain-English reading.** The feature now receives the timing information it
was designed around, runs continuously in the actual app, and can display the
same conservative result already accepted by the frozen product suite. It does
so beside the ordinary chord name rather than replacing or leaking into any
other feature. The automated checks cover the app boundary and the most
important failure cases, but a release still needs a direct speed measurement of
this new path and hands-on checks on supported devices.

**Decisions.** Adopt the normalized temporal input stream as the sole app
adapter for automatic polychords. Keep `ChordAnalyzer` parallel and unchanged.
Use raw `CaptureFrame` availability for outer authorization, as preregistered,
and keep the secondary 200-millisecond gate independent. Keep product
diagnostics as the complete immutable `PolychordProductObservation`; do not put
thresholds, reason codes, or confidence wording into the visible annotation.

Treat source replacement, disconnect, all-notes-off, or unreconstructed state as
a tracker reset. Preserve carried notes only as incomplete history. Do not add
polychord state to `ChordEvent`, Explore seeds, key evidence, or link grammar.

**Next.** Add the dedicated normalized-time and allocation benchmark for the
complete product path, then perform the hands-on two-order, triad/seventh,
abstention, sustain, reattack, reset, accessibility, and device note-storm
checks. Freeze the release candidate only after those pass; only then may the
one final held POP909 exposure run.

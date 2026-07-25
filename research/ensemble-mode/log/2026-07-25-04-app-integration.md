# 2026-07-25: Phase 4 app integration

**Goal.** Wire the measured engine capability into the product: setting,
indicator, presentation, and the coupled features.

**Setup.** App work only; no engine or measurement changes. Verified by analyzer
and full test suites at package and root (534 + 227 passing).

**What happened.**

- **State.** `PlayingContextNotifier` (theory feature, prefs key
  `theory.playingContext`, default solo) feeds `analysisContextProvider`.
  Settings reset clears and invalidates it.
- **Settings UI.** A "Playing Mode" section with a Solo/Ensemble segmented
  control sits above Key Detection; the subtitle states the ensemble assumption
  plainly.
- **Indicator.** The tonality bar shows an ensemble badge whenever the effective
  analysis context is ensemble. It watches the effective context, not the raw
  setting, so it disappears while demo mode pins analysis to solo. Icon-only
  (the bar's horizontal space is at a premium), with a short tooltip; tapping it
  opens Settings scrolled to the Playing Mode section, so the badge itself is
  the path to turning the mode off.
- **Presentation.** Implied-root identities render plain symbols (never a slash:
  the formatting surfaces gate on `hasImpliedRoot` rather than redefining
  `hasSlashBass`, which ranking features consume); the inversion description is
  suppressed; the identity card's secondary label reads "Chord · rootless"; the
  tone ledger lists the implied root under missing tones; the copyable analysis
  details gain a "Playing mode" context line.
- **History.** `CaptureFrame` and `ChordEvent` record the playing context
  (default solo), since it is a second ranking-gating input alongside tonality.
- **Demo** is pinned to solo inside `analysisContextProvider`, keeping the
  scripted tour stable.
- **Lookup** needed no change: it flows through the same analysis context, so it
  honors the mode.
- **Deep links.** The grammar gains `mode=ensemble` (omitted for solo), and
  opening a link applies the sharer's playing context, mirroring the existing
  key philosophy (a link reproduces the sharer's context rather than adopting
  the recipient's). The mode change is visible via the badge.
- **Web/CLI parity.** `identifyChord()` takes a playing context;
  `whatchordIdentify(notes, key, notation, mode)` accepts an optional fourth
  argument; `chord_name` and `chord_debug` gain `--ensemble`. The /try page UI
  for the mode (and the web bundle regeneration) is Phase 5 site work.

**Decisions.**

- Slash suppression is display-only, gated per formatting surface on
  `hasImpliedRoot`; `hasSlashBass` semantics are unchanged so the measured
  ranking behavior cannot drift.
- Deep links overwrite the persisted playing context on open, including back to
  solo for modeless links. This mirrors the key parameter's documented
  philosophy; if it proves surprising in practice, a transient override is the
  fallback design.
- The ensemble badge is launch scope (adopted from the plan): naming changes
  globally in ensemble, and a forgotten toggle must not read as a broken
  analyzer.

**Next.**

- Phase 5: chord recognition algorithm article (templates, prices, rules, and
  the new mode), /try page mode control plus web bundle regeneration, CHANGELOG
  and whatsnew, closing entry.

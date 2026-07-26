# 2026-07-25: Phase 5 documentation and initiative close

**Goal.** Complete the documentation contract and close the initiative: the
algorithm article, the /try page mode control, release notes, and the final
status.

**Setup.** Documentation and site work only; no engine, app-logic, or
measurement changes.

**What happened.**

- **Algorithm article** (`docs/site/articles/chord-recognition-algorithm.html`,
  required by the NOTE comments in the engine): the no-ghost-roots passage now
  scopes itself to solo analysis and links to a new "Ensemble mode: implied
  roots" section covering the failure mode, why the mode must be explicit, the
  generation restrictions, the pricing changes, the hard-rule preference with
  its off-idiom exception, the dominant tiebreak, and the measured numbers. The
  tie-breaker list gains the implied-root dominant rule in its real position,
  and the cache-key discussion now includes the playing mode.
- **/try page**: a Solo/Ensemble segmented control wired to the engine's new
  mode argument; the `mode=ensemble` URL parameter round-trips through the
  copy-link and open-in-app flows (matching the app's link grammar), the results
  echo shows the mode, and the social-preview worker passes the mode through and
  notes it in the description. The playing mode is deliberately not persisted on
  the web page; a fresh visit is solo.
- **Release notes**: CHANGELOG entry under Added and the whatsnew bullets.
- The web bundle (`docs/site/js/chord-id.js`) still needs regeneration from the
  updated `tool/web/chord_id_main.dart` before release, per the usual build
  flow.

**Decisions.**

- The initiative is complete: all five phases landed, with the acceptance suite
  in CI, corpus accuracy measured and held-out confirmed (entry 2026-07-25-03),
  and the product surface shipped (entry -04). The README statuses (this
  initiative and the research index) now say so.
- Remaining known follow-ups are recorded as future leads, not open work:
  local-key detection improvements lift ensemble accuracy directly (the
  chord-context handoff to a WhatKey initiative), a hollow implied-root key on
  the keyboard is deferred polish, and a true jazz-comping corpus would confirm
  the classical-synthesis numbers.

**Next.**

- None; the initiative closes with this entry. Future ensemble work starts a new
  dated entry (or initiative) rather than reopening this one.

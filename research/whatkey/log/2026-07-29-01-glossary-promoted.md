# 2026-07-29: The glossary is promoted to the archive root

**Goal.** Make the measurement vocabulary reachable from every initiative rather
than only from WhatKey, as part of making `research/` navigable for a reader who
did not write it.

**Setup.** Documentation change only: no detector, fixture, scoring, or
evaluation code was touched, and no recorded number changes.

**What happened.** `research/whatkey/GLOSSARY.md` moved to
`research/GLOSSARY.md`. Roughly half its entries (ablation, development and
held-out splits, paired statistics, p-value, one-shot evaluation, bootstrap
CI95) were never WhatKey-specific, and the later initiatives had no glossary to
link at all.

Mechanical updates, following the precedent in entry 2026-07-13-01, so every
reference stays correct from a fresh checkout:

| File                                  | Change                                 |
| ------------------------------------- | -------------------------------------- |
| `research/README.md`                  | `whatkey/GLOSSARY.md` to `GLOSSARY.md` |
| `whatkey/README.md`                   | two links to `../GLOSSARY.md`          |
| `whatkey/PROTOCOL.md`                 | link to `../GLOSSARY.md`               |
| `whatkey/log/README.md`               | link to `../../GLOSSARY.md`            |
| `whatkey/log/2026-07-07-04`, `-07-08` | links to `../../GLOSSARY.md`           |

The glossary's own outbound link to the design doc was repointed to
`whatkey/temporal-context-key-detection.md`. The file's title and preamble now
name the archive rather than WhatKey, and say that each initiative's PROTOCOL.md
is normative for its own rules.

Nothing that packages the paper is affected: `tool/whatkey/zenodo_bundle.sh`
bundles only `paper/main.typ` and `paper/main.pdf` from the release tag, and
`paper/main.typ` never referenced the glossary.

**Content corrections and additions in the same pass.**

- **Warmup was stale.** It stated the detector abstains until it has seen a
  minimum number of events "(currently 3)". The shipped HMM has used
  `defaultMinEvents = 1` since the whatkey-local adoption in entry
  `whatkey-local/log/2026-07-26-14`. The entry now records all three facts: the
  HMM ships 1, the paper recipes pin 3 so the frozen results reproduce, and the
  older pre-HMM detectors keep 3 as their default.
- **Twelve entries added** for vocabulary the later initiatives use without
  definition anywhere: adoption bar, attribution arm, exposure weighting, golden
  test, near-tie window, pre-declaration, ruler, segmenter, shell omission,
  stability metrics, superset absorption, and top-1 exact. `Ruler` was the most
  conspicuous gap; it appears in every initiative and had never been defined.
- **Event** gained a pointer to `Segmenter`, since what commits an event was
  previously left implicit.
- **Entries carrying verdicts were trimmed to a consistent rule.** Several
  existing entries recounted how a mechanism was measured (confidence weighting
  "tested repeatedly and never helped", BOCPD, duration weighting, the two
  blends, hysteresis, mode tilt, profile pair). The rule applied throughout:
  keep what the thing is, what it does, and whether it is in the shipped system;
  drop how we found out and any tuned value; keep a pointer to the log. The
  findings live in the logs, where they can be corrected.
- **Log references became real links.** All eleven were bare text naming a date,
  which asked the reader to go hunting. They now resolve, including the
  whatkey-local reference that had been a backticked path, which is the file's
  first cross-initiative link.

**Decisions.**

- The glossary is archive-scoped from here. New initiatives link to
  `../GLOSSARY.md` rather than defining measurement terms in their own READMEs.
- Terms that are conventional music theory (rootless voicing, implied root) stay
  out; the glossary covers measurement and internal engineering vocabulary, not
  harmony. Idioms that read fine in context (blast radius) stay out too.
- Entries name whether a mechanism is on, off, or unadopted, but not the value
  it is tuned to. Constants live in code and in the logs that set them, and
  duplicating them here is what let Warmup sit stale. Warmup itself is the one
  exception, since an entry that will not say what the minimum is has explained
  nothing; it now links the log that changed the value.

**Next.** Standardize the six non-WhatKey initiative READMEs onto a shared
skeleton, linking the glossary rather than re-explaining terms.

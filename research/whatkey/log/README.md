# WhatKey Log

Dated entries recording what was tried, what happened, and what was decided. The
goal is that a newcomer (or a future methods section) can reconstruct the
project's reasoning without combing through git history.

## Conventions

- One file per working session, experiment, or significant decision:
  `YYYY-MM-DD-NN-short-slug.md`, where `NN` is a zero-padded sequence number for
  that date. Multiple entries on one day increment the sequence so directory
  sorting preserves the order decisions were made.
- Entries are append-only. If a conclusion turns out to be wrong, write a new
  entry that corrects it and links back; do not rewrite the old one.
- Record enough to reproduce: engine commit, fixture version, and the exact,
  copy-pasteable commands, verbatim in a fenced block in Setup, not paraphrased
  ("the standard dev run" is not a command). Harness reports and claims files
  also embed their own generating command, so a report found in `build/` is
  self-documenting. "It worked better" without numbers and pins is not an entry.
- Negative results and dead ends get entries too; they are the part git history
  is worst at preserving.
- Link measurement terms to [../../GLOSSARY.md](../../GLOSSARY.md) instead of
  re-defining them, following the linking rule stated there.
- When an entry leans on heavy technical jargon, statistics, or math, include a
  **Plain-English reading** section (after Results/Reading, before Decisions)
  that interprets that entry's specific numbers for a reader without the
  background: what the result means, not just what it measures. Entries
  2026-07-07-01 and 2026-07-07-04 are the pattern to follow.

## Entry template

```markdown
# YYYY-MM-DD: Title

**Goal.** What question this session tried to answer.

**Setup.** Engine commit, fixture version, corpus pins, parameters.

**What happened.** Actions and results, with numbers.

**Plain-English reading.** (When the entry is jargon- or statistics-heavy.) What
the numbers mean for a reader without the background.

**Decisions.** What was decided and why, including alternatives rejected.

**Next.** Open threads this creates or closes.
```

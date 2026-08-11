# 2026-08-11: Record the failed development-exposure attempt

**Goal.** Run the single designated development exposure from its committed
premeasurement boundary, verify its provenance and accounting, and only then
inspect selector outcomes.

**Setup.** The repository was clean at implementation commit `4cad7720`. The
designated output directory was absent. ASAP was clean at commit
`afc815c75c42e83a79c03feb6da8a35e77d4c6b8`, and POP909 was clean at commit
`d83e6edba6872a704f5d3b8b32f5cb540088dae6`. The exact command was:

```sh
./.venv/bin/python tool/polychord/development_exposure.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory \
    build/polychord/register-selector-development-exposure-v1
```

The correction was verified with:

```sh
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover -s tool/polychord -p '*_test.py'
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/development-exposure-v1.md \
  research/polychord/log/2026-08-11-10-development-exposure-failed-attempt.md
git diff --check
```

**What happened.** The harness wrote all 23 ASAP piece reports, all 101 POP909
sample-piece reports, and the first When in Rome piece report. It then stopped
before receiving the second When in Rome result because that fixture's event 1
contained `[49, 49, 64, 68]`, while the Dart boundary correctly required a
strictly increasing pitch set. No corpus summary, review packet, or manifest was
written. Selector outcomes in the partial piece reports were not inspected.

The 125 partial files are preserved locally, unchanged, at
`build/polychord/register-selector-development-exposure-v1-failed-attempt-1`.
The SHA-256 of the compact JSON inventory of relative path and file SHA-256
pairs is `0fe00cc2b3886f15fb6574bfe4a3ecf664ab9fb34e50c91de6d0d36979753468`.

A source-only audit of all 3,694 permitted When in Rome development events found
597 events in 40 pieces with repeated voice occurrences at an identical MIDI
pitch, comprising 625 occurrences to collapse. No event's MIDI list was out of
order. The committed fixtures preserve voice occurrences, whereas WhatChord's
channel-blind analysis boundary observes a sorted, distinct pitch set.

The corrected projection made all 3,694 permitted development events valid
strictly increasing pitch sets. The expanded duplicate-and-ordering regression
passed as part of all 261 polychord Python tests. Python formatting and lint,
Markdown formatting, and whitespace validation also passed. The first sandboxed
test attempt could not update the externally installed Flutter SDK cache; the
identical suite passed after Codex granted that external cache access.

**Plain-English reading.** The measurement did not produce a valid result. It
exposed an adapter mismatch before the outcome could be finalized: a score may
have two voices sounding the same piano key, but WhatChord represents that as
one sounding pitch. Treating the repeated occurrence as an extra analyzer note
would misstate the live product input.

**Decisions.** Keep the partial attempt as a failed artifact and do not derive a
selector conclusion from it. Project each When in Rome event to sorted, distinct
MIDI pitches before Dart analysis. Record the source occurrence count, analyzed
distinct-note count, affected-event count, and collapsed-occurrence count in
every piece report. Add a synthetic duplicate-and-ordering regression and commit
the correction before rerunning the designated output path.

This is an input-representation correction, not a selector lever or an outcome-
driven change. The four frozen selector profiles, primary analyzer, development
roster, stable-display reducer, and adoption bars remain unchanged.

**Next.** Commit this corrected premeasurement boundary, rerun the same
designated command, and perform manifest and accounting checks before reading
any selector summary.

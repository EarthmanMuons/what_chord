# 2026-08-11: Fix the internal-suite evaluation harness

**Goal.** Fix the complete prediction, cross-implementation comparison, scoring,
and provenance path before generating or reading any result from the frozen
author-adjudicated adoption suite.

**Setup.** Work began from clean repository commit `1cd51044`, which contains
the preregistered selector and its independently cross-checked Python and pure
Dart implementations. No frozen-suite prediction or score, development-corpus
selector result, prior-art baseline result, or held POP909 item was generated or
read during this step.

## Evaluation path

`tool/polychord/internal_suite_evaluation.py` defines one deterministic run for
the full selector and all three preregistered leave-one-component-out ablations.
It performs the following operations in order:

1. validates the exact frozen suite and every pinned dependency;
2. extracts registered notes from snapshots and exact pinned replay frames
   without supplying product expectations, construction assignments, source
   labels, eligibility judgments, or primary alternatives to either selector;
3. obtains every complete Python and Dart decision document and refuses to
   continue on any decoded-document mismatch;
4. writes a complete diagnostic artifact retaining every evaluated frame,
   structural candidate, selector trace, and raw decision;
5. writes one scorer-compatible prediction artifact for each fixed selector;
6. invokes the already-frozen exact scorer once for each of those four
   preregistered artifacts; and
7. writes every per-case score plus a manifest containing the command, working
   directory, repository state, runtimes, suite and dependency pins, replay
   fixture pins, implementation pins, output hashes, and the explicit statement
   that no corpus split or held POP909 data applies to this run.

The output directory must not already exist. A failed or partial attempt is
therefore preserved rather than silently overwritten; a later attempt must use a
new path and be disclosed.

## Replay-window decision fixed before scoring

A single-frame replay observation is an exact adjacent-register snapshot and is
evaluated normally. A bounded replay window is not one simultaneous snapshot.
The harness evaluates and retains every constituent frame, but its case-level
`adjacentRegisterSnapshot` prediction abstains with `missing-register-evidence`.
It never verticalizes the union of notes or chooses one frame after inspecting
its result.

This affects the Petrushka rehearsal-49 coverage case only. That case was
already frozen as ineligible and is excluded from adjacent-register positive
recall, so the mapping cannot change any gate. Fixing it now nevertheless keeps
the complete prediction artifact interpretable and prevents a later evaluator
from manufacturing an aggregate sonority.

## Pre-result controls

The new unit controls use only synthetic notes and fixtures. They cover all four
selector identifiers and unique filenames, exact snapshot and replay-window
extraction, scorer-candidate projection, selector abstention preservation,
window abstention, all-frame and all-profile accounting, and refusal on one
Python/Dart field difference.

A synthetic six-note frame was also sent through the actual persistent Dart
adapter. All four profile decisions were returned. This exercised the process
boundary without loading a frozen-suite observation.

The controls were run with:

```sh
python3 -m unittest discover -s tool/polychord \
  -p 'internal_suite_evaluation_test.py'
mise python:format
mise python:lint
python3 -m unittest discover -s tool/polychord -p '*_test.py'
./.venv/bin/python -c \
  'import sys; sys.path.insert(0, "tool/polychord"); import internal_suite_evaluation as h; frames=[{"id":"synthetic/snapshot","midiNotes":[48,52,55,66,70,73]}]; result=h.dart_decisions(frames); print(len(result), len(result["synthetic/snapshot"]))'
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/log/2026-08-11-06-suite-evaluation-harness.md
git diff --check
```

All eight focused controls and all 246 polychord Python tests passed. Python
formatting and lint passed. The synthetic Dart process check returned one frame
and four profile decisions. The managed Codex filesystem sandbox initially
denied access to mise's and Flutter's external caches; the identical commands
passed after narrowly scoped approval. This was not a nono boundary.

Final SHA-256 pins:

- evaluation harness:
  `ad53dea92d26d5d4e4ee6ba56aba63e9f2bd45c26cf115991ae155ec6c16f9cc`;
- focused controls:
  `3e3826e44c8514257a50b35ecbc07d095760fa3bc586a6d05c72b7e4bbde96ee`;
- protocol: `635dddc39740527bc84b28ffa3d90310e6796ad58a53b716237d530782df610f`;
- unchanged preregistration:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`;
- unchanged frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- unchanged exact scorer:
  `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9`;
- unchanged Python selector:
  `e72d97326abb36e03418be7c41b98305ca3f756d530787e288758d26f2d2e1e7`; and
- unchanged Dart selector:
  `b362196dfe29ee95e19f7fe5888d94459662436dd5573ec94319da59d7c0a0ca`.

**Plain-English reading.** The next command will reveal whether the fixed rule
agrees with our frozen musical policy cases. Before allowing that result to
exist, we now have a reviewed, tested path that prevents the labels from
entering either implementation, checks both implementations again on the exact
suite frames, retains every decision and score, and refuses to overwrite an
attempt.

**Decision.** Commit this harness and record as a pre-measurement scientific
boundary. Keep the frozen suite, scorer, selector, and held reserve unchanged.

**Next.** From a clean commit, run exactly:

```sh
./.venv/bin/python tool/polychord/internal_suite_evaluation.py \
  research/polychord/data/internal-suite/suite-v0.json \
  --out-directory build/polychord/register-selector-suite-v1
```

Retain and hash every generated artifact, record every per-case result, and do
not alter `polychord-register-policy/1` in response to the score.

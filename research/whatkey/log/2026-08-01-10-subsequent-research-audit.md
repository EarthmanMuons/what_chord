# 2026-08-01: Subsequent-research and frozen-system audit

**Goal.** Determine which work completed after the TISMIR portal submission must
change the revised manuscript, which work may be mentioned only to qualify an
existing claim, and which work is outside the paper. Preserve the frozen
paper-era detector and result record unless a later result is necessary to keep
the manuscript accurate.

**Setup.** This was a read-only provenance and claim audit, not a detector run.
The repository was at `73eb2f25b69aab34ce7e5052f3259071d8a62d7a`. The baseline
is the anonymous v2026.7.15 portal manuscript derived from release v2026.7.14;
v2026.7.30 is the revision starting point because it contains the separately
logged ASAP-When in Rome label correction. The six completed post-submission
initiatives listed in `research/README.md` were reviewed against the manuscript,
their protocols and summaries, relevant dated logs, the frozen detector recipe,
and current runtime defaults.

Representative audit commands were:

```sh
sed -n '1,230p' tool/whatkey/src/detector_recipe.dart
sed -n '1,220p' packages/whatkey/lib/src/models/key_behavior.dart
sed -n '1,140p' lib/features/key/providers/key_behavior_notifier.dart
rg -n 'defaultCadenceBoost|defaultMinEvents|defaultFunctionalBlend|defaultProgressionBlend|defaultModeTilt|defaultEmissionHalfLife' packages/whatkey/lib/src/detectors/hmm_key_detector.dart
rg -n 'live|application|performed exactly once|progression rules|cadential|margin|abstain' research/whatkey/paper/main.typ
sed -n '1,125p' research/whatkey-local/README.md
sed -n '1,105p' research/whatkey-local/PROTOCOL.md
sed -n '1,165p' research/performed-input/README.md
rg -n 'A1|closed.loop|neutral|exact|held-out|key detector|feedback' research/performed-input/log research/performed-input/README.md
```

The historical reproduction boundary was checked against WhatKey logs
`2026-07-20-01-historical-reproduction-contract` and
`2026-07-30-01-runtime-defaults`. The later detector mechanisms were checked
against WhatKey Local logs `2026-07-26-02` through `2026-07-26-18` and the
`2026-07-27-01` blend retest. The coupled replay was checked against Performed
Input logs `2026-07-27-12` and `2026-07-28-13`.

**What happened.**

## The paper and current application are distinct systems

The named recipes preserve the reported detector exactly. Current application
defaults have intentionally moved:

| Setting or boundary          | Frozen paper configuration                               | Current application behavior                               |
| ---------------------------- | -------------------------------------------------------- | ---------------------------------------------------------- |
| Evidence half-life           | 30 s selected configuration; 1 s comparison              | User presets at 30/4/1 s; new installations default to 4 s |
| Minimum events before claim  | 3                                                        | 1                                                          |
| Cadence-conditioned boost    | 0                                                        | 4                                                          |
| Functional/progression blend | 0/0 in selected system; functional 0.1 in 1 s comparison | 0/0                                                        |
| Same-tonic mode tilt         | 2                                                        | 2                                                          |
| Chord-analysis profile       | `whatKeyPaper2026`                                       | `current`                                                  |

The reproduction lock proves that the current repository can regenerate all
paper-era fixtures and all nine frozen result directories. It also proves why
the manuscript must call this a frozen evaluated configuration rather than the
current shipped detector. In particular, the paper's 30-second configuration is
no longer the application's default behavior, even though it remains the
user-selectable `stable` preset.

One methods omission is now visible. `whatKeyPaper2026` pins `minEvents: 3`, so
all reported runs prohibited a claim on the first two events. The manuscript
currently says that the 0.3 posterior margin governs whether the detector
claims, without stating this additional gate. The revision must specify both.
The later removal of the gate does not require replacing any paper number.

## Later cadence work narrows, but does not reverse, a negative result

The paper's progression layer is a broad, decaying event-history score blended
into the HMM's emissions. The later `cadenceBoost` is a different mechanism: it
redistributes transition probability only after a completed, narrowly gated
dominant-seventh-family resolution, and it excludes ambiguous plain-major
triggers and dominant-quality targets that would break blues behavior.

The distinction is empirical as well as architectural. WhatKey Local's
post-adoption retest left the original progression blend at zero: on When in
Rome development data it traded `+0.0192` coverage for `-0.0157` exact per piece
(`p=0.169`) and produced blues and secondary-dominant regressions. The
functional blend still helped the classical local-key ruler but collapsed both
blues fixtures to zero exact. Those findings reinforce the repertoire limitation
and preserve the measured negative for the specific emission-side blends. They
do not support the manuscript's broader phrases “progression rules” or
“cadential rules” as statements about all ways harmonic motion can be used.

The later cadence results must not be promoted into the paper's frozen
confirmatory record. They were developed after the paper's test results were
known, and their final held-out package reused the same designated test pieces.
Moreover, cadence strength 4 was adopted as an explicit product trade after it
failed the original Isophonics guard: the dated decision amended the guard for
that adoption, while the frozen protocol document still says “Amendments: None.”
The logs preserve the decision honestly, but it is not suitable evidence for
upgrading this paper's headline.

The revised paper should therefore name the tested decaying progression-score
emission blend precisely and add at most one short discussion or limitation
sentence distinguishing it from subsequent cadence-conditioned transition work.
No later accuracy table or held-out number belongs in the results.

## “One-shot” needs a temporal boundary

The original paper-era result set was executed once under its predeclared
protocol. Subsequent WhatKey Local work later reused the same test pieces in a
separately predeclared product-development package. That reuse does not
retroactively change the original results, but after resubmission it is no
longer literally true that the test splits have only ever been evaluated once.
The revision must scope the claim to the original confirmatory result set and
must not use later test results to strengthen it post hoc.

## The performed-input path supports a narrower live claim

The paper's ASAP and ASAP-When in Rome fixtures begin with recorded performed
MIDI. Offline replay applies sustain semantics, the production chord analyzer,
the three-note capture gate, and the production event segmentation core. The
detector then consumes the stored chord-recognition events in causal timestamp
order. This establishes evaluation on replayed performed MIDI through the core
analysis/capture path and demonstrates algorithmic compatibility with streaming
operation.

It does not exercise a musician interacting with the product, MIDI or BLE
transport, Flutter provider and timer scheduling, wall-clock processing latency,
the display, or usability. It therefore cannot establish live-user accuracy or
usefulness. “Live” remains appropriate for the motivating use case; the
evaluation should be described as causal streaming evaluation on offline replay
of recorded performed MIDI.

Performed Input's `0.551` held-out figure is chord-name agreement with a Roman
functional analysis, not key-estimation accuracy, so it is outside this paper.
Its A1 arm does partially answer a future-work sentence in the submitted paper:
the current detector was placed inside the replay loop and its claims fed back
to subsequent chord analysis. On held-out data, A1 stable/balanced/reactive
chord-name exactness was `0.559/0.556/0.557` versus neutral A0 at `0.551`, all
within the predeclared 0.01 band. This later experiment says that coupled key
feedback had little effect on chord-name agreement under replay. It does not
measure whether that feedback changes key-tracking accuracy. The manuscript's
open question should be removed or narrowed accordingly, without importing the
numbers as paper results.

## Six-initiative disposition

| Initiative        | Relationship to the submitted paper                                                       | Disposition                                                                |
| ----------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| WhatKey Local     | Changes runtime defaults and exposes overbroad progression, warm-up, and one-shot wording | Required scope and methods corrections; no later headline numbers          |
| Performed Input   | Audits the replay boundary and partly executes the proposed coupled-feedback follow-up    | Use to narrow live and future-work claims; exclude its chord-name headline |
| Chord Context     | Later chord-ranking changes can alter fresh fixtures                                      | Outside the results; cite only through the frozen reproduction boundary    |
| Ensemble Mode     | Adds manually selected rootless-chord naming                                              | Outside this key-estimation paper                                          |
| Ensemble Tiebreak | Changes candidate admission and ranking for rootless jazz chords                          | Outside this key-estimation paper                                          |
| Tone Pricing      | Changes chord labels for a narrowly bounded omission case                                 | Outside this key-estimation paper                                          |

The overview documents also need synchronization after the manuscript wording is
settled. `research/README.md`, `research/whatkey/README.md`, and
`research/whatkey/CONTRIBUTION.md` repeat “at least parity” and stricter-task
language rejected by the offline-comparison audit.
`research/whatkey-local/README.md` repeats “strictly easier” and “parity or
better.” Append-only dated logs remain unchanged; editable summaries should
eventually match the revised claims.

**Plain-English reading.** The newer system does not belong in this paper. It
does, however, show exactly where the submitted wording confused a frozen
experiment with a living application. Keeping the old detector is the cleaner
and more defensible choice: state its complete recipe, describe the replay
boundary honestly, narrow negatives to the mechanisms actually tested, and do
not use later work to rescue or enlarge the paper's claims.

**Decisions.** Keep the paper-era detector, fixture profile, and result set as
the study object. Add the omitted three-event claim gate. Treat 30 seconds as
the study's selected section-scale operating point, not the current app default.
Limit “one-shot” language to the original predeclared result set. Replace broad
progression-rule negatives with the exact emission-blend mechanism, and include
at most one concise note distinguishing subsequent transition-side work. Narrow
live claims to causal streaming evaluation on replayed performed MIDI and state
that no live musician-interaction study was performed. Narrow or remove the
now-partly-executed closed-loop future question. Exclude all later headline
numbers and the four unrelated chord-naming initiatives. No additional detector
experiment is needed for this integration decision.

**Next.** Resolve the paper's claim architecture using the completed literature,
reference-provenance, controlled-analysis, offline-comparison, and subsequent-
research audits. Write one central claim and align the title, abstract,
contribution hierarchy, limitations, and conclusion before making local prose
edits. Update the editable research summaries after the manuscript's final claim
wording is stable.

# What WhatKey Contributes

> **Archival status, 2026-08-02:** This document preserves the public preprint's
> original contribution framing. A later audit concluded that the central
> reference-dependent ranking result is valid but insufficiently novel for
> further publication effort, and that the offline table supports descriptive
> context rather than a parity claim. See the
> [current project status](README.md#project-status) and
> [publication-closure record](log/2026-08-02-01-close-publication-path.md).

This note is a historical plain-English companion to the preprint. It is not the
normative record of experiments; the paper, protocol, logs, and committed result
artifacts remain the source of truth. The discussion below is retained to show
how the project was framed before the final novelty audit.

## Short version

WhatKey is not primarily a claim that a new key-detection architecture beats the
field. The selected detector is intentionally conservative: a causal hidden
Markov model (HMM) over profile-correlation evidence, with abstention and one
carefully constrained mode cue.

The contribution is the task definition, measurement discipline, and empirical
characterization around that detector. The paper claims five things, in this
order:

- a task definition and evaluation protocol for streaming key estimation with
  abstention, where coverage, stability, modulation lag, and posterior
  reliability are first-class measurements;
- a fixture-based reproducibility design with frozen splits and one held-out
  evaluation;
- evidence that key-detection scores only mean something once the task says
  which timescale of key should count as correct;
- an empirical map of symbolic and temporal additions: one adopted mode cue, and
  measured negative results showing which plausible additions do not help this
  setting;
- a validated interpretable baseline: a causal, abstaining HMM that reaches at
  least parity with standard offline whole-piece key finders on held-out data,
  with an honesty-checked confidence display.

That combination is useful even if the final algorithm is simple.

## What problem is being studied?

Most key-detection work asks for a key after a system has seen a complete score,
recording, or symbolic sequence. WhatKey studies a stricter interactive problem:
a musician plays a MIDI keyboard, an upstream chord recognizer emits ranked
chord hypotheses, and the key detector must update after each chord without
seeing the future.

That changes the evaluation. A live key indicator should not only be "accurate"
in the abstract. It should also know when not to answer, avoid flickering
between keys, catch real key changes with reasonable lag, and expose whether its
confidence number can be trusted. The paper's protocol makes those requirements
measurable.

## What is scientifically new?

The strongest contribution is the evaluation framing. The paper defines a
causal, streaming, abstaining key-estimation task and evaluates it with metrics
that match the task: coverage, accuracy on claimed events, MIREX-weighted near
misses, modulation matching and lag, spurious switches, time to first claim,
paired statistics by piece, and posterior reliability diagnostics.

The second major contribution is the timescale finding, measured across pop and
classical corpora (Isophonics, When in Rome, ASAP) whose annotations encode
different kinds of key. A short memory follows brief local-key assertions; a
longer memory absorbs those excursions and reports the stable section key.
Neither setting is simply "more accurate" by itself. Each comes out ahead when
scored on the kind of key it reports, even on the same recordings. This means a
key-detection score is under-specified unless the task says whether brief
tonicizations or the broader section key count as the right answer.

The third contribution is reproducibility discipline. Fixtures are generated
from real app chord-recognition output under a neutral context, labels are
stripped before detector calls, splits and provenance are versioned, gated
corpora are rebuilt locally rather than committed, and the held-out result set
was declared before running.

## Is the final detector special?

Special, but not revolutionary.

HMMs over key-profile emissions already exist, and the paper says so. WhatKey's
detector is special because of the operating constraints and the measured
adaptation to them:

- it runs causally by forward filtering, not offline Viterbi decoding;
- it consumes chord-recognition events rather than ground-truth notes or audio
  chroma;
- it abstains using a posterior-margin floor;
- it reports stability and key-change behavior, not just key accuracy;
- it uses duration-weighted profile evidence;
- it adds one mass-preserving same-tonic mode cue that can help choose C major
  vs. C minor without moving evidence toward unrelated keys;
- it calibrates displayed confidence without changing rankings or claims.

The method should be read as a strong, interpretable baseline for this stricter
task, not as a new general-purpose MIR model. Its value is partly that it got
simpler as the measurements accumulated.

## Why do the negative results matter?

The negative results are not filler. They rule out attractive stories.

Because the input includes chord identities, it was natural to expect
key-relative chord-function rules, cadential progression rules, and
recognizer-confidence weighting to improve the detector. Some of that extra
information did help early local-key experiments. But for the selected
section-key task, most of it either washed out or made the system worse:

- functional chord evidence helped local-key tracking but hurt section-key
  stability and misread blues harmony;
- progression evidence helped an older architecture but was inert under the HMM;
- recognizer-confidence weighting did not help in any tested setting;
- relative-mode cues were too weak and unstable to adopt;
- BOCPD caught more changes but produced more false section-key switches;
- explicit dwell tuning mostly moved along the same coverage-accuracy frontier.

Those results are useful because they prevent a plausible but overcomplicated
system from being mistaken for progress.

## What did chord-recognition output actually buy us?

It bought the task and the experimental questions more than it bought the final
section-key model.

The upstream recognizer makes WhatKey's setting different: the detector sees
ranked chord identities, costs, voicings, bass, roots, qualities, and durations
from the same stream the app sees. That richer input motivated many reasonable
hypotheses. The measurements then showed that, for a stable section-key
indicator, the final detector mostly wants duration-weighted pitch-profile
evidence plus the constrained same-tonic mode cue.

That is still a result. It says that much of the extra chord-identity-specific
information is not load-bearing for the section-key product target, even though
some of it matters when the target shifts toward local-key tracking. The later
stable/balanced/reactive product exploration reaches a similar conclusion: once
the detector class is fixed, the useful user-facing behavior modes are mainly
emission-memory and display-calibration settings, not a proliferation of
symbolic rules.

## What can other people reuse?

A reader can reuse several pieces without adopting the whole app:

- the selective-prediction evaluation frame for key estimation with abstention;
- the fixture design for testing a streaming detector on stored event streams
  without leaking labels;
- the paired-statistics discipline for detector adoption decisions;
- the label-timescale warning when comparing local-key and section-key corpora;
- the causal HMM baseline with posterior-margin abstention;
- the mass-preserving mode-cue pattern: add symbolic evidence only inside a
  musically invariant pair when the cue should not affect the broader key
  choice;
- the negative-result map of which additions were not worth carrying forward.

## What should not be claimed?

The paper should not be read as showing that WhatKey is the best key detector in
general. It does not compare against every modern offline score-analysis system,
does not train a neural model, and does not claim that section-key annotations
are more correct than local-key annotations.

The defensible claim is narrower and stronger: under live-style, causal,
abstaining constraints, a simple measured HMM reaches at least parity with
standard offline whole-piece baselines on held-out pop-song fixtures (the one
held-out split with a like-for-like offline baseline; the classical splits test
generalization), while making visible the abstention, stability, calibration,
and label-timescale tradeoffs that ordinary key-finding evaluations often hide.

## Bottom line

The work contributes less by inventing a surprising algorithm than by making a
messy real-time MIR task measurable. It shows that the main question is not just
"which detector is most accurate?" but "what kind of key is the detector being
asked to report, under what latency and abstention constraints, and what should
count as correct?"

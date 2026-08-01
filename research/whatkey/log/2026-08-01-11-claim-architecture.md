# 2026-08-01: Fix the revised paper's claim architecture

**Goal.** Synthesize the literature, reference-provenance, experiment-arm,
revision-analysis, offline-comparison, and subsequent-research audits into one
central claim and an explicit evidence hierarchy before revising the title,
abstract, or conclusion.

**Setup.** This is a scientific framing decision, not a new experiment. The
repository was at `c3fa3da43b1b8eb05a88e6f1890b94488035dd8d`. The decision uses
the frozen paper results and the predeclared revision analyses recorded in
WhatKey logs `2026-08-01-01` through `2026-08-01-10`. No detector configuration,
fixture, split, claim stream, threshold, or reported result changed in this
entry.

The relevant manuscript and audit material was reviewed with:

```sh
rg -n '^### E0a|^### E1a|^### E1b|^### E1c|^### S2|^### S4|^### Provisional central statement' research/whatkey/paper/scratchpad.revision.md
sed -n '405,525p' research/whatkey/paper/main.typ
sed -n '45,115p' research/whatkey/log/2026-07-07-22-filtered-mode-and-dose-response.md
sed -n '1,150p' research/whatkey/log/2026-08-01-05-overlap-segment-reanalysis.md
sed -n '1,260p' research/whatkey/log/2026-08-01-06-overlap-dual-reference.md
sed -n '1,260p' research/whatkey/log/2026-08-01-08-development-factorial.md
```

**What happened.**

## Central claim

The revised paper's one-sentence empirical claim is:

> The reference construct is part of the streaming key-estimation task: on fixed
> Beethoven performances, detector outputs, common claimed events, and a shared
> 12-class ontology, analyst-declared key contexts and active notated
> key-signature collections reverse the ranking of the same two frozen detector
> packages, one function-aware with short memory and one profile-based with long
> memory.

This wording names what R3 actually holds constant and what changes. It is
limited to the 36 overlap performances and two frozen detector packages. It does
not call either reference ground truth, does not treat the key signature as an
oracle, and does not attribute the reversal to temporal granularity alone.

The measured basis is substantial enough to support the claim. The two
references agree on only `0.6465` of events per piece. On 8,160 common claims,
paper-minus-reflex accuracy is `-0.0806` under analyst-declared contexts and
`+0.0796` under key-signature collections. The exploratory piece-level
difference of differences is `+0.1602`, CI95 `[+0.1184, +0.2046]`, and is
positive on 31 of 36 pieces. Those numbers and the shared 12-class mapping must
accompany the result; the interaction remains exploratory rather than a newly
retrofitted confirmatory test.

## Why this is not only bandwidth matching

The familiar bandwidth intuition says that a rapidly changing target will tend
to favor a more responsive estimator and a persistent target a smoother one. The
revised paper should acknowledge that intuition rather than claim it as a new
idea. Its empirical contribution is more specific:

- neither detector is retuned or rerun in R3;
- the performances, detector outputs, common-event mask, and label cardinality
  are fixed;
- two documented, musically valid reference constructs disagree on more than a
  third of events and reverse the model-selection conclusion; and
- the broader development evidence shows that both evidence memory and a
  harmonic-function ingredient have reference-regime-dependent value, not merely
  that one curve is smoother.

Thus the novelty is a controlled construct-validity result and its consequences
for evaluation and model selection, not the invention of incremental hearing,
causal key estimation, HMM smoothing, or a new detector architecture.

## Evidence hierarchy

| Level                            | Role in the revised paper                                           | Evidence and permitted claim                                                                                                                                                                                                                                                                     |
| -------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Primary                          | Controlled reference-construct result                               | R3: on fixed Beethoven performances and predictions, changing between analyst context and key-signature collection reverses the package ranking.                                                                                                                                                 |
| Supporting mechanism evidence    | Explain why reference choice affects model selection                | R4: on development data, memory and functional evidence have opposite simple effects across the When in Rome and Isophonics evaluation regimes when crossed independently. Report coverage and call the analysis exploratory; repertoire, observations, and reference practice remain entangled. |
| Supporting temporal evidence     | Relate detector behavior to reference persistence                   | R2: as the same analyst-reference corpus is restricted to longer-persistence segments, relative accuracy shifts from reflex toward paper, including on common claims. Do not claim a sharp 12-measure crossover or relabeling experiment.                                                        |
| Generalization check             | Show that the package ordering was not confined to development data | The original predeclared held-out package ordering reverses across the two reference corpora. Name the bundled memory/function difference, unequal coverage, exact contributing cohorts, and the fact that two within-regime tests are not a formal interaction test.                            |
| Method and artifact contribution | Make the study reusable                                             | A causal streaming evaluation protocol with selective prediction, stability, lag, frozen recipes, provenance, and reproducibility artifacts. The HMM is an interpretable experimental instrument and baseline, not the main algorithmic novelty.                                                 |
| Secondary context                | Bound rather than headline                                          | Classic music21 profile analyzers provide descriptive reference points only. Mechanism-specific negative ablations may remain selectively. Live use is motivation; the evidence is causal replay of performed MIDI, not a live-user study.                                                       |

## Benchmark implication

The broader implication is deliberately one step weaker than the controlled
observation: a streaming key-estimation score is not interpretable without the
reference's provenance, semantics, temporal persistence, and tonal ontology,
reported alongside the detector's information boundary and coverage. This is a
benchmark-reporting recommendation supported by the observed reversal, not a
claim that all datasets or repertoires will behave the same way.

The revision should use **reference-annotation regime** as the umbrella term. It
should reserve:

- **causal/online** versus **retrospective/whole-piece** for algorithmic
  information availability;
- **global** versus **local** for output temporal scope;
- **analyst-declared key context**, **time-aligned tonality region**, and
  **active notated key-signature collection** for the actual reference
  constructs; and
- **reference-segment persistence** for the quantity used in the segment
  analysis.

“In-time” belongs to the broader analytical and perceptual lineage. Both in-time
and retrospective analysis are valid tasks. “Section key” should not be used as
if it made Isophonics tonality regions and ASAP key signatures semantically
equivalent.

## Claims retired or subordinated

- Retire “evidence memory selects which kind of annotated key the detector
  reports” as the central causal formulation. Memory response differs across the
  studied regimes, but their repertoire, observations, and reference
  construction also differ.
- Retire “only annotation timescale changed,” “same recordings relabeled at
  different granularities,” and the claim that the segment figure isolates a
  crossover threshold.
- Replace “strictly falls,” “only falls,” and a universal “no interior optimum”
  with the observed sweep: When in Rome accuracy declines strongly to a
  15-second minimum and partially rebounds, while Isophonics rises to a broad
  plateau from 8 seconds. No one setting is favored by both regimes.
- Retire “at least parity,” “strictly harder,” and the affirmative live-
  application conclusion under the separately recorded comparison and system-
  boundary decisions.
- Narrow progression and other negative claims to the exact mechanisms tested.
- Do not use later detector results to improve the frozen paper's headline.

## Sufficiency decision

The evidence is sufficient for structural revision. No further detector run,
repertoire stratification, alternate-reference analysis, or inferential test is
needed before editing. The controlled R3 result directly answers the editors'
reference-source concern; R4 separates the paper's bundled detector knobs; R2
makes the segment result piece- and coverage-aware; R1 fixes the 24-state metric
cohort; and the literature/provenance audit supplies the historical and musical
limits.

Uncertainty should be primary for R2-R4. The full seven-point memory sweep may
remain as descriptive development evidence, but it does not need a new test at
every inspected dose. Its inferential weight should come from the predeclared R4
endpoint contrasts, not from adjectives about visual monotonicity.

**Plain-English reading.** The paper no longer needs to prove that long memory
tracks slow labels. It can show something more concrete and less inflated: two
legitimate answer keys applied to the same performances and unchanged detector
answers select different winners. The rest of the experiments show that this is
consequential for both a memory setting and a modeling ingredient, while the
limitations say exactly where repertoire and annotation practice remain
confounded.

**Decisions.** Make the R3 reference-ranking reversal the primary empirical
contribution. Use R4, R2, and the original held-out package reversal as
supporting evidence in that order. Present the causal abstaining protocol and
frozen HMM as the methodological instrument, not an algorithmic breakthrough.
Demote the offline table, live-use claim, and mechanism negatives. Use the
one-sentence claim above as the consistency test for the title, abstract,
contribution list, discussion, limitations, conclusion, and resubmission letter.

**Next.** Perform the structural manuscript revision. Start with an outline and
claim-location map, then rewrite the title, abstract, introduction, related
work, reference taxonomy, central-results narrative, limitations, and conclusion
as one coherent change. Only afterward handle the editors' local example,
abstention explanation, bibliography cleanup, and whole-paper tone pass. Update
editable research overview documents after manuscript claims are stable.

# 2026-08-01: Rebuild the manuscript around reference sensitivity

**Goal.** Implement the claim architecture from entry `2026-08-01-11` as one
coherent manuscript revision, then verify that the title, abstract, evidence
order, methods, limitations, conclusion, citations, and rendered PDF all state
the same qualified contribution.

**Setup.** This is a manuscript and bibliography change, not a new experiment.
The repository began at `aad862508370cdd2a8f8f7c01931bf2d50826215`, after the
R1-R4 analyses and the literature, reference-provenance, offline-comparison,
subsequent-research, and claim-architecture audits were committed. The detector
recipes, fixtures, splits, claim streams, thresholds, and result artifacts did
not change.

The revision used the existing audit record and was checked with:

```sh
sed -n '1,1120p' research/whatkey/paper/main.typ
sed -n '1,680p' research/whatkey/paper/refs.yml
rg -n 'section-key|local-key|ground truth|parity|live|one-shot|strictly' research/whatkey/paper/main.typ
mise research:whatkey-paper
pdftotext research/whatkey/paper/main.pdf - | wc -w
pdfinfo research/whatkey/paper/main.pdf
pdftoppm -png -r 120 research/whatkey/paper/main.pdf /private/tmp/whatkey-pdfs.HmkW5M/page
git diff --check
```

All ten rendered pages were visually inspected, with particular attention to the
new primary-result tables, the held-out table, section transitions, and the
bibliography.

**What happened.**

## Claim hierarchy and paper structure

The title is now **“Reference Definitions Reverse Detector Rankings in Streaming
Key Estimation.”** The abstract, introduction, central-results section,
limitations, and conclusion all lead with R3: on fixed Beethoven performances,
frozen detector outputs, 8,160 common claims, and a shared 12-class
diatonic-collection scoring ontology, analyst key contexts and active notated
key-signature collections reverse the long-versus-short package ordering. The
text reports the `-0.0806` and `+0.0796` contrasts, the `+0.1602` exploratory
difference of differences, its `[+0.1184, +0.2046]` interval, and the 31-of-36
positive piece interactions.

R4 follows as exploratory mechanism evidence, crossing 1/30-second memory and
0/0.1 functional blend independently with coverage beside exact accuracy. R2
then supplies piece-aware descriptive reference-persistence evidence without a
sharp threshold claim. The original held-out package reversal is explicitly a
generalization check: its two tests are not a formal interaction, the packages
bundle memory and function, and their coverages differ. The HMM and
selective-prediction protocol are the experimental instrument rather than the
main algorithmic novelty.

## Editorial concerns integrated

- The introduction and related work now place causal inference within the longer
  in-time analytical, perceptual, interactive, and real-time lineage, beginning
  with Weber, and state that retrospective and in-time readings are both valid.
- The data section distinguishes analyst-declared key context, time-aligned
  tonality region, and active notated key-signature collection. It separates
  provenance, semantics, persistence, repertoire, observation construction, and
  ontology rather than calling them two annotation cultures.
- Popular-music ambiguity is represented by the specific Am-F-C-G axis loop,
  with A-minor and C-major hearings, and by an explicit distinction between
  tonic ambiguity and answers outside the 24-state major/minor ontology.
- The metric definition now says that zero coverage leaves claimed-event
  accuracy undefined rather than perfect. The selective-prediction section
  explains that the 0.3 margin floor was selected on development data before
  held-out execution and evaluates it as a coverage-accuracy pair.
- “Streaming” is bounded to causal evaluation during offline replay of recorded
  performed MIDI. The text names the production analyzer, sustain semantics,
  three-event claim gate, and event segmenter while disclaiming a live-user,
  transport, latency, display, or usability study.
- The three music21 rows are now descriptive classic profile-correlation
  reference points. The paper removes parity, equivalence, noninferiority, and
  globally harder-task claims; it explains the different information and output
  forms and renames the restricted result a common-event-mask sensitivity
  analysis.
- The When in Rome reference is now the 2023 TISMIR corpus article. The
  bibliography adds verified historical, online-key, local-key, and
  popular-tonality sources, with repository URLs retained only where useful for
  data provenance.
- Colloquial and promotional phrases were replaced with direct statistical or
  methodological descriptions. The memory sweep is described accurately as a
  decline to 15 seconds with a partial rebound for When in Rome and a broad
  Isophonics plateau, not as strictly monotonic.

## Frozen boundary and correction disclosure

The paper names the 30-second and 1-second packages as frozen experiment
recipes, includes the paper-era three-event warm-up, and says they are not the
current application defaults. A single mechanism-scoped sentence distinguishes
the tested negative emission-side progression score from later transition-side
cadence work without importing later result numbers. The closed-loop future-work
claim was removed, and the original held-out execution is distinguished from
later reuse of some pieces.

The corrected ASAP-When in Rome transfer is disclosed directly: this project's
offset calibration changed 347 of 10,395 labels in 11 of 36 movements before
peer review, and every reported conclusion retained its direction. The
piece-aware R2 table replaces the historical pooled threshold figure as the
inferentially honest presentation.

## Metric-cohort correction caught during rendering audit

The first rewritten held-out table accidentally combined R1's corrected 38-track
Isophonics coverage/accuracy cohort with archived reference-dependent change and
spurious-switch columns from the 41-track report. Entry `2026-08-01-03`
explicitly says not to use the wholly modal tracks' nominal spurious counts as
evidence before that denominator is separately reassessed. The final table
therefore reports only coverage and exact accuracy, names the 38 scorable tracks
within the frozen 41-track split, retains the modal tracks as a separate
behavioral audit, and uses the corrected short-package coverage `0.7934` rather
than the archived all-track `0.7968`.

## Verification

The final manuscript compiles without warnings or missing citations. The PDF is
10 US-letter pages and 272,221 bytes. `pdftotext | wc -w` reports 7,281 words, a
conservative count that includes bibliography text and remains below the
journal's 8,000-word limit. Visual inspection found no clipped text, overlapping
elements, broken glyphs, or unreadable tables. Narrow table headers were
shortened after the first render to remove awkward label hyphenation.

**Plain-English reading.** The revised paper no longer asks readers to regard a
familiar HMM as the main breakthrough or to accept that “timescale alone” caused
every corpus difference. It makes the cleaner observation the audits support:
two defensible answer keys can score unchanged detector behavior differently
enough to choose opposite winners. The supporting experiments show why this
matters for design, and the limitations state what remains specific to these
performances, references, packages, and major/minor ontology.

**Decisions.** Use this structural revision as the base for the invited new
submission. Keep all R3-R4 revision inference explicitly exploratory, retain R2
as descriptive persistence evidence, and treat the original held-out package
tests as a separate generalization check. Do not restore a live-user claim,
offline parity claim, strict-monotonicity claim, or post-submission product
result during later polishing. Keep the held-out temporal metrics out of the
corrected cohort table unless their reference-dependent denominators receive a
separate declared audit.

**Next.** Commit the manuscript, bibliography, PDF, and this decision record as
one logical structural-revision checkpoint. Then synchronize the editable
WhatKey overview documents with the retired parity and timescale-only language.
After that, draft the new-submission cover letter and point-by-point editorial
response, including the post-submission alignment-correction disclosure, and
move scratchpad items from Edited to Verified only after response language and
manuscript locations are checked together.

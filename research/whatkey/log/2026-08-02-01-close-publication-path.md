# 2026-08-02: Close the WhatKey publication path

**Goal.** Record the decision to treat WhatKey as a completed engineering and
research archive without pursuing journal publication, together with the
literature correction, novelty assessment, valid outcomes, and ideas deferred
for future work.

**Setup.** This is a publication-scope decision, not a new experiment. The
repository was at `1e066b2128a33f8f7284d1ec82c8bb2da1a3358e` after the
narrative-compression pass. No detector configuration, fixture, split, claim
stream, reference label, metric, or result changed. The decision follows the
TISMIR editorial-stage decline and invitation to resubmit, the complete
reference and experiment audit, the controlled revision analyses, and a final
novelty stress test of the shortened manuscript.

## Newly located literature

The final stress test found several references that materially change how the
paper's central contribution should be judged:

- Oriol Nieto and Juan Pablo Bello, “Systematic Exploration of Computational
  Music Structure Research,” ISMIR 2016,
  <https://archives.ismir.net/ismir2016/paper/000043.pdf>. This study already
  demonstrates in another MIR task that changing the human reference can change
  algorithm rankings on the same material. It makes reference-dependent ranking
  a known evaluation phenomenon rather than a new general principle.
- Christof Weiß, Hendrik Schreiber, and Meinard Müller, “Local Key Estimation in
  Music Recordings: A Case Study across Songs, Versions, and Annotators,”
  IEEE/ACM TASLP 28 (2020), DOI <https://doi.org/10.1109/TASLP.2020.3030485>.
  This local-key study directly documents annotator disagreement and shows that
  many apparent system errors coincide with that disagreement.
- Çınar Gedizlioğlu and Kutluhan Erol, “A Regularization Algorithm for Local Key
  Detection,” Journal of Mathematics and Music 28(4) (2024), DOI
  <https://doi.org/10.1177/10298649241245075>. Its local-key dataset uses
  multiple expert annotators because modulation boundaries and key assignments
  are inherently ambiguous.
- Yiwei Ding, Yannik Venohr, and Christof Weiß, “An Evaluation Strategy for
  Local Key Estimation: Exploiting Cross-Version Consistency,” ISMIR 2025, DOI
  <https://doi.org/10.5281/zenodo.17706357>. This particularly close and recent
  work identifies dataset and annotator bias in single-reference local-key
  evaluation and proposes an annotation-free cross-version consistency measure.
- Christof Weiß et al., “Interacting with Annotated and Synchronized Music
  Corpora on the Dezrann Web Platform,” TISMIR (2025), DOI
  <https://doi.org/10.5334/tismir.212>. Its discussion treats annotation models,
  ambiguity decisions, and reference tradeoffs as information that corpus
  creators should already document explicitly.

The ISMIR 2025 paper should have surfaced during the earlier literature audit.
Its omission is recorded here rather than silently repaired after the
publication decision. Together these sources substantially weaken a broad
novelty claim based on showing that annotation choice affects evaluation.

## Novelty assessment

The revised paper's controlled result remains numerically valid. On the same 36
Beethoven performances, fixed detector outputs, common-claim mask, and shared
12-class representation, analyst-declared key contexts and active notated
key-signature collections reverse the ordering of the short- and long-memory
configurations. The measured interaction is not a mathematical tautology:
reference disagreement alone does not force any ranking reversal.

It is nevertheless too predictable and too well preceded to carry the paper as
its primary scientific contribution:

1. The two references deliberately answer different musical questions rather
   than providing competing measurements of one latent ground truth.
2. The two configurations were selected under development regimes aligned with
   those respective behaviors. Showing that the responsive configuration better
   fits the responsive analyst reference and the stable configuration better
   fits the persistent signature reference is an out-of-sample validation, but
   not a surprising discovery.
3. R4 shows that memory and functional evidence have opposite effects across the
   two development regimes, but repertoire, observation construction, reference
   provenance, and annotation practice remain confounded.
4. R2's shift toward longer memory on longer-persistence segments is consistent
   with familiar smoothing behavior and is mostly descriptive after the
   piece-aware correction.
5. The held-out reversal compares bundled configurations across corpora. The
   offline table is descriptive because the causal abstaining detector and the
   whole-piece analyzers receive different information and produce different
   output forms.
6. Once the mode, adaptive-model, calibration, and negative-result branches are
   removed, the selective-prediction protocol is not evaluated across enough
   independent systems or human outcomes to stand alone as a boundary-pushing
   methodological contribution.

Restoring the removed side investigations would add engineering detail and
useful negative evidence, but would not repair the central novelty problem. The
TISMIR editors' original concern therefore survives the revision even though the
manuscript is now more accurate, rigorous, and readable.

## What remains valid and useful

Closing publication does not invalidate the project. It produced:

- a working causal key detector with explicit abstention and measured behavior;
- a protocol that treats coverage, claimed-event accuracy, stability, change
  matching, lag, and time to first claim as separate quantities;
- frozen development and held-out splits, neutral fixture construction, label
  stripping, piece-level paired comparisons, and scorable-cohort rules;
- a reproducible alignment between performed ASAP inputs and When in Rome
  analyst contexts, with a recorded correction and content-based calibration;
- explicit provenance and reproduction procedures for license-gated corpora;
- a dated record of successful, null, and harmful mechanisms rather than a
  success-only narrative; and
- a practical detector and evaluation discipline that informed later WhatChord
  research initiatives and product behavior.

These are worthwhile engineering and methodological outcomes. They do not need
to be inflated into a novel journal claim to remain useful.

## Publication decision

Do not resubmit WhatKey to TISMIR and do not seek another research venue for the
present manuscript. The additional study required to establish a stronger
contribution is not proportionate to the project's current goals. Preserve the
public Zenodo preprint, manuscript drafts, code, protocols, logs, correction
records, splits, and result artifacts as an openly inspectable,
non-peer-reviewed research archive.

The repository's post-audit manuscript is a final working draft, not a planned
submission. No external article is retracted: the recorded numerical results
remain reproducible within their stated scope. The README should make the
publication status and the limits of the central claim explicit so the archive
does not imply that journal review is still in progress.

## Ideas deliberately deferred

Possible future work is recorded without opening a new initiative:

- **Reusable research-methods playbook.** Abstract the protocol-first workflow,
  development/held-out discipline, piece-level comparisons, correction ledger,
  claim-evidence matrix, data-provenance checks, license-gated reproduction, and
  append-only decision log into a template for future WhatChord studies.
- **Multi-reference evaluation.** Evaluate several independent detector
  families, separate reference-agreement and disagreement regions, quantify
  ranking sensitivity, and report distinct musical targets as separate axes
  rather than collapsing them into one ground truth.
- **In-time listener evidence.** Collect continuous judgments from musicians or
  listeners while music unfolds, then compare those judgments with retrospective
  analyst contexts and notated signatures.
- **Selective streaming benchmark.** Compare multiple causal models on a joint
  coverage, accuracy, stability, and lag frontier and validate the tradeoffs
  against musician preferences or interaction outcomes.
- **Dual-reference resource.** If licensing permits a genuinely reusable
  release, package the performed-input alignment and reference transformations
  as a benchmark resource rather than making the ranking reversal itself the
  headline discovery.

None of these is required to close WhatKey. A future initiative should begin
with its own question and protocol rather than being presented as unfinished
work from this project.

**Plain-English reading.** The study did careful work and found real effects,
but its best journal claim ultimately confirmed a lesson that the field already
knows: systems look different under references that encode different musical
answers. The honest outcome is to keep the detector, methods, corrections,
negative results, and reproducible archive while declining to spend more effort
turning that case study into a publication.

**Decisions.** Mark the WhatKey research phase complete and the publication path
closed. Preserve all existing artifacts. Update the WhatKey README and the
top-level research index to remove the parity and active-publication framing.
Retain the methods-abstraction ideas only in this entry until a separate future
initiative is explicitly opened.

**Next.** No further WhatKey experiment, manuscript revision, submission
response, supplement, or publication action is planned.

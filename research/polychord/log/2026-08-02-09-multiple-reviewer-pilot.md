# 2026-08-02: Multiple-reviewer pilot and guided instrument

**Goal.** Decide whether the annotation pilot seeks an expert endorsement or
evidence that qualified readers can independently reproduce the construct, how
many responses are useful, and whether to provide a guided web instrument.

**Setup.** Base repository commit `aba3d818`. This decision amends the
single-reviewer next step in log 2026-08-02-08 before any completed independent
response has been received or inspected. It does not change the frozen guide,
packet, response schema, or pre-adjudication measures, and it reads no corpus or
held-out data.

The decision is informed by two directly relevant precedents:

- Koops et al.,
  ["Annotator subjectivity in harmony annotations of popular music"](https://doi.org/10.1080/09298215.2019.1613436),
  used a common web interface with four expert annotators and showed that
  trained harmonic annotators still differ materially in vocabulary and chord
  choice.
- Hentschel et al.,
  ["The Annotated Mozart Sonatas: Score, Harmony, and Cadence"](https://doi.org/10.5334/tismir.63),
  required agreement between at least two theory experts and used a documented
  three-expert review process to produce consensus annotations.

**What happened.** We separated two questions that a single external review
would otherwise conflate. An expert can judge whether the proposed structure is
musically credible, which is useful content or face validation. Reproducibility
instead asks whether multiple qualified people independently apply the same
operational definition to the same evidence and produce compatible tags, layers,
and eligibility judgments. Authority or post-discussion consensus cannot
substitute for the latter measurement.

The structured layer assignment is also unnecessarily error-prone when entered
as raw JSON. A guided instrument can enforce the response schema and preserve
provenance without constraining the musical judgment. The appropriate design is
a focused expert annotation instrument, not an open crowd survey.

**Plain-English reading.** We are not looking for one authority to bless our
answer. We want to find out whether several appropriately trained people can
follow the same instructions and reach compatible answers before talking to one
another. A form can stop broken files and missing notes, but it must still allow
reviewers to disagree with us or say that the rubric does not fit.

**Decisions.** The six-case formative pilot targets three independent qualified
music-theory annotators; two is the minimum usable independent panel. One
external response remains valuable as expert feedback but does not support a
reproducibility claim. Reviewers complete the frozen task independently, without
the initial labels or peer responses. All raw responses are preserved and the
pre-adjudication report is generated before debriefing or consensus work.

Build a small, version-pinned guided annotation instrument when practical. It
must present the unchanged neutral packet, record presentation order, validate
structural completeness, and export the existing JSON response schema. It must
allow abstention, alternatives, confidence, and free-form reasons; must not show
detector output or initial or peer answers; and must not silently repair or
normalize a theoretical choice. Reviewer identity and qualifications remain
separate from the pseudonymous response.

The staged progression is:

1. Build and verify the guided instrument against the frozen packet and
   validator while other score-verification and detector research continues.
2. Obtain two, preferably three, independent expert pilot responses.
3. Freeze and validate every raw response, then generate the preregistered
   pre-adjudication comparison before discussion.
4. Debrief reviewers individually, document ambiguities and representation
   failures, and version the guide, ruler, or instrument if revisions are
   needed.
5. If publication remains the goal, design a larger, deliberately balanced case
   set and freeze its sampling and analysis plan before using it for a general
   reliability claim.

The six-case pilot remains formative. Adding reviewers makes its diagnostic
evidence stronger, but does not make six examples sufficient for kappa,
confidence intervals, hypothesis tests, or a population-level reliability claim.

**Next.** Treat the guided instrument as a separable implementation task, not a
blocker for the split census, score verification, temporal-evidence exploration,
or other local research. Recruit qualified reviewers in parallel and record the
instrument version, reviewer qualification criteria, and response/report digests
in later dated entries.

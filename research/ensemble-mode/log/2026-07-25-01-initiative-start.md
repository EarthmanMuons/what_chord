# 2026-07-25: Initiative start, plan adopted

**Goal.** Record the product decision to build the ensemble (comping) mode that
chord-context Track D costed, and adopt the design and integration plan.

**Setup.** No experiments this entry. Inputs are the chord-context evidence:
gate measurement (log entry 2026-07-20-16), corpus-scale accuracy estimate
(entry 2026-07-20-19), and the design sketch
(`research/chord-context/rootless-voicings-notes.md`). Engine at commit
755c6b35.

**What happened.** Reviewed the Track D evidence against the current engine and
app surfaces and wrote the plan (`../ensemble-mode-plan.md`): mode as a
`PlayingContext` field on `AnalysisContext` (explicit toggle, default solo),
then five phases landing as separate commits: (1) inert engine contract change,
(2) ghost-root generation with diatonic filtering and missing-root pricing, (3)
guide-tone/dominant-color tiebreak plus real-engine measurement against the
chord-context rulers, (4) app integration (settings, presentation, history,
links, lookup, demo, web/CLI), (5) docs and release. Drafted `PROTOCOL.md`
inheriting the frozen chord-context protocol, with the comping suite as the
acceptance ruler and the DCML rootless synthesis as the corpus ruler.

**Decisions.**

- Track D proceeds as its own initiative, `research/ensemble-mode/`, per the
  decision in `research/chord-context/README.md` to pursue it outside the
  completed chord-context project. The plan in `../ensemble-mode-plan.md` is
  adopted.
- The mode is explicit, per the gate finding that auto-detection is impossible
  in principle; any inference-based design remains rejected in advance.
- Solo-mode invariance is a hard adoption requirement: with the mode off, engine
  output must be bit-identical to shipped behavior.
- The tiebreak ships only with its own measured contribution; the mode does not
  wait for it if it underperforms.
- Measurement harnesses are extended in `tool/chord-context/` rather than
  duplicated, since they score against the same frozen rulers and splits.

**Next.**

- Phase 1: land `PlayingContext` on `AnalysisContext` with the cache-aliasing
  test and all construction sites updated, zero behavior change.
- Freeze `PROTOCOL.md` with a dated entry before the first tiebreak measurement.

# 2026-08-12: Preregister automatic timing sensitivity

**Goal.** Freeze an exploratory comparison that can show how much the current
200-millisecond onset and display baselines affect the evidence record, without
choosing a favorable threshold after reading comparison results.

**Setup.** Work began from clean repository commit
`15c709005ffb212b5664e6ea98469529073d8db2`. No comparison implementation
existed, no alternate profile was run, no new corpus or source result was read,
and no held POP909 song or ASAP test performance was opened.

Commit `f4c19ec65803f2dff4450653e142002ae8471cfe` originally recorded the source
search as closed. Commit `15c709005ffb212b5664e6ea98469529073d8db2` followed
with the timing correction. The old log heading “Methodological correction
before commit” meant before the correction commit, not before the original
source-search commit. This entry records that clarification without rewriting
the now committed append-only log.

The design used these already exposed inputs:

- threshold-free onset-evidence contract:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- unchanged 50/200 onset-support baseline:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`;
- preserved version-2 output baseline:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`;
- timing-calibration plan:
  `c06e5a279397da466814b9d13f6489a6bd4a9d3719e3f2886a9a2702f7796f1b`;
- POP909 sample roster:
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`;
- existing local POP909 onset report:
  `60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`; and
- Laviano _Malediction_ sequence:
  `e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`.

The literature rationale remains the primary research already recorded in the
initiative: Palmer at 20-50 milliseconds; Hove, Keller, and Krumhansl at 25, 30,
and 50 milliseconds; Tillmann and Bharucha at 50 milliseconds; Hukin and Darwin
reporting task-dependent effects beginning around 80 milliseconds and
approaching zero contribution around 300 milliseconds; and Borchert, Micheyl,
and Oxenham testing a 200-millisecond asynchronous condition without estimating
a polychord boundary.

**What happened.** `automatic-timing-sensitivity-preregistration.md` fixes two
independent ordered comparisons:

- onset-gap minima of 50, 80, 100, 200, and 300 milliseconds, with the existing
  50-millisecond within-layer maximum unchanged; and
- authorization-survival dwells of 0, 50, 100, 200, and 300 milliseconds,
  reported as coverage opportunities rather than product displays.

The comparison consumes the existing threshold-free candidate evidence instead
of regenerating POP909 with a favorable rule. It must reproduce the committed
200-millisecond baseline totals exactly and report raw spans, gaps,
note-instance bindings, shared-tone and sustain context, per-piece
concentration, every newly positive episode, and monotonicity. The Liszt
boundary is replayed from its pinned sequence rather than copied from the
earlier result. Synthetic exact and just-inside boundary cases test mechanics
separately from source coverage.

The design explicitly discloses that its grid is development-informed by the
known 96-, 97-, 125-, and 200-millisecond observations. It therefore cannot
provide independent confirmation. POP909 remains an unlabeled exposure source,
and the Liszt case remains a score-established rapid-alternation boundary even
if a lower-gap rule supplies positive cue support.

The expected result is also frozen rather than presented later as a discovery.
Every POP909 profile should remain at zero because all previously observed cases
with two compact layers had zero separation. The two Liszt opportunities should
be positive at 50 and 80 milliseconds, neutral at 100 milliseconds and above,
and survive only the 0- and 50-millisecond appearance dwells. The implementation
must derive those results from the pins; disagreement is a reproduction failure.

**Plain-English reading.** We can now measure whether 200 milliseconds was
responsible for dismissing opportunities without pretending that the threshold
producing the most candidates is the best one. The comparison will show what
changes as timing assumptions move. It cannot tell us which changed result is a
true polychord until source-positive and matched-guard evidence exists.

**Decisions.** Freeze the two profile families, inputs, raw evidence record,
metrics, baseline reproduction, monotonicity checks, source-case treatment, and
stopping rules as `polychord-automatic-timing-sensitivity/1`. Keep within-layer
compactness at 50 milliseconds so the first comparison changes one onset
parameter at a time. Do not select or recommend an onset threshold or appearance
dwell from this measurement.

The formatted preregistration has SHA-256
`957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522`.

Do not treat potential display duration as actual product output, combine
multiple candidates as though a selector chose them, read corpus labels, use
synthetic controls as source coverage, or touch the 808-song POP909 reserve.

**Next.** Commit the preregistration before implementation. Then implement the
fixed comparison and focused tests, commit them without running the full report,
and execute the exact registered command in a separate measurement step.

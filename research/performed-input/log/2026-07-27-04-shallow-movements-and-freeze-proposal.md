# 2026-07-27: Shallow movements diagnosed; scoring and split proposal

**Goal.** Close the last open item before the ruler freeze: determine whether
the four gate-failing movements (7-1, 7-4, 12-1, 31-3_4) are noisy or broken,
then draft the scoring semantics and split for review.

**Setup.**

```sh
.venv/bin/python tool/whatkey/wir_alignment_probe.py 7-1 7-4 12-1 31-3_4 --windows 4
```

The probe gained `--windows N`: the shift response computed per time window,
which separates uniform shallowness (texture, annotation granularity) from
sectional drift (the offset is piecewise, so no global value fits).

**What happened.** None of the four is merely noisy; all four are piecewise
misaligned, each in a different way:

- 7-1: two regimes. Windows 1-2 peak at +2 relative to the applied -2 offset
  (absolute 0), windows 3-4 peak sharply at the applied offset (0.766, 0.835).
  The global calibrator picked the half with more mass; the halves genuinely
  disagree by 2 measures.
- 7-4: same shape, one measure. Windows 1-2 want absolute 0, windows 3-4 want
  the applied -1 (0.704, 0.799 at their peak).
- 12-1 (Op. 26, theme and variations): windows 1-2 align beautifully at 0
  (0.854, 0.686), windows 3-4 degrade into shallow off-zero peaks, drift
  compounded by late-variation figuration texture.
- 31-3_4: flat in every window; the two-movements-in-one-folder measure
  numbering never lines up as any offset, piecewise or not.

The likely mechanism for 7-1/7-4/12-1 is a repeat- or ending-convention
mismatch: the ASAP downbeat map and the analysis count first/second endings
differently, so the numbering agrees up to a structural boundary and disagrees
by a constant after it. This is a piecewise-constant offset, which a
changepoint-aware calibration (two offsets, one content-chosen boundary) could
rescue for at least 7-1 and 7-4. 31-3_4 needs its movement boundary split before
any of that applies.

**Decisions.**

- All four stay excluded by the census gate. The ruler proceeds over the 32
  passing movements; a piecewise-calibration rescue is a captured follow-up, not
  a blocker.
- Rescued movements can join the ruler later without weakening the freeze
  because the proposed split assigns sides by sonata (below): a rescued
  movement's side is already determined by its sonata, not decided after looking
  at results.

**Proposed for freeze (pending review).** The ruler definition, to be frozen
into PROTOCOL.md on approval:

1. Scoring unit: time-weighted agreement over the union of event display
   intervals ([timestampMs, +durationMs]) intersected with the analyst harmony
   timeline. Not event counting: a chord held for four seconds matters four
   times as much as a passing one, matching what a user experiences.
2. Agreement tiers between the app's top-ranked candidate and the analyst chord
   (music21 conversion of key+figure, with a fixed quality-family mapping table;
   augmented-sixth figures score by member set since the app legitimately names
   them as enharmonic dominants):
   - exact: root pitch class and quality family both match (headline);
   - root: root pitch class matches;
   - members: chord-tone sets match regardless of root spelling.
3. Boundary tolerance: within one interpolated beat of an analyst span boundary,
   agreement with either neighboring span counts. The census showed the worst
   healthy-movement mismatches are exactly these quantization artifacts (log
   -02).
4. Attribution arms, built in this order: A0 = the current fixtures (app
   segmentation, neutral C:maj analysis context); B = same segmentation with the
   annotated analyst key as context (isolates key-context contribution); C =
   annotation-boundary segmentation (isolates segmentation contribution); A1 =
   live inferred-key context (the full product path, heaviest tooling). Headline
   numbers always ship with their decomposition.
5. Split: by sonata number, seeded hash, targeting roughly 70/30 dev/test by
   event mass over gate-passing movements. Sonata-level assignment keeps all
   movements and performances of a work on one side and pre-determines the side
   of any future rescue. Test spent once, pre-declared, per PROTOCOL.md.
6. Adoption bar for any engine change motivated by this ruler: paired per-piece
   exact delta, CI95 excluding zero, Wilcoxon p < 0.05, solo goldens and comping
   suite clean, oracle-pool continuity clean.

**Next.** On approval: freeze items 1-6 into PROTOCOL.md, generate and commit
the split manifest, then build the scorer and run the A0 baseline.

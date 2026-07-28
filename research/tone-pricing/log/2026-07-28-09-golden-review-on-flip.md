# 2026-07-28: Review-on-flip applied to the goldens themselves

**Goal.** Per review: the goldens, like the oracle verdicts, are curated
judgments from a past pricing regime, not ground truth. Examine every golden the
package broke on musical merits before letting the revert stand on authority.

**Setup.** Each broken case replayed through the real analyzer at both prices
with full candidate bands and costs (utc side); tier-side flips judged from the
package run's outputs.

**The utc five, case by case.**

- Dm9/C and Dm9/F (C-Db-D-E-F): tops unchanged. The vanished alternative is the
  exact-bookkeeping Dbmaj7(b9,#9) reading, which fell out of the near-tie band
  when Dm9's unexplained-Db reading cheapened by a point. Losing an
  everything-explained curiosity from the alternatives list is defensible; these
  goldens could be relaxed if the lever ever returns.
- Am11, key C (C-D-E-G-A): D9sus4/A left the band although its own cost and the
  top's are unchanged, so band composition is sensitive to third-party
  repricing. Mild loss of a useful reading; top unchanged.
- C(addb9,add9)/E (C-Db-D-E-G): genuine regression. The new top, D9sus4/E at
  1.75, simply ignores the Db, the defining crunch of the split-ninth cluster
  the old name existed to spell.
- Cm6b9/A (C-Db-Eb-A): regression-leaning. Adim at 1.10 wins by tie rule over
  Cm6b9/A at 1.05, leaving the Db unnamed.

**Verdict on utc 1.0, now on merits:** the two top-flips violate the
name-what-sounds philosophy directly: cheap unexplained tones let readings
ignore the interesting note. Rejected musically, not just procedurally. The
three alternatives-band losses alone would not have justified rejection.

**The tier three, case by case:** the harmonic-minor tonic flip (C#m(maj7,b13)
in C# minor to Aadd#9/C#) is the true regression, the keyed canonical context;
C#m(maj9,b13)/E to Amaj7(#9,#11)/E is a dense-cluster toss-up; and losing the
C#m(maj13)/B# alternative from C7(#5,b9) would have been an improvement.
Verdict: one regression, one toss-up, one improvement; the canonical case
sustains the revert.

**What the review adds beyond the revert:**

1. A narrower future path for the tier correction exists: since the killing case
   is key-contextual, pairing the m(maj7) tier promotion with a strengthened
   harmonic-minor tonic rule (a tonality-gated protection instead of the blanket
   marked-price subsidy) could keep the canonical naming while pricing the
   context-free absorption honestly. Recorded, not opened; it carries rule-layer
   blast radius of its own.
2. Two goldens are marked as relaxable if the lever returns (the Dm9 bookkeeping
   alternatives), and one flip would have been an improvement; the golden suite
   is confirmed as curated judgment that mostly, but not uniformly, encodes
   current best taste.
3. The near-tie band's sensitivity to third-party repricing (the Am11 case) is
   noted as a mechanism quirk worth remembering when reading future
   band-composition diffs.

**Plain-English reading.** We re-argued every taste test the experiment broke
instead of treating the test file as scripture. Most of the vetoes hold up: the
cheap-forgiveness dial really does make the app ignore the very note that makes
a chord interesting, and the price hike really does break the textbook
harmonic-minor chord. But two of the broken tests were guarding trivia, one
break would have been an improvement, and the deadly break turns out to be about
key context, leaving a door open for a smarter version later. The revert stands,
now for reasons we can defend note by note.

**Next.** The shell-lever decision from log -08 stands unchanged.

# 2026-07-26: One-event warmup gate shipped

**Goal.** Implement the decision from the initiative discussion (2026-07-26):
ship minEvents 1 as the detector default, per the evidence in entries -14/-15.

**Setup.** As entries -14/-15. The bar 2 judgment is decided the same way as the
cadence boost's entry -05: the accepted cost is Isophonics stable exact -0.0038
against coverage +0.0258 with zero losing tracks; with both adoptions combined,
Isophonics stable sits above the pre-initiative baseline on both axes (coverage
0.9368 vs 0.9216, exact 0.7758 vs 0.7753).

**What happened.** Implementation:

- `HmmKeyDetector.defaultMinEvents = 1` with the adoption rationale in the doc
  comment; the margin floor is the real gate. The app constructs the detector
  with defaults, so the display detector and the internal key both receive it
  with no app-side change.
- The paper recipes continue to pin `minEvents: 3`, and the harness now resolves
  the min-events default per detector (the HMM follows the shipped default; the
  research accumulator detectors keep their historical three-event warmup). The
  chord-context harnesses default `--min-events` to the detector default so they
  mirror shipped behavior.
- Contract verification: a `--recipe whatKeyPaper2026` run still reproduces the
  pre-adoption claims byte for byte, and a default `--detector hmm` run is
  byte-identical to the measured minEvents 1 arm.
- Tests updated to the new semantics (suite 237 and package 61 green): the
  package minEvents test pins the mechanism explicitly and a new test covers the
  shipped gate (a clear first chord claims; a maximally ambiguous cluster
  abstains); the app tests that used the three-event warmup as a convenience now
  abstain via ambiguous clusters, proving the margin floor and reset semantics
  directly; the key-mode streak test shows one claiming event still does not
  adopt; the relabel test records that the opening entry now gets its relabel
  moment too.
- Changelog entry added (key detection responds from the first clear chord).

**Plain-English reading.** The app's key button now lights up on the first chord
you play when that chord is decisive, instead of always waiting for three, and
stays empty on genuinely ambiguous openings. Everything downstream
(auto-adoption streak, ensemble naming, the history relabel) behaves as before,
just with the detector's opinion available two chords earlier.

**Decisions.** Shipped as decided. This closes the initiative's detector work
for real this time; the remaining steps are the holdout evaluation and the
headline tables, both still paused for discussion.

**Next.** Holdout per the staged 2x2 plan when the discussion resolves.

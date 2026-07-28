# 2026-07-28: The modest package runs and reverts: the goldens hold the line

**Goal.** Run the package pre-declared in log -07 (minorMajor7 tier correction
plus utc 1.0) under the ship-or-revert rule.

**What happened.** Pre-change current-profile baselines were locked first (A0
exact 0.602, BC-modal 0.580, POP909 dense consistency 0.9755), the package was
implemented with profile-aware prices (the frozen whatKeyPaper2026 profile
keeping utc 2.0 and the marked m(maj7) price so paper fixtures regenerate
byte-identically), and the guard suite ran.

**The goldens failed, in both halves.** Eight golden tests broke under the full
package. Attribution by running utc-only (tier reverted): five failures are
utc-driven, three tier-driven.

- The tier bump's failures include the disqualifying case: the harmonic-minor
  tonic goldens (C-Db-E-A in C# minor as C#m(maj7,b13), and its transposition)
  flip to split-third readings. Harmonic minor's tonic with its leading tone is
  the one context where minor-major seventh is musically canonical; pricing it
  out of that reading is exactly failure mode 6 from the pre-declaration.
  Frequency justified the tier on paper; the goldens showed what the frequency
  table cannot see, that the marked price is carrying an in-key naming
  convention.
- The utc side's failures are subtler but real: two curated rankings flip and
  three expected alternatives vanish from the surfaced near-tie band (Dm9/C
  loses its altered-major-seventh bookkeeping alternative, Am11 loses D9sus4/A).
  Cheapening unexplained tones lets partial readings crowd the band musicians
  see.

**Verdict: reverted, per the pre-declared rule.** The engine is restored to
shipped state (package suite 536 green, zero engine diff). The ruler's
prospective +0.4 to +0.9 points, earned against a functional-analysis ruler, do
not justify eroding the curated solo naming contract the goldens encode.

**What this resolves.** The superset side of the tone-pricing initiative is now
fully measured to the ground: the utc sweep (real gain, wrong bucket),
vocabulary rarity (melody bucket unreachable at honest prices), and the combined
modest package (rejected by the goldens) have all been run under
pre-declarations and declined. The remaining unexplored lead is the shell lever
(omission side), whose two blockers are mapped in log -04.

**Plain-English reading.** We tried the two respectable versions of "be more
forgiving about extra notes," and the app's own curated taste tests vetoed both:
one broke the classic harmonic-minor chord every theory student learns, and the
other cluttered the list of alternatives musicians see with half-explained
readings. The safety rails we set up before touching anything are the only
reason this took an afternoon instead of shipping a regression. The extra-note
side of the pricing question is now closed with receipts; what remains is the
missing-note side.

**Next.** Decision point: design the shell lever experiment (power-gate
relaxation plus seventh-as-color vocabulary, against the mapped blockers), or
close the initiative with the superset side resolved and the shell side
scoped-but-unbuilt.

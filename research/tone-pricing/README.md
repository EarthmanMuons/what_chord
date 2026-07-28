# Tone Pricing

What should a chord name pay for a tone it cannot explain, and what discount
should an honest incomplete reading get? The two questions are one
explanation-cost tolerance dial viewed from opposite sides, and both were
surfaced and priced by the performed-input initiative
([../performed-input/](../performed-input/README.md)):

- **Superset absorption**: the ranker prefers folding an extra sounding tone
  into a bigger name (a held C# over D minor displays as Dm(maj7)) over naming
  the base chord and leaving the tone unexplained. The base-plus-unexplained
  reading is not merely ranked second; it is priced out of the near-tie surface
  entirely (performed-input log 2026-07-27-11). Ceiling on the live ruler: at
  most 7 exact points (the whole added-tone family), realistically less.
- **Shell omission**: no-third seventh shells had no honest label priced
  competitively (D-A-C names Am/D at 0.95 with D7 behind at 1.7 paying a
  missing-third penalty, and no omitted-third vocabulary existed). About 1.8% of
  observed playing time, split by idiom: jazz shell voicing expects the seventh
  reading, folk supports the slash (performed-input log 2026-07-28-05).

Status: closed. The superset side was measured to declination, every lever
rejected by a guard or by arithmetic. The shell side shipped: the bare
flat-seven shell now surfaces D7(omit3) as an alternative beside the
complete-triad reading.

## Results

**Superset absorption: no lever survived, and the reasons are recorded.**

- The unexplained-tone price sweep found a real plateau (1.0 to 0.75, paired
  gains with CI95 excluding zero) but in the wrong bucket: the recovered time
  was partial-content base naming, not the declared melody-absorption target,
  and the flagship case is arithmetically unflippable because the absorbing name
  explains every tone at 0.1. Not proposed, per the attribution rule
  ([log -05](log/2026-07-28-05-utc-sweep.md)).
- Vocabulary-rarity scoping showed 68.3% of absorption flows through common-tier
  names priced at zero, which is defensible surface naming rather than a defect.
  The one lopsided absorber, minorMajor7, was frequency-justified for a tier
  promotion on ChoCo counts, but the same arithmetic closes the melody bucket at
  any honest price ([log -06](log/2026-07-28-06-vocabulary-rarity-scoping.md)).
- The combined package (tier promotion plus the cheaper unexplained price) was
  pre-declared, implemented profile-aware, and failed the goldens on both
  halves; it reverted per its own ship-or-revert rule. Re-judging every broken
  golden on musical merits upheld the veto: the cheaper price lets two readings
  ignore the flat nine that defines their sonority, and the tier promotion
  breaks the harmonic-minor tonic, the one context where m(maj7) is canonical
  ([logs -07 through -09](log/)).
- The narrow rescue, a tonality-gated tier price, was scoped and declined: the
  protection already exists as a pair-specific tie rule, which the price hike
  disengaged by pushing the pair outside the near-tie window. Worse, the golden
  case and the flagship absorption case are the same configuration, so the gate
  would shelter 68% of the mass while the flip arithmetic holds the rest in
  place ([log -10](log/2026-07-28-10-tonality-gated-tier-scoping.md)).

**Shell omission: shipped as D7(omit3).** A blast-radius census run before any
engine work gated the design to bare shells: allowing any color reaches 43% of
pooled playing time (every minor seventh respells as a power stack, the
historical failure in one number), the gentle colors still collide with
canonical names, and the bare shell touches six case families at 2% of pooled
mass ([log -11](log/2026-07-28-11-shell-lever-design.md)). The probe swept both
sevenths and excluded the major-seventh form by two independent instruments
([log -12](log/2026-07-28-12-shell-probe-sweep.md)). External research then
settled the symbol: Brandt and Roemer's copyist standard pictures exactly
D7(OMIT 3), prefers "omit" over "no", and independently states both restrictions
the measurements had derived, so the identity rides the existing
dominant-seventh candidate rather than new power vocabulary
([log -13](log/2026-07-28-13-shell-symbol-research.md)). Adoption changed
exactly one surfaced band in the 1,501-case pool and moved nothing on the ruler
([log -14](log/2026-07-28-14-shell-adoption.md)).

**Method notes worth carrying forward.**

- Goldens are curated judgments, not ground truth, and re-judging them on merits
  is now part of review-on-flip. They also encode in-key naming conventions that
  corpus frequency cannot see, so a future vocabulary-tier argument needs golden
  reconciliation in its design, not just frequency counts.
- Tie rules only engage inside the near-tie window, so a price change large
  enough to clear that window silently disables the rules protecting the case it
  moves.
- A closed template (an exact voicing mask) buys containment by construction,
  which is what let the shell lever proceed despite the power-chord history.

## Why this shape

The instruments are unusually ready: the exposure-weight table ranks every
change by real playing time instead of enumeration rows, the performed-input
development ruler and its frozen adoption bar provide the live check, the ChoCo
common-name priors carry the name-frequency signal, and the oracle-comparison
machinery provides the blast-radius tooling. The risk is not measurement but
taste: both dials sit directly on the musician-expected naming philosophy, so
the guards (revised below in PROTOCOL) carry the load.

## Build order

All four steps ran in order; the outcomes are in Results above.

1. **Arm C simultaneity refinement** (prerequisite): the BC arm is this
   initiative's residual-isolating instrument, and its span-union voicings
   currently inflate the superset bucket with tones that never sounded together
   (performed-input log 2026-07-27-07). Fix the construction before aiming an
   engine change at the residual it measures.
2. **Baselines**: the 8-plus pitch-class self-consistency census over existing
   fixture events (the dense-set stress check reserved in performed-input log
   2026-07-28-05); the post-refinement BC residual; the exposure-weighted
   inventory of the standing evaluation rows (the high-mass soft-verdict
   entries, led by the 0-2-9 and 0-1-8 shell family).
3. **Experiment mechanism**: how pricing variants are prototyped (engine-side
   research profile or debug pricing overrides), scoped before any lever moves.
4. **Levers, each with pre-declared expectations**: the unexplained-tone price
   for base readings; the missing-essential discount and shell vocabulary forms;
   evaluated against the live ruler, the census suite, and the standing rows.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline, the revised oracle guard
  (review-on-flip), and the adoption bar.
- [Log](log/): dated, append-only record of every experiment and decision.

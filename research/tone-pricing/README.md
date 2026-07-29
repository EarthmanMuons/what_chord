# Tone Pricing

The engine names a chord by charging it for every note it cannot explain for
free. Two complaints come out of that one dial. Play a triad and hold a melody
note over it, and the name inflates to swallow the extra note. Play a jazz shell
with no third, and no honest name fits at all. What should an unexplainable note
cost, and what discount does an incomplete reading deserve?

**Status:** complete. The absorption side was measured and declined; the
omission side shipped one narrowly contained label.

## What came out

**Absorption: no lever survived, and the reasons are on the record.**

- **Making unexplained notes cheaper works, on the wrong cases.** The price
  sweep found a real plateau with a genuine paired gain, but the time it
  recovered was ordinary half-played chords, not the melody-absorption target it
  was aimed at. The flagship case cannot be flipped by any price at all, because
  the absorbing name already explains every sounding note.
- **Charging rare names more breaks curated musical judgment.** The combined
  package failed its [goldens](../GLOSSARY.md#golden-test) on both halves and
  reverted under its own pre-declared rule. Re-judging every broken case on
  musical merits upheld the veto rather than overturning it: the cheaper price
  let two readings ignore the flat nine that defines their sound, and the tier
  change broke the harmonic minor tonic, the one context where a minor-major
  seventh is canonical.
- **The narrow rescue was empty.** Gating the price on the key looked like it
  would protect the canonical cases, but the protection already existed as a tie
  rule, which the price hike itself had disengaged by pushing the pair outside
  the [near-tie window](../GLOSSARY.md#near-tie-window). The gate would have
  sheltered 68% of the mass while arithmetic held the rest in place. Clever,
  measured, empty.

**Omission: shipped as D7(omit3).** A blast-radius census run before any engine
work gated the design to bare shells only: allowing colors reaches 43% of pooled
playing time, which is the historical power-chord failure in one number. The
bare shell touches six case families at 2%. External research then settled the
symbol, since Brandt and Roemer's copyist standard pictures exactly D7(OMIT 3),
prefers "omit" over "no", and independently states both restrictions the
measurements had already derived. Adoption changed exactly one surfaced reading
in the 1,501-case pool and moved nothing on the live ruler.

## Method notes worth carrying forward

These generalize beyond this initiative:

- **Goldens are curated judgments, not ground truth**, so re-judging them on
  merits is now part of reviewing any change that breaks one. They also encode
  in-key naming conventions that corpus frequency cannot see, so a future
  argument from frequency counts needs golden reconciliation in its design.
- **Tie rules only engage inside the near-tie window.** A price change large
  enough to clear that window silently disables the rules that were protecting
  the case it moves. This is the trap the narrow rescue fell into.
- **A closed template buys containment by construction**, which is what let the
  shell change proceed at all despite the power-chord history.

## Where this fits

[Performed Input](../performed-input/README.md) surfaced and priced both sides.
It found that the engine-actionable share of its residual is concentrated in
absorption, and separately that no-third shells account for about 1.8% of
observed playing time, split by idiom: a jazz shell voicing expects the seventh
reading, a folk one expects the slash.

The instruments were unusually ready, which is why this was worth attempting:
real playing-time weighting to rank changes by exposure rather than by catalog
rows, a frozen live [ruler](../GLOSSARY.md#ruler) with an adoption bar,
chord-name frequency priors from a million-annotation corpus, and existing
blast-radius tooling. The risk was never measurement. It was taste, since both
dials sit directly on the musician-expected naming philosophy, which is why the
guards carried the load.

## Contents

- [Protocol](PROTOCOL.md): inherited discipline, the revised oracle guard
  (review-on-flip), and the adoption bar.
- [Log](log/): dated, append-only record of every experiment and decision.

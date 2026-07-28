# Tone-Pricing Protocol

Status: DRAFT; the discipline below is binding from the first experiment.
Inherits the chord-context protocol conventions (splits, label isolation,
statistics) and the performed-input protocol's frozen rulers and adoption bar as
the live check.

## Binding now

- **Pre-declared expectations per lever.** Every pricing or vocabulary change
  states, before measurement: the bucket it claims to move, the expected
  direction on the live ruler's exact tier, and the surfaces it must not move.
- **Development only until resolution.** Tuning uses the performed-input
  development split and the census instruments. The performed-input test split
  stays sealed; it is spent once, after this initiative resolves (ship or
  decline), as the confirmation of the final engine state.
- **Review-on-flip replaces zero-flip.** The reviewed oracle entries are
  justified snapshots of past engine behavior, not ground truth (many could be
  taken multiple ways without justifying an engine change at the time). For this
  initiative: any flip of a reviewed entry, whatever its label, is surfaced with
  its exposure mass and re-reviewed to a fresh verdict before the change ships.
  No silent flips; blast radius always reported weighted and unweighted. The
  zero-flip constraint remains in force for work outside this initiative.
- **Standing evaluation rows.** The exposure-heavy soft-verdict entries
  (performed-input log 2026-07-28-05 skim) are re-read against every candidate
  change; their verdicts and notes are updated in
  `tool/chord/oracle_reviewed.json` as part of adoption, not afterward.

## Guards

- Solo goldens, comping suite 18/18, `tool/benchmark.sh --check`.
- Pop-jazz behavioral fixtures per their declared byte-identity contracts.
- Dense-set stress: the 8-plus pitch-class self-consistency census must not
  degrade materially under any adopted lever.
- Key-detection non-interference does not apply to pure ranking changes, but any
  change that alters committed event streams re-runs the whatkey-local guard
  commands.
- POP909 corroboration, if used, evaluates on a split frozen from the held pool
  (`research/performed-input/data/pop909-held-pool.json`), keeping the
  exposure-weight triage and the evaluation corpus disjoint.

## Adoption bar

The performed-input adoption bar applies: paired per-piece improvement on the
development split's exact tier (CI95 excluding zero, Wilcoxon p < 0.05), guards
green, attribution confirming the change moves the bucket it claims, plus this
initiative's review-on-flip obligations completed.

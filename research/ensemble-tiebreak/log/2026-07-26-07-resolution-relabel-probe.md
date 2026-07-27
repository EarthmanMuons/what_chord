# 2026-07-26: Resolution-aware relabel probe: legs confirmed at 90% precision

**Goal.** Assess the scoped follow-up from entry -03 at simulation level before
any app implementation: can the next chord's identity disambiguate the
minor-third-axis dominant re-rootings the analyzer cannot?

**Setup.** A simulation arm in `rootless_corpus.dart`: when the previous scored
event's inferred-arm chosen reading is an implied-root dominant that does not
resolve into the current chosen root (down a fifth, or a half step for the
substitute), and exactly one minor-third-axis re-rooting of it does resolve down
a fifth, relabel the record to that member and score the flip. Tritone twins are
excluded by design: both members resolve into the same target, so resolution
carries no information about them.

**What happened.** Two iterations:

1. **Ungated: decisively negative.** Fired 743, fixed 173, broken 546 on Weimar
   dev reactive (24% precision). Real jazz dominants frequently do not resolve
   at all (chains, back-cycling, turnarounds), so "did not resolve into the next
   chord" is weak evidence of a wrong root on its own.
2. **Gated on the flat-nine stack: decisive positive.** The minor-third
   re-rooting is only tone-identical when the chosen reading carries the
   symmetric flat-nine colors; a plain dominant with natural colors has no such
   twin, so firing there was never justified. With the gate (`chosenFlatNine`):
   reactive 192 fired / 173 fixed / 18 broken (90% precision, net +155 events,
   about +0.9 points of record accuracy); stable 203 / 181 / 22 (net +159).
   Every fix from the ungated version is retained; the breaks collapse
   thirty-fold. DCML dev fires zero times at either behavior: post-admission
   classical has no misrooted flat-nine-stack implied dominants, so the
   classical continuity risk is nil.

**Plain-English reading.** When the ensemble mode reads a flat-nine comping
voicing, four different dominant roots explain the identical notes and the
analyzer must guess. One chord later, the resolution usually gives the answer
away, and correcting the history entry at that moment fixes nine mistakes for
every one it introduces, on jazz only, touching nothing classical. This is the
same shape as the two relabel mechanisms already proven (retroResAll's
resolution rule in chord-context; the one-event hindsight relabel in
whatkey-local), applied to the one ambiguity family that genuinely needs the
next chord.

**Decisions.** The mechanism is validated at simulation level. The
implementation home is the app's existing one-event relabel
(`InternalKeyCoordinator`): for an ensemble implied-root dominant history entry
carrying the flat-nine stack that does not resolve into the next committed root,
promote the minor-third-axis candidate that resolves down a fifth. Record-only,
one event deep, net-positive rather than per-flip perfect, matching the accepted
character of the shipped relabel.

**Next.** App implementation on approval; the simulation arm stays in the
harness as the reference semantics.

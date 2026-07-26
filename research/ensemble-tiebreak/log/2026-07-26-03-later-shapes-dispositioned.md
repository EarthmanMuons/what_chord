# 2026-07-26: The later miss shapes, dispositioned before the holdout

**Goal.** Before spending the test split, decide whether the residual shapes
beyond entry -02's fixes are addressable now (initiative discussion,
2026-07-26).

**Setup.** Engine at the entry -02 state. One candidate mechanism was built and
measured: a dominant re-rooting preference (among implied dominant-family
readings of the same tones, natural colors beat altered, then the in-key root
wins the symmetric ties), registered as a hard rule after the semitone-pair
rule.

**What happened.** The rule measured exactly inert: Weimar dev aggregates and
every miss shape byte-identical, comping suite unchanged. The investigation of
why is the real result; each remaining family is out of the analyzer's reach for
a structural reason:

- **Minor-third-axis dominants (274 on Weimar dev).** A flat-nine upper
  structure repeats every minor third, and the major scale contains two of the
  four roots (V and V-of-vi both sit in key), so key membership cannot split the
  pair the engine actually faces. Only the resolution, the next chord, can. The
  per-voicing analyzer has no temporal context by design; the natural home for
  this fix is a resolution-aware relabel of ensemble history entries one event
  later, the mechanism chord-context log 2026-07-20-15 already validated at 100%
  flip precision (retroResAll) and whatkey-local shipped the plumbing for (the
  one-event relabel).
- **Sharp-five tritone twins (135).** `dominant7Sharp5` is not among the
  ensemble implied-root template qualities, so the true reading is never
  generated; a template-eligibility question, whole-tone symmetric even if
  admitted, 0.7% of events.
- **The half-diminished/major-seventh asymmetric cells (458 and 182).** The
  entry -01 contingency showed these follow the per-solo global key labels; the
  lever is a genuinely local key, not a naming rule.
- **Minor-major re-rootings (20-30 per ruler).** Augmented-axis symmetry of the
  minor-major shell; same temporal-context story as the flat-nine axis, at a
  fortieth of the size.

The inert rule was removed rather than left as live dead weight in the ranking
policy (an unused option with a neutral default is retained by precedent; an
unused pairwise rule is complexity with no measured benefit); the shared
altered-color helper it introduced stays, since the idiom gate uses it. The
recognizer article's ensemble section was also rewritten in plainer language for
its technical audience (same policy, fewer jazz shorthands) per the same
discussion.

**Plain-English reading.** The mistakes that remain are not fixable by smarter
naming of a single voicing: one family needs to see the NEXT chord (which of two
equally-in-key dominants was meant is revealed by where it resolves), one needs
a chord type the rootless generator does not offer (rare and self-ambiguous),
and the biggest needs a local key instead of the corpus's one-key-per-solo
labels. The right tools for the first and third already exist in the app (the
history relabel and the internal key); wiring resolution awareness into the
relabel is a scoped future round, not a quick pre-holdout fix.

**Decisions.** Proceed to the holdout with the entry -02 result as the declared
change set. The remaining shapes are recorded here as the residual floor with
their mechanisms named; the resolution-aware ensemble relabel is the scoped
follow-up candidate.

**Next.** Pre-declare and run the test-split confirmation.

# 2026-07-26: The remaining residual is boundary-shaped

**Goal.** Before wrapping the initiative, decompose the two never-mined residual
masses on the primary ruler: the "other" bucket (the largest non-exact bucket
after the cadence boost) and the abstention mass, to decide whether any further
mechanism is worth building.

**Setup.** Offline analysis over existing artifacts, no new detector runs: WiR
dev claims files from the shipped configuration (stable and hl1, cadence
boost 4) joined against the fixture labels. Script in the session scratchpad;
buckets by signature distance, abstentions by position (warmup = first three
events, near-change = within two events of an annotated key change, interior),
lag = claim matches an annotated local key within four events.

**What happened.**

Claim buckets (share of claimed events):

| Bucket              | Stable | hl1   |
| ------------------- | ------ | ----- |
| exact               | 0.537  | 0.602 |
| fifth, same mode    | 0.175  | 0.148 |
| fifth, mode differs | 0.061  | 0.080 |
| relative            | 0.067  | 0.049 |
| two fifths          | 0.049  | 0.034 |
| farther (3-6)       | 0.086  | 0.062 |
| parallel            | 0.025  | 0.026 |

Structure findings:

- Of the "other-ish" mass (two fifths, farther, fifth-with-mode-change), 39%
  (stable) and 43% (hl1) is disguised lag: the claim matches an annotated local
  key within four events. The genuinely-unrelated share of all claims is roughly
  8-12%, half what the raw bucket suggested.
- The residual is boundary-concentrated. About 39% of all claims fall within two
  events of an annotated key change, and exactness there is 0.33 (stable) and
  0.39 (hl1) against 0.54/0.60 overall. When-in-Rome is modulation-dense, so
  transition zones dominate the remaining error mass.
- Abstentions concentrate at the same boundaries: 41% (stable) and 47% (hl1) of
  abstentions sit within two events of an annotated change; warmup is only
  26%/18%; the interior remainder is a third.

**Plain-English reading.** After the cadence boost, the detector is not mostly
wrong about settled passages; it is unsettled exactly where the music is
unsettled. Both its remaining mistakes and its silences pile up in the few
events around each key change. That means the promising remaining levers are
about behavior at boundaries (when to speak, how fast to align), not about
teaching it more harmony.

**Decisions.** Wrap-up candidate list, ranked against this data:

1. **Cadence-conditioned margin relief** (worth one probe): after the shipped
   cadence trigger fires, relax the claim margin floor for that event. The
   posterior has just been moved by a trusted signal; the biggest abstention
   mass sits at exactly those boundaries. One parameter, claim-layer only.
2. **Cold-start tonic prior** (marginal): seed the initial posterior from the
   first event's chord instead of uniform. Warmup is only about a fifth of
   abstentions, roughly 4% of events; small ceiling, near-free to test.
3. Not pursued, with reasons: a learned transition kernel (the dwell probe and
   the relative-switch-factor null say static transition structure is not
   binding; only input-conditioned transitions have paid); a P(chord | key)
   categorical emission table (two family strikes: the functional blend's blues
   failure and entry -11; a DCML-fit table would encode classical priors against
   pop); two-timescale posterior fusion (the product value is already captured
   by the decoupled internal key).
4. The ensemble residual's exact-key naming share (30%, entry -04) is tiebreak
   territory for a future ensemble-mode round, out of scope for key detection.

**Next.** Probe candidates 1 and 2 on the dev rulers; then the holdout
evaluation plan (paused pending discussion).

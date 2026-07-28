# 2026-07-27: Arm A1 lands; avenue 1 complete

**Goal.** Build the last attribution arm (A1: the live key detector feeding
analysis context through the replay loop, per behavior preset) and close avenue
1 with its full decomposition.

**Setup.** `replay_batch.dart` gained `liveKeyHalfLifeSeconds`: the shipped
`HmmKeyDetector` runs in the loop, each committed event updates it, and its
claimed key becomes the analysis context for subsequent frames (sticky across
abstentions, starting neutral), mirroring the app's live feedback.
`asap_wir_extract.py` gained `--arm A1 --behavior stable|balanced|reactive`
(half-lives 30/4/1 s, shipped defaults otherwise). Dart and Python checks green.

```sh
for b in stable balanced reactive; do
  .venv/bin/python tool/whatkey/asap_wir_extract.py ... --arm A1 --behavior $b
  .venv/bin/python tool/performed-input/identity_score.py \
    --fixtures build/whatkey-fixtures/asap-wir-nc-v2-armA1-$b \
    --split development --arm A1-$b --out build/performed-input/a1-$b-dev.json
done
```

**What happened.** The complete attribution set, development split, mean per
piece:

| arm         | segmentation  | context     | coverage | exact | root  | members |
| ----------- | ------------- | ----------- | -------- | ----- | ----- | ------- |
| A0          | app           | neutral     | 0.493    | 0.595 | 0.737 | 0.525   |
| A1-stable   | app           | live (30 s) | 0.493    | 0.595 | 0.738 | 0.524   |
| A1-balanced | app           | live (4 s)  | 0.493    | 0.595 | 0.738 | 0.524   |
| A1-reactive | app           | live (1 s)  | 0.493    | 0.596 | 0.738 | 0.525   |
| B           | app           | analyst key | 0.493    | 0.595 | 0.737 | 0.524   |
| C           | analyst spans | neutral     | 0.749    | 0.570 | 0.730 | 0.435   |
| BC          | analyst spans | analyst key | 0.749    | 0.572 | 0.732 | 0.435   |

Every context column agrees to within a thousandth: neutral, analyst-perfect,
and live-inferred at all three speeds name the same chords. The key context
conclusion from log -06 now holds end to end through the real detector feedback
loop, wrong keys and cold starts included. Chord naming on performed classical
input is effectively context-free; the key display matters as its own product
surface, not as a shaper of chord names.

**Avenue 1 verdict.** The decomposition is complete and the residual is triaged
to ground:

- Coverage (49%) is the segmenter's caution; perfect boundaries buy 26 points of
  time at a small exact cost (log -06).
- Of disagreement time: about a third is functional labels never voiced, almost
  half is defensible sub-chord naming, the member-identical root dualities side
  with the product's naming philosophy (log -08), and the added-tone family
  survives every cheap mechanism (input demotion log -10, near-tie re-ranking
  log -11), leaving deep pricing surgery and voicing-structure awareness as
  recorded, deliberately-not-pursued leads with modest ceilings.

**Proposed avenue re-ranking (pending review).** With avenue 1's lessons:

1. **Causal prefix stability** (avenue 2) next: the one live product surface
   still unmeasured is label churn while a chord assembles, it reuses the
   existing fixtures and scorer conventions, and avenue 1 showed the live path's
   problems are about what happens between stable chords, not about the stable
   chords themselves.
2. **Voicing-structure awareness** (avenue 5) as the deep engine lead, now with
   a measured target (3.7% of displayed time, the strangest visible names).
3. **Frequency-weighted pool** (avenue 3) and **POP909** (avenue 4) stay queued
   behind those.

**Plain-English reading.** The last gift we could grant the app, its own key
detector's answer at any speed, changes nothing about the chords it names, which
closes the ledger on avenue 1: the live naming gap is now fully accounted for,
split between labels the player never voiced, honest sub-chord names,
naming-culture differences we choose to keep, and two recorded engine leads that
are real but expensive. What no ruler has yet seen is the flicker: what the
display does while a chord is still landing. That is the proposed next
measurement.

**Decisions.**

- Attribution arms complete; the protocol's decomposition requirement is now
  satisfiable for any future headline on this ruler.
- Avenue 1 status moves to complete-and-standing (the ruler, split, and tools
  remain the initiative's measurement backbone).

**Next.** On review of the re-ranking: scope avenue 2 (causal prefix stability)
with its own ruler definition entry: replay events note by note in onset order,
measure label churn and time-to-final-label, and freeze scoring semantics before
results, per protocol.

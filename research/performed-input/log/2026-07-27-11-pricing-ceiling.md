# 2026-07-27: Pricing ceiling measured; near-tie re-ranking is dead

**Goal.** Scope the pricing-threshold avenue from log -10 offline: how much
disagreement time could any re-ranking of surfaced candidates fix, and does the
base-reading shape (the base chord sitting just behind the extended winner)
actually exist in the surfaced near-ties?

**Setup.** New `tool/performed-input/candidate_ceiling.py`: for every exact-tier
disagreement segment (after boundary tolerance), checks whether any surfaced
alternative candidate matches the analyst exactly, records the time-weighted
cost gap behind the winner, and whether the winning alternative's chord tones
are a strict subset of the top candidate's (the base-reading shape). The quality
interval table gained `minorSharp5` and `minor7Sharp5`, which appear only among
alternatives (top-1 tiers and all prior numbers unaffected).

```sh
.venv/bin/python tool/performed-input/candidate_ceiling.py \
  --out build/performed-input/ceiling-a0-dev.json
```

**What happened.** A0 development split:

- The analyst chord appears among surfaced alternatives on 10.0% of disagreement
  time (4.0% of displayed; 15.4% of added-tone time). That is the hard ceiling
  for any re-ranking confined to what the analyzer already surfaces.
- The base-reading shape is essentially absent: 7.6% of the flippable time. When
  the analyzer names Dm(maj7) over a melody dwell, "Dm plus an unexplained tone"
  is not sitting behind it in the near-tie window; the candidate surface is
  built from full-explanation readings, and partial explanations are either
  priced far out or not enumerated.
- Where a flip does exist, the cost gap is wide (time-weighted median 0.150, p90
  0.250), so this is not a near-tie-window tweak either.

Verdict: the cheap form of the pricing avenue (re-rank surfaced near-ties) is
dead. The real experiment would change explanation-cost pricing inside the
engine so that base-plus-unexplained readings are enumerated and priced
competitively before the near-tie surface forms. That is genuine ranking surgery
affecting every naming context (solo, jazz, explore), guarded by oracle-pool
continuity, against a ceiling of at most 7 points of exact on this ruler (the
whole added-tone family) and realistically much less.

**Plain-English reading.** We asked whether the app already knows the right
answer and just ranks it second. Mostly it does not: on nine tenths of the
disagreement time, the analyst's chord is not among the alternatives the app
considered close, and the specific "plain chord just behind the fancy one"
pattern we hypothesized barely exists. Making the plain reading compete would
mean changing how the engine prices unexplained notes everywhere, a heavyweight
lever aimed at a modest prize.

**Decisions.**

- Engine work on the added-tone family is paused: every cheap mechanism is now
  measured and rejected (input-layer demotion, log -10; near-tie re-ranking,
  this entry), and the remaining lever (deep pricing surgery) is recorded with
  its modest ceiling for some future initiative to pick up deliberately, not
  stumbled into.
- With avenue 1's decomposition complete and its engine residual triaged to
  ground, the initiative's remaining open items are arm A1 (live inferred key,
  three presets, protocol completeness) and the untouched avenues 2 through 5 on
  the README ranking.

**Next.** Build arm A1 to complete the protocol's attribution set (the live key
detector feeding analysis context through the replay path, reported per behavior
preset), then step back and re-rank the initiative's avenues with everything
avenue 1 taught us.

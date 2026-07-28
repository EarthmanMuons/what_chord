# 2026-07-27: Display-policy frontier: segmenter gating dominates

**Goal.** Chart the flicker-versus-latency frontier of candidate display
policies offline (log -14's next step), so the display-policy conversation
reaches UX review with its trade-offs quantified.

**Setup.** New `tool/performed-input/display_policy_sim.py` over the emitted
frames and committed events: `raw` (today's display), `dwell-D` (the display
adopts a label only after the raw stream shows it continuously for D ms; blanks
pass through), and `gated` (the display shows each committed event's label from
its approximate commit time, event start plus the 200 ms minimum chord duration,
holding through gaps). Per policy: the stability ruler's flickerShare and
switchesPerMin on the simulated stream, plus the UX price: per committed event,
the latency until the display first shows that event's label, and the share of
events whose label never appears (missed).

```sh
.venv/bin/python tool/performed-input/display_policy_sim.py \
  --out build/performed-input/display-policy-dev.json
```

**What happened.** Development split:

| policy    | flicker | switches/min | latency med | latency p90 | missed |
| --------- | ------- | ------------ | ----------- | ----------- | ------ |
| raw       | 0.466   | 321.8        | 0 ms        | 0 ms        | 0.000  |
| dwell-100 | 0.366   | 132.8        | 100 ms      | 100 ms      | 0.028  |
| dwell-200 | 0.287   | 104.0        | 200 ms      | 200 ms      | 0.058  |
| dwell-300 | 0.201   | 83.7         | 300 ms      | 300 ms      | 0.308  |
| dwell-500 | 0.099   | 60.7         | 500 ms      | 500 ms      | 0.566  |
| dwell-750 | 0.075   | 45.6         | 750 ms      | 750 ms      | 0.743  |
| gated     | 0.064   | 40.6         | 200 ms      | 200 ms      | 0.000  |

The segmenter-gated policy dominates the entire dwell family: lowest flicker
(0.466 to 0.064, a sevenfold reduction), fewest switches (5.4 per second to
0.7), bounded latency, and zero missed chords, because it displays exactly the
events the capture path commits. The dwell filters fail structurally: past 200
ms they start missing real chords wholesale (31% at dwell-300, 57% at
dwell-500), since a label inside a short or ornamented event never survives the
dwell before the raw stream moves on. The stability judgment the dwell filter
tries to recompute already exists, better, in the segmenter's pending-challenger
logic.

Caveats, recorded with the result:

- The commit time is approximated as event start plus the 200 ms minimum
  duration; the real debounce sometimes commits later, so gated latency is a
  lower bound. An app-side prototype would measure the true distribution.
- Gating changes the display's semantics: today the label means "sounding now",
  gated it means "the chord you played", held through gaps and silence. Whether
  to hold, dim, or blank during gaps is a product decision the simulation cannot
  make, and variants (gated-with-blank-on-silence) sit between.
- Corpus breadth, raised in review: the frontier's shape comes from 21 Beethoven
  movements. The stability metrics need no ground-truth labels, so replication
  on broader corpora (the full multi-composer ASAP set, or recorded user
  sessions) is cheap and should precede any shipped dial; this split picks the
  shape, not the final value. The dominance argument is structural (the
  segmenter already computes the needed judgment), which is the part most likely
  to transfer across idioms.

**Plain-English reading.** We simulated every reasonable way to calm the
display. Making labels earn their place by surviving a delay helps a little and
then starts eating real chords: by half a second of required dwell, the screen
never shows most of what was played. Routing the display through the same
machinery that already decides what counts as a chord beats every delay setting
on every axis at once: seven times less flicker, one change every second and a
half instead of five per second, a fifth of a second of lag, and nothing missed.
The remaining questions are pure product taste: what the screen should do
between chords, and confirming the numbers on music beyond Beethoven.

**Decisions.**

- The frontier and the structural dominance argument go to UX review; no
  app-side change is proposed from the research side, per the initiative's
  scope.
- Broader-corpus replication of the stability frontier is the pre-ship
  validation step if the gated direction is pursued.

**Next.** Avenue 2's measurement mission is complete (ruler frozen, baseline
recorded, frontier charted, product question handed off). Remaining on the
initiative: avenue 5 (voicing structure) as the deep engine lead, avenues 3 and
4 queued, and the one-shot test-split spend whenever a pre-declared result set
warrants it.

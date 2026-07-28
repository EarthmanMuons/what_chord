# 2026-07-28: POP909 stability replication: the pattern holds, the magnitudes are idiom-shaped

**Goal.** Replicate the stability baseline and display-policy frontier on the
pop corpus, closing the corpus-breadth caveat recorded in log -15.

**Setup.** New `tool/whatkey/pop909_extract.py`: a deterministic stride sample
(101 of 909 songs) replayed through the real capture path with frame emission,
three tracks merged, pedal-aware, neutral context; fixtures, frames sidecars,
and a roster file (split-file shape, explicitly not a frozen split) under
`build/whatkey-fixtures/pop909-nc-v1`. The frozen stability tools consume the
set unchanged.

```sh
.venv/bin/python tool/whatkey/pop909_extract.py --analysis-profile whatKeyPaper2026
.venv/bin/python tool/performed-input/stability_score.py \
  --fixtures build/whatkey-fixtures/pop909-nc-v1 \
  --split-file build/whatkey-fixtures/pop909-nc-v1/roster.json \
  --split development --out build/performed-input/stability-pop909.json
.venv/bin/python tool/performed-input/display_policy_sim.py \
  --fixtures build/whatkey-fixtures/pop909-nc-v1 \
  --split-file build/whatkey-fixtures/pop909-nc-v1/roster.json \
  --out build/performed-input/display-policy-pop909.json
```

**What happened.** Baseline, POP909 (101 songs) against classical dev (21
movements) in parentheses:

| labeledShare  | switchesPerMin | flickerShare  | settle med   | settle p90    | churnPerEvent |
| ------------- | -------------- | ------------- | ------------ | ------------- | ------------- |
| 0.894 (0.567) | 95.3 (321.8)   | 0.187 (0.466) | 187 (213) ms | 4011 (873) ms | 0.71 (1.27)   |

Frontier on POP909:

| policy    | flicker | switches/min | latency med | missed |
| --------- | ------- | ------------ | ----------- | ------ |
| raw       | 0.187   | 95.3         | 0 ms        | 0.000  |
| dwell-100 | 0.173   | 75.5         | 100 ms      | 0.003  |
| dwell-200 | 0.155   | 69.2         | 200 ms      | 0.009  |
| dwell-300 | 0.124   | 61.9         | 300 ms      | 0.172  |
| dwell-500 | 0.073   | 55.3         | 500 ms      | 0.399  |
| dwell-750 | 0.057   | 49.4         | 750 ms      | 0.559  |
| gated     | 0.082   | 51.3         | 200 ms      | 0.000  |

Readings:

1. **The structural conclusion transfers.** On pop as on classical, the dwell
   family starts eating real chords at useful strengths (17% missed at
   dwell-300, 40% at dwell-500), and segmenter gating is the only policy that
   cuts flicker substantially (0.187 to 0.082) with nothing missed. Dwell-500
   edges gating on raw flicker (0.073) only by silently dropping two chords in
   five, which is not a policy.
2. **The magnitudes are idiom-shaped, and Beethoven was the stress case.** Pop
   arrangements are chordal: the raw display is labeled 89% of the time (57%
   classical), switches 1.6 times per second rather than 5.4, and flickers at
   0.19 rather than 0.47. The review's caution about the small classical corpus
   was correct in direction: the classical numbers are the worst case, not the
   typical case, and any shipped dial tuned only on them would have overweighted
   the problem.
3. **A pop-specific tail the classical corpus hid:** settle p90 is 4.0 seconds
   (0.87 s classical). Pop chords are long, and late ornaments re-label the
   display deep into a chord's life; gating fixes exactly this tail, which is
   arguably more user-visible than fast flicker since the name changes mid-chord
   while nothing harmonically new is happening.

**Plain-English reading.** On pop music the screen misbehaves the same way but
three times less often, and it has a habit the classical test could not show: a
chord that sits for four seconds can have its name revised at the end for no
audible reason. The recommendation survives its first out-of-idiom test intact:
route the display through the segmenter, which fixes both the fast flapping and
the late renames, at a fifth of a second of lag, missing nothing, in both
idioms.

**Decisions.**

- Log -15's corpus-breadth caveat is closed for the frontier's structural claim;
  the caveat stands, correctly, against quoting any single flicker number as
  universal.
- POP909 stability fixtures (roster, not split) are the second standing corpus
  for any future display-policy or stability work.

**Next.** The initiative queue holds avenue 3 (frequency-weighted pool and
observed-voicing sampling, for which POP909 is now an admitted source) and the
eventual pre-declared test-split spend. The display-policy frontier, now two
idioms strong, is ready for the UX conversation whenever the product side takes
it up.

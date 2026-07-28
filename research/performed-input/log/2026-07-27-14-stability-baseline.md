# 2026-07-27: Stability ruler frozen; the display flickers by policy

**Goal.** Execute the approved freeze (log -13): stability ruler v1 into
PROTOCOL.md, development baseline, and the concentration reading that decides
which fix conversation to have.

**Setup.**

```sh
.venv/bin/python tool/performed-input/stability_score.py \
  --split development --out build/performed-input/stability-a0-dev.json
```

Concentration diagnostic (switches and flicker time classified inside versus
outside committed event windows) computed from the same frames and fixtures;
method inline in this entry's numbers, tool unchanged from the reviewed freeze.

**What happened.** Development baseline (21 pieces, mean per piece):

| labeledShare | switchesPerMin | flickerShare | settle med | settle p90 | churnPerEvent |
| ------------ | -------------- | ------------ | ---------- | ---------- | ------------- |
| 0.567        | 321.8          | 0.466        | 213 ms     | 873 ms     | 1.27          |

The gate-excluded smoke magnitudes hold on the real split: the raw display label
changes more than five times per second of labeled time, and nearly half of all
labeled display time is spent on labels that live under half a second.

Where it concentrates:

- 20.4% of labeled display time falls outside committed events, in the stretches
  the segmenter itself refuses to commit. That time hosts 53.8% of all label
  switches and flickers at 67.0%, twice the inside rate. The display is showing,
  at full confidence, exactly the material the capture path already knows is
  unstable.
- Inside committed events, flicker share is still 33.2% with 1.27 label changes
  per event: ornaments and passing tones re-label the display in the middle of
  chords the segmenter has already stabilized.

**Reading.** Both regimes point at display policy rather than analyzer quality.
Avenue 1 proved the analyzer names stable voicings acceptably and
context-freely; this ruler shows the product surfaces every intermediate reading
anyway, because the display consumes raw per-frame analysis while the
segmenter's stability judgment (pending-challenger debounce, minimum duration)
is consulted only for history and key detection. Two candidate policies, both
presentation-layer with no engine change:

- Segmenter-gated display: show committed labels, holding through the gaps. Zero
  flicker by construction; the price is commit latency (the settle median of 213
  ms says the raw display often lands the final answer well before the 200 ms
  minimum duration plus debounce would commit it).
- Minimum-dwell hold: the display switches only after a candidate label survives
  some dwell. A tunable point between today's raw stream and full gating.

The flicker-versus-latency frontier of these policies is measurable offline from
the frames and events already emitted, no app change needed to decide.

**Plain-English reading.** The app changes its displayed chord name over five
times a second while a real piece is played, and half of what it shows lives
less than half a second. The engine is not confused; the screen is simply wired
to every intermediate guess, including the fifth of display time its own capture
machinery has already flagged as not-yet-a-chord. The fix is a display policy
with one dial, how long a name must survive before the screen adopts it, and we
can measure the whole dial offline before touching the app.

**Decisions.**

- Stability ruler v1 frozen as approved; baseline recorded.
- The fix conversation is scoped to display policy (presentation layer);
  analyzer stability work is explicitly out of scope on this evidence.

**Next.** Simulate display policies offline over the existing frames and events
(raw, minimum-dwell at several values, segmenter-gated), chart the
flicker-versus-latency frontier on the development split, and bring the frontier
to review before any app-side proposal.

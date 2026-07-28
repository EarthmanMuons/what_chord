# 2026-07-28: A gate-busy "settling" affordance is measured out

**Goal.** Evaluate the feel-test suggestion that the display gate's ~200 ms
latency could read as purposeful rather than laggy if some affordance showed
instantly while the gate is settling.

**What happened.** The affordance's duty cycle is computable from the existing
raw and gated streams: it would be active whenever the raw top-1 disagrees with
the displayed label. Measured (development split and the POP909 roster): active
39.5% of labeled time on classical and 23.2% on pop, firing 168 and 73 bursts
per minute respectively, median burst 112-200 ms. Real playing keeps the gate
perpetually busy, so "waiting" is not a rare state to signal, and any visual
channel keyed to it inherits the flicker the text channel just lost.

**Disposition.**

- Gate-state indicator: declined on the numbers above.
- First response to the lag feel: habituation. The latency is uniform and
  predictable, and the keyboard already acknowledges input instantly; only the
  name is deliberate. Re-evaluate after days of playing.
- If the feel persists: polish the arrival (an eased, confident entrance
  animation at promotion, which animates at the calm committed rate of about 0.7
  per second) rather than signaling the wait.
- A narrowly scoped variant (an in-progress treatment on the held note/interval
  label only during a build-from-nothing warmup) would not strobe and remains
  available if the deliberate-build case still feels laggy after habituation.
- Shortening the display gate below 200 ms: declined for display/history
  coherence, priceable offline if ever reconsidered.

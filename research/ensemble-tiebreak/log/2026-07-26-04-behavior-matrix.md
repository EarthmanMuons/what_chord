# 2026-07-26: Behavior matrix: preset sensitivity collapses

**Goal.** Complete the entry -02 measurement across all key behavior timescales
before the holdout (initiative discussion, 2026-07-26): the app's ensemble
naming runs on the pinned reactive internal key, so stable alone is not the
product-faithful arm.

**Setup.** Engine at the entry -02/-03 state; same commands as entry -02 with
`--behavior balanced` and `--behavior reactive`.

**What happened.** Dev splits, engine top-1 exact:

| Ruler, behavior | Inferred | Annotated | Hindsight |
| --------------- | -------- | --------- | --------- |
| Weimar stable   | 0.9288   | 0.9291    | 0.9296    |
| Weimar balanced | 0.9267   | 0.9291    | 0.9327    |
| Weimar reactive | 0.9285   | 0.9291    | 0.9399    |
| DCML stable     | 0.9654   | 0.9729    | 0.9651    |
| DCML reactive   | 0.9629   | 0.9729    | 0.9605    |

Readings:

- Preset sensitivity has essentially collapsed: all Weimar arms sit within 0.2
  points of each other where the baseline spread arms visibly. Naming no longer
  depends on the key containing the root, so the key timescale stops mattering
  to naming accuracy. No preset-specific risk remains for the holdout, which
  will report the stable and reactive arms.
- A consequence for a whatkey-local adoption, recorded honestly: the internal
  reactive naming key's measured advantage (93.5 against 92.8 on DCML dev, its
  log 2026-07-26-07) has dissolved; post-admission the ordering even inverts
  within noise (96.29 reactive against 96.54 stable). Admission robustness ate
  the mechanism the decoupled key exploited. The internal key stays: it is
  harmless for naming and it remains the relabel driver, and the relabel retains
  clear value on jazz (Weimar reactive hindsight 0.9399 against live 0.9285,
  still +1.1 points one event later).

**Plain-English reading.** Before this change, naming a rootless chord correctly
often depended on the key detector having just the right belief, so faster key
settings helped. Now the name mostly comes from the notes themselves, and any
key setting does about equally well. The one-event history correction still pays
on jazz, so the machinery built for it keeps its job.

**Decisions.** Holdout proceeds with stable and reactive arms reported. The
internal naming key's diminished live advantage is noted for whatkey-local's
record; no unwinding, since the relabel still rides it.

**Next.** Pre-declare and run the Weimar test split.

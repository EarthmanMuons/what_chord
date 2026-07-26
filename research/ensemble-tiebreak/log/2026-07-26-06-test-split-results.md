# 2026-07-26: Test-split confirmation: zero losing solos

**Goal.** Execute the result set pre-declared in entry -05.

**Setup.** As declared: baseline arms reconstructed from the pre-admission
engine (commit 3294abca's three analysis files, restored from git and swapped
back after the runs; package suite and comping gate verified intact afterward),
current arms on the shipped engine, stable and reactive behaviors,
weimar-comping-v1 test split (83 solos, 77 with scored events, 3,666 rootless
seventh events).

**What happened.** Engine top-1 exact:

| Behavior, arm       | Baseline | Current |
| ------------------- | -------- | ------- |
| stable, inferred    | 87.3%    | 94.2%   |
| stable, annotated   | 86.1%    | 94.6%   |
| reactive, inferred  | 85.5%    | 93.1%   |
| reactive, annotated | 86.1%    | 94.6%   |

Paired per-solo (seeded bootstrap CI95 and Wilcoxon, as entry -02):

- stable inferred: +0.0628, CI95 [+0.0448, +0.0816], 41 wins / 0 losses / 36
  ties, p = 2.4e-08. Annotated: +0.0751, CI95 [+0.0536, +0.0990], 41/0.
- reactive inferred: +0.0688, CI95 [+0.0499, +0.0892], 46/0/31, p = 3.5e-09.

**Against the pre-declared expectations.** All met: transfer at roughly dev
magnitude (aggregate +6.9 to +7.6 points against dev's +8.4 to +9.2), the
behavior arms within about a point of each other, and the annotated arm moving
with the inferred arm. Not a single solo regressed in any arm.

**Plain-English reading.** On held-out jazz standards never seen during any
tuning, the ensemble mode's naming goes from about seven chords in eight to
better than fifteen in sixteen, and not one solo got worse. The mechanism is
structural (readings that previously could not exist now can), which is why it
transfers cleanly.

**Decisions.** The test split is spent; the entry -02 change is confirmed on
held-out data and stands as this initiative's shipping result. Remaining
residual and its mechanisms per entry -03.

**Next.** README results section; the resolution-aware ensemble relabel stays
the scoped follow-up.

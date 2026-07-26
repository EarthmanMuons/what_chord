# 2026-07-26: Warmup-gate removal confirmed on the overlap; decision pending

**Goal.** Execute the runs pre-declared in entry -14 and complete the
adoption-bar evidence for minEvents 1.

**Setup.** As entry -14. One correction recorded for honesty: the first paired
comparison ran against the overlap baselines from entry -03, which predate the
cadence-boost default and so conflated the two adoptions; the numbers below use
the correct entry -06 baselines (cadence boost 4). The chord-context harnesses
gained a `--min-events` flag (default 3, the current shipped value) for the
downstream arm.

**What happened.** Overlap (performed input), minEvents 1 vs the shipped
configuration:

| Timescale | Coverage                  | Exact            | TTFC med/p90 | Paired exact                                          |
| --------- | ------------------------- | ---------------- | ------------ | ----------------------------------------------------- |
| hl30      | 0.8870 to 0.8942          | 0.5211 to 0.5239 | 2/3 to 0/2   | +0.0027, CI95 [+0.0011, +0.0052], p = 0.0007 (24/4/8) |
| hl4       | 0.8548 vs 0.8548 base-era | 0.5351 to 0.5377 | 2/3 to 0/2   | (not separately tested; direction matches)            |
| hl1       | 0.8281 to 0.8291          | 0.5282 to 0.5307 | 2/2 to 0/2   | +0.0026, CI95 [+0.0011, +0.0047], p = 0.0006 (24/4/8) |

Coverage paired at hl30: +0.0072, CI95 [+0.0045, +0.0110], p < 0.0001 (29 wins,
zero losses). The pre-declared expectation (coverage and time to first claim
improve, exact not materially worse) is exceeded: exact improves with
significance at both tested timescales.

Calibration rides along cleanly: raw ECE on Isophonics dev stable claimed events
moves 0.148 to 0.145 (mean confidence 0.925 to 0.919 against accuracy 0.777 to
0.775), so the fitted display temperature remains valid.

Downstream (rootless harness, DCML dev, reactive, minEvents 1): ensemble
inferred exact unchanged at 93.5%, hindsight unchanged at 94.7%; the fallback
bucket (no claim yet) halves from 129 to 65 events at 90.8% exact. Neutral to
mildly positive, as expected for a first-events mechanism.

**Plain-English reading.** On real performances the detector that speaks from
the first chord is slightly more accurate, not less, at every speed, and its
confidence readout stays as honest as before. The app-facing effect is simple:
the key indicator lights up on the first chord instead of the third, and nothing
else about its behavior changes.

**Decisions.** Adoption-bar ledger for minEvents 1: bar 1 met as written (WiR
hl1 exact +0.0103, p = 0.0028, at better coverage and unchanged spurious); bar 3
met (suite improves or holds; ambiguous probes fully acceptable-compliant); bar
4 met with significance; bar 5 met (downstream neutral). Bar 2 is the open
judgment: Iso stable exact -0.0038 (p = 0.0048) against coverage +0.0258 with
zero losing tracks; under the entry -05 amendment precedent this is the same
decision shape the cadence boost required. The ship decision is deliberately
left to the initiative discussion, alongside the paused holdout question.

**Next.** Ship decision on minEvents 1; then the holdout evaluation per the
staged plan.

# 2026-07-27: Correction addendum: overlap numbers on corrected asap-wir labels

**Goal.** Record corrected values for the overlap (performed-input) numbers in
entries -03 and -06, whose `asap-wir-nc-v1` ground truth carried measure-shifted
key labels in 11 of 36 movements (3.34% of events; discovery and correction in
performed-input logs 2026-07-27-02 and -03, corrected corpus `asap-wir-nc-v2`).
The original entries stay as written, per the append-only convention.

**Setup.** Era-faithful arms: pre-warmup-gate `--min-events 3` with explicit
cadence boost, matching the defaults in effect when entries -03 and -06 ran.

```sh
for hl in 30 4 1; do for cb in 0 4; do
  dart run tool/whatkey/harness.dart \
    --fixtures build/whatkey-fixtures/asap-wir-nc-v2 --detector hmm \
    --decay-half-life-seconds $hl --cadence-boost $cb --min-events 3 \
    --out build/whatkey-local/overlap-v2-hl$hl-cb$cb
done; done
python3 tool/whatkey/compare.py \
  build/whatkey-local/overlap-v2-hl30-cb4/report.json \
  build/whatkey-local/overlap-v2-hl30-cb0/report.json
```

**What happened.** Entry -06's confirmation table, corrected (published values
in parentheses):

| Timescale | Base            | cb 4            | Mods                        | Paired exact                                          |
| --------- | --------------- | --------------- | --------------------------- | ----------------------------------------------------- |
| hl30      | 0.5042 (0.5042) | 0.5200 (0.5211) | 142 to 152/454 (141 to 153) | +0.0159, CI95 [+0.0094, +0.0232], p = 0.0001 (26/4/6) |
| hl4       | 0.5177 (0.5155) | 0.5365 (0.5351) | 223 to 238/454 (226 to 239) | +0.0188, CI95 [+0.0081, +0.0293], p = 0.0017 (27/8/1) |
| hl1       | 0.5223 (0.5186) | 0.5307 (0.5282) | 264 to 272/454 (264 to 271) | +0.0084, CI95 [-0.0016, +0.0188], p = 0.147 (23/12/1) |

The pre-declared expectation still holds on corrected labels: exact and matched
modulations up at every timescale, hl30 and hl4 individually significant, hl1 a
positive trend (somewhat weaker than published, p = 0.147 vs 0.087). The cadence
boost 4 adoption stands unchanged. Entry -03's cb 3 reading was an intermediate
dose on the same corpus and inherits the same correction direction; it was not
re-run separately since the adoption rested on the cb 4 confirmation above.

For the going-forward record, the current shipped defaults (cadenceBoost 4,
minEvents 1) on corrected labels:

| Timescale | Coverage | Exact | MIREX | Mods    | Spurious (med, p90) |
| --------- | -------- | ----- | ----- | ------- | ------------------- |
| hl30      | 0.894    | 0.523 | 0.638 | 152/454 | 3, 9                |
| hl4       | 0.855    | 0.539 | 0.660 | 238/454 | 8, 16               |
| hl1       | 0.829    | 0.533 | 0.654 | 272/454 | 12, 30              |

**Plain-English reading.** Fixing eleven pieces' shifted answer keys nudges
every overlap number by a few thousandths and flips nothing: the cadence boost
still earns its keep on real performances at every speed.

**Decisions.** No configuration change. `asap-wir-nc-v2` or later for any future
runs on this corpus.

**Next.** None; the initiative remains complete.

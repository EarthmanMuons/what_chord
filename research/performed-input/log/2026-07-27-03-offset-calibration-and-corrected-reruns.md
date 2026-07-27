# 2026-07-27: Content-based offset calibration; historical numbers corrected

**Goal.** Fix the downbeat-map offset calibration that log -02's census caught
mislabeling 8 of 36 movements, re-verify with the census, quantify exactly how
much ground truth the bug corrupted, and re-run every study number that depended
on the old labels so the historical record carries legitimate values.

**Setup.**

```sh
.venv/bin/python tool/whatkey/asap_wir_extract.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --bench-root build/whatkey-corpora/contrapunctus-bench \
  --analysis-profile whatKeyPaper2026
.venv/bin/python tool/whatkey/wir_alignment_probe.py
# era-faithful re-runs (recipes for the 07-07 arms; explicit
# --cadence-boost/--min-events 3 for the 07-26 overlap arms) plus
# current-defaults reference runs; see the addenda logs for the commands.
```

**What happened.**

Calibration fix (`asap_wir_extract.py`): the last-measure match is now only an
anchor. The offset is chosen by content, scoring each candidate within 2 of the
anchor by the time-weighted overlap between sounding pitch classes and the
analyst chord active at each snapshot, using the harmony spans the extractor now
carries (log -02). The census's sharp-peak structure makes the argmax
effectively deterministic; the probe stays the independent verifier. The
extractor now requires the repo venv (music21 for figure conversion).

Calibration results: all 8 known-misaligned movements corrected (3-1, 9-1, 14-3,
16-2, 31-1 to +1 relative; 30-1, 7-4 to -1; 7-3 resolved its -1/-2 ambiguity to
-1 absolute). Two of the shallow movements also moved (10-1 by -1, peak 0.680 vs
0.605; 7-1 by -2 on a thin 0.011 margin). Every healthy movement kept its
anchor.

Census after the fix: 35 of 36 movements peak at +0. Formerly misaligned
movements now sit at 0.70-0.87. Still below the gate: 31-3_4 remains flat (0.41
at every shift, structurally unusable as-is), and 12-1 (0.588), 7-4 (0.593), 7-1
(0.667) peak at 0 but shallowly; the gate from log -02 keeps all four out of any
ruler freeze pending individual inspection.

Exact contamination, measurable because the v1 and v2 replays are
event-identical (same timestamps, so the diff is purely ground-truth
correction): 347 of 10,395 event key labels (3.34%) were wrong, across 11
movements; worst were 30-1 (22.9%), 7-1 (18.9%), 16-2 (15.9%).

Corrected study numbers, era-faithful configurations on the corrected labels
(full tables in the two addenda: whatkey log 2026-07-27-01, whatkey-local log
2026-07-27-02):

- Timescale experiment (whatkey log 2026-07-07-21): shipped-era exact 0.47 to
  0.504, reflex 0.59 to 0.601; the reflex-wins-on-tonicization-labels conclusion
  is unchanged and slightly stronger. Mode confusion: the shipped arm's
  parallel-mode confusion drops from 9% to 6%, so total mode error falls from
  14% to 11% of claims; a third of the measured mode error was mislabeled ground
  truth.
- Cadence boost overlap (whatkey-local log 2026-07-26-06): cb4-vs-base paired
  exact +0.0159 (p = 0.0001) at hl30, +0.0188 (p = 0.0017) at hl4, +0.0084 (p =
  0.147) at hl1, against published +0.0169 / +0.0197 / +0.0096 (p = 0.087). Same
  signs, same significance pattern, matched modulations still up at every
  timescale; the adoption stands.
- Current shipped defaults (cadenceBoost 4, minEvents 1) on corrected labels,
  the going-forward reference: exact 0.523 (hl30), 0.539 (hl4), 0.533 (hl1);
  coverage 0.894 / 0.855 / 0.829; matched modulations 152 / 238 / 272 of 454.

Guard disposition: no engine, app, or detector code changed; the fix is
labels-only in a build-time extractor, and the v1 fixtures remain on disk and in
the reproduction contract untouched. The whatkey-local behavioral guards
therefore do not apply; the study re-runs above are the meaningful check, and
they reproduce every conclusion.

**Plain-English reading.** We re-labeled the corpus with the measure offsets the
notes themselves vote for, re-graded every experiment that ever used the old
labels, and the answers barely moved: every decision made on this corpus
survives, the detector was in truth a touch better than we thought, and the
scariest-looking product number (how often the app shows the wrong mode)
improves once the answer key stops being wrong underneath it.

**Decisions.**

- `asap-wir-nc-v2` (content-calibrated, harmony-labeled) is the lineage for all
  performed-input work and any future key work; v1 stays frozen for the
  historical reproduction contract, with a correction note in REPRODUCING.md.
- Correction addenda recorded in both affected initiatives' logs rather than
  editing the original entries (append-only convention).
- The census gate keeps 31-3_4, 12-1, 7-4, and 7-1 out of ruler freezes.

**Next.** Back to the avenue 1 build order: inspect the shallow movements, then
freeze span-level scoring semantics and the dev/test split over the gate-passing
movements.

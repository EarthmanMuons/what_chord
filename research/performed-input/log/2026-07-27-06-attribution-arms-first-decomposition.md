# 2026-07-27: Arms B, C, BC built; the first decomposition lands

**Goal.** Build the remaining cheap attribution arms (B: annotated analyst key
as analysis context; C: annotation-boundary segmentation; BC: both) and read the
first decomposition of the live-identity gap.

**Setup.** `replay_batch.dart` gained two optional request fields:
`contextTimeline` (context switches at given times, applied to both the
segmenter path and span analysis) and `spanBoundaries` plus `spanNoteThreshold`
(annotation-boundary segmentation: each adjacent boundary pair is one span,
whose voicing is the notes sounding at least the threshold fraction of the span,
still subject to the three-note capture gate). `asap_wir_extract.py` gained
`--arm A0|B|C|BC` (arm sets get an `-arm<X>` suffix; A0 fixtures unchanged) and
`--span-note-threshold` (default 0.25, recorded in the manifest). Dart checks
green (analyze, import order, full root test suite); ruff 0.16.0 green.

```sh
for arm in B C BC; do
  .venv/bin/python tool/whatkey/asap_wir_extract.py \
    --asap-root build/whatkey-corpora/asap-dataset \
    --bench-root build/whatkey-corpora/contrapunctus-bench \
    --analysis-profile whatKeyPaper2026 --arm $arm
done
.venv/bin/python tool/performed-input/identity_score.py \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2-armB \
  --split development --arm B --out build/performed-input/b-dev.json
# likewise armC/c-dev.json, armBC/bc-dev.json
```

**What happened.** Development split, mean per piece, the full 2x2 on
(segmentation, context):

| arm | segmentation  | context     | coverage | exact | root  | members |
| --- | ------------- | ----------- | -------- | ----- | ----- | ------- |
| A0  | app           | neutral     | 0.493    | 0.595 | 0.737 | 0.525   |
| B   | app           | analyst key | 0.493    | 0.595 | 0.737 | 0.524   |
| C   | analyst spans | neutral     | 0.749    | 0.570 | 0.730 | 0.435   |
| BC  | analyst spans | analyst key | 0.749    | 0.572 | 0.732 | 0.435   |

Wiring check on arm B: the analyst-key context flips the top-1 (root, quality)
on 33 of 5,973 development events (0.55%), so the context genuinely flows and
genuinely does not matter. The effect is equally null under both segmentations.

Three findings:

1. **The missing-key-context hypothesis is dead.** Giving the analyzer the
   analyst's own local key moves exact by at most +0.002 anywhere in the table.
   Whatever the engine displays on performed input, it would display nearly the
   same thing with perfect key knowledge. Ranking context is a tiebreak, and
   real voicings rarely present the tie.
2. **Segmentation owns the coverage half of the gap, and it is a trade, not a
   free win.** Perfect analyst boundaries lift displayed time from 0.49 to 0.75
   while exact drops 2.5 points: the newly covered time is the sparse,
   ornamented texture the app's segmenter previously declined to name. The
   members tier falls harder (0.52 to 0.43) because span voicings accumulate
   ornamental pitch classes. The remaining 25% of time is uncovered even with
   perfect boundaries: those spans never hold three concurrent threshold-passing
   notes, an input-representation limit, not a segmenter bug.
3. **The ranking residual at perfect-everything is exact 0.57.** With analyst
   boundaries and analyst key both granted, the engine agrees with the analyst's
   root and quality family 57% of displayed time (root 73%). One caveat before
   treating that as an engine defect: the ruler's ceiling is not 1.0, because
   analysts label functional harmony while the app names surface chords; an
   arpeggiated measure the analyst calls V7 contains passing sonorities that any
   honest surface-namer will name. Separating surface-vs-functional mismatch
   from true ranking misses needs a qualitative error census over BC
   disagreements.

**Plain-English reading.** We granted the app perfect knowledge, one gift at a
time. Telling it the key changed almost nothing, which retires a long-standing
suspicion. Handing it the analyst's chord boundaries let it speak 50% more of
the time at slightly lower precision, putting a measured price on the
segmenter's caution. And with every gift granted at once, the app still agrees
with the analyst only 57% of the time, which means the next truth to extract is
how much of that residual is the engine being wrong versus the analyst and the
app answering different questions.

**Decisions.**

- Arm construction semantics recorded here and in the tools; the 0.25 span note
  threshold is declared in each arm manifest.
- No engine change is proposed from these numbers (protocol: arms decompose,
  adoption needs a targeted change plus the bar).

**Next.** Qualitative error census over BC disagreements: sample disagreement
time, categorize surface-vs-functional versus genuine misranking versus label
noise, and size the truly actionable residual before proposing any engine work.
Arm A1 (live inferred key, three presets) stays queued behind it.

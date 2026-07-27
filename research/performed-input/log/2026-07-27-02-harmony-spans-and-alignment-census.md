# 2026-07-27: Harmony spans in the extraction, and an alignment census

**Goal.** Build step 1 of avenue 1: extend the ASAP x When in Rome extraction to
carry the analyst chord spans it previously discarded, then hand-inspect the
resulting alignment quality before freezing scoring semantics or the split (log
2026-07-27-01, build order).

**Setup.**

```sh
.venv/bin/python tool/whatkey/asap_wir_extract.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --bench-root build/whatkey-corpora/contrapunctus-bench \
  --analysis-profile whatKeyPaper2026
.venv/bin/python tool/whatkey/wir_alignment_probe.py            # full census
.venv/bin/python tool/whatkey/wir_alignment_probe.py 8-1 --worst 5
```

**What happened.**

Extraction extension (`tool/whatkey/asap_wir_extract.py`): each fixture now
carries a `harmony` timeline, the full RomanText chord-span sequence (measure,
beat, key, figure) projected into performance milliseconds through the same
downbeat alignment the key labels already use. Performance downbeats anchor
measures (which keeps lookups correct across performed repeats); spans starting
mid-measure are placed by linear beat interpolation between downbeats, with
compound meters counted in dotted beats. Each event also gets a `labels.harmony`
convenience label, the span active at its start. Conversion of (key, figure) to
expected chord content stays a scoring-time decision. The default set name moved
to `asap-wir-nc-v2`; the v1 set the key work uses is untouched. 36 fixtures
regenerate cleanly.

Inspection tool (`tool/whatkey/wir_alignment_probe.py`, committed since the
census will re-run after fixes): per movement it checks timeline sanity,
agreement between the two independent key paths (measure-map `localKey` vs
harmony-span key), music21 conversion of every labeled figure, chord-tone
overlap between analyst chord and performed `pcMask`, and a shift response: mean
overlap when all harmony labels are displaced by a global measure offset in [-2,
+2].

Findings, good news first:

- Every RomanText figure in the corpus converts through music21: zero parse
  failures across all 36 movements.
- The two key paths agree on 94-100% of events per movement; disagreements sit
  exactly where expected, at mid-measure key changes where the span path is
  finer than the measure-map path.
- The shift response validates the whole alignment chain: on healthy movements
  the overlap peaks sharply at shift 0 (0.71-0.89 at 0 vs roughly 0.4-0.6
  everywhere else). The probe therefore doubles as a calibration diagnostic.

The census, `+0` peak sharp and healthy in 24 of 36 movements:

| shift  | -2        | -1        | +0        | +1        | +2    | verdict        |
| ------ | --------- | --------- | --------- | --------- | ----- | -------------- |
| 1-1    | 0.452     | 0.383     | **0.888** | 0.419     | 0.444 | healthy        |
| 10-1   | 0.513     | 0.612     | 0.656     | 0.599     | 0.564 | shallow        |
| 11-1   | 0.463     | 0.365     | **0.818** | 0.540     | 0.483 | healthy        |
| 12-1   | 0.427     | 0.469     | 0.588     | 0.449     | 0.472 | shallow        |
| 13-4   | 0.570     | 0.548     | **0.744** | 0.616     | 0.563 | healthy        |
| 14-3   | 0.420     | 0.483     | 0.451     | **0.626** | 0.514 | offset +1      |
| 15-1   | 0.546     | 0.485     | **0.792** | 0.599     | 0.562 | healthy        |
| 15-4   | 0.574     | 0.516     | **0.798** | 0.573     | 0.598 | healthy        |
| 16-1   | 0.613     | 0.449     | **0.830** | 0.693     | 0.648 | healthy        |
| 16-2   | 0.471     | 0.435     | 0.578     | **0.653** | 0.506 | offset +1      |
| 18-1   | 0.437     | 0.404     | **0.885** | 0.636     | 0.567 | healthy        |
| 2-1    | 0.483     | 0.354     | **0.857** | 0.596     | 0.683 | healthy        |
| 21-2   | 0.400     | 0.461     | **0.787** | 0.471     | 0.452 | healthy        |
| 21-3   | 0.476     | 0.463     | **0.774** | 0.616     | 0.507 | healthy        |
| 22-1   | 0.621     | 0.562     | **0.861** | 0.598     | 0.644 | healthy        |
| 23-1   | 0.466     | 0.534     | **0.852** | 0.650     | 0.563 | healthy        |
| 26-2   | 0.493     | 0.431     | **0.716** | 0.379     | 0.438 | healthy        |
| 27-1   | 0.418     | 0.423     | **0.833** | 0.590     | 0.483 | healthy        |
| 28-1   | 0.550     | 0.510     | **0.822** | 0.604     | 0.605 | healthy        |
| 3-1    | 0.439     | 0.437     | 0.521     | **0.774** | 0.550 | offset +1      |
| 3-2    | 0.434     | 0.382     | **0.744** | 0.438     | 0.440 | healthy        |
| 30-1   | 0.459     | **0.692** | 0.575     | 0.487     | 0.445 | offset -1      |
| 31-1   | 0.429     | 0.538     | 0.447     | **0.776** | 0.504 | offset +1      |
| 31-3_4 | 0.439     | 0.397     | 0.382     | 0.407     | 0.385 | flat, unusable |
| 4-1    | 0.468     | 0.472     | **0.872** | 0.542     | 0.520 | healthy        |
| 5-1    | 0.569     | 0.424     | **0.828** | 0.547     | 0.600 | healthy        |
| 7-1    | 0.618     | 0.541     | 0.649     | 0.543     | 0.537 | shallow        |
| 7-2    | 0.417     | 0.500     | **0.713** | 0.481     | 0.476 | healthy        |
| 7-3    | **0.670** | 0.641     | 0.428     | 0.479     | 0.525 | offset -1/-2   |
| 7-4    | 0.429     | **0.581** | 0.563     | 0.449     | 0.411 | offset -1      |
| 8-1    | 0.408     | 0.384     | **0.798** | 0.486     | 0.441 | healthy        |
| 8-2    | 0.499     | 0.472     | **0.884** | 0.473     | 0.498 | healthy        |
| 8-3    | 0.475     | 0.435     | **0.832** | 0.462     | 0.525 | healthy        |
| 9-1    | 0.476     | 0.526     | 0.556     | **0.728** | 0.583 | offset +1      |
| 9-2    | 0.433     | 0.435     | **0.772** | 0.477     | 0.468 | healthy        |
| 9-3    | 0.488     | 0.625     | **0.803** | 0.600     | 0.481 | healthy        |

(9-2 is the `9-2_no_trio` fixture.)

The bad news that the census caught before it could poison the ruler:

- Eight movements have a wrong or dubious measure offset: 3-1, 9-1, 14-3, 16-2,
  and 31-1 peak at +1; 30-1 and 7-4 peak at -1; 7-3 drifts toward -1/-2. The
  extractor's offset calibration matches only the last map measure against the
  last analysis measure and considers only offsets {0, +1}, so it cannot even
  represent the -1 cases. This is not new to v2: the same offset feeds the v1
  KEY labels, so those movements' key boundaries have been measure-shifted all
  along (mostly benign for keys, which change rarely, but real).
- 31-3_4 is flat at every shift. The fixture folder covers two movements (sonata
  31, movements 3 and 4 run together) and the When in Rome analysis measure
  numbering evidently does not line up with the ASAP map at any global offset;
  it needs either a per-section alignment or exclusion.
- 10-1, 12-1, and 7-1 peak at 0 but shallowly (0.59-0.66); they need individual
  eyeballing before the split freeze.

Two systematic observations that shape the scoring design:

- The worst per-event mismatches on healthy movements are span-boundary
  artifacts: an analyst chord placed at beat 3 while the performed chord arrives
  a fraction later (Pathetique m1, `viio7/V` labeled while the player still
  sounds V), or an arpeggiated partial arrival credited to the wrong neighbor
  span. Point-event pairing would count all of these as misses; span-level
  time-weighted scoring with boundary tolerance is the right shape, as scoped.
- Even on healthy movements only 51-73% of events have pitch content strictly
  inside the analyst chord, while the analyst root is present in 76-91%.
  Performed events legitimately carry ornamental and pedal-blurred non-chord
  tones. Strict containment is the wrong notion of agreement; the metric must
  compare what the app named against the analyst chord, with note-content
  overlap reserved for alignment validation, which is all it is used for here.

**Plain-English reading.** The chord ground truth now rides along with every
performed event, and a cheap self-test (slide all the labels sideways and watch
agreement collapse) proves the labeling is genuinely anchored for two thirds of
the corpus. The same self-test caught a fifth of the corpus wearing its labels
one measure off, a bug that has quietly been shifting the key ground truth too,
and one movement whose labels do not fit at any offset.

**Decisions.**

- The alignment census is a gate: no movement enters the ruler (either split)
  until its shift response peaks sharply at 0. Currently 24 of 36 pass.
- The offset calibration fix (content-based selection over {-1, 0, +1} instead
  of last-measure matching over {0, +1}) is the next change. It touches the
  shared alignment that also produces the key labels, so per PROTOCOL.md the
  whatkey guard commands re-run with it, and the key-side impact gets its own
  disposition before any regenerated set replaces v1 for key work.
- `31-3_4` is excluded pending per-section alignment; 10-1, 12-1, and 7-1 are
  held out of any freeze until individually inspected.

**Next.** Implement the content-based offset calibration, re-run the census,
inspect the three shallow movements, then freeze scoring semantics and the
dev/test split over the movements that pass the gate.

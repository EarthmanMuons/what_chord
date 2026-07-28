# 2026-07-27: Error census sizes the actionable residual

**Goal.** Execute log -06's next step: categorize exact-tier disagreement time
into surface-vs-functional mismatch, defensible sub-chord naming, and genuine
engine-actionable misses, on both the BC arm and the product-path A0 arm.

**Setup.** New `tool/performed-input/error_census.py`: walks the frozen scoring
loop, and for each disagreeing time segment classifies (a) content: were all
analyst chord tones sounding (`playable`), only the root (`partial`), or not
even the root (`absent`); (b) naming: the app chord's relation to the analyst
chord (rootHit, appSubset, appSuperset, overlapping, unrelated). Time-weighted
matrix plus heaviest playable samples.

```sh
.venv/bin/python tool/performed-input/error_census.py \
  --out build/performed-input/census-bc-dev.json          # armBC default
.venv/bin/python tool/performed-input/error_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --out build/performed-input/census-a0-dev.json
```

**What happened.** Shares of disagreement time (development split):

BC arm (analyst boundaries, disagreement = 0.409 of displayed):

| content  | rootHit | appSubset | appSuperset | overlapping | unrelated | total |
| -------- | ------- | --------- | ----------- | ----------- | --------- | ----- |
| playable | 0.107   | 0.000     | 0.238       | 0.053       | 0.000     | 0.398 |
| partial  | 0.165   | 0.010     | 0.009       | 0.166       | 0.048     | 0.398 |
| absent   | 0.000   | 0.015     | 0.004       | 0.094       | 0.091     | 0.204 |

A0 arm (app segmentation, disagreement = 0.401 of displayed):

| content  | rootHit | appSubset | appSuperset | overlapping | unrelated | total |
| -------- | ------- | --------- | ----------- | ----------- | --------- | ----- |
| playable | 0.060   | 0.000     | 0.122       | 0.058       | 0.000     | 0.239 |
| partial  | 0.200   | 0.014     | 0.008       | 0.171       | 0.054     | 0.446 |
| absent   | 0.000   | 0.022     | 0.001       | 0.140       | 0.152     | 0.314 |

Readings:

1. **BC's big playable bucket was largely the arm's own artifact.** Playable
   drops from 0.40 (BC) to 0.24 (A0): span-union voicings accumulate ornament
   pitch classes that real capture never presents at once. The BC samples are
   dominated by turn figures baked into names (D-C#-D over D minor scored as D
   minorMajor7). Arm C's construction (0.25 threshold over whole spans) inflates
   appSuperset; a simultaneity-preserving span voicing is a noted arm
   refinement.
2. **On the product path, the non-actionable floor is large.** 31% of A0
   disagreement time is `absent` (the player never voiced even the analyst root:
   functional labels over pedal points, melody-over-implied-harmony) and much of
   `partial` (45%) is the app correctly naming the sub-chord that was actually
   sounding. The engine-actionable core, `playable`, is 24% of disagreement,
   roughly 10% of displayed time.
3. **The playable core has two recognizable shapes**, from the samples:
   - _Pedal-blurred ornaments baked into names_ (appSuperset, 12%): the sustain
     pedal holds an ornament tone with the chord, and the analyzer names the
     union (i in D minor with a sustained C# becomes D minorMajor7). Real live
     behavior, plausibly improvable by transient-tolerant voicing weighting; any
     such change is input-layer and triggers the whatkey non-interference guard.
   - _Root-choice conventions_ (rootHit plus part of overlapping): the
     m6-versus-half-diminished duality on identical pitch classes (iiø65 in D
     minor named G minor6; both are pcs {2,4,7,10}), and V named V7 when a
     passing seventh sounds. These connect directly to the oracle-comparison
     ranking conventions; the members tier already credits the pc-set agreement.
4. **One scoring refinement candidate for ruler v1.1** (not applied; the ruler
   stays frozen): the members tier compares the app's canonical quality
   intervals, so an It6 sounding {1,7,9} named as an A dominant7 (three notes
   present, no fifth) misses even the member tier. Comparing against the
   candidate's `presentIntervalsMask` instead would credit these enharmonic aug6
   matches. Recorded for a versioned ruler bump, with re-baselining, if adopted.

**Plain-English reading.** Of the time the app disagrees with the analyst on
real playing, about a third is the analyst labeling harmony the player never
literally sounded, and almost half is the app naming the fragment that was
actually under the fingers. The genuinely attackable slice is about a tenth of
all displayed time, and it splits into two nameable habits: swallowing a
pedal-held ornament into the chord name, and picking the other legal root for an
ambiguous stack. Both are engine conversations we already know how to have, one
in the input layer, one in the ranking conventions.

**Decisions.**

- No engine change proposed yet; the census gives the two candidate avenues
  their sizes (each on the order of a few percent of displayed time).
- Ruler v1 stays frozen; the presentIntervalsMask refinement is queued as a v1.1
  candidate requiring a versioned bump and re-baseline.
- Arm C's span-voicing construction gets a refinement note (simultaneity
  preservation) before it is used for any adoption argument.

**Next.** Two candidate engine avenues, to be scoped as separate entries with
pre-declared expectations: (1) transient-tolerant voicing weighting against the
pedal-ornament bucket (input layer, full guard set); (2) minor-mode
m6/half-diminished root convention review against the root-choice bucket
(ranking, oracle-pool continuity). Arm A1 (live key, three presets) remains
queued.

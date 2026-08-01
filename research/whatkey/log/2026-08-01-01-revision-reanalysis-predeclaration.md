# 2026-08-01: Predeclare the revision reanalyses

**Goal.** Define the smallest additional analyses needed to answer the TISMIR
editorial concerns about claim support, reference provenance, repertoire, and
annotation timescale without retuning against the spent held-out data. This
entry is written before calculating any of the new endpoints below.

## Why another analysis is warranted

The paper's frozen evidence still supports the broad observation that detector
behavior depends on the evaluation regime, but the revision audit found four
places where the original presentation outran the design:

1. Isophonics correctness excludes modal/no-key events that the detector's
   24-state major/minor ontology cannot express, while the reported coverage
   denominator includes them. Accuracy and coverage therefore do not currently
   describe the same selectable population.
2. The overlap-corpus segment figure pools events after filtering by the span of
   the existing analyst-key run. It does not create independently relabeled
   annotation granularities, and it does not show piece-level uncertainty or the
   configurations' different coverage.
3. The cross-corpus contrast changes repertoire, observations, label source,
   label persistence, and ontology together. A same-performance comparison
   against analyst keys and notated key signatures can isolate reference
   construct more closely, although it still cannot isolate every difference
   between annotation traditions.
4. The two named configurations cross both memory (30 versus 1 seconds) and
   functional blend (0 versus 0.1). A small factorial is needed before language
   about either ingredient can be sharpened.

These are post-submission construct-validity analyses. They do not convert the
already inspected data into a new confirmatory test.

## State known before this declaration

- The archived paper and reflex claims have already been inspected on the
  held-out When in Rome and Isophonics splits and on the corrected 36-piece
  ASAP/When-in-Rome overlap.
- Isophonics contains 568 of 19,062 events with `localKey: null`. The held-out
  split contains 305 such events in three entirely modal Beatles tracks; exact
  and MIREX scoring currently use 38 held-out tracks, while coverage, switching,
  and time-to-first summaries use all 41.
- The pooled overlap-figure values at minimum analyst-run spans of 0, 12, 20,
  and 32 measures have already been calculated and inspected. Those thresholds
  are therefore frozen historical choices, not newly predeclared cut points.
- The paper configuration is 30-second memory with functional blend 0; the
  reflex configuration is 1-second memory with functional blend 0.1. The
  submitted manuscript did not contain the other two cells of that factorial.
- The new scorable-cohort summaries, piece-level segment summaries, common-claim
  results, dual-reference interaction, and complete development factorial below
  have not been calculated at the time of this entry.

## Frozen inputs

The analysis starts at repository commit
`638c9d83a24e5a045acafa2f727d54e58d6bb45d`. The new tools may be implemented
after this declaration, but they must report the hashes below and fail when an
input differs.

- `isophonics-nc-v1` manifest SHA-256:
  `e9ae1f97a4d04b04a36dbb7468830923191b2e0281d129bf51dc814b063b48a5`
- Isophonics split SHA-256:
  `9f766789c4beeda65d9229d7c77c11c7e2f9be04746fa9d8b321edaa2abfe970`
- Isophonics paper held-out claims SHA-256:
  `401042ec2232fe3c5870af9b6ae78bea43760b5294e381a0b79b362d56e8671f`
- Isophonics reflex held-out claims SHA-256:
  `c6e8dd76d837095c4e36126ad44acf520d2c776834a16cca0f73904e20704f5f`
- Corrected `asap-wir-nc-v2` manifest SHA-256:
  `32bb9edd0ab0ac861ad1a474d439cf32dce6139254922f62d3e9d454dbe128a1`
- Corrected overlap paper claims SHA-256:
  `474a3497b30b2cd25f185821267cd9b49788de1b1b18a511c26d9be86daf8d99`
- Corrected overlap reflex claims SHA-256:
  `e83a960eff6fadc77d1a2ffa47bfe8016e6aa2e2de967656bdd2d366d3adf079`
- ASAP annotations SHA-256:
  `02e4b80f0a78150d1bd0fc21c9cee72ed65a61710c1b1f84368c52216b3e0ff` at ASAP
  commit `afc815c75c42e83a79c03feb6da8a35e77d4c6b8`
- When in Rome fixture manifest SHA-256:
  `21a8130e4796bfd43db9be8189c2f2c4e8a98dea6b5835bc0c2d941f0f1d6683` at corpus
  commit `aa7539f1cf480997a68998405c0783ebf6339c16`
- Contrapunctus bench commit: `b9e011c8cf34c5e76691dcf2c835b8c99ebd9d59`
- ChoCo/Isophonics commit: `5fe168fd55be5c84512abcfbc4e6f1b1f8f0092a`

## Analysis R1: align the Isophonics scoring cohort

**Question.** What selective-prediction results do the frozen configurations
produce when accuracy and coverage use the same events that the detector's
ontology can score?

**Rules.** A scorable event has a non-null `localKey` in the fixture. Coverage
is claimed scorable events divided by all scorable events; accuracy is exact
correct claims divided by claimed scorable events. Piece-level macro summaries
include every piece with at least one scorable event. The three entirely modal
held-out tracks are not correctness-scored, but remain in a separate table with
event count, claim count, time to first claim, and switches. Abstention on an
out-of-ontology event is not called correct. The original all-event behavior
metrics and archived reports remain unchanged.

**Primary output.** For paper and reflex on the held-out split: scorable pieces,
events, claims, macro coverage, macro exact accuracy on claims, and paired
piece-level differences. The output must also give micro counts so the
denominators are auditable. This is a denominator correction, not a new model
comparison; inferential significance is not promoted as confirmatory.

Planned command after the declared tool is implemented:

```sh
python3 tool/whatkey/revision_reanalysis.py isophonics-cohort \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split test \
  --claims paper=research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/claims.json \
  --claims reflex=research/whatkey/results/test-split-2026-07-07/test-iso-hmm-reflex/claims.json \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/isophonics-test-cohort.json
```

## Analysis R2: make the overlap segment result piece-aware

**Question.** Does the existing overlap result remain visible when pieces,
coverage, and unequal claim sets are made explicit?

**Rules.** Use the same corrected fixtures, frozen paper/reflex claims, and
already inspected minimum same-key-run spans of 0, 12, 20, and 32 measures. Do
not add, remove, or move a threshold after looking at results. For each
threshold, eligibility is determined solely from the span of the existing
analyst-key run and is identical for both configurations. Report eligible
pieces/events, each configuration's claims, per-piece macro coverage, and
per-piece macro exact accuracy on its own claims. The primary sensitivity view
uses only events claimed by both configurations, reports the common-claim
fraction, and compares per-piece exact accuracy on that identical event set.
Pieces without an eligible event for the relevant view are omitted with the
omission count reported. Preserve the submitted pooled-event values as the
historical view.

**Inference.** Report paired piece-level differences and 95% paired bootstrap
intervals with the fixed seed below. Because both the thresholds and pooled
direction were already inspected, treat every result as post-hoc/descriptive; do
not attach a fresh confirmatory claim to whether an interval excludes zero.

```sh
python3 tool/whatkey/revision_reanalysis.py overlap-segments \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --claims paper=build/whatkey-harness/asap-wir-v2pw-paper/claims.json \
  --claims reflex=build/whatkey-harness/asap-wir-v2pw-reflex/claims.json \
  --min-segment-measures 0,12,20,32 \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/overlap-segments.json
```

## Analysis R3: compare two references on the same performances

**Question.** On the 36 overlap performances and the same frozen detector
claims, does the relative ordering of paper and reflex depend on whether the
reference comes from analyst-stated keys or notated key signatures?

**Common ontology.** Transform both references and detector claims to 12
diatonic-collection classes. A major key maps to its tonic pitch class; a minor
key maps to its relative-major tonic pitch class. ASAP's key-signature reference
already identifies the corresponding major/relative-minor collection. This
equalizes the label cardinality and deliberately gives up major/minor identity;
the 24-state analyst result remains available separately in R2.

**Primary view.** Restrict to events for which both references exist and both
configurations claim. Compute per-piece accuracy for each configuration under
each reference. Report the paired interaction

`(paper - reflex under key signature) - (paper - reflex under analyst key)`.

Also report reference agreement, common-claim coverage, piece/event counts, and
95% paired bootstrap intervals. Secondary views may give each configuration's
own-claim accuracy paired with coverage, but may not replace the common-claim
primary view.

**Interpretation limit.** This is an exploratory reference-construct sensitivity
analysis on Beethoven performances. A key signature is not an oracle perceptual
key and the comparison does not isolate annotation timescale, repertoire, or
ontology in general. It can support narrower language about reference
provenance; it cannot establish that one annotation practice is correct or that
the result generalizes to popular music.

```sh
python3 tool/whatkey/revision_reanalysis.py dual-reference \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --asap-annotations build/whatkey-corpora/asap-dataset/asap_annotations.json \
  --claims paper=build/whatkey-harness/asap-wir-v2pw-paper/claims.json \
  --claims reflex=build/whatkey-harness/asap-wir-v2pw-reflex/claims.json \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/overlap-dual-reference.json
```

## Analysis R4: cross memory and functional evidence on development data

**Question.** Holding every other historical paper setting fixed, how do memory
and functional evidence act separately and together under the When in Rome and
Isophonics development rulers?

**Grid.** On each frozen development split, cross emission half-life `{1, 30}`
seconds with functional blend `{0, 0.1}`. These levels are fixed because they
are the two values already embodied in the named configurations. All other
settings are pinned explicitly to the historical paper recipe. This is an
explanatory factorial, not tuning: no cell is adopted as a replacement and no
new level may be introduced after inspection. No held-out detector run is
permitted.

**Outcomes.** Primary outcomes are per-piece exact accuracy on claims and
coverage on the same scorable cohort. Report simple memory effects within each
functional level, simple functional effects within each memory level, and the
difference of those differences, separately by corpus. MIREX, modulation,
stability, and latency remain secondary diagnostics. Use paired pieces, report
piece/event/claim counts and 95% paired bootstrap intervals, and describe the
analysis as post-hoc/explanatory.

The commands deliberately spell out the historical configuration rather than
combining a recipe with overrides, which the harness rejects:

```sh
for corpus in wir iso; do
  if [ "$corpus" = wir ]; then
    fixtures=research/whatkey/data/fixtures/when-in-rome-v1
    split_file=research/whatkey/data/splits/when-in-rome-v1.json
  else
    fixtures=build/whatkey-fixtures/isophonics-nc-v1
    split_file=research/whatkey/data/splits/isophonics-nc-v1.json
  fi

  for half_life in 1 30; do
    for functional in 0 0.1; do
      dart run tool/whatkey/harness.dart \
        --fixtures "$fixtures" --split-file "$split_file" \
        --split development --detector hmm \
        --confidence-weighting off --functional-blend "$functional" \
        --progression-blend 0 --self-transition 0.9 \
        --emission-temperature 0.25 --hysteresis 1 \
        --profiles albrechtShanahan --weighting duration \
        --decay-half-life-seconds "$half_life" --min-events 3 \
        --margin-floor 0.3 --mode-tilt 2 --relative-tilt 0 \
        --relative-cadence-tilt 0 --relative-evidence-tilt 0 \
        --relative-evidence-window 1 --cadence-boost 0 \
        --cadence-triad-boost 0 --cadence-margin-factor 1 \
        --cold-start-tonic-prior 0 --relative-switch-factor 1 \
        --fifths-decay 0.5 --mode-switch-factor 0.5 \
        --calibration-temperature 1 \
        --out "build/whatkey-revision/grid-$corpus-hl$half_life-f$functional"
    done
  done
done

python3 tool/whatkey/revision_reanalysis.py factorial \
  --when-in-rome-fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --isophonics-fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --run-root build/whatkey-revision \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/development-factorial.json
```

## Decisions

- Preserve every submitted and corrected historical artifact; new JSON output
  goes under `build/whatkey-revision/` and will record its generating command,
  source hashes, script commit, cohort rules, and counts.
- Do not exclude the three modal held-out tracks from the dataset or behavioral
  reporting. Exclude only their undefined 24-key correctness scores through the
  objective event-level scorable mask.
- Do not rerun or tune a detector on a held-out split. R1-R3 rescore immutable
  claims; R4 runs new detector cells only on development splits.
- Do not describe the overlap segment filter as relabeling annotation
  granularity. Do not describe the dual-reference result as annotation timescale
  isolated from all other constructs.
- Do not use a newly favorable secondary metric or subset as the headline. The
  common-claim and scorable-cohort views declared above remain primary even if
  their result is inconvenient.

**Plain-English reading.** The next work is not to search for a better detector.
It is to ask cleaner questions of outputs that are mostly already frozen. One
analysis repairs a mismatched denominator, two put the same performances and
claims under fairer comparisons, and one uses development data to separate two
settings that the paper had bundled. Whatever these analyses show, the revision
must report that result and narrow its language accordingly.

**Next.** Review and commit this declaration. Then implement and test the
hash-checking reanalysis tool, run R1-R4 in order, record each result in its own
append-only log entry, and update the revision scratchpad before editing the
manuscript.

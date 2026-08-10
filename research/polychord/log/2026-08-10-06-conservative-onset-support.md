# 2026-08-10: Define conservative onset-cohort support

**Goal.** Fix the smallest musically defensible interpretation of raw onset
evidence before running a corpus measurement or assigning any product effect.

**Setup.** Base repository commit `d3b030cb`. The threshold-free input contract
was `polychord-onset-evidence/1`. The already committed 0- and 400-millisecond
matched-history controls were known before this decision, so this was not a
blind choice with respect to those fixtures. No development or held-out corpus
measurement, exposure census, candidate acceptance total, or product-policy
outcome was run before fixing the parameters.

The numerical rationale was checked against four primary studies reached by
title, DOI, and onset-asynchrony searches on 2026-08-10:

- Palmer, "On the Assignment of Structure in Music Performance," _Music
  Perception_ 14.1 (1996), DOI
  [10.2307/40285708](https://doi.org/10.2307/40285708): 20-50 millisecond melody
  leads conveyed performed voice structure;
- Hove, Keller, and Krumhansl, "Sensorimotor Synchronization with Chords
  Containing Tone-Onset Asynchronies," _Perception & Psychophysics_ 69.5 (2007),
  DOI [10.3758/BF03193772](https://doi.org/10.3758/BF03193772): chord sequences
  with 25-, 30-, and 50-millisecond onset differences shifted synchronization
  and perceptual centers;
- Tillmann and Bharucha, "Effect of Harmonic Relatedness on the Detection of
  Temporal Asynchronies," _Perception & Psychophysics_ 64.4 (2002), DOI
  [10.3758/BF03194732](https://doi.org/10.3758/BF03194732): listeners judged a
  50-millisecond delayed chord tone, with sensitivity affected by harmonic
  context; and
- Borchert, Micheyl, and Oxenham, "Perceptual Grouping Affects Pitch Judgments
  Across Time and Frequency," _Journal of Experimental Psychology: Human
  Perception and Performance_ 37.1 (2011), DOI
  [10.1037/a0020670](https://doi.org/10.1037/a0020670): a 200-millisecond onset
  difference between overlapping complex tones disrupted fusion in their task.

None of these studies tested polychord identification or establishes a universal
threshold. They constrain a conservative ablation rather than supply ground
truth.

The implementation was checked with:

```sh
python3 tool/polychord/onset_support.py \
  --fixture research/polychord/data/frame-replay/synchronous-six-note-cohort.json \
  --after-event-index 5
python3 tool/polychord/onset_support.py \
  --fixture research/polychord/data/frame-replay/two-register-held-cohorts.json \
  --after-event-index 5
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/prior-art-search.md \
  research/polychord/onset-support-ablation.md \
  research/polychord/log/2026-08-10-06-conservative-onset-support.md
shasum -a 256 \
  research/polychord/onset-support-ablation.md \
  tool/polychord/onset_support.py \
  tool/polychord/onset_support_test.py \
  research/polychord/onset-evidence-schema.md \
  tool/polychord/onset_evidence.py \
  research/polychord/data/frame-replay/manifest.json
git diff --check
```

**What happened.** The named ablation `coherent-separated-onsets-50-200ms/1`
fixes two inclusive constants: each candidate layer must span no more than 50
milliseconds, and the nearest endpoints of the two non-overlapping onset
intervals must be separated by at least 200 milliseconds. Both lower-then-upper
and upper-then-lower orders are eligible.

The result is deliberately one-sided. A complete case satisfying all three
timing conditions receives `onsetCohortSupport: positive`. Every other case is
`neutral`, never negative. Incomplete history is marked `incomplete`; its
per-layer booleans, order, and separation remain `null` rather than being
derived from partial evidence. Velocity and pressed-versus-pedal-sustained state
remain visible in the raw record but do not affect this profile.

The matched-history controls behave as intended:

- the synchronous `C|Gm` candidate has zero-millisecond layer spans, overlapping
  onset intervals, zero separation, and neutral onset support; and
- the layered `C|Gm` candidate has zero-millisecond layer spans,
  lower-then-upper order, 400 milliseconds of interval separation, and positive
  onset support.

These are contract controls, not an accuracy result. Eleven new tests cover the
fixed identity and parameters, both matched histories, reverse layer order,
inclusive 50- and 200-millisecond boundaries, each layer just outside the
cohort-span maximum, separation just below the minimum, incomplete history,
velocity invariance, frames without candidates, and exact output fields. The
complete polychord Python suite contains 80 passing tests.

Pinned SHA-256 digests:

- onset-support contract:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`;
- onset-support implementation:
  `e5d74ecc2583cd60b6be155d56c9dbc5bc9e4bd3f3b107cbeda5a2285c996544`;
- onset-support tests:
  `5c0698449b38b2773111a708d822a42cf7e75aca06a2d7b9a40005f163759b4f`;
- unchanged onset-evidence contract:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- unchanged onset-evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- unchanged frame-replay manifest:
  `9168ae68010415bf38439d8d774040e4272bbb5529c2e4089680c9ab4fdaa06e`.

**Plain-English reading.** Small timing differences commonly occur inside a
performed chord and can communicate voicing without proving that two chords were
played. This profile therefore waits for a much clearer pattern: two tightly
attacked note groups at least 200 milliseconds apart. Even then it says only
that timing supports the proposed split. It never treats missing or synchronous
timing as evidence that a polychord is wrong.

**Decisions.** Adopt `coherent-separated-onsets-50-200ms/1` as the first onset
interpretation. Keep both constants in the ablation identity and implementation
rather than exposing tuning flags. Use nearest onset-interval endpoints, not
first-onset distance, making the 200-millisecond requirement stricter when a
layer is rolled. Keep the rule orientation-neutral and one-sided.

Do not describe 50 or 200 milliseconds as a perceptual boundary for polychords.
Do not use this output as confidence, ranking, abstention, or display policy.
Any alternate parameters must be a separately named comparison, not an
unrecorded retuning of this profile.

**Next.** Define an implementation-shaped, frame-level measurement that applies
this exact profile without tuning and reports candidate exposure, evidence
availability, positive support, neutral reasons, and per-piece concentration.
Keep those observations separate from accuracy because the available corpora do
not contain verified polychord labels.

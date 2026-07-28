# Performed-Input Evaluation Protocol

Status: FROZEN 2026-07-27 (ruler v1, log 2026-07-27-04 approved; baseline in log
2026-07-27-05). This protocol inherits the frozen chord-context protocol
(`research/chord-context/PROTOCOL.md`): split discipline, label isolation,
ground-truth rules, statistics conventions, and the performance budget apply as
written there. This document records only what is specific to this initiative.

## Ruler v1 (frozen)

Implemented by `tool/performed-input/identity_score.py`; the alignment census
gate is `tool/whatkey/wir_alignment_probe.py`.

1. **Scoring unit.** Time-weighted agreement over the union of event display
   intervals ([timestampMs, +durationMs]) intersected with the analyst harmony
   timeline. Coverage is the displayed share of analyst-labeled time; tiers are
   reported on displayed time only (the coverage/accuracy-on-claimed pairing).
2. **Agreement tiers** between the app's top-ranked candidate and the analyst
   chord (music21 conversion of key+figure): _exact_ = root pitch class and
   quality family match, where family is (third, fifth, seventh) classified from
   the member interval set identically on both sides (headline); _root_ = root
   pitch class matches; _members_ = chord-tone sets match regardless of root.
   Augmented-sixth figures score by member set at every tier.
3. **Boundary tolerance.** Within one interpolated beat (`beatMs`) of an analyst
   span boundary, agreement with either neighboring span counts.
4. **Attribution arms**, in build order: A0 = app segmentation with neutral
   analysis context (the committed fixtures); B = annotated analyst key as
   context; C = annotation-boundary segmentation; A1 = live inferred-key
   context. A0, B, and C are key-behavior-mode-free by construction (no detector
   in the loop); A1 reports all three behavior presets (stable, balanced,
   reactive), since the preset changes the context stream the analyzer sees.
   Headline numbers always ship with their decomposition.
5. **Split.** By sonata number, seeded hash over all 32 sonatas
   (`tool/performed-input/freeze_split.py`, frozen manifest in
   `data/splits/asap-wir-nc-v2.json`): every movement and performance of a work
   shares a side, and the side of any later-rescued movement is already
   determined by its sonata. Movements enter only by passing the census gate
   (shift response peaking sharply at zero).

## Stability ruler v1 (frozen)

Frozen 2026-07-27 (log 2026-07-27-13 approved; baseline in log -14). Implemented
by `tool/performed-input/stability_score.py` over the frames sidecars
(`asap_wir_extract.py --emit-frames`).

1. **Label stream.** The top-1 (root pitch class, quality) per sounding-set
   change under A0 conditions (app segmentation, neutral context); a blank entry
   when the display drops below three notes. Extensions are excluded from the v1
   label; extension-only flicker is a recorded refinement.
2. **Metrics** (per piece, mean per piece over the split): labeledShare;
   switchesPerMin (transitions to a different non-null label per minute of
   labeled time); flickerShare (labeled time in dwells under 500 ms, the primary
   metric); settleMs per committed event (median and p90); churnPerEvent.
3. **Split and adoption.** The frozen identity split applies unchanged, test
   spent once and pre-declared. Adoption bar: paired per-piece improvement on
   flickerShare with switchesPerMin and settleMs supporting, and the identity
   ruler's exact tier as a non-regression check, so stability is never bought by
   naming worse chords.

## Binding now

- **Split before tuning.** A development/test split, frozen by piece (all
  performances of a sonata movement share a side), lands before any number from
  the ruler informs an engine change. The test split is spent once, on a
  pre-declared result set.
- **Scoring defined before results.** The span-level, time-weighted scoring
  semantics (what counts as the displayed label matching an annotated harmony
  span, how abstention and segmentation mismatch are counted) are frozen in a
  log entry before any comparison is trusted, so the metric cannot drift toward
  whatever the engine already does.
- **Attribution arms are part of the ruler.** Every headline run reports the
  live-key arm, the annotated-key arm, and the annotation-boundary segmentation
  arm together. A number without its decomposition does not ship.
- **License gate.** ASAP (CC BY-NC-SA 4.0) and the unverified When in Rome
  Beethoven analyses keep all derived fixtures under `build/`; only splits,
  manifests, and hashes are committed.

## Guards

- **Solo invariance where it applies.** Engine changes motivated by this
  initiative keep the existing guarantees: chord golden suite, comping suite
  18/18, and `tool/benchmark.sh --check`, exactly as prior initiatives demanded.
- **Key-detection non-interference.** Changes to the input layer (segmentation,
  capture) can alter committed event streams; any such change re-runs the
  whatkey-local guard commands (its log 2026-07-26-01) before adoption, since
  the key detectors consume those streams.
- **Oracle-pool continuity.** Ranking changes still measure blast radius against
  the canonical pool (`tool/chord/pool_diff.py`) with zero flips on
  `clearly-correct` reviewed entries as a hard constraint.

## Adoption bar (frozen)

Paired per-piece improvement on the development split of the exact tier
(bootstrap CI95 excluding zero and Wilcoxon p < 0.05 via the
`tool/whatkey/compare.py` conventions), guards green, and the attribution arms
confirming the change moves the bucket it claims to move. The test split is
spent once, on a pre-declared result set.

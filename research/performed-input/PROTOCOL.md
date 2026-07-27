# Performed-Input Evaluation Protocol

Status: DRAFT. The measurement discipline below is binding now; the ruler
definition freezes with the avenue 1 scoping entries, before any engine tuning
against it. This protocol inherits the frozen chord-context protocol
(`research/chord-context/PROTOCOL.md`): split discipline, label isolation,
ground-truth rules, statistics conventions, and the performance budget apply as
written there. This document records only what is specific to this initiative.

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

## Adoption bar

To be frozen with the ruler. The intended shape, recorded so the freeze is a
confirmation rather than an invention: paired per-piece improvement on the
development split of the primary metric (bootstrap CI95 excluding zero and
Wilcoxon p < 0.05 via the `tool/whatkey/compare.py` conventions), guards green,
and the attribution arms confirming the change moves the bucket it claims to
move.

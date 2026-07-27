# 2026-07-27: Initiative start and asset audit

**Goal.** Open the performed-input initiative: capture the ranked avenues for
surfacing remaining chord-identity accuracy issues in the live streaming causal
use case, and audit what avenue 1 (the ASAP x When in Rome performed-input
identity benchmark) needs versus what already exists.

**Setup.** Document and code reading only, no runs. Sources: the
oracle-comparison workflow (research/chord-oracle-comparison.md), the whatkey
ASAP tooling (`tool/whatkey/asap_extract.py`, `asap_wir_extract.py`), the
contrapunctus RomanText parsing (`tool/chord/`), and the fixture builds under
`build/whatkey-fixtures/`.

**What happened.** The motivating decomposition, recorded so the initiative has
its "why" in one place:

- The oracle harness has reached diminishing returns: its big structural
  disagreement clusters are triaged, and further passes mostly re-litigate rows
  already reviewed as genuine ambiguity. It compares against what other
  libraries would name a pitch-class set; it cannot see product misses.
- Every corpus identity number (DCML, Weimar) scores voicings synthesized from
  the annotations themselves: complete, simultaneous, pre-segmented. The live
  path (sounding-note aggregation, pedal, segmentation, partial arrivals) has
  never had a ruler.

Asset audit for avenue 1, all findings positive:

- `tool/whatkey/asap_extract.py` already replays ASAP performance MIDI through
  the app's real capture path (pedal-aware snapshots, the actual
  `ChordEventSegmenter` via `replay_batch.dart`), so fixture events reflect
  genuine capture behavior on performed input.
- `tool/whatkey/asap_wir_extract.py` already aligns performance time to score
  measures (ASAP downbeat maps) and parses the When in Rome RomanText analyses
  via the contrapunctus tooling; `cbench.parse_rntxt` yields (measure, beat,
  key, figure, time signature) tuples, and the script keeps the keys while
  discarding the figures. Chord-level ground truth rides the same alignment that
  key ground truth already uses.
- The contrapunctus benchmark work already converts Roman figures plus local key
  into expected chord content, so figure-to-identity conversion is an
  adaptation, not new research.
- License gate confirmed: ASAP is CC BY-NC-SA 4.0, the Beethoven analyses are
  not license-verified, both extractors refuse to write inside `research/`;
  fixtures stay under `build/` and only splits and manifests get committed.

What avenue 1 still needs, in build order: (1) extend the alignment to emit
per-event expected harmony spans (figure, local key, span boundaries) next to
the existing key labels; (2) define and freeze the span-level time-weighted
scoring semantics before any comparison is trusted; (3) freeze a
development/test split by sonata movement; (4) the attribution arms
(live-inferred key versus annotated key, app segmentation versus
annotation-boundary segmentation).

**Plain-English reading.** We have spent months proving the engine names clean
chords well. Nobody has ever measured what the app actually displays while a
human plays, because the ground truth and the replay machinery lived in
different tools. It turns out the two are one script apart: the pipeline that
labels performed events with analyst keys parses the analyst's chords too and
throws them away.

**Decisions.**

- Initiative opened as `research/performed-input/` with four ranked avenues
  (README): the performed-input benchmark, causal prefix stability, the
  frequency-weighted pool with observed voicings, and POP909 diligence.
- Protocol discipline binding immediately; the ruler definition and adoption bar
  freeze with the avenue 1 scoping entries, before any tuning (PROTOCOL.md).
- Avenue 1 starts first, per the ranking rationale: it is the only option that
  measures an unmeasured product surface, and its attribution arms decide
  whether remaining accuracy work even lives in the analysis engine or in the
  segmentation and key context around it.

**Next.** Extend the ASAP x When in Rome extraction to carry harmony spans,
inspect the resulting alignment quality on a handful of movements by hand, then
freeze scoring semantics and the split.

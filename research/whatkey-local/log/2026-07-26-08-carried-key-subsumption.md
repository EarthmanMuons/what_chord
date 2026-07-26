# 2026-07-26: Carried-key deficit partially subsumed by the relabel

**Goal.** Before adopting the entry -07 candidates, determine whether the
sticky-key deficit (candidate 2) is an independent mechanism or is already
covered by the one-event hindsight relabel (candidate 1).

**Setup.** Engine commit 9436ff0e. `rootless_corpus.dart` gains a provenance
split of the hindsight arm; same run configuration as entry -07, reactive
behavior.

**What happened.** Reactive, DCML dev, exact/total by key provenance:

| Provenance         | Live inferred | Hindsight (one event) |
| ------------------ | ------------- | --------------------- |
| fresh (11,156 ev)  | 94.3%         | 95.2%                 |
| carried (1,912 ev) | 88.7%         | 91.8%                 |
| fallback (129 ev)  | 94.6%         | 91.5%                 |

The relabel recovers 60 of the 217 carried-key misses (+3.1 points on carried
events) along with 101 fresh-key events. The carried deficit that remains after
the relabel (91.8 vs 95.2) has no identified mechanism: at those moments the
detector is abstaining because evidence is thin, so the carried claim is the
best causal information that exists, and the app already bounds carry time with
the per-preset stale windows (10/20/30 s), which the harness's unbounded carry
does not model. The small fallback regression (4 events of 129) is warm-up
noise: hindsight at the piece's first events can pick a not-yet-settled claim
over the annotated-key stand-in.

**Plain-English reading.** The "old key held too long" problem and the "relabel
one chord later" fix overlap: once the detector does make up its mind, the
relabel rewrites the entries that were named under the held-over key. What is
left after that is the detector being genuinely unsure, which no bookkeeping can
fix.

**Decisions.** Candidate 2 is closed as an independent adoption item; its
recoverable share rides along with candidate 1. Design answers for the adoption
questions are recorded in the initiative discussion (2026-07-26): the relabel
integrates unconditionally across playing modes (solo effect measured inert as
retroKey, chord-context log 2026-07-20-15), and the decoupled naming key scopes
to the ensemble path only, where the benefit is measured and where a
naming/display key disagreement has no visible key-signature contradiction.

**Next.** Implement candidate 1 (unconditional one-event history relabel,
record-only, no detector feedback) and candidate 3 (ensemble naming under an
internal reactive-timescale key); then design the minor-evidence asymmetry
before any holdout use.

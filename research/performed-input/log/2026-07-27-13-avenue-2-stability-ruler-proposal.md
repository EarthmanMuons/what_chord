# 2026-07-27: Avenue 2 opened: prefix-stability pipeline and ruler proposal

**Goal.** Open avenue 2 (causal prefix stability) per the approved re-ranking
(log -12): build the measurement pipeline and propose the stability ruler,
keeping the development split unseen until the ruler is reviewed.

**Setup.** `replay_batch.dart` gained `emitFrames`: alongside events, the output
carries the per-snapshot display-label change points (top-1 (rootPc, quality)
whenever it changes; a bare timestamp when the display goes blank below three
notes). `asap_wir_extract.py --emit-frames` routes them to a `frames/` sidecar
directory so fixture files stay out of the stream, and
`tool/performed-input/stability_score.py` computes the metrics. The app's
identity display derives synchronously from the sounding-note providers with no
logical debounce (`identity_display_provider.dart`; the 260 ms UI crossfades
mask but do not gate changes), so this per-frame label stream is what the
product logically displays.

Fixture lineage note: regenerating the base set moved its content hash off the
frozen split's pinned value. The cause is cosmetic, the informational
`labels.arm` field the arm tooling added to the fixture writer after the split
froze; the events and ground truth are unchanged, verified by re-scoring the
development split to per-piece identity on all four ruler metrics. The split
file stays frozen as the record of its freeze-time hash; this entry is the
lineage record.

```sh
.venv/bin/python tool/whatkey/asap_wir_extract.py ... --emit-frames
.venv/bin/python tool/performed-input/stability_score.py \
  --split gateExcluded --out build/performed-input/stability-smoke.json
```

**Proposed stability ruler (pending review).**

1. Label stream: the top-1 (root pitch class, quality) per sounding-set change
   under A0 conditions (app segmentation, neutral context, justified by the
   context-free findings of logs -06 and -12). Extensions are excluded from the
   v1 label; extension-only flicker is a noted refinement.
2. Metrics, per piece, mean per piece over the split:
   - labeledShare: labeled display time over the piece span;
   - switchesPerMin: transitions to a different non-null label per minute of
     labeled time;
   - flickerShare: labeled time in dwells shorter than 500 ms;
   - settleMs per committed event: time from event start to the last label
     change inside the event (median and p90 over events);
   - churnPerEvent: label changes strictly inside committed events.
3. Same frozen split and one-shot test discipline as the identity ruler; the
   adoption bar shape carries over (paired per-piece on the primary metric,
   which is flickerShare, with switchesPerMin and settleMs as the supporting
   pair and identity-ruler exact as the non-regression check: stability must not
   be bought by naming worse chords).

**Plumbing validation** (gate-excluded movements only; the development split
remains unseen): labeled 0.557, switches/min 425.8, flicker share 0.632, settle
median 244 ms, p90 794 ms, churn/event 1.93. The magnitudes are plausible
physics rather than bugs: with no smoothing between the analyzer and the
display, every arpeggio note re-roots the analysis, so the raw label stream
flaps several times per second on stormy movements. If the development baseline
confirms this, the stability surface is likely the largest user-visible finding
of the initiative so far.

**Plain-English reading.** We can now measure the flicker: how often the chord
name changes while someone plays, how much of the display's life is spent on
names that live less than half a second, and how long a chord takes to settle.
The first careful look at four warm-up movements suggests the raw display
changes its mind about seven times a second during busy passages, softened only
by a fade animation. Whether that holds on the real measurement set is exactly
what the frozen ruler will say.

**Decisions.**

- Development split untouched until this ruler is approved and frozen.
- The fixture-hash lineage note above stands in place of amending the frozen
  split file.

**Next.** On approval: freeze the stability ruler into PROTOCOL.md, run the
development baseline, and read where the flicker concentrates (within events
versus between them), which decides whether the conversation is about
presentation smoothing, segmenter-gated display, or analyzer stability.

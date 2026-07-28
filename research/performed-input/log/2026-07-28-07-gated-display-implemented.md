# 2026-07-28: Gated display implemented; immediate-onset variant rejected

**Goal.** Implement the approved display policy (log -06, all five decisions
approved in review), pricing the onset-rule variant offline first.

**What happened.**

**Onset rule decided by measurement, against my lean.** The simulator gained a
`gated-live` policy modeling the segmenter's exact live semantics (immediate
adoption when nothing is active, 200 ms challenger takeover, reset on blanks).
It destroys most of the win: classical flicker 0.413 versus 0.064 for the
age-gated model (pop 0.138 versus 0.082), because sparse textures constantly dip
below three notes and every dip lets the next ephemeral label display instantly.
The protection lives in the 200 ms survival gate at onset, not the challenger
debounce. Implemented rule: age-gated, a chord displays once its identity has
survived the stability window, uniform ~200 ms latency.

**Implementation, as briefed:**

- `ChordEventSegmenter` gains read-only `active`/`activeSince` getters (package
  tests added; takeover backdating means promotion is instantaneous after a
  challenger resolves).
- New `displayed_chord_provider.dart` in theory state:
  `chordStabilityMinDurationProvider` (the shared 200 ms constant, now owned by
  theory with history forwarding to it), `displayFrameProvider` (demo included,
  lookup excluded), and `DisplayedChordNotifier`, which runs its own
  display-gate segmenter with one timer serving both challenger resolution and
  warmup promotion.
- Presentation rewired to the gate: `chordPresentationProvider`, the identity
  display's alternatives, the alternatives list, implied-root keys, and the
  ranking details sheet (which now explains the displayed frame's input). Lookup
  bypasses everywhere for instant manual feedback; history capture consumes raw
  frames unchanged.
- CHANGELOG entry added (Changed), including the screen-reader benefit raised in
  review: announcements now change only when a chord actually lands.

**One trap, caught by the existing guard suite:** publishing the gated frame
synchronously inside the frame listener tripped the same-frame rebuild assertion
tests (live MIDI exiting lookup; auto key adoption). Fixed with the
KeyModeNotifier adoption pattern: the display write lands between passes via a
microtask.

**Guard disposition.** The capture path is untouched (history's segmenter and
its raw frame source are unchanged, byte-for-byte identical event streams), so
the whatkey non-interference guard does not apply. Checks run: root analyze,
import order, full root suite (246 passing), package analyze and suite (536
passing), new gate tests (6) and segmenter getter tests (2).

**Plain-English reading.** The screen now waits the same fifth of a second the
history and key detector already wait before believing a chord, so the name you
see is the name that ends up in your history, every time. We almost shipped the
more eager version; the simulator showed it would have let every arpeggio's
first guess flash through, so the calmer rule won on numbers, not taste.

**Decisions.**

- All five review decisions implemented as approved; onset rule resolved to
  age-gated by the `gated-live` measurement.
- In-practice feel (the review's reserved judgment) is the remaining validation:
  the true commit-lag distribution can be measured from debug logging if the
  feel raises questions.

**Next.** Ship-and-feel: the change rides the normal release flow. The
initiative returns to its standing state; the held test-split spend remains the
only queued research item.

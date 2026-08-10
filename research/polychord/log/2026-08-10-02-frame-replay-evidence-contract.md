# 2026-08-10: Freeze the frame-replay evidence contract

**Goal.** Replace onset-only temporal examples with an exact, auditable event
substrate before designing a polychord candidate generator or temporal grouping
rule.

**Setup.** Base repository commit `c9f3ea8f`. No development or held-out corpus
fixture, corpus annotation, or detector result was read. The maintainer-authored
labels for the archived matched six-note pilot controls were already known from
the preceding work. Their common note collection informed two neutral replay
fixtures, but neither label was copied into the schema, fixture, or manifest.
The existing live MIDI state transition code and performed-input extraction
tools were inspected only to align terminology and pedal behavior. The contract
and committed fixtures were checked with:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check \
  research/README.md \
  research/polychord/FRAMEWORK.md \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/frame-replay-schema.md \
  research/polychord/data/frame-replay/*.json \
  research/polychord/log/2026-08-10-02-frame-replay-evidence-contract.md
shasum -a 256 \
  research/polychord/FRAMEWORK.md \
  research/polychord/frame-replay-schema.md \
  research/polychord/data/frame-replay/manifest.json \
  research/polychord/data/frame-replay/*.json \
  tool/polychord/frame_replay.py \
  tool/polychord/frame_replay_test.py
git diff --check
```

**What happened.** `polychord-frame-replay/1` now records a normalized event
window without any chord label, proposed split, or detector output. Every
fixture includes:

- a state at the start of the observation window;
- ordered note-on, note-off, and sustain-pedal events, retaining order among
  events with the same timestamp;
- note-on velocity and note-off release velocity;
- the complete pressed, pedal-sustained, sounding, and pedal state after every
  event; and
- an exclusive terminal timestamp so the final state's dwell is defined.

The transition model rejects duplicate or unordered event indices, decreasing
timestamps, velocity-zero note-ons, note-offs for notes that are not pressed,
duplicate note-ons for pressed notes, redundant pedal transitions, impossible
initial states, unknown fields, and any recorded frame that differs from replay.
Repressing a pedal-sustained note moves it back to the pressed set; pedal
release clears only sustained notes.

Four exact synthetic fixtures cover the first substrate invariants:

1. two held register cohorts entering 400 milliseconds apart;
2. the identical six-note collection entering synchronously;
3. release under pedal, re-press, and pedal-up behavior; and
4. a cropped observation window with pressed and sustained notes carried in from
   earlier events.

The first two deliberately reach the same six-note sounding state through
different event histories. They carry no expected polychord or integrated-chord
answer. That separation permits later register-only and temporal ablations to
consume identical evidence without embedding the conclusion in the fixture.

The manifest pins the framework, schema document, executable validator, and all
four fixture bytes. Its validator rejects a changed dependency or fixture before
semantic replay.

Pinned SHA-256 digests:

- framework: `0516629db36ba8d307ed8cec68617e73b9e29b0548108d4cd2e5250921421a21`;
- frame-replay schema:
  `58f6c5cbc99c6e4ee7476e12f247f1ee0e526b3aee7bd5f595e8f712a0f0a1fa`;
- manifest: `9168ae68010415bf38439d8d774040e4272bbb5529c2e4089680c9ab4fdaa06e`;
- carried-in state fixture:
  `f06906c019ea6130c18b08eca4587099eb78250b058739f27ddafbf736a9a311`;
- pedal release and re-press fixture:
  `dc46bdd95b403d8609dc5e6fd85645fb268cf05ef899de76d6006d1ca52ac7a0`;
- synchronous six-note fixture:
  `76ea3de1622cf5f9955b45109ccd507da33044778f616987768be50a19261146`;
- two-register-cohort fixture:
  `4026012d9c2073c262a1b3b05608e54cccf5ebe8bad043fe4d868f135d63e05e`;
- executable validator:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- validator tests:
  `daf66eda03dfcca171b339d69f31d0bfb7dd2253c68b0e2794d250233e11bfb6`.

The full polychord Python suite contains 32 passing tests after adding the eight
frame-replay tests.

**Plain-English reading.** We can now tell the difference between notes still
held by fingers, notes sounding only because of the pedal, and notes that merely
appeared somewhere in the same passage. Two performances can end on the same
six-note collection while preserving the different paths by which they got
there. The replay files describe only what happened, not what chord name we hope
an algorithm will choose.

**Decisions.** Designate `polychord-frame-replay/1` as the only admissible
fixture format for temporal grouping evaluation in this initiative. An onset
list plus aggregate pitch set is not temporal evidence. Source-channel,
sostenuto, half-pedal, all-notes-off, disconnect reset, and per-note expression
remain outside schema 1 and require an explicit later schema revision if needed.

Retain every same-timestamp event and derived intermediate frame even when it
has zero notated dwell. Array order is the causal tie-break and may matter to a
live pipeline. Require an explicit initial state for cropped windows and a
terminal timestamp for final dwell.

Keep expected chord names, split assignments, and eligibility labels in a
separate suite layer. The replay substrate must remain reusable across the
register-only baseline and every later temporal ablation.

**Next.** Implement the conservative register-only candidate generator as a pure
function over one replay frame. It may emit all qualifying contiguous splits
under Framework v0, but it must not rank, display, or consume temporal history.
Test it first against synthetic product-policy guards, then connect it to frame
replay for proposal-exposure measurement without reading held-out data.

# Polychord pilot review instrument

Status: deferred on 2026-08-10 without collecting responses. Do not distribute
this instrument or use it to collect research data. It remains intact as a
byte-pinned historical artifact for logs 2026-08-02-10 and -11; the design
correction is recorded in log 2026-08-10-01 and `../FRAMEWORK.md`.

This research-only static instrument guides qualified musicians through the
`polychord-pilot-review/1` response schema. It is a focused expert annotation
task, not a public survey, and it neither determines nor normalizes the musical
answer.

Version 2 presents musical evidence in forms a reviewer can read directly:
unannotated score excerpts for source cases and written note names, a neutral
piano-keyboard view, and a plain-language attack timeline for generated cases.
Raw MIDI values, source identifiers, and digests remain available only under the
verified packet and exported response; they are not displayed in the reviewer
flow. The evidence and response schema are unchanged.

The operating instructions and unfinished distribution-readiness checklist below
are retained only to reconstruct the abandoned design. Completing them would not
reactivate the pilot; a later external study requires a new registered evidence
design and instrument version.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000
```

Open <http://127.0.0.1:8000/research/polychord/review-instrument/>. Opening
`index.html` directly is unsupported because the browser must fetch and verify
the adjacent guide, packet, presentation manifest, and score images.

The instrument refuses to start unless all pinned SHA-256 values match. It
verifies the packet and guide bytes, then the presentation manifest and each
score image. It presents cases in the packet's neutral order and preserves that
order in the exported response.

## Reviewer preparation

Recruit musicians with formal theory study or equivalent advanced practical
experience. Reviewers should read standard notation, keyboard and piano-roll
views, identify common triads and seventh chords, and distinguish extensions,
slash chords, and upper-structure voicings. They do not need programming, MIDI,
JSON, MIR, or WhatChord knowledge.

The instrument begins with a standardized 10 to 15 minute orientation:

1. Read the musician-facing reviewer guide.
2. Inspect three worked examples covering an expected polychord, misleading
   decomposition, and single-chord-preferred boundary. These note collections
   are not reused in the pilot packet.
3. Pass three task-boundary questions. Incorrect responses receive the same
   written feedback for every reviewer. Readiness answers are neither retained
   nor exported; only orientation completion is stored with the local draft.

Do not coach an individual reviewer through pilot cases. Before distribution,
run one cognitive walkthrough with a qualified musician who is not counted in
the independent pilot panel. Record unclear wording, navigation failures, time,
and resulting revisions without collecting or retaining a completed response.

## Reviewer workflow

1. Use the assigned pseudonymous ID or generate one in the instrument. Do not
   enter a name or email address.
2. Complete all six cases independently. The instrument permits cannot
   determine, alternatives, confidence, and free-form reasons. For generated
   cases it derives octave-neutral and shared note membership from the explicit
   written-note assignment. It never proposes a chord identity.
3. Download the completed response. The export retains the packet evidence and
   digests unchanged and contains no presentation or orientation answers.
4. Return that unadjudicated file without discussing individual cases. Do not
   edit it after download.

Draft answers are stored only in browser local storage under a key scoped to the
instrument version and packet digest. Nothing is submitted to a server. Use
**Clear local draft** before another reviewer uses the same browser profile.
Opening a complete score is an explicit navigation to the pinned source host.

Validate a returned file from the repository root:

```sh
python3 tool/polychord/pilot_ruler.py \
  research/polychord/pilot-ruler-v0.json \
  --validate-review path/to/completed-review.json
```

Reviewer qualifications and contact information are collected and retained
separately from the pseudonymous response. A deployment must not add analytics,
telemetry, answer suggestions, detector output, initial answers, or peer
answers.

## Evidence-presentation provenance

Score images are deterministic crops of the exact source PDFs pinned in the
packet. Reproduce and verify them with:

```sh
python3 tool/polychord/prepare_review_score_excerpts.py \
  --petrushka-pdf path/to/ptrouchkascn00stra.pdf \
  --augurs-pdf path/to/lesacreduprintem00stra_3.pdf
```

The script verifies each PDF digest before invoking `pdftoppm`, records the
page, resolution, crop rectangle, renderer version, image dimensions, and output
digest in `assets/manifest.json`, and refuses to overwrite a differing result.
The crops contain no added harmonic analysis or highlighting.

Generated note evidence intentionally uses enharmonically neutral dual labels
for black keys, such as C-sharp/D-flat, because the blinded packet contains MIDI
rather than a frozen spelling. Reviewers preserve meaningful spelling in their
free chord-identity text. A synthesized-audio rendering is deliberately absent:
timbre, articulation, duration, and mix would add perceptual evidence not
carried by the current symbolic input. Audio can be studied later only as a
separately frozen evidence condition.

## Development checks

```sh
npx prettier --check \
  research/polychord/review-instrument \
  tool/polychord/review_instrument_test.mjs
npx stylelint research/polychord/review-instrument/styles.css
mise python:format
mise python:lint
node --test tool/polychord/review_instrument_test.mjs
python3 -m unittest discover -s tool/polychord -p '*_test.py'
```

The Node test constructs a mechanical response in a temporary directory and
passes it through the Python validator. That fixture is not a research
annotation and is never retained.

## Distribution-readiness checklist

Complete and record this pass before giving the instrument to a pilot reviewer.
Use only the orientation and mechanical placeholder answers; delete any
downloaded file afterward.

- Complete the orientation and six-case flow in current Chrome, Firefox, and
  Safari at desktop and narrow widths, 200% browser zoom, and enlarged system
  text. Confirm every score excerpt, keyboard, note label, and attack timeline
  is legible without reference to the underlying raw evidence.
- Complete the flow by keyboard: use the skip link, orientation check, case
  navigation, radio and checkbox groups, selects, add/remove actions, error
  links, and download without a pointer. Confirm focus remains visible and moves
  to the requested case or invalid field.
- With VoiceOver and Safari at minimum, confirm landmarks, fieldset legends,
  labels, keyboard-view text alternatives, score alt text, help text, completion
  state, derived readouts, status messages, and error summary are announced
  intelligibly. Add another screen-reader/browser combination when practical.
- Confirm failed orientation and incomplete download attempts save no research
  response. Confirm every marked orientation question and error-summary link
  reaches its corresponding control.
- Reload during the review and confirm local draft and orientation recovery.
  Clear the draft and confirm no answer, reviewer ID, or readiness state
  survives for the next reviewer using that browser profile.
- Download a mechanically complete response, validate it with the Python command
  above, and confirm the evidence, packet digest, guide digest, and case order
  remain unchanged.
- Open each full-score link, confirm the source location can still be reached,
  and confirm returning to the form preserves the draft.
- Inspect the browser console for content-security-policy, module-loading,
  storage, image-verification, or download errors. Confirm loading and
  completing the form creates no outbound request other than explicit reviewer
  navigation to a score source.

Record browser and assistive-technology versions, operating systems, source
commit, all pinned digests, cognitive-walkthrough results, defects, and
dispositions in a dated research-log entry.

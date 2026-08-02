# Polychord pilot review instrument

This is a research-only, static annotation instrument for the frozen
`polychord-pilot-review/1` packet. It guides a qualified independent reviewer
through the existing response schema; it is not an open public survey and does
not determine or normalize the musical answer.

Do not distribute it for real responses until the multi-reviewer comparison
report is frozen and the distribution-readiness checklist below is complete.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000
```

Open <http://127.0.0.1:8000/research/polychord/review-instrument/>. Opening
`index.html` directly is unsupported because the browser must fetch and verify
the adjacent guide and packet.

The instrument refuses to start unless the byte-level SHA-256 digest of
`pilot-review-template-v0.json` matches its pinned value and the guide digest
matches the value carried by that packet. It presents cases in the packet's
existing neutral order, which is preserved in the exported response.

## Reviewer workflow

1. Open and read the frozen annotation guide without consulting another reviewer
   or the initial annotations.
2. Use the assigned opaque ID or generate one in the instrument. Do not enter a
   name or email address.
3. Complete all six cases. The instrument permits abstention, alternatives,
   confidence, and free-form reasons. For synthetic cases it derives layer pitch
   classes and shared pitch classes from the explicit MIDI-note assignment. It
   never proposes a chord identity.
4. Download the completed JSON. The export retains the packet evidence and
   digests unchanged and contains no instrument-only draft fields.
5. Return that raw file without discussing individual cases. Do not edit it
   after export.

Draft answers are stored only in browser local storage under a key scoped to the
instrument version and packet digest. Nothing is submitted to a server. Use
**Clear local draft** before another reviewer uses the same browser profile.
Opening a pinned score-source link is a separate navigation to the source host.

Validate the returned file from the repository root:

```sh
python3 tool/polychord/pilot_ruler.py \
  research/polychord/pilot-ruler-v0.json \
  --validate-review path/to/completed-review.json
```

Reviewer qualifications and contact information are collected and retained
separately from the pseudonymous JSON response. A study deployment must not add
analytics, telemetry, answer suggestions, detector output, or visibility into
initial or peer answers.

## Development checks

```sh
npx prettier --check \
  research/polychord/review-instrument \
  tool/polychord/review_instrument_test.mjs
npx stylelint research/polychord/review-instrument/styles.css
node --test tool/polychord/review_instrument_test.mjs
python3 -m unittest discover -s tool/polychord -p '*_test.py'
```

The Node test constructs a mechanical response in a temporary directory and
passes it through the Python validator. That fixture is not a research
annotation and is never retained.

## Distribution-readiness checklist

Complete and record this pass before giving the instrument to a reviewer. Use
mechanical placeholder answers only and delete the downloaded file afterward.

- Exercise the complete six-case flow in current Chrome, Firefox, and Safari at
  desktop and narrow viewport widths, 200% browser zoom, and enlarged system
  text.
- Complete the flow by keyboard: use the skip link, case navigation, radio and
  checkbox groups, selects, add/remove actions, error links, and export without
  a pointer. Confirm focus remains visible and moves to the requested case or
  invalid field.
- With VoiceOver and Safari at minimum, confirm the page landmarks, fieldset
  legends, labels, help text, case completion state, derived readouts, status
  messages, and error summary are announced intelligibly. Add a second
  screen-reader/browser combination when practical.
- Confirm an incomplete export downloads nothing and every error-summary link
  reaches the corresponding control.
- Reload mid-review and confirm local draft recovery. Clear the draft and
  confirm that no answer or opaque ID survives for the next reviewer using that
  browser profile.
- Export a mechanically complete response, validate it with the Python command
  above, and confirm that the evidence, packet digest, guide digest, and case
  order remain unchanged.
- Open each pinned score link, confirm the intended source location can still be
  reached, and confirm returning to the form preserves the draft.
- Inspect the browser console for content-security-policy, module-loading,
  storage, or download errors. Confirm that loading and completing the form
  creates no outbound request other than explicit reviewer navigation to a
  pinned score source.

Record the browsers, versions, assistive technology, operating systems, source
commit, source digests, defects, and disposition in a dated research-log entry.

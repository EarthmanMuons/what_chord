# 2026-08-02: Guided independent-review instrument

**Goal.** Implement the guided annotation instrument specified in log
2026-08-02-09 without changing the frozen packet, guide, response schema, or
pre-adjudication measures, and close any mechanical validation gaps discovered
while testing the export path.

**Setup.** Base repository commit `3cf784f6`. No completed independent response
existed or was inspected. No corpus fixture, held-out split, initial-to-neutral
case mapping, or detector output was exposed to the browser instrument.

Working directory: `/Users/abs/src/whatchord`. Reproducibility commands:

```sh
npx prettier --check research/polychord/review-instrument research/polychord/README.md research/polychord/reviews/README.md tool/polychord/review_instrument_test.mjs
npx stylelint research/polychord/review-instrument/styles.css
mise css:lint:fix
mise python:format
mise python:lint
node --check research/polychord/review-instrument/app.mjs
node --check research/polychord/review-instrument/model.mjs
node --test tool/polychord/review_instrument_test.mjs
python3 -m unittest discover -s tool/polychord -p '*_test.py'
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json --validate-review research/polychord/pilot-review-template-v0.json
git diff --check
shasum -a 256 research/polychord/pilot-review-template-v0.json research/polychord/pilot-annotation.md research/polychord/review-instrument/index.html research/polychord/review-instrument/styles.css research/polychord/review-instrument/app.mjs research/polychord/review-instrument/model.mjs tool/polychord/pilot_ruler.py tool/polychord/review_instrument_test.mjs
```

The static HTTP smoke check used a temporary localhost server. Every listed URL
returned HTTP 200 with the expected content type:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
curl -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/review-instrument/ --next -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/review-instrument/app.mjs --next -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/review-instrument/model.mjs --next -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/review-instrument/styles.css --next -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/pilot-review-template-v0.json --next -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n' http://127.0.0.1:8765/research/polychord/pilot-annotation.md
```

Pinned SHA-256 digests:

- frozen packet:
  `8eb672bf73ba7dea9eb781bd3c1886b0542030104c24915399e78a92986c70fa`;
- frozen guide:
  `f311f428603fa3a7a65b7834f34c02b298c33c53dce1193d9241e65399c9c4d8`;
- instrument HTML:
  `9e88ebcd58ad5e3feea554c40fe2b963ae21e7880c65e505cccc46a468b0680c`;
- instrument CSS:
  `f68ca225f17be00292c6ab93d05e04e736b700d1d27e2bf256e23b9e224a735a`;
- browser controller:
  `99a8e4d1e43a61c1e642e7a3282ee8c760b9850f3faf25df0c3418313ecc1c9e`;
- pure export model:
  `219be2b8f7d505106ef076b058b9e81d76a2d50ed4a56aa038f3294bb73fb695`;
- canonical Python validator:
  `4a4d031480fdeda789319af47308a1827a7f4a461fd4f2b795696db89cd37226`;
- cross-language test:
  `cc569c36b786fe1eba638b1ab3c28a31846cdc0899dcad7688c63f826618d1ef`.

**What happened.** The research-only static instrument verifies the packet and
guide byte digests before showing any case. It presents the packet's existing
neutral order, never loads the initial ruler, stores a draft only in browser
local storage, and exports the unchanged `polychord-pilot-review/1` schema.
There is no backend, analytics, telemetry, or chord-name suggestion path.

Native form controls guide the reviewer through the observation and construction
tags, score-source pitch-class layers, synthetic MIDI-note assignment,
integrated alternatives, three separate eligibility judgments, confidence, and
free-form notes. Synthetic pitch classes and shared pitch classes are derived
from explicit note assignment. Score-source identities and pitch classes remain
free reviewer judgments. The UI retains abstention and unassigned notes instead
of forcing an answer.

The export model was tested across JavaScript and Python: a purely mechanical
temporary response passes the same canonical validator used on returned files,
and the temporary file is removed. Four Node tests and 22 Python tests pass. The
instrument also has a restrictive content-security policy, a skip link, native
fieldset semantics, keyboard-visible focus, live status and error summaries,
responsive large-target controls, and reduced-motion handling.

Building the form exposed three canonical-validator omissions. Before any
response existed, validation was tightened so every layer has a non-empty pitch
class set, synthetic layers contain at least one MIDI note whose derived pitch
classes match the declared set, and score-source responses cannot add MIDI or
unassigned-note evidence absent from the blinded packet. The agreement-test
fixture now removes private-ruler MIDI detail when constructing a score-source
review; scoring still compares its pitch-class layers exactly as before.

The available in-app browser surface was not attached during this session.
Source checks, cross-language export validation, CSS lint, and localhost HTTP
delivery passed, but interactive visual, keyboard, download, local-storage, and
assistive-technology behavior was not observed in a real browser.

**Plain-English reading.** Reviewers now have a form that prevents broken files
without suggesting our musical answers. The file it downloads is checked by the
same independent validator used by the study. We have tested the data machinery,
but we have not yet watched the page operate in an actual browser, so it is not
ready to send to reviewers solely on the strength of these automated checks.

**Decisions.** Designate this source set `polychord-pilot-review-instrument/1`.
Keep it research-only and local-first; record the exact commit and source
digests when distributing it. Do not add instrument-only metadata to the frozen
response schema. Record instrument provenance in the distribution and response
log instead. Do not deploy telemetry or expose initial, detector, or peer
answers.

The instrument is implementation-complete but not distribution-ready until a
real-browser pass confirms the six-case flow, validation focus, local recovery,
JSON download, responsive layout, keyboard operation, and basic screen-reader
semantics. The existing one-review agreement reporter also does not yet provide
the independent-reviewer pairwise comparisons required by the panel design; its
multi-reviewer successor must be specified, tested, and frozen before the first
response. These prerequisites are separate from, and do not block, split-census,
score, or temporal-evidence research.

**Next.** As a separate logical change, generalize and preregister the agreement
report for the full reviewer panel, retaining initial-to-reviewer and every
reviewer-to-reviewer comparison separately. Then run the browser and
assistive-technology checklist without entering a research response, fix only
interface defects, pin the distribution commit, and recruit two, preferably
three, qualified independent reviewers. Preserve each returned response
unchanged and do not inspect or discuss case-level disagreements until all pilot
responses are frozen and the preregistered panel report has been generated.

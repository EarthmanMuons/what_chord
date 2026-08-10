# 2026-08-10: Freeze release and pedal evidence

**Goal.** Convert the bounded audit's field requirements into a reusable,
threshold-free evidence contract before proposing any categorical
interpretation.

**Setup.** The audit result and its post-run reporting correction were committed
at repository commit `100e7752`. Its detailed report remains unchanged under
`build/`, and its canonical audit implementation remains untouched so the
embedded pins continue to identify the exact measurement code.

The new contract is `polychord-release-pedal-evidence/1`, documented in
`release-pedal-evidence-schema.md` and implemented independently by
`tool/polychord/release_pedal_evidence.py`. It consumes only a validated
`polychord-frame-replay/1` fixture, one exact replay frame, and candidates from
`polychord-register-candidates/1`. It does not read the POP909 audit report,
corpus annotations, internal-suite expectations, or held data.

The exact validation commands were:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/release_pedal_evidence.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-pedal-history.json \
  --after-event-index 12
./.venv/bin/python -m unittest discover \
  -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/release-pedal-evidence-schema.md \
  research/polychord/log/2026-08-10-11-release-pedal-evidence-contract.md
```

**What happened.** The contract replays one causal record for each currently
sounding note. It preserves the current sounding instance's onset, current
pressed or sustained state, state-changing release when applicable,
current-state origin, reattack-from-sustain status, and the prior release that
made an observed reattack possible. It also retains the latest pedal transition
and exact event-order relation between the current onset and current pedal-down
origin. All event times, velocities, and derived ages remain raw facts.

Layer summaries report state and completeness counts, known age ranges, exact
release timestamps and spans, reattack counts, and pedal-relation counts. They
contain no tolerance or category. The candidate summary only totals those facts
across the two fixed register assignments.

Onset provenance is intentionally repeated in this second evidence object
because every new fact refers to the same sounding-note instance. Regression
tests compare it to `polychord-onset-evidence/1` on every committed replay
fixture, preventing the two contracts from silently assigning different current
onsets.

The new synthetic `two-register-pedal-history` fixture supplies a complete
six-note `C|Gm` control with lower and upper release groups, a sustained-note
reattack, a second release of that note, and final pedal clearing. Its exact
frames are validated and SHA-pinned in the replay manifest. Synthetic tests also
cover carried-in unknown onset, release, state, reattack, and pedal-transition
origins; same-timestamp note/pedal event order; output fields; candidate removal
on pedal release; preservation of pressed-note history across pedal release; and
rejection of invalid replay state.

Adding the fixture changed the replay-manifest digest to
`1abd073c595e07cc103120a6c1186d7628e815cb2ed727cc2d75e7d3bc847471`. The
internal-suite seed's declared `frameReplayManifest` dependency was updated to
that digest. No suite case, expectation, eligibility field, or scoring field
changed. The full polychord test discovery then passed 114 tests.

**Plain-English reading.** Later experiments can now tell the difference between
a key that is still physically held, a released key whose sound remains under
the pedal, and a note that was released and played again. They can also tell
whether a note began before or during the current pedal episode. The tool
reports those facts without deciding that an old, released, or pedal-held note
is musically irrelevant.

**Decisions.** Keep this contract separate from the completed audit tool and
from the onset interpretation. Preserve unknown carried-in history rather than
assuming it began at the fixture boundary. Treat a pressed note's absent current
release as not applicable; count unknown releases only among sustained notes.
Record raw release equality and spans without defining a release cohort.

Do not include exact-candidate runs, causing or terminating events, dwell, or
corpus causal windows in the single-frame evidence object. Do not add support,
penalty, confidence, eligibility, or display fields. Do not infer a pedal or age
threshold from the audit.

**Next.** Commit the schema, implementation, fixture, and tests as one logical
evidence-contract change. Then define the minimum frame-window and stable-layer
assignment needed for threshold-free motion evidence. Any categorical
release/pedal interpretation remains a separately named, preregistered ablation
and needs a justification beyond the unlabeled POP909 subset. Leave the clean
reserve untouched.

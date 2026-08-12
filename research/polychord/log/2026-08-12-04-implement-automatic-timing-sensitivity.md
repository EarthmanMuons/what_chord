# 2026-08-12: Implement automatic timing sensitivity

**Goal.** Implement the comparison frozen in
`automatic-timing-sensitivity-preregistration.md` without running the registered
POP909 and Liszt measurement before the implementation is committed.

**Setup.** Work began from repository commit
`5233d57f95fc5f54a84c3c502a6948a817634eea`, which contains the preregistration
at SHA-256 `957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522`.
The implementation does not expose alternate grids, corpora, labels, source
cases, or output outside `build/`. It fixes onset-gap minima at 50, 80, 100,
200, and 300 milliseconds; the within-layer maximum at 50 milliseconds; and
appearance dwells at 0, 50, 100, 200, and 300 milliseconds.

The implementation and test pins before this entry were:

- `tool/polychord/automatic_timing_sensitivity.py`:
  `70c53374ae8b6da32ad2a5849620682321d984189a84ecc2fa23186009751f37`; and
- `tool/polychord/automatic_timing_sensitivity_test.py`:
  `7d86282ad8b331859931b3cf02e6ecec068d4485bafd1fd28d129b0a90b1c89f`.

The exact checks were:

```sh
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover -s tool/polychord -p '*_test.py'
```

The fixed POP909 input contract and committed mechanics fixtures were checked
without running the sensitivity comparison:

```sh
./.venv/bin/python -c 'import sys; from pathlib import Path; sys.path.insert(0, "tool/polychord"); import automatic_timing_sensitivity as s; r=s.validate_source_report(Path("build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json")); c=s.mechanics_controls(); print(r["schema"], r["measurementId"], len(r["candidateFrames"]), [x["fixtureId"] for x in c["matchedHistoryControls"]])'
```

It printed:

```text
polychord-onset-exposure-census/1 pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1 2524 ['synchronous-six-note-cohort', 'two-register-held-cohorts']
```

**What happened.** The canonical implementation now:

- requires the exact preregistration, POP909 report, roster, corpus commit,
  aggregate MIDI digest, schemas, measurement ID, label-blind declaration, and
  source-report contract pins before reading a candidate record;
- verifies each old contract pin against the old report's recorded repository
  commit rather than incorrectly comparing a historical pin with today's
  checkout;
- derives every profile from raw `onsetEvidence`, compares the 200-millisecond
  result with both the stored interpretation and the unchanged committed
  interpreter, and aborts on any mismatch;
- retains every candidate assignment, onset record, signed interval gap,
  within-layer span, layer order, shared pitch class, sustain presence, frame
  dwell, and sounding-instance binding;
- tracks independent authorization opportunities only while the exact candidate
  and every `(midiNote, onsetEventIndex)` binding persist across consecutive
  event indices;
- reports inclusive survival at every fixed appearance dwell, separately counts
  zero-duration episodes, and labels summed opportunity duration as distinct
  from selector or product display time;
- replays the pinned Liszt MIDI through the unchanged development normalization,
  strict frame replay, onset-evidence, and register-candidate functions, then
  requires exact reproduction of the two previously disclosed target rows;
- replays the committed synchronous and 400-millisecond `C|Gm` matched-history
  fixtures and constructs exact-threshold and one-millisecond-below mechanics
  controls for every onset and nonzero dwell boundary; and
- asserts onset-gap and appearance-dwell monotonicity, the frozen POP909 totals,
  the disclosed all-zero POP909 expectation, and the disclosed Liszt outcome.

Python formatting and lint passed. The full polychord Python suite passed 275
tests. The POP909 input validator reproduced the exact source schema,
measurement ID, 2,524 candidate frames, and the two committed matched-history
fixtures.

The registered measurement command was deliberately not run. The pinned Liszt
file is not currently present at `tmp/pdfs/liszt-malediction.mid`; the eventual
run will fail before producing output unless that exact file is restored with
SHA-256 `e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`. No
substitute source or transcribed result is accepted.

**Plain-English reading.** We now have a measurement instrument whose choices
were written down before it could produce the comparison. It cannot silently
change the timing values, read the held songs, treat old summary labels as new
raw evidence, or turn overlapping possible candidates into claimed screen time.
The tests show that threshold equality, one-millisecond misses, reattacks,
missing frames, and zero-duration events behave as declared. They do not tell us
the study result; that remains the next, separately recorded step.

**Decisions.** Keep the implementation and measurement as separate commits. Do
not modify the preregistration after this implementation boundary. Do not select
any onset or dwell row from the eventual output. Keep detailed POP909 and Liszt
event data under `build/`, and record only verified aggregates, case
dispositions, and cryptographic pins in the result log.

**Next.** Commit this implementation. Restore the exact pinned Liszt file to the
registered local path, run only the command in the preregistration from a clean
implementation commit, validate the resulting local JSON, and record the result
in a new dated measurement entry regardless of outcome. Do not read the 808-song
POP909 reserve or the ASAP test split.

# POP909 disjoint-candidate release and pedal audit

Status: preregistered, not yet executed. This document fixes the label-free
post-result audit `pop909-sample-disjoint-release-pedal-audit/1`, emitted as
`polychord-release-pedal-audit/1`. The canonical implementation is
`tool/polychord/release_pedal_audit.py`. Commit this document and implementation
with a clean worktree before the first corpus run.

## Question and boundary

The pinned onset-exposure result found 59 pitch-class-disjoint register
candidate instances in 12 songs, and every instance included at least one note
sounding through sustain. This bounded audit asks:

> What exact note-release, sustain-pedal, restrike, note-age, and repeated-frame
> history produced those 59 already identified observations?

The audit is descriptive. It does not decide whether any candidate is a
polychord, assign positive or negative labels, set a timing threshold, tune a
display rule, or estimate accuracy. POP909 chord, beat, key, and structure
annotations remain unread. The 808-song reserve is neither selectable nor read.

The selected cases are not a random sample and are not 59 independent musical
examples. They are the complete pitch-class-disjoint subset of a previously run
measurement, retained because this is the smallest structurally distinct subset
in which release and pedal history can be inspected without choosing cases by
their new temporal outcome.

## Frozen source and selection

The only source report is:

```text
build/polychord/pop909-sample-accompaniment-channel-blind-onset-exposure-v1.json
```

Its required SHA-256 is
`60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`, its schema
is `polychord-onset-exposure-census/1`, and its measurement identity is
`pop909-sample-accompaniment-channel-blind-onset-exposure-50-200ms/1`. The tool
rejects any other report.

Selection is mechanical: retain every candidate interpretation whose
`candidate.sharedPitchClasses` array is exactly empty. Multiple candidates on
one frame remain separate instances. The already reported invariants are fixed
as validation checks: exactly 59 candidate instances across song IDs `010`,
`046`, `064`, `091`, `163`, `361`, `487`, `649`, `685`, `703`, `721`, and `757`.
A mismatch aborts the audit rather than changing its scope.

For those 12 songs only, the tool rereads the same `BRIDGE` plus `PIANO` MIDI
projection and applies the same channel-blind normalization used by the source
census. Each selected raw MIDI file must match its digest in the source report.
The reconstructed observation frame, structural candidate, and onset evidence
must reproduce the source row exactly before new history is attached.

## Threshold-free causal fields

For every currently sounding candidate note, the audit records:

- the exact MIDI note and whether it is physically pressed or pedal-sustained;
- the normalized event index, timestamp, and velocity of the note-on that
  created its current sounding instance, or explicit unknown values for
  carried-in state;
- the note's age since that note-on;
- for a sustained note, the state-changing note-off index, timestamp, release
  velocity, and age since release;
- the event and timestamp at which the note entered its current pressed or
  sustained state;
- whether the current note-on reattacked a pedal-sustained instance, plus the
  prior state-changing release event when known; and
- when the pedal is currently down, whether the note-on preceded the current
  pedal-down transition.

For the global sustain state, the audit records whether the pedal is down, the
last transition's event and timestamp when observed, and its current-state age.
For each exact layer it retains note records plus counts of pressed, sustained,
known-release, unknown-release, reattacked, and carried-in facts. It also
reports the distinct known release timestamps and their raw minimum, maximum,
and span. These are observations, not release-cohort labels.

The frame-replay schema begins from an explicit initial state. Unknown onset,
release, restrike, state-age, or pedal-transition facts remain null; the tool
does not impute them. In the POP909 projection the stream begins empty and
pedal-up, but preserving unknowns keeps the audit logic valid for bounded
fixtures that begin inside a performance.

## Instance and run units

A candidate instance is one exact pitch-class-disjoint candidate on one
normalized event frame. Same-timestamp intermediate frames remain instances and
may have zero dwell. Candidate milliseconds use the source report's dwell from
that frame to the next normalized event, or to MIDI end.

A candidate run groups an exact candidate allocation across consecutive
normalized event indices in one song. Exact means the complete serialized
candidate, including both MIDI-note assignments, layer identities, split, gap,
and shared-tone field. Matching display symbols are not sufficient. A missing
event index ends the run even if the same candidate later returns.

Each run retains:

- its exact candidate and song;
- first and last observation event, start time, exclusive end time, frame count,
  zero-dwell count, and summed observed duration;
- every observation with its causing event, source frame, source onset evidence,
  and new release/pedal evidence;
- the event that terminates the run, when one exists; and
- the normalized causal event window from the earliest referenced current onset,
  release, state transition, or pedal transition through the terminating event.

This grouping reduces repeated-frame inflation for inspection without deleting
the frame-level denominator or treating runs as ground-truth musical events.

## Fixed summaries

The report gives instance, run, song, zero-dwell, and observed-duration totals.
It reports counts of instances with pedal down, sustained notes, all notes
sustained, complete sustained-note release origins, restrikes, and notes whose
current attack precedes the current pedal-down transition. Note-state totals use
candidate-note occurrences, meaning one assigned MIDI note on one candidate
frame; repeated frames remain repeated observations.

Exact histograms are emitted for instances and runs per song, run frame counts,
sustained-note counts, distinct known release timestamps, and starting and
terminating event types. Run duration, pedal-state age, note-on age, and
sustained-note release age use count, minimum, median, and maximum. These fixed
summaries describe the bounded subset. They are not prevalence estimates for
POP909, polychords, or user input.

## Provenance and run discipline

The report embeds:

- its schema, measurement identity, UTC generation time, exact command, and
  working directory;
- the source report path, digest, measurement identity, and label-read flag;
- POP909 root, commit, dirty state, selected song IDs, and an aggregate digest
  of the 12 selected MIDI files;
- Python and Mido versions;
- the repository commit and dirty state of every declared measurement input;
- SHA-256 pins for the replay, register-candidate, onset-evidence,
  onset-exposure, and audit documents and implementations; and
- explicit definitions of every denominator.

The detailed report contains corpus-derived event sequences and must remain
local under `build/`. The tool rejects an output elsewhere. The first corpus run
must occur only after the preregistration commit, with a clean POP909 checkout
and clean declared repository inputs. Preserve its output unchanged and record
its SHA-256 and aggregate findings in a later dated log entry.

The exact run command is:

```sh
./.venv/bin/python tool/polychord/release_pedal_audit.py \
  --out build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
```

After the run, verify every embedded file pin and recompute all fixed summaries
from the retained run observations. Use the raw audit only to decide which
threshold-free facts belong in the reusable release/pedal evidence contract.
Commit that contract before proposing a categorical support, penalty,
abstention, or display rule. Motion remains a later named increment.

# 2026-07-27: Provenance split: half melody, half pedal

**Goal.** Execute log -08's next step: split the added-tone disagreement family
by note provenance (physically held versus pedal-sustained) to decide whether
the mechanism conversation is about voicing structure, pedal handling, or both.

**Setup.** New `tool/performed-input/provenance_census.py`. Instead of extending
`sounding_snapshots` (log -08's sketch), the census rebuilds per-note sounding
segments with provenance straight from the raw ASAP MIDI, mirroring the
extraction's pedal semantics, and classifies each disagreement segment's extra
pitch classes (tones beyond the analyst chord, in segments where the full
analyst chord was sounding). This achieves the split with zero changes to shared
extraction code. Classification: `heldDwell` (held at least 400 ms or half the
segment), `transientPress` (press under 200 ms, persisting only via pedal),
`pedalCarry` (pressed before the segment, sounding in it only via pedal).
Thresholds recorded in the report.

```sh
.venv/bin/python tool/performed-input/provenance_census.py \
  --out build/performed-input/provenance-a0-dev.json
```

**What happened.** A0 development split: the added-tone family is 17.6% of
disagreement time (7.0% of displayed, 257 s), and it splits:

| provenance     | share |
| -------------- | ----- |
| heldDwell      | 0.527 |
| pedalCarry     | 0.251 |
| transientPress | 0.221 |

Both hypotheses from logs -07 and -08 were each half right:

- **Half the family is melody-over-accompaniment** (heldDwell, about 3.7% of
  displayed time): tones a hand is genuinely holding, mostly melodic dwells over
  sustained harmony. No input-layer timing filter can touch these without eating
  real chord tones; addressing them means giving the engine some concept of
  voicing structure (a melodic top voice versus the harmonic block below it).
  That is a genuine research avenue, not a lever.
- **Half is pedal-shaped and mechanically reachable** (pedalCarry plus
  transientPress, about 3.3% of displayed time): earlier harmony carried across
  a chord change by the pedal, and grace-note-length presses smeared into the
  voicing by the pedal. The app's live input layer already distinguishes held
  from pedal-sustained notes, so a mechanism of the shape "on fresh attacks,
  demote sustained-only tones that conflict with the newly voiced content" is
  implementable where the data already exists.

**Plain-English reading.** The app's weirdest chord names on real playing come
from two habits of equal size: it hears the singer as part of the chord, and it
hears yesterday's chord still ringing in the pedal. The second habit is fixable
with information the input layer already has. The first needs the engine to
learn what a melody is, which is a bigger and genuinely interesting project.

**Decisions.**

- The pedal-blur mechanism is the next engine candidate: roughly 3.3% of
  displayed time, input-layer, with the full guard set (solo goldens, comping
  suite, benchmark check, whatkey-local guard commands) since it changes
  committed event streams. Prototyping it offline needs provenance-carrying
  snapshots in the replay path; that extension now has a concrete customer and
  gets built for the prototype, optional and byte-identical when off.
- Melody-over-accompaniment (voicing-structure awareness) is captured as a
  research avenue on the initiative README ranking, sized at about 3.7% of
  displayed time on this ruler, larger in user-visible weirdness.

**Next.** Scope the pedal-blur mechanism as its own entry: pre-declare the
expectation (added-tone pedalCarry and transientPress time falls materially;
exact rises on the development split; guards clean, blues fixtures
byte-identical), extend the replay path with provenance-carrying snapshots,
prototype the demotion rule offline, and only then discuss adoption.

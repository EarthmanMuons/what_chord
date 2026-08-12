# 2026-08-12: Audit the first automatic motion-source leads

**Goal.** Determine whether the Stravinsky contrary-motion lead from log
2026-08-11-15, or a second source-attested Herrmann lead, can satisfy the
automatic-suite admission rule without inventing event timing or endpoint
continuity.

**Setup.** Tracked files began at clean commit
`ec7789e275eee2277baeb33c55a8a25518cd2c24`. No selector output, corpus outcome,
or held POP909 song was read. This was source verification and temporal coverage
auditing, so its correction is retained in a new dated entry rather than
silently rewriting log 2026-08-11-15. The active plan is amended in place.

The fixed inputs were:

- automatic-suite plan:
  `0900d74010f8eb33a99233aea49b49bd7a12aed8bdcb4c4a5967d716305542f4`;
- v2 selection plan:
  `d992c3b7e85c0d83b14ea18b4422d91d1c456cf988b07e7720c99d71ace1a8aa`;
- v2 output contract:
  `83bf6a5f182b3b7204d21863964ddf5a9a2da35014f2ef9d24e3c657b94d81c2`;
- motion support rule:
  `50886b62cf5e361148af3b05fd015f0e75a54eb5f4a36fac4ac690f07d57e083`;
- motion-exposure endpoint contract:
  `4cd93c6a53f32f1a344878843dca01aa76825ee9737466de0134a0e332f444e1`;
- register-candidate checker:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`; and
- prior suite-plan log:
  `ae0218fa8ae73de5fc4725c44e706e6763dac0e5f614500579976035d1c1641e`.

## Stravinsky score and sequence audit

The previously pinned 37-page 1922 piano score was rendered at 400 and 1,200
DPI. Printed page 37 confirms the closing chromatic-seventh and repeating-triad
construction under _p sub. e staccatissimo_. The score is authoritative for the
written construction, pitches, rhythm, and articulation. It does not specify an
exact note-off time for a staccatissimo realization, so neither the notated
duration nor the interval to the next attack can establish continuous
sounding-instance authorization.

```sh
pdftoppm -f 33 -l 37 -png -r 400 \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  tmp/pdfs/stravinsky-pages
pdftoppm -f 35 -l 37 -png -r 1200 \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  tmp/pdfs/stravinsky-pages-hires
```

An independently authored public MIDI sequence by David Siu was acquired as a
performed-sequence corroboration, not as ground truth or a replacement score:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/petrushka-midi-page.html \
  https://www.midi-karaoke.info/215c5051.html
curl -L --max-time 30 \
  -o tmp/pdfs/petrushka-david-siu.mid \
  https://www.midi-karaoke.info/215c5051.mid
shasum -a 256 \
  tmp/pdfs/petrushka-midi-page.html \
  tmp/pdfs/petrushka-david-siu.mid \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf
```

The pins are:

- MIDI listing HTML:
  `c1632a84c30cd3f83c722589c843b45d61bd9b216b3d3805b73ff2f34406b395`;
- MIDI file: `5430dffb2056f226bc82a79fe8f9a3244aaf9744c1db07a04226714bd359ebf8`;
  and
- score PDF: `90d0b14d929697f33762eacb715c3331a6ebf0faf1e722e0f50598241ebf5664`.

The sequence is Standard MIDI File format 1 with five tracks, 120 ticks per
beat, and a decoded duration of 888.72356385 seconds. Parsing the merged event
stream with Python 3.12.13 and mido 1.3.3 found these representative successive
attacks in its closing chromatic passage:

```sh
./.venv/bin/python - <<'PY'
import mido

path = "tmp/pdfs/petrushka-david-siu.mid"
mid = mido.MidiFile(path)
tempo = 500000
seconds = 0.0

for message in mido.merge_tracks(mid.tracks):
    seconds += mido.tick2second(message.time, mid.ticks_per_beat, tempo)
    if message.type == "set_tempo":
        tempo = message.tempo
    if (
        876.4 <= seconds <= 877.3
        and message.type in {"note_on", "note_off"}
    ):
        is_on = message.type == "note_on" and message.velocity > 0
        kind = "on" if is_on else "off"
        print(f"{seconds:.6f}\t{kind}\t{message.note}\tch={message.channel}")
PY
```

| Attack time (s) | Released (s) | Duration (ms) | Next attack (s) | Inter-onset (ms) |
| --------------- | ------------ | ------------- | --------------- | ---------------- |
| 876.434469      | 876.559469   | 125.000       | 876.863040      | 428.571          |
| 876.863040      | 876.988040   | 125.000       | 877.291611      | 428.571          |

The first row attacks MIDI notes `43 47 50 53 / 79 83 86 91`; the second attacks
`56 60 63 66 / 77 81 84 89`. These are the sequence author's own exact voicings
and alignment. They do not corroborate the proposed note-for-note window in log
2026-08-11-15 and therefore are not suitable fixture labels.

They do corroborate the decisive timing distinction. The sounding instances
exist for 125 milliseconds, then cease for about 303.571 milliseconds before the
next attack. `polychord-output/2` invalidates authorization when the bound
sounding instances release. Its 200-millisecond appearance gate therefore cannot
count the inter-onset interval or the silence after release.

**Disposition.** Retain the score passage as a source-attested construction and
threshold-free motion construct. Reject it as an automatic display-positive
lead. Do not lengthen its notes in a normalized fixture to obtain the desired
result, and do not admit the proposed exact score assignment without a later
independent note-level verification.

## Herrmann alternative audit

Moreira's official examples PDF was re-rendered at 1,200 DPI. Example 6, “The
Pass,” names and notates A-flat minor below a sustained G-minor triad, followed
in a later section by F-sharp minor below G minor. The PDF retains SHA-256
`09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`.

The exact registered endpoint checks were:

```sh
python3 tool/polychord/register_candidates.py 56 59 63 67 70 74
python3 tool/polychord/register_candidates.py 54 57 61 67 70 74
```

They generate exactly `Gm|G#m` and `Gm|F#m`, respectively. Preserving the
source's upper and lower roles gives an exact minus-two-semitone translation in
the lower layer and a static upper layer, hence positive oblique support under
`rigid-layers-oblique-or-contrary/1`.

The notation places a rest and positive-duration noncandidate material between
these sections. `adjacent-timestamp-terminal-frames/1` explicitly refuses to
skip such a state, while the general motion schema and ablation define no
endpoint-selection, lookback, memory, or elapsed-time policy. Deleting the gap
would silently supply a transition the source does not contain. The example also
lacks a local tempo or authoritative per-note timestamps from which to establish
the display dwell.

**Disposition.** Retain “The Pass” as a source-attested oblique-motion construct
and a useful future tracker-design question. Reject it as an automatic positive
under the present causal evidence contract. Any rule that relates remembered
candidate states across a gap must be separately named, preregistered, and
tested against matched ordinary progressions before this example is revisited.

## Decision

Neither current evidence branch has an admitted source-attested automatic
positive. Motion and onset remain diagnostic, no automatic suite should be
encoded yet, and no exact version-2 selector is justified.

The next step is a bounded search for a source that combines an explicit
polychord analysis or notation with authoritative timestamped note-level data, a
direct candidate-to-candidate transition under a frozen causal endpoint rule,
and at least 200 milliseconds of continuous target authorization. Failure to
find one is an acceptable stopping result under the current product contract; it
is not permission to relax the evidence rule after seeing the sources.

The final active-document pins are:

- automatic-suite plan:
  `909d066a4d2ff454fbe696a905ea10044daac7a995048efde1ceff1a168ffb25`;
- v2 selection plan:
  `6600e2ed925d21ff47eeba2cb45967ce5cc9d4eea85860a9b1c505b90cd4e7d8`; and
- protocol: `0cc39731a385abe7b0534811e9cc403e8278fc09e9e84a79e15453464b4961fe`.

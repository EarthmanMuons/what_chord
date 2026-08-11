# 2026-08-10: Admit the Petrushka event window without verticalization

**Goal.** Fill the preregistered moving-construction cell with an exact
score-derived replay of the rehearsal-49 Petrushka chord. Preserve the two
arpeggiated chordal units without inventing a simultaneous aggregate snapshot,
and make that distinction executable in the internal suite.

**Setup.** Work began from clean repository commit `50ac1731`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

## Source verification

The primary source remains the public-domain 1912 full score held by the UNC
Music Library and digitized by Internet Archive:

- Internet Archive identifier `ptrouchkascn00stra`;
- SHA-256 `8c753ed9ddc37e61d7fb1a261fd350cbe7b529d9bc957e9c2efcfab953532d64`;
- second tableau, rehearsal 49, first measure, final quarter note;
- printed page 64, PDF page 66.

The exact PDF from the earlier score-verification work was copied back into the
temporary PDF workspace and re-hashed before inspection. A separate
public-domain clarinet-parts scan from the Petrucci Library mirror was
downloaded as a cross-check. It has SHA-256
`df7f162a8898e5938485c95b8d9043610a299ecaba7bf53435127f6aebe16f7d`, 47 PDF
pages, and shows rehearsal 49 on part page 6 for Clarinet I and part page 6 for
Clarinet II (PDF page 20). The independent scan makes the accidentals,
transposing-instrument labels, and rhythmic grouping substantially clearer than
the small full-score scan.

For clean reproduction, the equivalent source-acquisition and verification
commands are:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/ptrouchkascn00stra.pdf \
  https://archive.org/download/ptrouchkascn00stra/ptrouchkascn00stra.pdf
  tmp/pdfs/ptrouchkascn00stra.pdf
shasum -a 256 tmp/pdfs/ptrouchkascn00stra.pdf
pdfinfo tmp/pdfs/ptrouchkascn00stra.pdf
pdftoppm -f 66 -l 66 -png -r 1200 -singlefile \
  tmp/pdfs/ptrouchkascn00stra.pdf \
  tmp/pdfs/petrushka-r49-page66-1200

curl -L --max-time 30 \
  -o tmp/pdfs/petrushka-suite-clarinets.pdf \
  'https://petruccilibrary.us/files/imglnks/imslp-us_files/Stravinsky_Igor_1971/Stravinsky%20-%20Petrushka%20Suite%20%28Clarinets%29.pdf'
shasum -a 256 tmp/pdfs/petrushka-suite-clarinets.pdf
pdfinfo tmp/pdfs/petrushka-suite-clarinets.pdf
pdftoppm -f 6 -l 6 -png -r 600 -singlefile \
  tmp/pdfs/petrushka-suite-clarinets.pdf \
  tmp/pdfs/petrushka-clarinet1-page6
pdftoppm -f 20 -l 20 -png -r 600 -singlefile \
  tmp/pdfs/petrushka-suite-clarinets.pdf \
  tmp/pdfs/petrushka-clarinet2-page6
```

All three rendered score views were inspected at original resolution. The full
score confirms the simultaneous entries and inherited tempo. The separate parts
confirm the following transposition into sounding pitch:

| Part                 | Written six-note ascent | Sounding six-note ascent | MIDI notes        |
| -------------------- | ----------------------- | ------------------------ | ----------------- |
| Clarinet I in B-flat | D4 F#4 A4 D5 F#5 A5     | C4 E4 G4 C5 E5 G5        | 60 64 67 72 76 79 |
| Clarinet II in A     | A3 C#4 E4 A4 C#5 E5     | F#3 A#3 C#4 F#4 A#4 C#5  | 54 58 61 66 70 73 |

The C-major note is six semitones above the corresponding F-sharp-major note at
each of the six attacks. This establishes upper-over-lower order as `C|F#` for
this passage without generalizing that orientation to other Petrushka-chord
statements.

## Replay normalization

The selected excerpt is the six-note ascent in the final quarter note of the
first rehearsal-49 measure. The score groups the notes as two sixteenth-note
triplets. The inherited quarter-note marking is 50, so one quarter note is 1,200
milliseconds and each triplet sixteenth is 200 milliseconds. Leading rests are
outside the replay window. Paired attacks occur at 0, 200, 400, 600, 800, and
1,000 milliseconds; the final notes release at the 1,200-millisecond excerpt
boundary.

This is a score-normalized symbolic replay, not captured MIDI. Both clarinet
attacks on a pulse are musically simultaneous. Their events are serialized
deterministically as follows:

1. release the preceding notes in ascending MIDI order;
2. attack the new notes in ascending MIDI order; and
3. retain every zero-duration intermediate frame created by that ordering.

The initial attacks are likewise ordered by ascending MIDI note. Every note-on
uses fixed velocity 64 and every note-off uses release velocity 0. Those values
are valid transport placeholders, not interpretations of the printed dynamic,
and neither affects the replay state or evidence used here.

## Suite representation

The new `frame-replay-window` observation selects event indices 0 through 23,
inclusive. Its twelve distinct MIDI notes are an inventory across time for
construction assignment only. They are not a simultaneous analyzer input.

Window register baselines are now generated separately for every selected frame.
`expectedCandidateFrames` records only frames with nonempty candidate lists and
thereby asserts that every omitted frame is empty. All 24 Petrushka frames
contain at most two sounding notes, so the expected list is empty. The validator
never passes the twelve-note window union to the register generator.

The executable `moving-arpeggiated-layers` scope feature additionally requires a
multi-timestamp replay window and rejects the claim if any selected frame
contains both complete construction units. The case is therefore a positive
source-backed construction, ineligible for both snapshot input conditions, and
eligible for future timestamped onset/motion research. Its source assignment
does not become observed MIDI channel or voice truth: linking changed pitches
across frames remains a later named-model decision under `FRAMEWORK.md`.

The octatonic-derived interpretation remains the primary alternative. The
suite's positive expectation tests WhatChord's declared constructional product
policy and does not settle the analytical debate or claim independent ground
truth.

## Verification

The completed change was checked with:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/adoption-suite-plan.md \
  research/polychord/frame-replay-schema.md \
  research/polychord/golden-candidates.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/log/2026-08-10-22-petrushka-event-window-admission.md \
  research/polychord/data/frame-replay/manifest.json \
  research/polychord/data/frame-replay/stravinsky-petrushka-r49-arpeggios.json \
  research/polychord/data/internal-suite/suite-v0.json
git diff --check
```

The final evidence pins are:

- adoption-suite plan:
  `558ab5256fb0818ac94b1f691dcd97ed87c1b52bc9b30aa351fb14545b0bb544`;
- frame-replay schema:
  `93cbfe0cb77cb570d4c444438b8cde8df82c04e68e0667c134ba21cde10e85b8`;
- unchanged frame-replay validator:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- rehearsal-49 replay fixture:
  `8e751d444245f4763aa379108441076079f387adff69dd6acb2f0db4ff955dc2`;
- nine-fixture replay manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- internal-suite schema:
  `b60ff78b0c2e20412701fbd6f651057c7bbedd0648348572b64494fc9ae759f6`;
- internal-suite validator:
  `4853e2f5e2777cf7c653fef71672d85edb9069db82e2872efdad9ef218f4f9e4`;
- frame-replay tests:
  `fc75fc0141f4c2cd0de7caecce4fc584f75ec92d48bccad053533e97b0a510bc`;
- internal-suite tests:
  `032e3edc82665f88f42ad38d6d2ea4072bfc1fb0225f46f2c562e03b72b08f71`; and
- thirteen-case internal suite:
  `1b6eecbe33a4b219929a93f8515354ed006f1bf486742564fe3aa54d0cecf5b4`.

Final validation passed all 170 polychord Python tests, all nine replay
fixtures, all 13 internal-suite cases, Python lint and formatting, Markdown and
JSON formatting, and `git diff --check`.

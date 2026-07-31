# Contextual Spelling Notes

Status: working notes, promoted from the root scratchpad on 2026-07-19. These
feed Track B (contextual spelling and notation) of the chord-context initiative;
see `temporal-context-chord-recognition.md`. The line-of-fifths material
originates from a conversation with Hex on the Music Theory Discord, lightly
edited.

## The problem

WhatChord names sonorities at the pitch-class layer, so enharmonically
equivalent chords get one canonical name regardless of function. With
surrounding context (key, prior chords, melodic direction), a different
enharmonic spelling of the same pitch classes is often the musician-expected
reading. This is a presentation-layer problem: the identity ranking can be
correct while the spelling is not.

## Canonical test cases: augmented sixths vs. dominant sevenths

Each pair is pitch-class identical; only context distinguishes them.

- `Ab C Eb F#`: German augmented sixth in C minor, if resolving to G. Spelled
  `Ab C Eb Gb`, it is Ab7 functioning as a dominant seventh.
- `Ab C F#`: Italian augmented sixth in C minor. Spelled `Ab C Gb`, an
  incomplete Ab7.
- `Ab C D F#`: French augmented sixth in C minor. Spelled `Ab C D Gb`, an Ab7#11
  / Ab7b5-flavored dominant color.

The best first test case is the German sixth with its resolution played out:
`Ab C Eb F#` moving to `G B D G` (directly, or through the cadential six-four
`G C Eb G`). The resolution makes the augmented-sixth function unambiguous.
WhatChord's current pitch-class layer calls the sonority Ab7, which is expected
and correct for that layer; the contextual spelling layer is what would
distinguish them. Note that a C minor key context alone often suffices, before
the resolution arrives: Gb is remote in C minor's fifths neighborhood while F#
is adjacent, so key-conditioned spelling handles this causally.

## Line-of-fifths window heuristic (Hex)

The core idea: choose the enharmonic spelling of a rolling window of pitch
classes that minimizes the width of the spelled set on the line of fifths. Hex's
illustration, two spellings of the same combined pitch classes:

```
Gb Db Ab Eb Bb F C G D A E B F# C# G# D# A#
                 * *   * *   *        *
```

versus:

```
Bbb Fb Cb Gb Db Ab Eb Bb F C G D A E B F# C# G# D# A#
*         *        *       * *   * *
```

Taken together, the pitch classes span 9 fifths when spelled contrapuntally
correctly versus 13 when spelled naively. (In lead-sheet symbol terms, for a
diminished seventh Hex would still almost always take the bass as the root.)

Heuristics, in Hex's formulation:

- Keep rolling windows of recent pitch classes and infer the most likely
  spelling of the whole set, minimizing its total width in fifths.
- Maximize the number of diatonic semitones between adjacent notes.
- Assume the last semitone in any chromatic line is diatonic, and strongly
  prefer diatonic semitones for the final motion of any line involving a
  semitone in the MIDI.

Known bounds: by itself the method never produces a window wider than 12 fifths
(the enharmonic diesis; anything wider could be respelled). In practice,
chromatic notes most often approach diatonic notes by diatonic semitone, which
can produce correctly spelled passages in a single key that aggregate to
slightly more than 12 uniquely spelled pitches. Combined with the semitone
heuristics, this should spell most material well short of constant modulation to
remote regions. A side benefit: consistent spelling helps choose roots
consistently on the lead-sheet side.

The fifths-window approach works best once enough context exists to surmise the
key, which ties it to the temporal-context initiative: the rolling pitch window
is itself a lightweight temporal structure, independent of chord boundaries.

## Follow-up: soft width bound, not minimization (Hex, 2026-07-31)

A second conversation, after Track B closed in
`log/2026-07-20-17-track-b-residual-decomposed.md`, revised the heuristic above.
Recorded because a reader of that section alone would implement strict
minimization.

- The objective is not "keep the window as small as possible." The revised
  formulation is a soft ceiling: the spelled set should not usually exceed about
  17 fifths.
- The ceiling has to sit above 12. At or below the diesis, two spellings of the
  same pitch class cannot both appear in the window, so a passage that genuinely
  wants F double sharp and G natural as distinct functional entities is
  unreachable by construction. The 12-fifth bound noted above is therefore a
  property every output satisfies, not evidence that an output is correct: it is
  satisfiable by the wrong spelling.
- Declared scope: standard tonal vocabulary and the chromaticism around it.
  Where composers write for enharmonic or 12-tone equal-tempered symmetry there
  is no derivable best spelling and the notation is conventional, so that
  material is not a fair test of the method.

Worked stress case, G sharp minor and its dominant, positions on the line of
fifths with C at 0:

- `D# F## A# C#` spans 7 to 13, width 6.
- `D# G A# C#` spans 1 to 10, width 9.

Minimization picks the correct spelling here, and ties at 9 either way on the
full G sharp harmonic minor collection. An earlier reading that had minimization
preferring G natural was measuring distance from C rather than from the window's
actual center up in the sharps.

App-side, `spellPitchClass` derives each chord tone's letter from its degree
above the chord root and computes the accidental needed to reach the pitch
class, allowing up to double accidentals, so `D#7` already spells `D# F## A# C#`
with no fifths reasoning involved. Non-chord tones have no root to work from and
fall through to the key-based speller, which is where this class of problem
would actually bite, and which is the same population the chromatic-line rules
target.

## Voice-leading direction

A smaller detail: temporal direction can inform isolated-note spelling, sharps
for ascending motion and flats for descending. Low priority next to the
fifths-window heuristic, which subsumes much of it.

## Ground truth

When-in-Rome fixtures derive from scores with real spelled pitches, which makes
spelling accuracy directly measurable, an unusually clean ground truth compared
to the label-mapping problems on the identity side.

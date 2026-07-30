---
cardDescription:
  "How notes are numbered from the tonic, what each degree is called, and how
  scales produce chords and Roman numerals."
cta:
  description:
    "WhatChord highlights the Roman numeral when a chord fits the current key
    you’re playing in. Free for iOS and Android. No subscription, no ads, no
    internet required."
  secondary:
    href: "/try"
    label: "Name chords in a key in your browser →"
    lead: "Prefer not to install?"
  storeBadges: true
  title: "Watch the degrees as you play."
decks:
  - "A scale degree is a note’s position within a scale, counted up from the
    tonic, the scale’s home note. It names a note by its role in a key rather
    than by its letter, so the same degree points to a different pitch in every
    key while keeping the same position relative to the tonic."
  - "Degrees are the vocabulary behind keys, chord function, and Roman numeral
    analysis. This guide covers how they are numbered, the traditional name each
    one carries, how scale formulas show each note’s interval above the tonic,
    and how building chords from scale degrees reveals which chords belong to a
    key."
description:
  "Learn how scale degrees number notes from the tonic, how flats and sharps
  shape scale formulas, and how scales produce chords and Roman numerals."
group: "musicians"
indexOrder: 3
related:
  - "why-chord-naming-is-hard"
  - "chord-naming"
  - "chord-symbols"
socialDescription:
  "A concise guide to numbering notes from the tonic, reading scale formulas,
  naming each degree, and building chords and Roman numerals."
socialTitle: "How Scale Degrees Work"
tag: "Reference"
title: "Scale Degree Guide"
---

## Numbering the Scale

In the seven-note scales used in tonal harmony, the tonic is degree 1, and the
scale is numbered up from there, through 7, with the octave arriving back at 1.
The numbers are relative, not absolute. In the C major scale, the fifth degree
is G; in the E major scale, the fifth degree is B. Same role in the key,
different pitch on the instrument.

<div class="member-stack-scroll">
  <table class="member-stack">
    <caption>
      The C Major Scale
    </caption>
    <tbody>
      <tr>
        <th scope="row">Note names</th>
        <td>C</td>
        <td>D</td>
        <td>E</td>
        <td>F</td>
        <td>G</td>
        <td>A</td>
        <td>B</td>
        <td>C</td>
      </tr>
      <tr>
        <th scope="row">Degree numbers</th>
        <td>1</td>
        <td>2</td>
        <td>3</td>
        <td>4</td>
        <td>5</td>
        <td>6</td>
        <td>7</td>
        <td>1</td>
      </tr>
    </tbody>
  </table>
</div>

In many theory texts the numbers are written with a small caret above them
(<span class="sdeg">1</span>, <span class="sdeg">2</span>,
<span class="sdeg">3</span> …) to distinguish a scale degree from a chord member
or a [figured-bass figure](https://en.wikipedia.org/wiki/Figured_bass). This
guide uses plain numbers for readability.

## The Technical Names

In major, each degree also has a traditional name that describes its
relationship to the tonic.

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Degree</th>
      <th scope="col">Name</th>
      <th scope="col">Relationship to the tonic</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>Tonic</td>
      <td>The home note, the tonal center the key is named after.</td>
    </tr>
    <tr>
      <td>2</td>
      <td>Supertonic</td>
      <td>
        The step directly above the tonic (<em>super</em>, above).
      </td>
    </tr>
    <tr>
      <td>3</td>
      <td>Mediant</td>
      <td>
        A third above the tonic, between the tonic and dominant.
      </td>
    </tr>
    <tr>
      <td>4</td>
      <td>Subdominant</td>
      <td>
        A fifth below the tonic (<em>sub</em>, below), the lower
        counterpart of the dominant.
      </td>
    </tr>
    <tr>
      <td>5</td>
      <td>Dominant</td>
      <td>
        A fifth above the tonic, the upper counterpart of the
        subdominant.
      </td>
    </tr>
    <tr>
      <td>6</td>
      <td>Submediant</td>
      <td>
        A third below the tonic, the lower counterpart of the mediant.
      </td>
    </tr>
    <tr>
      <td>7</td>
      <td>Leading tone</td>
      <td>A semitone below the tonic, pulling strongly up to it.</td>
    </tr>
  </tbody>
</table>

The scale is numbered upward, but these names also look downward from the tonic:
degree 4 is a fourth above the tonic and a fifth below it, while degree 6 is a
sixth above and a third below.

The names mirror each other around the tonic: each _sub-_ degree sits as far
below the tonic as its partner sits above. The seventh degree is the one place
the mirror bends.

<!-- prettier-ignore -->
<div class="degree-mirror">
  <svg
    viewBox="0 0 540 400"
    role="img"
    aria-labelledby="mirror-title mirror-desc"
    fill="currentColor"
  >
    <title id="mirror-title">
      Scale-degree names mirrored around the tonic
    </title>
    <desc id="mirror-desc">
      The tonic sits at the center. The dominant, mediant, and
      supertonic rise above it, and the subdominant, submediant, and
      subtonic fall the same distances below it: a fifth, a third, and
      a second.
    </desc>
    <!-- axis of reflection through the tonic, stopping short of the
         interval labels on the right -->
    <line
      x1="88"
      y1="200"
      x2="292"
      y2="200"
      stroke="currentColor"
      stroke-opacity="0.28"
      stroke-dasharray="5 5"
    />
    <!-- connectors and mirror brackets -->
    <g
      stroke="currentColor"
      fill="none"
      stroke-opacity="0.32"
      stroke-width="1"
    >
      <path d="M265 152 H296 M265 248 H296" />
      <path d="M296 152 h8 v96 h-8" />
      <path d="M265 104 H368 M265 296 H368" />
      <path d="M368 104 h8 v192 h-8" />
      <path d="M265 48 H448 M265 352 H448" />
      <path d="M448 48 h8 v304 h-8" />
    </g>
    <!-- interval labels -->
    <g
      fill="currentColor"
      fill-opacity="0.7"
      font-size="13"
      font-style="italic"
      dominant-baseline="middle"
    >
      <text x="314" y="200">a second</text>
      <text x="386" y="200">a third</text>
      <text x="466" y="200">a fifth</text>
    </g>
    <!-- degree nodes -->
    <g fill="none" stroke="currentColor" stroke-width="1.5">
      <rect x="115" y="31" width="150" height="34" rx="17" />
      <rect x="115" y="87" width="150" height="34" rx="17" />
      <rect x="115" y="135" width="150" height="34" rx="17" />
      <rect
        x="115"
        y="183"
        width="150"
        height="34"
        rx="17"
        stroke="var(--accent-light)"
        stroke-width="2.5"
      />
      <rect x="115" y="231" width="150" height="34" rx="17" />
      <rect x="115" y="279" width="150" height="34" rx="17" />
      <rect x="115" y="335" width="150" height="34" rx="17" />
    </g>
    <g
      fill="currentColor"
      font-size="15"
      text-anchor="middle"
      dominant-baseline="central"
    >
      <text x="190" y="46">Dominant</text>
      <text x="190" y="102">Mediant</text>
      <text x="190" y="150">Supertonic</text>
      <text
        x="190"
        y="198"
        fill="var(--accent-light)"
        font-weight="700"
      >
        Tonic
      </text>
      <text x="190" y="246">Subtonic</text>
      <text x="190" y="294">Submediant</text>
      <text x="190" y="350">Subdominant</text>
    </g>
  </svg>
</div>

### Leading tone or subtonic

The seventh degree earns the name leading tone only when it sits a semitone
below the tonic, as it does in the major scale, where its pull toward home is
strong. When it sits two semitones below, as in natural minor, that pull weakens
and the degree takes the name subtonic instead. Raising it by a semitone, which
is exactly what harmonic minor does, restores the leading tone.

## Numbers, Names, and Solfège

Numbers are one of several movable systems for the same idea. In major, the
technical names give tonic, supertonic, mediant, and so on, while movable-_do_
[solfège](https://en.wikipedia.org/wiki/Solf%C3%A8ge) names the degrees _do, re,
mi, fa, sol, la, ti_. All three describe notes relative to the tonic rather than
as absolute pitches, so their relationships transpose from one key to another.

## Scale Formulas

An interval is the distance between two notes. A flat (`♭`) lowers that distance
by one semitone; a sharp (`♯`) raises it by one. A major third interval spans
four semitones, while a minor third interval spans three.

Degree and formula describe a note two different ways:

- **Scale degrees** count positions within a scale. C is the third note of A
  minor, so it is degree `3`.
- **Scale formulas** describe each note's interval above the tonic. C is a minor
  third above A, so the formula labels it `♭3`.

Scale formulas use the parallel major scale as their reference, meaning the
major scale with the same tonic. Its formula is <code class="formula">1, 2, 3,
4, 5, 6, 7</code>. The table below focuses on major and the three familiar forms
of minor:

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Scale</th>
      <th scope="col">Formula</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Major</td>
      <td><code class="formula">1, 2, 3, 4, 5, 6, 7</code></td>
    </tr>
    <tr>
      <td>Natural minor</td>
      <td><code class="formula">1, 2, ♭3, 4, 5, ♭6, ♭7</code></td>
    </tr>
    <tr>
      <td>Harmonic minor</td>
      <td><code class="formula">1, 2, ♭3, 4, 5, ♭6, 7</code></td>
    </tr>
    <tr>
      <td>Ascending melodic minor</td>
      <td><code class="formula">1, 2, ♭3, 4, 5, 6, 7</code></td>
    </tr>
  </tbody>
</table>

Relative to the parallel major, all three minor forms lower degree 3; changes to
degrees 6 and 7 distinguish them. That fixed reference keeps each formula label
tied to one interval, so `♭3` always means a minor third above the tonic. The
flat does not mark the note as foreign to the scale; it only compares it with
that reference. This convention is used throughout the guide for scale formulas
and Roman-numeral degree labels.

## Harmonizing the Scale

Degrees also build chords. The root is the note a chord is built from. Take each
degree as a root and stack thirds using only notes in the scale, skipping every
other degree. The chord on degree 1 uses <code class="formula">1, 3, 5</code>;
the chord on degree 2 uses <code class="formula">2, 4, 6</code>; the pattern
continues around the scale. Each degree yields a triad, a three-note chord;
adding one more third adds the seventh above the root, making a four-note
seventh chord.

A triad's [quality](chord-naming.html#from-degrees-to-quality-names) comes from
the two thirds it stacks from bottom to top.

- A major third followed by a minor third makes a major triad.
- A minor third followed by a major third makes a minor triad.
- Two minor thirds make a diminished triad.
- Two major thirds make an augmented triad.

In major the pattern of qualities is fixed: major, minor, minor, major, major,
minor, diminished. Roman numerals name these chords by degree and quality at
once. An uppercase numeral is a major triad, a lowercase one is minor, a `°`
marks a diminished triad, and a `+` an augmented one.

<table class="article-table">
  <caption>
    Major Scale Triads
  </caption>
  <thead>
    <tr>
      <th scope="col">Degree</th>
      <th scope="col">Roman numeral</th>
      <th scope="col">Triad quality</th>
      <th scope="col">Chord in C major</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>I</td>
      <td>Major</td>
      <td><span class="chord">C</span></td>
    </tr>
    <tr>
      <td>2</td>
      <td>ii</td>
      <td>Minor</td>
      <td><span class="chord">Dm</span></td>
    </tr>
    <tr>
      <td>3</td>
      <td>iii</td>
      <td>Minor</td>
      <td><span class="chord">Em</span></td>
    </tr>
    <tr>
      <td>4</td>
      <td>IV</td>
      <td>Major</td>
      <td><span class="chord">F</span></td>
    </tr>
    <tr>
      <td>5</td>
      <td>V</td>
      <td>Major</td>
      <td><span class="chord">G</span></td>
    </tr>
    <tr>
      <td>6</td>
      <td>vi</td>
      <td>Minor</td>
      <td><span class="chord">Am</span></td>
    </tr>
    <tr>
      <td>7</td>
      <td>vii°</td>
      <td>Diminished</td>
      <td><span class="chord">Bdim</span></td>
    </tr>
  </tbody>
</table>

Natural minor follows a different pattern. The Degree column still counts
positions within the scale, but flats before the Roman numerals show which chord
roots are lower than their parallel-major counterparts. Degree `3` therefore
appears as `♭III`.

<table class="article-table">
  <caption>
    Natural Minor Scale Triads
  </caption>
  <thead>
    <tr>
      <th scope="col">Degree</th>
      <th scope="col">Roman numeral</th>
      <th scope="col">Triad quality</th>
      <th scope="col">Chord in A minor</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>i</td>
      <td>Minor</td>
      <td><span class="chord">Am</span></td>
    </tr>
    <tr>
      <td>2</td>
      <td>ii°</td>
      <td>Diminished</td>
      <td><span class="chord">Bdim</span></td>
    </tr>
    <tr>
      <td>3</td>
      <td>♭III</td>
      <td>Major</td>
      <td><span class="chord">C</span></td>
    </tr>
    <tr>
      <td>4</td>
      <td>iv</td>
      <td>Minor</td>
      <td><span class="chord">Dm</span></td>
    </tr>
    <tr>
      <td>5</td>
      <td>v</td>
      <td>Minor</td>
      <td><span class="chord">Em</span></td>
    </tr>
    <tr>
      <td>6</td>
      <td>♭VI</td>
      <td>Major</td>
      <td><span class="chord">F</span></td>
    </tr>
    <tr>
      <td>7</td>
      <td>♭VII</td>
      <td>Major</td>
      <td><span class="chord">G</span></td>
    </tr>
  </tbody>
</table>

C major and A natural minor contain the same notes, but changing the tonic
reorders the chords and changes their Roman numerals.

Natural minor keeps its subtonic two semitones below the tonic. Harmonic minor
raises that note by one semitone to create a leading tone. That change affects
three triads: `♭III` becomes `♭III+`, `v` becomes `V`, and `♭VII` becomes
`vii°`. The major `V` is the most important functional result, restoring a
strong dominant-to-tonic resolution.

Seventh chords extend the same stack. The major scale gives
<span class="chord">Cmaj7</span> on the tonic, <span class="chord">Dm7</span> on
the supertonic, the dominant seventh <span class="chord">G7</span> on the fifth,
and the half-diminished <span class="chord">Bm7(♭5)</span> on the seventh. A
Roman numeral, in the end, is just a scale degree carrying a chord.

## Degrees and Spelling

Because a conventionally spelled
[diatonic scale](https://en.wikipedia.org/wiki/Diatonic_scale) uses each letter
once, a degree also fixes the letter its chord's root is spelled with. The chord
a third above the tonic in C is some kind of E; the chord a sixth above is some
kind of A; whatever accidentals the key adds, the letter stays put. It holds for
altered degrees too: the `♭VI` in C is written <span class="chord">A♭</span>,
not <span class="chord not-used">G♯</span>, because it is still the sixth
degree, built on the letter A. This is the same
[enharmonic logic](why-chord-naming-is-hard.html#enharmonic-spelling) that
spells the notes inside a chord, applied to the roots themselves.

## Tendency and Function

Scale degrees describe both melodic tendencies and harmonic functions. As a
note, the leading tone tends to rise to the tonic. As chord roots,
<span class="chord">V</span> tends toward <span class="chord">I</span>, while
<span class="chord">ii</span> commonly prepares <span class="chord">V</span>.
These relationships transpose from one major key to another because they follow
degrees rather than letters.

This is why analysis so often reduces to a handful of numerals. A progression of
<span class="chord">ii</span>-<span class="chord" >V</span >-<span class="chord">I</span>
behaves the same in every major key because it is a statement about degrees: the
supertonic moving to the dominant, the dominant resolving home.

## How WhatChord Uses Scale Degrees

The scale-degree strip highlights the Roman numeral of a chord that fits the
current key, whether you selected the key or WhatChord detected it
automatically. Chords that do not fit cleanly remain unhighlighted rather than
receiving a forced label.

Explore Scales shows every scale's tones and formula. Where stacked-third
harmony applies, it also lays out the diatonic triads and seventh chords with
Roman numerals. Selecting a degree shows its technical name and, where
appropriate, its resolution tendency.

Thinking in degrees is what makes harmony portable: a note, a chord, or a
progression keeps its meaning as you move it from key to key.

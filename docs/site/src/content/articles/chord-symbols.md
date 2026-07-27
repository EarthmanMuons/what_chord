---
cardDescription:
  "How WhatChord formats chord symbols: extensions, added tones, alterations,
  parentheses, and slash bass, with the reasoning behind each choice."
cardTitle: "Chord Symbol Guide"
decks:
  - 'A chord symbol is a concise name for a harmonic identity, not an exhaustive
    inventory of the notes being played. It describes a chord’s quality,
    independent of the register, spacing, and doublings of any particular <a
    href="https://en.wikipedia.org/wiki/Voicing_(music)">voicing</a>.'
  - 'Chord symbol nomenclature has never been governed by a single universal
    standard. Different publishers, educators, software packages, and musical
    traditions use slightly different conventions. This guide documents the
    conventions WhatChord applies: a practical style for contemporary lead-sheet
    and jazz notation (not classical <a
    href="https://en.wikipedia.org/wiki/Figured_bass" >figured-bass</a > or <a
    href="https://en.wikipedia.org/wiki/Roman_numeral_analysis" >Roman-numeral
    analysis</a >). Where established practice diverges, it takes a clear
    position and explains the reasoning, favoring readability, consistency, and
    unambiguous interpretation rather than cataloging every variant.'
description:
  "A reference for how WhatChord formats chord symbols: extensions, added tones,
  alterations, parentheses, omissions, and slash bass, with the reasoning behind
  each choice."
group: "musicians"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 2
pageTitle: "How to Format Chord Symbols | WhatChord"
related:
  - "why-chord-naming-is-hard"
  - "chord-naming"
  - "scale-degrees"
socialDescription:
  "The conventions behind WhatChord’s chord symbols: extensions, added tones,
  alterations, parentheses, and slash bass, explained for musicians."
socialTitle: "How to Format Chord Symbols"
tag: "Reference"
title: "Chord Symbol Guide"
---

## Naming, Writing, and Playing

Three related questions are easy to conflate: what are these notes called, what
symbol should I write to suggest this chord, and what will a player do with what
I wrote? This guide answers the first: given a set of notes, which symbol names
them.

The other two allow more latitude. The notes D-G-A-C are exactly
<span class="chord">D7sus4</span>, but a lead sheet might write
<span class="chord">D7sus</span>, or even <span class="chord">Dsus</span>,
trusting the reader to fill in the seventh. A performer, in turn, may voice any
of these freely; jazz players will happily hang a seventh on anything.

Identification favors the precise name. Where a choice remains, we lean toward
what a musician expects to read, not the loosest shorthand a setting allows.

## Symbol Structure

A symbol has three parts:

<div class="symbol-parts">
  <div class="symbol-part">
    <span class="symbol-part-label">Root</span>
    <span class="symbol-part-example">C</span>
  </div>
  <span class="symbol-part-join">+</span>
  <div class="symbol-part">
    <span class="symbol-part-label">Quality &amp; extensions</span>
    <span class="symbol-part-example">maj7</span>
  </div>
  <span class="symbol-part-join">+</span>
  <div class="symbol-part symbol-part-optional">
    <span class="symbol-part-label"
      >Slash bass <span class="symbol-part-opt">optional</span></span
    >
    <span class="symbol-part-example">/ E</span>
  </div>
</div>

Examples include <span class="chord">C</span>, <span class="chord">Cm7</span>,
<span class="chord">C13♭9</span>, and <span class="chord">Cmaj7 / E</span>.

The root and bass are spelled to fit the current tonal context. The middle
portion is formatted from the identified chord quality and extensions. Spelling
and notation preferences, including enharmonic respellings chosen for
convenience, change how the symbol looks without changing the underlying sense
of root.

Two common notation styles are available. Before extensions and alterations are
added, chord symbols start from these base quality labels:

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Quality</th>
      <th scope="col">Textual</th>
      <th scope="col">Symbolic</th>
      <th scope="col">Example</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Major triad</td>
      <td>no suffix</td>
      <td>no suffix</td>
      <td><span class="chord">C</span></td>
    </tr>
    <tr>
      <td>Minor triad</td>
      <td><code>m</code></td>
      <td><code>−</code></td>
      <td>
        <span class="chord">Cm</span> or
        <span class="chord">C−</span>
      </td>
    </tr>
    <tr>
      <td>Diminished triad</td>
      <td><code>dim</code></td>
      <td><code>°</code></td>
      <td>
        <span class="chord">Cdim</span> or
        <span class="chord">C°</span>
      </td>
    </tr>
    <tr>
      <td>Augmented triad</td>
      <td><code>aug</code></td>
      <td><code>+</code></td>
      <td>
        <span class="chord">Caug</span> or
        <span class="chord">C+</span>
      </td>
    </tr>
    <tr>
      <td>Suspended triads</td>
      <td><code>sus2</code>, <code>sus4</code></td>
      <td><code>sus2</code>, <code>sus4</code></td>
      <td><span class="chord">Csus4</span></td>
    </tr>
    <tr>
      <td>Dominant seventh</td>
      <td><code>7</code></td>
      <td><code>7</code></td>
      <td><span class="chord">C7</span></td>
    </tr>
    <tr>
      <td>Major seventh</td>
      <td><code>maj7</code></td>
      <td><code>Δ7</code></td>
      <td>
        <span class="chord">Cmaj7</span> or
        <span class="chord">CΔ7</span>
      </td>
    </tr>
    <tr>
      <td>Minor seventh</td>
      <td><code>m7</code></td>
      <td><code>−7</code></td>
      <td>
        <span class="chord">Cm7</span> or
        <span class="chord">C−7</span>
      </td>
    </tr>
    <tr>
      <td>Minor-major seventh</td>
      <td><code>m(maj7)</code></td>
      <td><code>−Δ7</code></td>
      <td>
        <span class="chord">Cm(maj7)</span> or
        <span class="chord">C−Δ7</span>
      </td>
    </tr>
    <tr>
      <td>Half-diminished seventh</td>
      <td><code>m7(♭5)</code></td>
      <td><code>ø7</code></td>
      <td>
        <span class="chord">Cm7(♭5)</span> or
        <span class="chord">Cø7</span>
      </td>
    </tr>
    <tr>
      <td>Fully diminished seventh</td>
      <td><code>dim7</code></td>
      <td><code>°7</code></td>
      <td>
        <span class="chord">Cdim7</span> or
        <span class="chord">C°7</span>
      </td>
    </tr>
  </tbody>
</table>

In everyday practice these are not sealed systems; musicians often mix them,
writing a dash for a minor chord but spelling out `maj7`, or reaching for `°`
and `ø7` while leaving the rest textual.

The examples below use textual notation throughout.

## Extensions vs. Added Tones

The seventh is what turns an upper note into an extension. With a seventh
present, a natural ninth, eleventh, or thirteenth continues the
[tertian stack](chord-naming.html) and is named as an extension. Without the
seventh, that same note is an _added tone_, written with `add`, and implies no
seventh: <span class="chord">C9</span> has a seventh, while
<span class="chord">Cadd9</span> does not.

- A natural ninth is `9` when the chord has a seventh, otherwise `add9`.
- A natural eleventh is `11` when the chord has a seventh, otherwise `add11`.
- A natural thirteenth is `13` when the chord has a seventh, otherwise `6` (see
  below).

The lower members of the extensions are optional: a
<span class="chord">C11</span> may omit its ninth, and a
<span class="chord">C13</span> its ninth and eleventh.

The highest extension present is promoted into the main symbol. Any present
lower extension is folded in rather than spelled out separately, while
alterations stay explicit. So a dominant thirteenth with a flat ninth and sharp
eleventh is <span class="chord">C13(♭9,♯11)</span>.

### Sixth Chords

The seventh is what makes a chord a thirteenth rather than a sixth. With no
seventh, a major or minor triad with the sixth degree is a sixth chord,
<span class="chord">C6</span> or <span class="chord">Cm6</span>; adding a ninth
gives the conventional <span class="chord">C6/9</span>.

### Why not add2 or add4?

Chord symbols say nothing about register, so an added tone's label never changes
with its voicing: a D added to a C triad is the same ninth whether it sits next
to the root or an octave above, and an F is the same eleventh either way. There
is no need to drop to <code class="not-used">add2</code> or
<code class="not-used">add4</code> just because a note happens to be voiced
close to the root.

Register independence rules out voicing-based switching, but it does not by
itself favor `add9` over <code class="not-used">add2</code>, or `add11` over
<code class="not-used">add4</code>, since each pair ignores register equally. No
strict rule settles the choice; `add9` and `add11` simply prevail as the common
convention.

`sus2` and `sus4` remain distinct because they describe replacement of the
third, not merely an added tone.

## Alterations

Altered upper extensions are written explicitly: `♭9`, `♯9`, `♯11`, and `♭13`.
Here `♭` and `♯` mean lowered or raised by a semitone from the natural
extension, using whatever accidental the spelling requires; a `♭9` does not
necessarily carry a literal flat on the note. When a triad has an altered ninth
without the harmonic support for a stacked extension, the symbol can use `add♭9`
or `add♯9`.

An altered fifth that defines the base quality normally stays with that quality
label. It is usually inline, as in <span class="chord">C7♭5</span>,
<span class="chord">Cmaj7♯5</span>, and <span class="chord">Cm♯5</span>. The
exception is a bare major triad with a flat five: inline,
<span class="chord not-used">C♭5</span> risks reading as a C-flat root rather
than a lowered fifth, so the altered fifth is parenthesized as
<span class="chord">C(♭5)</span>. The parenthesized half-diminished spelling
<span class="chord">Cm7(♭5)</span> is a conventional form kept for familiarity,
much like <span class="chord">C6/9</span>.

When such a chord also carries other modifiers, the altered fifth joins them in
the single trailing group rather than running the accidentals together or
stranding a second set of parentheses: a dominant seventh with a flat five and a
flat nine is <span class="chord">C7(♭5,♭9)</span>, and an extended
half-diminished chord is <span class="chord">Cm9(♭5,♭13)</span>, not
<span class="chord not-used">Cm9(♭5)♭13</span>.

Modifiers are ordered consistently by musical degree: ninths, elevenths, then
thirteenths, with alterations placed alongside their degree.

## Parentheses

This guide reserves parentheses for grouping and disambiguation. They are one of
the least standardized parts of chord symbol notation, used for all sorts of
purposes depending on the source. Some teaching styles, such as Berklee-derived
materials, parenthesize every tension and alteration as a rule, as in
<span class="chord not-used">C7(♯11)</span>, where we prefer to keep a lone
alteration inline as <span class="chord">C7♯11</span>.

A symbol carries _at most one parenthesized group_, placed at the end, so
parentheses never appear in the middle of the label or as two separate groups. A
group forms only where running the modifiers inline would be ambiguous or hard
to read:

- Multiple modifiers are grouped: <span class="chord">C7(♭9,♯11)</span>.
- Modifiers on suspended seventh chords are grouped rather than run onto the
  suspension: <span class="chord">C7sus4(♭13)</span>.
- In textual notation, added tones after the spelled-out `aug` and `dim` labels
  are grouped so the words do not run into `add`:
  <span class="chord">Cdim(add9)</span> is clearer than
  <span class="chord not-used">Cdimadd9</span>.
- An altered fifth carried in the quality label joins the group when other
  modifiers are present: <span class="chord">C7(♭5,♭9)</span> and
  <span class="chord">Cm9(♭5,♭13)</span>.
- Textual minor-major symbols write the major seventh or promoted major
  extension inside the group, with any other modifiers joining it:
  <span class="chord">Cm(maj7)</span>, <span class="chord">Cm(maj9)</span>, and
  <span class="chord">Cm(maj9,♭13)</span>.
- A lone upper-extension modifier after promoted `maj11` or `maj13` is grouped
  because the two-digit promoted label is already dense:
  <span class="chord">Cmaj11(♭13)</span> and
  <span class="chord">Cmaj13(♯11)</span>.
- Bare altered colors after a plain major root are grouped so the accidental
  belongs to the extension, not the root: <span class="chord">C(♯11)</span>.
- A promoted extension after an accidental root is grouped for the opposite
  reason, so the root accidental remains clear:
  <span class="chord">C♯(11)</span> and <span class="chord">F♯(13,♯11)</span>.

Where concatenation is already clear, the modifiers stay inline. A single
ordinary modifier needs no group: <span class="chord">C7♭9</span>,
<span class="chord">C13♯11</span>, <span class="chord">Cmaj9♯11</span>, or
<span class="chord">Cadd♯9</span>. An added tone reads cleanly inline after a
label that already ends in a self-contained mark: the bare root
(<span class="chord">Cadd9</span>), the fused `m`
(<span class="chord">Cmadd11</span>), and the symbolic quality signs `+` and `°`
(<span class="chord" >C+add13</span >).

Textual notation separates grouped modifiers with commas for readability, as in
<span class="chord">C13(♭9,♯11)</span>. Symbolic notation omits them for
compactness, writing the same chord as <span class="chord">C13(♭9♯11)</span>,
since the accidentals already mark where each modifier begins.

## Omissions

Omission markers such as <code class="not-used">no5</code> and
<code class="not-used">omit3</code> do appear in practice, but this guide avoids
them. For the purpose of communicating an identity, they add visual noise
without changing which chord is named.

Commonly omitted tones, especially perfect fifths in extended chords, should be
understood as part of that chord's identity rather than turned into a
performance instruction. Dropping a structurally important tone, like the third,
is a different matter: it weakens the reading instead of simplifying the symbol.

## Slash Bass

The slash note names the sounding bass under the chord symbol. It does not
change the root, and it does not make the bass note a second chord symbol. A
voicing with E in the bass and a C major seventh above it is therefore
<span class="chord">Cmaj7 / E</span>, not an E-rooted chord
[unless the notes support that analysis more strongly](why-chord-naming-is-hard.html#inversions).

Slash bass also affects which chord tones need to be named explicitly. If an
added-tone label would only repeat the bass note, that label is omitted. For
example, prefer <span class="chord">A♭7 / D♭</span> over the redundant
<span class="chord not-used">A♭7(add11) / D♭</span>. Only added tones compress
this way; an alteration keeps its label even when the bass supplies that note,
so a half-diminished chord with its lowered thirteenth in the bass is still
<span class="chord">Em7(♭5,♭13) / C</span>, not
<span class="chord not-used">Em7(♭5) / C</span>.

The same principle keeps slash-bass symbols from overstating stacked extensions.
A ninth only earns its place in the main symbol when the chord truly carries it,
so a ninth that comes from the bass alone stays in the bass:
<span class="chord">C7 / D</span>, not <span class="chord not-used">C9 /
D</span>. The seventh belongs to the quality rather than the extensions, so it
never drops out this way and <span class="chord">C7 / B♭</span> stays
<span class="chord">C7 / B♭</span>.

The slash note names the pitch a player sounds, so it favors a readable
spelling. When the bass is a genuine chord tone, its conventional inversion
spelling is kept, even where that means a less common letter, as with
<span class="chord">C♯maj7 / B♯</span>. But when the bass is a color or altered
tone, the sounding spelling wins, so a sharp ninth in the bass is
<span class="chord">A7(♯9) / C</span>, not <span class="chord not-used">A7(♯9) /
B♯</span>, and double accidentals are avoided.

## References

These formatting decisions draw on both historical and modern practice:

- Carl Brandt and Clinton Roemer,
  [_Standardized Chord Symbol Notation_](https://openlibrary.org/isbn/9780961268428)
  (1976), an early effort to standardize symbols and remove ambiguity for
  sight-reading studio musicians.
- Chuck Sher and others,
  [_The New Real Book_](https://www.shermusic.com/new/0961470143.shtml) (Sher
  Music Co., 1988), a practical model of jazz lead-sheet usage, including
  compact symbols that working musicians are likely to recognize quickly.
- Mark Levine,
  [_The Jazz Theory Book_](https://www.shermusic.com/1883217040.php) (Sher Music
  Co., 1995), a pedagogical reference for the musical reasoning behind chord
  qualities, extensions, alterations, and common voicing practice.

Where references or house styles differ, WhatChord favors symbols that are
concise, widely recognizable, and clear in a real-time app interface. The goal
is not to reproduce any one book's house style exactly, but to apply the same
clarity principles consistently across every displayed chord.

## Acknowledgements

This guide was sharpened by the careful reading, edits, and suggestions of
[u/65TwinReverbRI](https://www.reddit.com/user/65TwinReverbRI), whose feedback
shaped much of how these conventions are explained.

<div class="article-cta">
  <h3>See these symbols on real chords.</h3>
  <p>
    Enter any notes and WhatChord identifies the chord and formats its
    symbol using these conventions, without downloading a thing.
  </p>
  <a class="btn btn-primary" href="/try">Try it in your browser →</a>
</div>

---
cardDescription:
  "The bitmasks, chord-quality templates, explanation costs and ranking
  heuristics, and LRU cache behind real-time chord recognition."
cta:
  action:
    href: "https://github.com/EarthmanMuons/whatchord"
    icon: "github"
    label: "View source on GitHub"
    variant: "ghost"
  description:
    "Free for iOS and Android. No subscription, no ads, all analysis on-device."
  secondary:
    href: "/try"
    label: "Try identifying chords in your browser →"
    lead: "Prefer not to install?"
  storeBadges: true
  title: "See it in action."
decks:
  - "A technical look at the analysis engine behind WhatChord: pitch-class
    bitmasks, chord templates, implied roots, explanation costs, ranking
    heuristics, and the small LRU cache that keeps real-time chord
    identification fast."
description:
  "A technical deep-dive into the pitch-class bitmasks, chord templates, implied
  roots, explanation costs, ranking heuristics, and LRU cache behind real-time
  chord identification."
featuredDescription:
  "A detailed look at the bitmasks, chord-quality templates, explanation costs,
  ranking heuristics, and LRU cache that power real-time chord identification in
  a standalone Dart engine."
featuredOrder: 1
group: "technical"
indexOrder: 4
related:
  - "chord-ranking-performance"
  - "turning-live-midi-into-chord-events"
  - "key-detection-algorithm"
socialDescription:
  "A detailed look at the bitmasks, templates, implied roots, explanation costs,
  ranking heuristics, and LRU cache that power real-time chord identification."
socialTitle: "Building a Real-Time Chord Recognizer"
tag: "Technical deep-dive"
title: "Building a Real-Time Chord Recognizer"
---

## The problem is not a lookup

The first intuition when building a chord recognizer is to build a dictionary.
There are only 12 pitch classes, which means there are only `2^12 = 4096`
possible pitch-class sets. Store a name for each set, and when a user plays
C-E-G, look up C-E-G and return "<span class="chord">C major</span>."

The problem is not memory. Four thousand entries is trivial. The problem is
meaning. A pitch-class set does not contain enough information to decide what
musicians will call it.

Players routinely omit notes that a dictionary entry might expect; in an
ensemble, another instrument may even supply the root. Extended chords add notes
that no fixed entry anticipates. And the same set of pitch classes can
legitimately be described as
[multiple different chords depending on musical context](why-chord-naming-is-hard.html).

What you actually need is a cost model. It has to evaluate how well any given
set of notes fits each chord type, rank all plausible interpretations, and apply
musical judgment when costs are close.

## Overview: a four-stage pipeline

Before diving into each component, here is the overall shape of the algorithm. A
snapshot of sounding notes and its analysis context enter at the top; a ranked
list of chord interpretations comes out at the bottom. A separate
[segmentation stage](turning-live-midi-into-chord-events.html) decides which
live snapshots become stable chord events.

<div class="pipeline-flow">
  <div class="pf-endpoint">
    Input: sounding pitch classes + bass note + analysis context
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Pitch-class bitmask</div>
    <div class="pf-sub">
      12-bit integer: one bit per semitone in the octave
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Candidate generation</div>
    <div class="pf-sub">
      Sounding notes become candidate roots; Ensemble mode also tests
      tightly constrained implied roots
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Explanation cost</div>
    <div class="pf-sub">
      Each reading is priced by how cheaply it explains the input;
      core tones are free, everything else costs
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Ranking</div>
    <div class="pf-sub">
      Musical heuristics resolve ambiguous costs; hard structural
      rules override when cost alone would pick the wrong answer
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-endpoint">
    Output: top ranked chord candidates, result cached in LRU
  </div>
</div>

The rest of this article walks through each stage in detail, ending with a
discussion of known limitations.

## Pitch classes and bitmasks

WhatChord models the common
[12-tone equal temperament](https://en.wikipedia.org/wiki/12_equal_temperament)
(12-TET) pitch-class framework used by MIDI keyboards, which divides each octave
into equal semitone positions. A _pitch class_ is the note's position within
that octave, ignoring which octave it's in, so middle C, the C above it, and the
C three octaves below all share pitch class 0. In this engine, pitch classes are
numbered 0 (C) through 11 (B).

For analysis, the engine collapses the sounding notes into a set of pitch
classes plus the lowest sounding note as bass. The pitch-class set is
represented as a 12-bit integer mask where bit _n_ is set if pitch class _n_ is
present. C major (C=0, E=4, G=7) looks like this:

<table
  class="bit-field"
  aria-label="Bitmask for C major: bits 0, 4, 7 set"
>
  <thead>
    <tr>
      <th>11</th>
      <th>10</th>
      <th>9</th>
      <th>8</th>
      <th>7</th>
      <th>6</th>
      <th>5</th>
      <th>4</th>
      <th>3</th>
      <th>2</th>
      <th>1</th>
      <th>0</th>
    </tr>
  </thead>
  <tbody>
    <tr class="note-row">
      <td>B</td>
      <td>A♯</td>
      <td>A</td>
      <td>G♯</td>
      <td>G</td>
      <td>F♯</td>
      <td>F</td>
      <td>E</td>
      <td>D♯</td>
      <td>D</td>
      <td>C♯</td>
      <td>C</td>
    </tr>
    <tr class="bit-row">
      <td>0</td>
      <td>0</td>
      <td>0</td>
      <td>0</td>
      <td class="b1">1</td>
      <td>0</td>
      <td>0</td>
      <td class="b1">1</td>
      <td>0</td>
      <td>0</td>
      <td>0</td>
      <td class="b1">1</td>
    </tr>
  </tbody>
</table>

<pre><code><span class="cm">// Pitch classes: C=0, E=4, G=7</span>
<span class="kw">int</span> pcMask = (<span class="nu">1</span> &lt;&lt; <span class="nu">0</span>) | (<span class="nu">1</span> &lt;&lt; <span class="nu">4</span>) | (<span class="nu">1</span> &lt;&lt; <span class="nu">7</span>);
<span class="cm">// pcMask == 0b000010010001 == 0x091</span></code></pre>

This representation is compact and fast. Checking whether a pitch class is
present is a single bitwise AND. Counting present pitch classes is a
[popcount](https://en.wikipedia.org/wiki/Hamming_weight). Rotating the set
relative to a candidate root is a loop over bits with
[modular arithmetic](https://en.wikipedia.org/wiki/Modular_arithmetic). All of
these operations are cheap.

Candidate generation depends on the playing mode. Solo mode tests only pitch
classes present in the voicing as roots. This keeps the candidate count small
(typically 3–7 roots) and suits a MIDI stream that carries both harmony and
bass.

Ensemble mode evaluates the same sounding-root candidates, then adds a
constrained set of _implied_ roots for voicings whose root may be supplied by
another instrument. The restrictions that keep those additional readings useful
are described below under [Ensemble mode](#ensemble-mode).

## Chord templates

Chord qualities are also defined as bitmask templates. Each one describes three
sets of intervals relative to the root:

- **Required:** tones that must be present to identify this quality. Missing
  more than one required tone causes the template to be skipped entirely.
- **Optional:** tones frequently omitted in real voicings (almost always the
  perfect 5th). Present when played, unremarkable when absent.
- **Penalty:** tones that actively contradict this quality. Having a major 3rd
  present when you are trying to identify a minor chord raises the cost.

The 27 templates, organized by complexity:

<table class="article-table">
  <thead>
    <tr>
      <th>Quality</th>
      <th>Required intervals</th>
      <th>Optional</th>
      <th>Key penalties / constraints</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Major</td>
      <td class="mono">R, M3</td>
      <td class="mono">P5</td>
      <td class="mono">m3, m7, M7</td>
    </tr>
    <tr>
      <td>Major (♭5)</td>
      <td class="mono">R, M3, ♭5</td>
      <td>—</td>
      <td class="mono">P5, m3, m7, M7</td>
    </tr>
    <tr>
      <td>Minor</td>
      <td class="mono">R, m3</td>
      <td class="mono">P5</td>
      <td class="mono">M3, m7, M7</td>
    </tr>
    <tr>
      <td>Minor ♯5</td>
      <td class="mono">R, m3, ♯5</td>
      <td>—</td>
      <td class="mono">M3, P5, m7, M7</td>
    </tr>
    <tr>
      <td>Diminished</td>
      <td class="mono">R, m3, ♭5</td>
      <td>—</td>
      <td class="mono">M3, P5</td>
    </tr>
    <tr>
      <td>Augmented</td>
      <td class="mono">R, M3, ♯5</td>
      <td>—</td>
      <td class="mono">m3, P5</td>
    </tr>
    <tr>
      <td>Power (5)</td>
      <td class="mono">R, P5</td>
      <td>—</td>
      <td class="mono">m3, M3, ♭5, m6/M6, m7, M7</td>
    </tr>
    <tr>
      <td>Sus2</td>
      <td class="mono">R, M2, P5</td>
      <td>—</td>
      <td class="mono">m3, M3, m7, M7</td>
    </tr>
    <tr>
      <td>Sus4</td>
      <td class="mono">R, P4, P5</td>
      <td>—</td>
      <td class="mono">m3, M3, m7, M7</td>
    </tr>
    <tr>
      <td>Double sus (Sus2sus4)</td>
      <td class="mono">R, M2, P4, P5</td>
      <td>—</td>
      <td>Exact match only</td>
    </tr>
    <tr>
      <td>Major 6</td>
      <td class="mono">R, M3, M6</td>
      <td class="mono">P5</td>
      <td class="mono">m3, m7, M7</td>
    </tr>
    <tr>
      <td>Minor 6</td>
      <td class="mono">R, m3, M6</td>
      <td class="mono">P5</td>
      <td class="mono">M3, m7, M7</td>
    </tr>
    <tr>
      <td>Dominant 7</td>
      <td class="mono">R, M3, m7</td>
      <td class="mono">P5</td>
      <td class="mono">M7, m3</td>
    </tr>
    <tr>
      <td>7sus2</td>
      <td class="mono">R, M2, m7</td>
      <td class="mono">P5</td>
      <td class="mono">m3, M3, P4, M7</td>
    </tr>
    <tr>
      <td>7sus4</td>
      <td class="mono">R, P4, m7</td>
      <td class="mono">P5</td>
      <td class="mono">m3, M3, M7</td>
    </tr>
    <tr>
      <td>7♭5</td>
      <td class="mono">R, M3, ♭5, m7</td>
      <td>—</td>
      <td class="mono">P5, M7, m3</td>
    </tr>
    <tr>
      <td>7♯5</td>
      <td class="mono">R, M3, ♯5, m7</td>
      <td>—</td>
      <td class="mono">P5, M7, m3</td>
    </tr>
    <tr>
      <td>Major 7</td>
      <td class="mono">R, M3, M7</td>
      <td class="mono">P5</td>
      <td class="mono">m7, m3</td>
    </tr>
    <tr>
      <td>Major 7sus2</td>
      <td class="mono">R, M2, M7</td>
      <td class="mono">P5</td>
      <td class="mono">m3, M3, P4, m7</td>
    </tr>
    <tr>
      <td>Major 7sus4</td>
      <td class="mono">R, P4, M7</td>
      <td class="mono">P5</td>
      <td class="mono">m3, M3, m7</td>
    </tr>
    <tr>
      <td>Major 7♭5</td>
      <td class="mono">R, M3, ♭5, M7</td>
      <td>—</td>
      <td class="mono">P5, m7, m3</td>
    </tr>
    <tr>
      <td>Major 7♯5</td>
      <td class="mono">R, M3, ♯5, M7</td>
      <td>—</td>
      <td class="mono">P5, m7, m3</td>
    </tr>
    <tr>
      <td>Minor 7</td>
      <td class="mono">R, m3, m7</td>
      <td class="mono">P5</td>
      <td class="mono">M7, M3</td>
    </tr>
    <tr>
      <td>Minor 7♯5</td>
      <td class="mono">R, m3, ♯5, m7</td>
      <td>—</td>
      <td class="mono">P5, M7, M3</td>
    </tr>
    <tr>
      <td>Minor-Major 7</td>
      <td class="mono">R, m3, M7</td>
      <td class="mono">P5</td>
      <td class="mono">M3, m7</td>
    </tr>
    <tr>
      <td>Half-Diminished 7</td>
      <td class="mono">R, m3, ♭5, m7</td>
      <td>—</td>
      <td class="mono">P5, M3, M7</td>
    </tr>
    <tr>
      <td>Fully Diminished 7</td>
      <td class="mono">R, m3, ♭5, d7</td>
      <td>—</td>
      <td class="mono">m7, P5, M3, M7</td>
    </tr>
  </tbody>
</table>

Notice that the perfect 5th is optional for most chord families. Requiring it
would cause the algorithm to miss many idiomatic voicings in common use. The
power chord is the exception: a bare fifth is the whole chord, so its fifth is
required, and the reading is discarded outright if any tone it cannot name as
color is left over.

Penalty tones are not hard rejections. The template is still evaluated; it just
pays an added price. This handles cases where a note might simultaneously belong
to one chord and partially fit another, and lets the cost reflect the degree of
fit rather than producing a binary yes/no.

## Template pricing

For each candidate root, the analyzer rotates the pitch-class mask relative to
that root to get an interval mask. It then assigns an explanation cost for that
interval mask against the eligible chord templates.

<pre><code><span class="cm">// Rotate: compute intervals above rootPc for each sounding note</span>
<span class="kw">int</span> <span class="fn">rotateMaskToRoot</span>(<span class="kw">int</span> pcMask, <span class="kw">int</span> rootPc) {
  <span class="kw">var</span> rel = <span class="nu">0</span>;
  <span class="kw">for</span> (<span class="kw">var</span> pc = <span class="nu">0</span>; pc &lt; <span class="nu">12</span>; pc++) {
    <span class="kw">if</span> ((pcMask &amp; (<span class="nu">1</span> &lt;&lt; pc)) == <span class="nu">0</span>) <span class="kw">continue</span>;
    <span class="kw">final</span> interval = (pc - rootPc) % <span class="nu">12</span>;
    rel |= (<span class="nu">1</span> &lt;&lt; (interval &lt; <span class="nu">0</span> ? interval + <span class="nu">12</span> : interval));
  }
  <span class="kw">return</span> rel;
}</code></pre>

Each surviving reading is then priced by how well it explains the input. That
price is its _explanation cost_: core chord tones are free, and the name pays
for everything else it asks a reader to accept. The lowest cost is the best fit.

<table class="article-table">
  <thead>
    <tr>
      <th>Cost component</th>
      <th>Price</th>
      <th>Notes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Core chord tone present</td>
      <td class="pos mono">0</td>
      <td>The name itself carries these</td>
    </tr>
    <tr>
      <td>Vocabulary rarity</td>
      <td class="neg mono">0.1 / 0.4 / 1.0</td>
      <td>
        How readily a musician reaches for the quality name: everyday
        names (major, minor, 7, m7, maj7, sus4, 6ths, and the bare
        power chord) are free; marked names (dim, aug, dim7, m7♭5,
        m(maj7), sus2, double-sus, 7sus4) cost 0.1; uncommon ones
        (7♭5, 7♯5, maj7sus4, maj7♯5) cost 0.4; names that almost
        always respell a more common chord (m♯5, m7♯5, maj♭5, maj7♭5,
        7sus2, maj7sus2) cost 1.0
      </td>
    </tr>
    <tr>
      <td>Natural extension (9, 11, 13)</td>
      <td class="neg mono">0.30&ndash;0.35</td>
      <td>
        Integrated stack members on seventh chords. A candidate that
        would promote 9, 11, or 13 while its required seventh is
        missing is rejected; those same tones are add tones or sixths.
        An 11 or 13 with no 9 under it pays a small surcharge (it is
        really an add-tone wearing a stack name), waived for an 11 in
        the bass (the sus-pedal idiom, Am7/D). On marked-vocabulary
        hosts (a 13 on a half-diminished or minor-major seventh) the
        price is multiplied by 1.75.
      </td>
    </tr>
    <tr>
      <td>Add tone (add9, add11, add13)</td>
      <td class="neg mono">0.30&ndash;0.40</td>
      <td>
        Triad color. A natural 11 against a major third pays an
        avoid-tone surcharge of 0.5.
      </td>
    </tr>
    <tr>
      <td>Altered color (♭9, ♯9, ♯11, ♭13)</td>
      <td class="neg mono">0.45&ndash;0.55</td>
      <td>
        The alt palette lives on dominant chords; hosting one of these
        on any other quality doubles its price. The discount requires
        the dominant's flat seventh to actually sound: a dominant name
        missing its seventh is a phantom host and pays the doubled
        rate too. The ♯11 stays unmultiplied where it is idiomatic
        Lydian color (major, dominant, minor, and sus4 hosts).
      </td>
    </tr>
    <tr>
      <td>Split-degree surcharges</td>
      <td class="neg mono">0.4 / 0.6 / 0.8</td>
      <td>
        Two chromatic variants of one degree at once: a natural 2 plus
        ♭9/♯9, a natural 4 plus ♯11, a natural 6/13 plus ♭13, or a ♯5
        plus natural 13
      </td>
    </tr>
    <tr>
      <td>Stacked chromatic color</td>
      <td class="neg mono">0.15 / 0.3 / 0.9</td>
      <td>
        A chromatic color stacked among other colors reads as tension
        the name fails to integrate: an added ♭9 or ♯9 alongside other
        colors pays 0.15, and a ♭9 on a major sixth or seventh chord
        among other colors pays 0.3. A lone chromatic color (the
        harmonic-minor C6♭9, the Phrygian Cmadd♭9) is untouched.
        Fifthless minor-major ♭9+11 stacks pay 0.9 because they are
        usually chromatic bookkeeping rather than normal minor-major
        vocabulary.
      </td>
    </tr>
    <tr>
      <td>Empty fifth slot</td>
      <td class="neg mono">0.5 / 0.75</td>
      <td>
        A ♯11 or ♭13 with no fifth-slot tone sounding reads as the
        altered fifth instead: C-E-G♭ is C(♭5), not a fifthless
        Cadd♯11, and G-B-F-A-D♯ is G7♯5(9), not G9♭13. Fifthless
        major-family Lydian stacks with a supporting ninth (D♭maj9♯11)
        and the harmonic-minor m(maj7)♭13 idiom are exempt, as are
        minor-third flat-five hosts like Em7(♭5,♭13), whose flat five
        already occupies the slot.
      </td>
    </tr>
    <tr>
      <td>Missing essential tone</td>
      <td class="neg mono">0.5&ndash;1.7</td>
      <td>
        By the degree it would fill: a perfect fifth is routinely
        dropped (0.5), but a chord without its third (1.7), seventh
        (0.75), suspension (1.4), or defining altered fifth (0.9) is
        barely that chord. At most one may be missing.
      </td>
    </tr>
    <tr>
      <td>Implied root (Ensemble mode)</td>
      <td class="neg mono">0.25</td>
      <td>
        Another instrument may supply the root. Only constrained
        rootless candidates qualify, and their played bass carries no
        inversion cost.
      </td>
    </tr>
    <tr>
      <td>Unexplained tone</td>
      <td class="neg mono">2.0</td>
      <td>A sounding pitch the name cannot account for at all</td>
    </tr>
    <tr>
      <td>Bass placement</td>
      <td class="neg mono">0&ndash;1.0</td>
      <td>
        Root free; conventional inversion 0.15; integrated extension
        0.3; altered fifth 0.3; altered color 0.5; bare add tone 0.65;
        suspended tone 0.7; unexplained 1.0. Diminished and augmented
        chords invert freely, so their fifth in the bass counts as a
        plain core tone rather than an altered fifth. A complete plain
        triad over its added-ninth bass (the D/E idiom) is treated as
        an upper-structure pedal instead.
      </td>
    </tr>
    <tr>
      <td>Bare fifthless sixth chord</td>
      <td class="neg mono">0.45</td>
      <td>
        A three-tone root-third-sixth set is better read as the
        relative minor's triad (C-E-A as Am/C, not C6)
      </td>
    </tr>
  </tbody>
</table>

This input-centric accounting replaced an earlier template-centric cost model
that rewarded each matched template slot and normalized by template size. That
formulation systematically favored rare four-tone templates that booked every
sounding note as a required tone over more common readings that treat one note
as color, and it took a dozen hand-tuned counterweight bonuses to fight the
bias. Pricing the input directly removes the bias at the source: a rare name can
still win, but only when it explains the voicing decisively more cheaply than
any common name.

## Extension extraction

During template pricing, any tone not accounted for by the base template
(required + optional + penalty) lands in the "extras" mask. A few
context-specific penalty tones can be moved into that extras mask first when
they function as chord color instead of true contradictions. These get converted
to named extensions in the final chord identity, each priced by its role as
described above:

- **Alterations** (from the extras mask): flat 9 (semitone 1), sharp 9 (semitone
  3), sharp 11 (semitone 6), flat 13 (semitone 8)
- **Split-third add tone:** add sharp 9 (semitone 3) when a major-family triad
  already contains its major third
- **Natural extensions:** 9 (semitone 2), 11 (semitone 5), 13 (semitone 9)

Whether natural extensions become "9/11/13" or "add9/add11/add13" depends on
whether the chord has a 7th. With a 7th present, a 9, 11, or 13 reads as a
stacked extension regardless of which lower stack members are also sounding,
matching [common chord-symbol practice](chord-symbols.html) where the inner
extensions are freely omitted. Without a 7th, the same pitch class is labeled as
an add tone instead, with one hard exception: a bare major or minor triad plus a
major sixth is a sixth chord (C6, Cm6), so its add13 relabeling is rejected
outright rather than merely priced higher. The rejection spares the case where
the sixth is the bass, since the add13 label folds into the slash and the
reading survives as the conventional triad-over-sixth-bass symbol (A-C-E as
C/A).

Interval 3 is normally a minor third, but the analyzer allows a few narrow
musical exceptions where that pitch clearly functions as sharp-nine color
instead: dominant 7th shells with ♯9 color, plain major seventh chords with both
the major third and major seventh present, and major-family split-third
voicings. These exceptions keep common blues, altered-dominant sounds, and
explicit altered major-seventh colors from being misread as contradictions.

## How the prices were tuned

The prices were not established arbitrarily. They started as musician-judged
priors, were calibrated offline against a pool of every distinct 3–7 note
pitch-class set, and were then tuned against a set of golden test cases:
specific voicings where the expected output was chosen in advance. Most golden
cases capture chords a musician would name unambiguously; ambiguous cases pin
the intended primary reading for the current cost and ranking model.

The test suite covers major, minor, diminished, dominant, altered, and extended
voicings across different inversions and ambiguous situations. The tuning loop
looked like this:

1. Run the golden test suite.
2. For any case that failed, use the `chord-debug` CLI tool to inspect the full
   ranked candidate list with cost breakdowns.
3. Adjust prices or rules until the failing case passed.
4. Re-run the full suite to verify no regressions.

The `chord-debug` tool runs the full analysis pipeline on any set of notes and
prints each candidate with its cost, individual cost contributions, and the
ranking rule that decided its position relative to the previous candidate:

<pre><code>$ dart run tool/chord_debug.dart F# Bb C E

notes: F♯ B♭ C E  |  bass: F♯ (pc 6)  |  key: C major

 1) F♯7♭5          0.40
     members: root=F♯  major3=A♯  flat5=C  flat7=E
     cost: vocab+0.40

 2) C7♭5/G♭        0.70  Δ +0.30
     (vs prev: cost difference beyond tie-break range)
     members: root=C  major3=E  flat5=G♭  flat7=B♭
     cost: vocab+0.40  bass+0.30

 3) F♯7♯11         1.30  Δ +0.90
     (vs prev: cost difference beyond tie-break range)</code></pre>

The same diagnostic output also exposes
[enharmonic](https://en.wikipedia.org/wiki/Enharmonic_equivalence) spelling
decisions: MIDI provides pitch classes, and the engine chooses note names from
the winning chord context.

That kind of diagnostic visibility was essential for understanding why the
algorithm chose wrong answers and what needed to change. A weight that fixed one
case would sometimes break another, and the only way to make progress without
regressing was to have the full ranked list visible while making targeted
adjustments.

## The ranking problem

The debug output above shows why raw cost is only the first half of the problem.
Once multiple readings are plausible, the analysis engine needs a separate
ranking layer that encodes musical priorities more directly than a single
numeric cost can.

This is not an isolated case. Several common note sets produce near-identical
costs for multiple plausible interpretations, and the cost alone cannot
distinguish which one a musician would name:

- C-E-G-A: <span class="chord">C6</span> vs. <span class="chord">Am7/C</span>
  (identical costs; which reading wins depends on context and function)
- B-E-G with B in the bass: <span class="chord">Em/B</span> vs.
  <span class="chord">G6/B</span> (the complete triad should beat an inverted
  6th-chord spelling whose fifth is absent)
- B-D-F-A♭: <span class="chord">Bdim7</span> vs.
  <span class="chord">G♯dim7/B</span> vs. <span class="chord">Ddim7/C♭</span>
  vs. <span class="chord">Fdim7/C♭</span> (C♭ = B enharmonically; all four
  readings cost identically due to dim7 symmetry)

The analyzer handles these ambiguities with two ranking paths: narrow structural
overrides for cases where the conventional name should win despite cost, and
ordered tie-breakers for candidates whose costs are already close.

### Hard rules

Hard rules are intentionally narrow guardrails for known failure modes in the
cost model. They only fire when a pitch-class-valid but misleading
interpretation looks cheaper than the name musicians would normally expect. Each
rule is documented in code with the concrete voicing that motivated it, and
covered by focused ranking tests so the exception stays bounded.

### The near-tie window

The ordered list below applies only after those hard rules have had a chance to
run. If none of them fire and the cost difference is greater than `0.25` (the
`nearTieWindow` constant), the lower-cost candidate wins on cost alone.

When costs are within the near-tie window, tie-breaker rules are applied
sequentially. The first rule that produces a non-tie result decides the
ordering:

The displayed alternatives use the same cost window as a lower bound, then
include every ranked candidate through the last cost-window match. This keeps
hard-rule ordering coherent when a higher-ranked candidate sits just outside the
raw numeric window.

1. Prefer a voicing-supported upper-structure slash: a complete chord stacked
   above an isolated bass note, when the input carries real octaves
2. Prefer the key-functional seventh over its sixth-chord twin: a supertonic
   minor 7th, a leading-tone half-diminished 7th, or (in minor keys) a
   supertonic half-diminished 7th beats the sixth chord sharing its notes
3. Prefer the dominant among tied implied-root candidates (Ensemble mode), where
   the guide tones and colors support dominant vocabulary more strongly than a
   tonic-family reading
4. Prefer root-position 6th over inverted 7th
5. Prefer a complete triad over an incomplete 6th chord missing its fifth
6. Prefer upper-structure dominant 7th slash
7. Prefer major-seventh upper-structure sus slash
8. Prefer root-position dominant sus, including flat-nine sus colors, over
   remote slash reinterpretations
9. Prefer flat-nine-bass dominant shells over remote minor-major or diminished
   reinterpretations
10. Prefer the cleaner-spelled reading of tritone-twin extended dominants (C7alt
    vs G♭(9,♯11) shapes), unless one side is a complete natural-thirteenth stack
11. Prefer stable extended dominant inversions over altered-fifth dominant slash
12. Prefer a complete altered dominant thirteenth over an altered
    minor-thirteenth reading with rarer color
13. Prefer a complete flat-nine flat-thirteen dominant over a remote diminished
    or seventh-family spelling
14. Prefer complete major-triad ♯11 inversions over sparse major-13-sus4
    spellings
15. Prefer a complete major-triad inversion over a seventh-family chord where
    the bass is only an add-extension
16. Prefer root-position diminished 7th
17. Prefer dominant 7th slash over non-dominant seventh-family slash
18. Prefer a reading that names every tone over one that drops a tone, unless
    that would promote rarer altered bookkeeping above a lower-cost idiomatic
    shell
19. Prefer a lower-cost add-chord reading over an unusual seventh-family
    spelling that omits the third
20. Prefer a harmonic-minor tonic over a split-third major-triad inversion
21. Prefer a lower-cost major-seventh-bass inversion over a slash reading where
    the bass is only a remote color tone
22. Prefer fewer altered/tension colors
23. Prefer diatonic chords
24. Prefer a root-position relative-minor seventh over the equivalent
    major-sixth slash reading
25. Prefer the tonic chord
26. Prefer a complete triad with add-tone extensions over an unusual or sparse
    seventh-family reading that turns the same pitches into remote color
27. Prefer natural extensions (9/11/13) over add-tones, then fewer overall,
    unless that would reward an incomplete slash chord
28. Prefer root position
29. Prefer the more common name when the corpus shows a strong preference
    between otherwise equivalent spellings
30. Prefer cleaner spelling for otherwise tied tritone-related flat-five
    dominant readings
31. Prefer more conventional inversion, based on the bass tone's named role in
    the candidate rather than its raw interval alone
32. Prefer 7th chords over triads when both fit and the seventh is actually
    sounding, unless the seventh-family spelling is a suspended slash label with
    no third competing against a complete sixth-chord reading
33. Prefer fewer extensions
34. Avoid suspended chords
35. Prefer the reading whose members spell more cleanly in context

If all of these rules still have not produced a winner, there is a deterministic
fallback: sort by root pitch class numerically. This ensures the output is
always consistent for the same input, even for exotic voicings.

The ordering of these rules encodes musical priorities. Structural clarity (root
position, shell tones) comes before contextual preferences (diatonic, tonic).
Conventional naming (fewer alterations, natural extensions, and common corpus
labels) comes before complexity. Suspended chords are deprioritized late because
they are valid but easy to over-detect when a third is absent, so they should
win only when the surrounding evidence supports them.

### Turning the comparison into a stable order

Because hard rules and the near-tie window deliberately override raw cost, the
candidate comparison is not guaranteed to be transitive: A can beat B, B can
beat C, and yet C can beat A. A generic sort is undefined on a comparison like
that and can bury a strong reading below a weaker one.

So the engine linearizes the candidates rather than sorting them directly: it
repeatedly takes the one that nothing else outranks, breaking any cycle in a
fixed, repeatable way. The result honors every rule above and always produces
the same order for a given input.

That linearization is not free. To know which candidate nothing else outranks,
the engine has to compare every candidate against every other, which is
quadratic in the candidate count and dominates uncached analysis time. The
[ranking-performance deep dive](chord-ranking-performance.html) covers the
measurement, dead ends, and pruning work in detail.

## Ensemble mode

A pianist comping over a bassist might play <span class="chord">E-B♭-D-A</span>
to mean <span class="chord">C13</span>: the third, seventh, ninth, and
thirteenth of the chord while leaving C to the bass player. Ensemble mode
represents C as an implied root even though it is absent from the keyboard
voicing.

Pitch content alone cannot reveal whether a root was intentionally omitted:
<span class="chord">C-E-G</span>, for example, is both a complete
<span class="chord">C</span> triad and a rootless
<span class="chord">Am7</span>. The playing mode therefore makes the assumption
explicit. Solo mode expects the keyboard part to include the root; Ensemble mode
allows another part to provide it.

In Ensemble mode, candidate generation runs an additional pass over absent pitch
classes. An implied-root candidate qualifies only when:

- Its quality is dominant 7th, major 7th, minor 7th, minor-major 7th, or
  half-diminished 7th. Fully diminished 7th is excluded because its symmetry
  leaves four equally valid roots.
- Every required tone except the root sounds, and the chord name explains every
  sounding tone.

Any absent pitch class can serve as the implied root, whether or not it belongs
to the current key; key preference is a ranking concern, not a generation
filter. One pair gets an explicit ranking rule: a rootless half-diminished 7th
contains exactly the same notes as the rootless major 7th one semitone below it,
and when only one of the two candidate roots belongs to the key, that reading
wins.

An implied root adds `0.25` to the explanation cost. Bass placement is free for
these readings because the lowest keyboard note is expected to be a guide tone
or color rather than the chord root.

Ranking gives an idiomatic implied-root reading priority over sounding-root
alternatives; otherwise a complete upper-structure chord would usually win on
cost. Altered extensions on a non-dominant implied chord do not receive this
priority and compete on cost instead. An implied root from outside the key
receives it only when the reading's extensions are plain (a natural 9, 11, or
13), because every complete dominant 7th also matches a rootless dominant a
tritone away whose reading needs sharpened and flattened extensions; the
plain-extension requirement rejects those re-readings. If two implied-root
readings remain in a near tie, the dominant-family reading wins.

The result uses the plain chord symbol with a "rootless" tag, not a slash chord:
<span class="chord">E-B♭-D-A</span> appears as <span class="chord">C13</span>,
not <span class="chord">C13/E</span>. The tone breakdown marks C as implied, and
the keyboard draws the nearest matching C below the played bass as a hollow key.

## Caching for real-time performance

Running the full pipeline on every MIDI state change would be wasteful. Each
sounding root is evaluated against 27 templates, and Ensemble mode adds its
eligible implied-root evaluations. In practice, a pianist produces many repeated
input states throughout a piece.

The engine uses a 512-entry Least Recently Used (LRU) cache implemented as a
[`LinkedHashMap`](https://api.dart.dev/dart-collection/LinkedHashMap-class.html).
The cache key is a hash of four inputs:

- The pitch class set and bass note
- The analysis context (key signature, tonality, and playing mode)
- The observed voicing's register signature, when one is supplied, because
  register evidence can nudge the ranking
- The `take` parameter (how many candidates to return, default 5)

The context is included because the key and playing mode can both change which
candidate ranks first for the same notes. Solo and Ensemble analyses therefore
never alias to one cached result.

<pre><code><span class="kw">final</span> key = Object.<span class="fn">hash</span>(input.cacheKey, voicing?.signature ?? <span class="nu">0</span>, context, take);
<span class="kw">final</span> cached = _cache[key];
<span class="kw">if</span> (cached != <span class="kw">null</span>) {
  <span class="cm">// Promote on hit so eviction removes LRU, not FIFO</span>
  _cache
    ..<span class="fn">remove</span>(key)
    ..[key] = cached;
  <span class="kw">return</span> cached;
}</code></pre>

The LinkedHashMap preserves insertion order. On a cache hit, the entry is
removed and re-inserted at the end (most recently used). On eviction, the first
key is removed (least recently used). This is the standard LRU pattern in Dart
without a separate doubly-linked list.

The 512-entry capacity was chosen from benchmarks across random inputs,
exhaustive inputs, tonal progressions, and simulated live note transitions.
Realistic playing showed high reuse, and larger caches produced no material
improvement.

## Where the key in the context comes from

The analysis context carries a key, and several ranking rules lean on it:
preferring diatonic chords, preferring the tonic, choosing between a
half-diminished 7th and the major 7th a semitone below. That key can be set by
hand, but by default it is
[inferred live from the chords you have been playing](key-detection-algorithm.html)
and written back into the context. So the analyzer itself is memoryless, while
the context it runs against is not: temporal information reaches chord naming
through the key, and only through the key.

That routing is deliberate. Feeding the previous chord into ranking directly was
measured against a baseline that already knew the key, and it added nothing: the
key carries essentially everything the recent past has to offer.

## What the algorithm does not handle

A few things are known limitations or non-goals:

- **Static polychord lookup.** The snapshot analyzer still finds the best
  single-chord description of a combined note set. During live timestamped MIDI,
  a separate conservative layer can add a secondary stacked polychord annotation
  when two complete chordal groups have clearly separated attacks. It does not
  infer unfolding or overlapping-register constructions such as Stravinsky's
  [Petrushka chord](https://en.wikipedia.org/wiki/Petrushka_chord) from a static
  note set.
- **Non-12-TET tuning.** This engine is built around 12 pitch classes and
  standard MIDI note numbers. Microtonal intervals, quarter tones, and
  [just-intonation](https://en.wikipedia.org/wiki/Just_intonation) distinctions
  have no representation in this model.

The cost heuristics are tuned from experience. They encode accumulated musical
convention, but they are adjustable constants, not proven axioms. Edge cases and
counterexamples help improve them.

## The codebase

The analysis engine is written in [Dart](https://dart.dev/) and lives in
[`packages/whatchord/`](https://github.com/EarthmanMuons/whatchord/tree/main/packages/whatchord),
a standalone package with no framework dependencies; only the app around it is
[Flutter](https://flutter.dev/). It carries a unit test suite that verifies
known-correct outputs across major, minor, dominant, altered, extended, and
ambiguous chord types.

The project is open source and released under the Zero Clause BSD License, which
means you are free to use, modify, and share the code however you like.

If you find a misidentified chord, the best way to report it is to long-press
the chord card to open _Analysis Details_, copy the diagnostic output, and
[open a GitHub issue](https://github.com/EarthmanMuons/whatchord/issues/new/choose).
The diagnostic output includes the exact pitch classes and context that produced
the result, which makes it straightforward to reproduce and debug.

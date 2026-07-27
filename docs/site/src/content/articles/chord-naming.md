---
cardDescription:
  "How to move from notes to a chord name using default interval qualities,
  degree formulas, spelling, and candidate roots."
cardTitle: "Chord Naming Guide"
decks:
  - "A chord name is a compact explanation of how a set of notes behaves: which
    note is the root, which intervals define the quality, which tones are
    extensions or alterations, and whether the bass needs slash notation. It is
    not a prescription for exactly how to voice the chord; it names the harmonic
    identity those notes suggest."
  - 'This guide works through chord naming by hand, moving from a raw set of
    notes to the name that fits them. It is the companion to the <a
    href="chord-symbols.html">Chord Symbol Guide</a>, which documents how
    WhatChord formats the final symbol once the name has been chosen.'
description:
  "A practical guide to naming chords: default interval qualities, tertian
  stacks, enharmonic spelling, candidate roots, and how WhatChord chooses a
  readable chord symbol."
group: "musicians"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 1
pageTitle: "How to Name Chords | WhatChord"
related:
  - "why-chord-naming-is-hard"
  - "chord-symbols"
  - "scale-degrees"
socialDescription:
  "How to move from a set of notes to a readable chord name using default
  interval qualities, tertian stacks, spelling, and candidate roots."
socialTitle: "How to Name Chords"
tag: "Reference"
title: "Chord Naming Guide"
---

<h2>The Basic Idea</h2>

<p>
  Most chord symbols start from a
  <a href="https://en.wikipedia.org/wiki/Tertian">stack of thirds</a>.
  Pick a candidate root, then lay out the chord-member letter names
  above it:
</p>

<div class="member-stack-scroll">
  <table class="member-stack">
    <caption>
      Tertian Slots Above C
    </caption>
    <tbody>
      <tr>
        <th scope="row">Note names</th>
        <td>C</td>
        <td>E</td>
        <td>G</td>
        <td>B</td>
        <td>D</td>
        <td>F</td>
        <td>A</td>
      </tr>
      <tr>
        <th scope="row">Degree numbers</th>
        <td>1</td>
        <td>3</td>
        <td>5</td>
        <td>7</td>
        <td>9</td>
        <td>11</td>
        <td>13</td>
      </tr>
    </tbody>
  </table>
</div>

<p>
  The numbers do not describe register. In chord-symbol language, a D
  right next to middle C and a D two octaves higher are both the ninth
  above C. The stack is a naming map: each letter slot has a default
  quality, and the actual note either matches that default or alters
  it.
</p>

<h2>Default Interval Qualities</h2>

<p>
  The plain degree numbers in the stack name the positions: third,
  fifth, seventh, ninth, and so on. They do not by themselves tell you
  the final accidental. The note letter comes from the position in the
  stack, and the interval quality tells you whether that letter is
  natural, lowered, or raised.
</p>

<p>
  Above C, for example, the seventh slot is always some kind of B. B
  is the major seventh, B♭ is the minor seventh, and B𝄫 is the
  diminished seventh. It does not become A just because it has been
  lowered; changing the letter would move it into a different slot.
</p>

<p>Chord symbols have defaults for those interval qualities.</p>

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Chord member</th>
      <th scope="col">Default above C</th>
      <th scope="col">Lowered</th>
      <th scope="col">Raised</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>3rd</td>
      <td>E, major</td>
      <td>E♭, minor (<code>m</code>)</td>
      <td>E♯, <span class="unused">augmented</span><sup>*</sup></td>
    </tr>
    <tr>
      <td>5th</td>
      <td>G, perfect</td>
      <td>G♭, diminished (<code>♭5</code>, <code>dim</code>)</td>
      <td>G♯, augmented (<code>♯5</code>, <code>aug</code>)</td>
    </tr>
    <tr>
      <td>7th</td>
      <td>B♭, minor (<code>7</code>)</td>
      <td>B𝄫, diminished (<code>dim7</code>)</td>
      <td>B, major (<code>maj7</code>)</td>
    </tr>
    <tr>
      <td>9th</td>
      <td>D, major</td>
      <td>D♭, minor (<code>♭9</code>)</td>
      <td>D♯, augmented (<code>♯9</code>)</td>
    </tr>
    <tr>
      <td>11th</td>
      <td>F, perfect</td>
      <td>F♭, <span class="unused">diminished</span><sup>*</sup></td>
      <td>F♯, augmented (<code>♯11</code>)</td>
    </tr>
    <tr>
      <td>13th</td>
      <td>A, major</td>
      <td>A♭, minor (<code>♭13</code>)</td>
      <td>A♯, <span class="unused">augmented</span><sup>*</sup></td>
    </tr>
  </tbody>
</table>

<p class="article-table-note">
  <span class="fn-mark">*</span> Chord symbols never use these three
  qualities. Each is enharmonically a plainer chord member, so the
  simpler spelling always wins: a raised 3rd (E♯) is the perfect 11th
  (F), a lowered 11th (F♭) is the major 3rd (E), and a raised 13th
  (A♯) is the minor 7th (B♭).
</p>

<p>
  The third is major by default, unless <code>m</code> makes it minor.
  The fifth and eleventh are perfect by default, unless altered. Every
  default here matches the major scale except the seventh: the bare
  <code>7</code> means the lowered, minor seventh, so
  <span class="chord">C7</span> is C-E-G-B♭, not C-E-G-B. The word
  <code>maj</code> changes only that seventh, so
  <span class="chord">Cmaj7</span> means C-E-G-B, while
  <span class="chord">Cm7</span> changes the third to E♭ but leaves
  the seventh at its default B♭.
</p>

<p>
  Diminished and augmented are interval qualities too. A diminished
  interval is one semitone smaller than minor or perfect. An augmented
  interval is one semitone larger than major or perfect. Chord labels
  use those interval qualities as shortcuts:
  <span class="chord">Cdim</span> means a minor third plus a
  diminished fifth, C-E♭-G♭. <span class="chord">Cdim7</span> adds a
  diminished seventh, B𝄫. A half-diminished seventh chord,
  <span class="chord">Cm7(♭5)</span>, keeps the default minor seventh
  and lowers only the fifth. <span class="chord">Caug</span> means an
  augmented triad: C-E-G♯.
</p>

<h2 id="from-degrees-to-quality-names">
  From Degrees to Quality Names
</h2>

<p>
  Once the notes are mapped to degree numbers, the chord quality comes
  from the pattern those degrees make. A few common patterns do most
  of the work:
</p>

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Quality</th>
      <th scope="col">Degree formula</th>
      <th scope="col">Example on C</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Major triad</td>
      <td><code>1, 3, 5</code></td>
      <td><span class="chord">C</span> = C-E-G</td>
    </tr>
    <tr>
      <td>Minor triad</td>
      <td><code>1, ♭3, 5</code></td>
      <td><span class="chord">Cm</span> = C-E♭-G</td>
    </tr>
    <tr>
      <td>Diminished triad</td>
      <td><code>1, ♭3, ♭5</code></td>
      <td><span class="chord">Cdim</span> = C-E♭-G♭</td>
    </tr>
    <tr>
      <td>Augmented triad</td>
      <td><code>1, 3, ♯5</code></td>
      <td><span class="chord">Caug</span> = C-E-G♯</td>
    </tr>
    <tr>
      <td>Dominant seventh</td>
      <td><code>1, 3, 5, ♭7</code></td>
      <td><span class="chord">C7</span> = C-E-G-B♭</td>
    </tr>
    <tr>
      <td>Major seventh</td>
      <td><code>1, 3, 5, 7</code></td>
      <td><span class="chord">Cmaj7</span> = C-E-G-B</td>
    </tr>
    <tr>
      <td>Minor seventh</td>
      <td><code>1, ♭3, 5, ♭7</code></td>
      <td><span class="chord">Cm7</span> = C-E♭-G-B♭</td>
    </tr>
    <tr>
      <td>Half-diminished seventh</td>
      <td><code>1, ♭3, ♭5, ♭7</code></td>
      <td><span class="chord">Cm7(♭5)</span> = C-E♭-G♭-B♭</td>
    </tr>
    <tr>
      <td>Fully diminished seventh</td>
      <td><code>1, ♭3, ♭5, 𝄫7</code></td>
      <td><span class="chord">Cdim7</span> = C-E♭-G♭-B𝄫</td>
    </tr>
    <tr>
      <td>Dominant ninth</td>
      <td><code>1, 3, 5, ♭7, 9</code></td>
      <td><span class="chord">C9</span> = C-E-G-B♭-D</td>
    </tr>
    <tr>
      <td>Added ninth</td>
      <td><code>1, 3, 5, 9</code></td>
      <td><span class="chord">Cadd9</span> = C-E-G-D</td>
    </tr>
  </tbody>
</table>

<h2>Extensions vs. Added Tones</h2>

<p>
  A seventh turns upper notes into extensions. With the seventh
  present, D above C is a ninth, F is an eleventh, and A is a
  thirteenth. Without the seventh, those same notes are added tones or
  sixths:
  <span class="chord">C9</span> includes B♭, while
  <span class="chord">Cadd9</span> does not.
</p>

<p>
  The thirteenth has one common naming exception. If there is no
  seventh, an A above C is written as a sixth:
  <span class="chord">C6</span>. Add the seventh and that same chord
  member becomes a thirteenth: <span class="chord">C13</span>.
</p>

<h2>Slash Bass</h2>

<p>
  The bass note is the lowest sounding note. When the bass is not the
  root of the chord name, chord symbols write it after a slash:
  <span class="chord">C9 / E</span> means C dominant ninth with E in
  the bass. The slash note is not a second chord, and it does not
  change the root. It only tells the player what note is underneath
  the chord.
</p>

<p>
  If the bass is already the root, no slash note is needed. A C
  dominant ninth with C in the bass is simply
  <span class="chord">C9</span>, not
  <span class="chord not-used">C9 / C</span>.
</p>

<h2>How to Name a Chord</h2>

<p>A practical naming pass looks like this:</p>

<ol>
  <li>
    List the sounding
    <a href="https://en.wikipedia.org/wiki/Pitch_class"
      >pitch classes</a
    >
    and the bass note. Ignore doublings, but keep the lowest note for
    slash-bass decisions.
  </li>
  <li>
    Try candidate roots. Usually those are notes already present in
    the chord, plus obvious enharmonic spellings when they make the
    tertian stack cleaner.
  </li>
  <li>
    For each root, write the
    <code>1, 3, 5, 7, 9, 11, 13</code> letter stack.
  </li>
  <li>
    Place each sounding note into its letter slot, respelling
    enharmonically when the chord function demands it.
  </li>
  <li>
    Prefer names with a clear triad or seventh-chord base, fewer
    awkward alterations, and no unnecessary slash bass.
  </li>
</ol>

<p>
  The result is not always unique. Some pitch sets really do have
  several good names, and musical context may decide between them. But
  this process gives you a disciplined way to find the names that are
  musically defensible before choosing the most readable one.
</p>

<h2>Worked Example</h2>

<p>
  Suppose the sounding notes are C-E-G-B♭-D, with C in the bass. The
  goal is to work from the notes toward a name, not to assume the name
  first. C is a good root to test because it is in the bass, and the
  notes above it include the familiar C-E-G shape.
</p>

<p>Start by stacking thirds above C through the ninth:</p>

<div class="member-stack-scroll">
  <table class="member-stack">
    <caption>
      Tertian Slots Above C
    </caption>
    <tbody>
      <tr>
        <th scope="row">Note names</th>
        <td>C</td>
        <td>E</td>
        <td>G</td>
        <td>B</td>
        <td>D</td>
      </tr>
      <tr>
        <th scope="row">Degree numbers</th>
        <td>1</td>
        <td>3</td>
        <td>5</td>
        <td>7</td>
        <td>9</td>
      </tr>
    </tbody>
  </table>
</div>

<p>
  Now compare the sounding notes to those slots. C-E-G gives a major
  triad because the third is E, not E♭. The seventh slot above C is
  some kind of B; the sounding note is B♭, which is the default minor
  seventh. A major triad plus the default minor seventh is written
  <span class="chord">C7</span>, not <span class="chord">Cm7</span>,
  because nothing has made the third minor. D is in the ninth slot.
  Because the seventh is present, that D is an extension rather than
  an added tone.
</p>

<div class="member-stack-scroll">
  <table class="member-stack">
    <caption>
      Sounding Notes Interpreted Above C
    </caption>
    <tbody>
      <tr>
        <th scope="row">Note names</th>
        <td>C</td>
        <td>E</td>
        <td>G</td>
        <td>B♭</td>
        <td>D</td>
      </tr>
      <tr>
        <th scope="row">Degree numbers</th>
        <td>1</td>
        <td>3</td>
        <td>5</td>
        <td>♭7</td>
        <td>9</td>
      </tr>
    </tbody>
  </table>
</div>

<p>
  That points to <span class="chord">C9</span>: the seventh is
  present, so it is not <span class="chord">Cadd9</span>, and the bass
  is C, so no slash note is needed. Before committing to it, though, a
  thorough pass should weigh the other roots.
</p>

<h2>Trying Other Roots</h2>

<p>
  For this note set, the candidate roots are the notes that are
  actually sounding: C-E-G-B♭-D.
</p>

<p>
  Try E next. The letter stack above E is E-G-B-D-F-A-C. The sounding
  notes then map as E-G-B♭-D-C:
</p>

<div class="member-stack-scroll">
  <table class="member-stack">
    <caption>
      Sounding Notes Interpreted Above E
    </caption>
    <tbody>
      <tr>
        <th scope="row">Note names</th>
        <td>E</td>
        <td>G</td>
        <td>B♭</td>
        <td>D</td>
        <td>C</td>
      </tr>
      <tr>
        <th scope="row">Degree numbers</th>
        <td>1</td>
        <td>♭3</td>
        <td>♭5</td>
        <td>♭7</td>
        <td>♭13</td>
      </tr>
    </tbody>
  </table>
</div>

<p>
  That gives an E half-diminished seventh shape:
  <code>1, ♭3, ♭5, ♭7</code>. The remaining C is the lowered
  thirteenth above E, and it is also the bass, so the full name spells
  out both facts: <span class="chord">Em7(♭5,♭13) / C</span>. That is
  valid, but it is already more complex than the C-rooted name: it
  needs an altered fifth, an altered thirteenth, and slash bass, while
  the C reading gave a direct dominant ninth.
</p>

<p>
  Doing the same check for each sounding note gives this comparison:
</p>

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Root tested</th>
      <th scope="col">Note names in stack order</th>
      <th scope="col">Degree numbers</th>
      <th scope="col">Candidate name</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>C</td>
      <td>C-E-G-B♭-D</td>
      <td><code>1, 3, 5, ♭7, 9</code></td>
      <td><span class="chord">C9</span></td>
    </tr>
    <tr>
      <td>E</td>
      <td>E-G-B♭-D-C</td>
      <td><code>1, ♭3, ♭5, ♭7, ♭13</code></td>
      <td><span class="chord">Em7(♭5,♭13) / C</span></td>
    </tr>
    <tr>
      <td>G</td>
      <td>G-B♭-D-C-E</td>
      <td><code>1, ♭3, 5, 11, 13</code></td>
      <td><span class="chord">Gm6 / C</span></td>
    </tr>
    <tr>
      <td>B♭</td>
      <td>B♭-D-C-E-G</td>
      <td><code>1, 3, 9, ♯11, 13</code></td>
      <td><span class="chord">B♭6♯11 / C</span></td>
    </tr>
    <tr>
      <td>D</td>
      <td>D-C-E-G-B♭</td>
      <td><code>1, ♭7, 9, 11, ♭13</code></td>
      <td><span class="chord">D9sus4(♭13) / C</span></td>
    </tr>
  </tbody>
</table>

<p>
  Those names are not equally useful. The C reading has a complete,
  familiar base chord: <code>1, 3, 5, ♭7</code>, then one ordinary
  ninth. The alternatives need more explanation: they lack a complete
  triad or seventh-chord base, depend on several upper extensions or
  altered degrees, or require slash bass to account for C underneath
  them.
</p>

<p>
  The C reading wins because it has the strongest base chord, the bass
  is the root, and the remaining note has a standard name as a ninth.
  Deciding which reading is “best” can still be tricky, especially in
  real music where context matters, but this is the kind of comparison
  that makes one option much easier to justify than the others.
</p>

<h2>Why Spelling Matters</h2>

<p>
  The spelling is not cosmetic. In this example, B♭ is the seventh
  above C. Spelling the same physical piano key as A♯ would make it
  look like some kind of altered sixth instead of the chord’s seventh.
  Both spellings represent the same pitch class, but chord symbols use
  <a href="why-chord-naming-is-hard.html#enharmonic-spelling"
    >enharmonic spelling</a
  >
  to show function, not just keys on the instrument.
</p>

<h2>How WhatChord Uses This Idea</h2>

<p>
  WhatChord evaluates candidate roots and qualities in software rather
  than by hand. It assigns each candidate an explanation cost based on
  musical fit: stable triads and seventh chords, sensible extensions,
  spelling that fits the chord member, and bass relationships that
  musicians expect to read. Close alternatives can still appear when
  the notes genuinely support more than one interpretation.
</p>

<p>
  The app asks the same questions a player asks: What is the root?
  What is the base quality? Which notes are extensions or alterations?
  Is the bass part of the chord or a slash note? Which spelling makes
  the stack readable?
</p>

<p>
  For the implementation details behind those costs, see
  <a href="chord-recognition-algorithm.html"
    >Building a Real-Time Chord Recognizer</a
  >.
</p>

<h2>Acknowledgements</h2>

<p>
  This guide was inspired in part by discussion with
  <a href="https://www.reddit.com/user/MaggaraMarine"
    >u/MaggaraMarine</a
  >, who pointed toward clarifying default interval qualities behind
  chord symbols, and
  <a href="https://www.reddit.com/user/65TwinReverbRI"
    >u/65TwinReverbRI</a
  >, whose examples helped motivate the focus on tertian spelling and
  systematic root checking.
</p>

<div class="article-cta">
  <h3>Try the process on your own notes.</h3>
  <p>
    Enter any notes and WhatChord identifies the strongest chord
    names, including close alternatives when the voicing is genuinely
    ambiguous.
  </p>
  <a class="btn btn-primary" href="/try">Try it in your browser →</a>
</div>

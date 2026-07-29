---
cardDescription:
  "The inversions, extensions, altered tones, and enharmonic ambiguities behind
  real chord recognition, and how WhatChord handles them."
cardTitle: "Why Chord Naming Is Harder Than It Looks"
decks:
  - "Inversions, extensions, altered tones, and enharmonic ambiguities make real
    chord recognition a hard musical problem. Here is how WhatChord handles
    them."
description:
  "The inversions, extensions, altered tones, and enharmonic ambiguities that
  make real chord recognition a hard musical problem."
featuredDescription:
  "The inversions, extensions, altered tones, and enharmonic ambiguities behind
  real chord recognition, and how WhatChord handles them."
featuredOrder: 0
group: "musicians"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 0
pageTitle: "Why Chord Naming Is Harder Than It Looks | WhatChord"
related:
  - "chord-naming"
  - "chord-symbols"
  - "scale-degrees"
socialDescription:
  "The musical ambiguities that make automated chord recognition a hard problem,
  and what WhatChord does about them."
socialTitle: "Why Chord Naming Is Harder Than It Looks"
tag: "For musicians"
title: "Why Chord Naming Is Harder Than It Looks"
---

## It starts with a deceptively simple question

You press four notes on a keyboard. A computer reads four numbers. What chord is
it?

The instinct is to say: look it up in a table. C major is C-E-G. Done. But that
instinct breaks down quickly when you sit down with a real piece of music, even
something straightforward, and start paying attention to what you are actually
hearing versus what the notes technically spell out.

Chord naming is musical interpretation, not pattern matching. The same set of
notes can legitimately be described in several different ways, and musicians
resolve this ambiguity constantly through context, convention, and
[voice-leading](https://en.wikipedia.org/wiki/Voice_leading) intuition. Teaching
that intuition to a computer requires encoding a surprising amount of musical
knowledge.

## The same notes, different chords

Start with a simple example. Play the notes C-E♭-G♭-A together. What chord is
that?

It is a
[fully diminished 7th chord](https://en.wikipedia.org/wiki/Diminished_seventh_chord).
That much is clear from the interval structure: four notes, each a minor third
apart, stacking perfectly up the octave. But here is the catch: fully diminished
7th chords are _symmetrical_. Every voicing of this chord divides the octave
into four equal parts. That means the same four piano keys can support four
different diminished-7th readings.

<div class="callout">
  <p>
    <strong>Cdim7</strong> = C-E♭-G♭-B♭♭<br />
    <strong>Adim7/C</strong> = A-C-E♭-G♭<br />
    <strong>D♯dim7/C</strong> = D♯-F♯-A-C<br />
    <strong>F♯dim7/C</strong> = F♯-A-C-E♭
  </p>
</div>

So which name is "right"? Without tonal context, none of the four spellings is
automatically more correct than the others. They are enharmonic descriptions of
identical piano keys, and the right answer depends on musical context: what key
you are in, what chord came before, which note is functioning as the bass, and
where the progression is heading.

The app resolves this using diatonic context. When you have set a key signature,
it prefers the diminished 7th reading that best fits the key, specifically the
one whose root is the diatonic leading tone. In D♭ major, these same piano keys
naturally point to <span class="chord">Cdim7</span>, the leading-tone diminished
7th that resolves to D♭. Without a key signature, it falls back to preferring
root position: the interpretation where the bass note is named as the root,
which is a clear default when no surrounding harmony is available.

## Inversions: the bass note changes everything

Inversion is one of the main reasons a chord name needs more than a pitch-class
lookup. When the third is in the bass instead of the root, a major chord carries
a different weight than it does in root position. When the fifth is in the bass,
the same pitch classes can sound stable in one progression and transitional in
another, depending on the surrounding music.

Classical theory calls these first and second inversion. Jazz and pop use slash
notation: <span class="chord">C/E</span> (C major with E in the bass),
<span class="chord">C/G</span> (C major with G in the bass). Either way, the
relationship between the bass note and the chord tones above it matters, and it
affects how the chord is named.

A MIDI keyboard tells the analyzer the pitch class of every sounding note,
including the lowest one. The lowest note is treated as the bass note and priced
separately from the upper structure. A chord where the bass is the root has a
lower explanation cost than the same chord with a bass that requires slash
notation. Not because root position is "more correct," but because it is the
more common interpretation and more informative to name explicitly as root
position first.

This pricing matters for a subtle reason. Consider C-E-G-A played with C in the
bass. Is that <span class="chord">C6</span> or <span class="chord">Am7/C</span>?
Both are completely valid readings: <span class="chord">C6</span> is a major
chord with an added 6th; <span class="chord">Am7/C</span> is an A minor 7th
chord in first inversion. In real music, both readings show up. The default
behavior is to show <span class="chord">C6</span> as the primary interpretation:
the root is in the bass and no inversion notation is required.
<span class="chord">Am7/C</span> appears below the chord identity card as an
alternative.

## Extensions: when does an extra note become part of the chord?

A triad has three notes. A 7th chord has four. But jazz pianists regularly play
voicings with five, six, or even seven distinct pitch classes and still call it
a single chord.

In common chord-symbol practice, extensions are named as part of a stack: 7, 9,
11, 13. A major 9th chord (<span class="chord" >Cmaj9</span >) normally implies
the major 7th as well. The 9 is an extension of the 7th-family chord, not just a
note tacked on. By contrast, <span class="chord">Cadd9</span> skips the 7th
entirely and adds the 9th on top of a basic triad. They are different sounds
with different names, even though both contain C-E-G-D.

WhatChord uses a conservative version of this distinction when labeling
extensions. A 9 needs the 7th below it. An 11 needs both the 7th and the 9th. A
13 needs the 7th and 9th, but not a sounding 11, matching common chord-symbol
practice where the 11th is often omitted. Without that support, the same notes
are labeled as add tones: add9, add11, or add13. The rule is simple to state and
surprisingly hard to get right in practice, because voicings often omit the 5th
while keeping the tones that define the chord function.

## Altered dominants: a dense naming problem

Dominant 7th chords such as <span class="chord">G7</span>,
<span class="chord">C7</span>, and <span class="chord">F7</span> are the
workhorses of functional harmony. They create tension that resolves, and because
jazz musicians spend so much time on them, dominant 7ths have accumulated a
particularly rich vocabulary of extensions and alterations.

The "[altered scale](https://en.wikipedia.org/wiki/Altered_scale)," the seventh
mode of melodic minor, provides a vocabulary of alterations that can be stacked
on a dominant chord: flat 9, sharp 9, sharp 11 or flat 5, and flat 13 or
sharp 5. A heavily altered dominant might look like
<span class="chord">G7(♯9,♯11,♭13)</span>: G plus its major 3rd (B), its minor
7th (F), and three altered upper extensions. That is six distinct pitch classes
in a single chord.

The dominant 7th sharp-nine chord is particularly well-known, nicknamed the
"[Hendrix chord](https://en.wikipedia.org/wiki/Dominant_seventh_sharp_ninth_chord)"
for its prominent use in "Purple Haze," where it appears as
<span class="chord">E7♯9</span>. Building one on G, the notes are G-B-F-A♯. That
A♯ is the same piano key as B♭, but the chord role is different: it is the
raised 9th above G. Without musical context, a naive recognizer might call the
same keys a diminished chord, a minor chord with a strange bass, or something
else entirely. The analyzer recognizes the dominant shell (major 3rd + flat 7th)
as the anchor, treats the sharp 9 as an alteration on that dominant function,
and reports <span class="chord">G7♯9</span> as expected.

This matters because dominant chords with alterations arise constantly in jazz,
blues, and rock. Getting them wrong breaks trust with any musician who knows
what they sound like.

### Upper-structure voicings

Experienced jazz pianists often build dominant chord voicings using an "upper
structure" technique: the left hand plays the shell tones (usually the 3rd and
flat 7th of the dominant, often with a bass root supplied nearby), and the right
hand plays what sounds like a separate chord, often a simple triad built on
another [scale degree](scale-degrees.html). The result is a rich color that
resists simple labeling.

In these cases, the analyzer keeps the dominant shell as the anchor instead of
treating the upper notes as unrelated chord roots. If the bass is itself a color
tone, such as the ♯11, the result is kept in the dominant family rather than
being treated as an unrelated root change.

## Enharmonic spelling

C♯ and D♭ are the same key on a piano. They are the same MIDI note number, but
they mean different things. Writing the wrong one in a chord symbol or lead
sheet is a mistake that musicians notice immediately.

In the key of E major, the pitch C♯ is the sixth degree of the scale. Writing
that same piano key as D♭ would be technically enharmonic but functionally
wrong. In the key of A♭ major, the same piano key is D♭, the fourth degree of
the scale.

Chord symbols follow the same logic. A dominant 7th built on G spells its minor
7th as F (two semitones below the octave), never E♯. A diminished 7th on B
spells its top note as A♭, the diminished 7th above B, not G♯, even though they
are identical pitches.

The app uses both the key signature and the identified chord root to determine
enharmonic spelling. When you have set the key signature to three flats (E♭
major or C minor), it will favor flat spellings for chord tones and extensions
throughout. When it identifies a dominant 7th on G, it spells the 7th as F
regardless of key context, because that is what the chord quality demands. These
two sources of context combine to produce spellings that look like what a
professional musician or copyist would write.

## Ambiguity is a feature, not a problem

Some voicings are genuinely ambiguous. Not because the algorithm failed, but
because the music itself has multiple valid interpretations.

The <span class="chord">C6</span> versus <span class="chord">Am7/C</span> case
from earlier is the basic version of this problem: the notes are identical, but
the musical meaning depends on where the harmony is going. Are you at the end of
a phrase resolving to tonic, or are you in the middle of a
[ii-V-I](https://en.wikipedia.org/wiki/Ii%E2%80%93V%E2%80%93I_progression) in G
major? The notes do not tell you. The music around them does.

Rather than arbitrarily committing to one name, the interface can show both when
costs are close. The primary result is the highest-ranked interpretation,
displayed as the main chord name. Other plausible readings appear below the
chord identity card. A musician looking at the screen gets the most likely
reading immediately, but can see at a glance that another name is also in play.

This is the more honest representation of what the notes can support. The four
notes C-E-F♯-B♭ are a clean example: they cost identically as
<span class="chord">C7♭5</span> and <span class="chord">F♯7♭5/C</span>, two
dominant 7th♭5 chords whose roots sit a tritone apart, the same symmetry that
underlies
[tritone substitution](https://en.wikipedia.org/wiki/Tritone_substitution) in
jazz. The app shows <span class="chord">C7♭5</span> as primary (root in the
bass), with <span class="chord">F♯7♭5/C</span> listed as an equal-cost
alternative.

## Where WhatChord fits

WhatChord is not trying to pretend that chord names are objective facts. It
tries to make the same practical judgment a good player would make first, while
still showing plausible alternatives when the notes support more than one name.

Each snapshot of sounding notes is evaluated on its own, but not in isolation.
The app follows the key from the chords you have been playing and reads the next
one against it, so a change of key changes how what comes after it is named.
Ensemble mode supplies the other kind of context, naming the chord a pianist
means when a bassist is covering the root. What it cannot do yet is follow
individual melodic lines through time, so a melody note held over a chord can
still pull the name toward something more elaborate than you meant. That is the
larger point: chord naming is harder than it looks because the notes are only
the beginning.

If you want to see how that musical judgment is represented in code,
[the underlying algorithm](chord-recognition-algorithm.html) is described in
more technical depth.

<div class="article-cta">
  <h3>Try it on your own keyboard.</h3>
  <p>
    Free for iOS and Android. No subscription, no ads, no internet
    required.
  </p>
  <div class="store-badges store-badges-spaced">
    <a
      href="https://apps.apple.com/us/app/whatchord-midi/id6758409779"
    >
      <img
        class="store-badge"
        src="../images/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg"
        alt="Download on the App Store"
      />
    </a>
    <a
      href="https://play.google.com/store/apps/details?id=com.earthmanmuons.whatchord"
    >
      <img
        class="store-badge"
        src="../images/GetItOnGooglePlay_Badge_Web_color_English.svg"
        alt="Get it on Google Play"
      />
    </a>
  </div>
  <p class="cta-secondary">
    Prefer not to install?
    <a href="/try">Try identifying chords in your browser →</a>
  </p>
</div>

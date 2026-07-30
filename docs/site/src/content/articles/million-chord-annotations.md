---
cardDescription:
  "How a large public chord corpus helped validate WhatChord’s chord vocabulary
  and guide future recognition priorities."
cta:
  action:
    external: true
    href: "https://github.com/EarthmanMuons/whatchord/blob/main/research/choco-chord-coverage.md"
    label: "Open the full details"
    variant: "primary"
  description:
    "The longer write-up includes the extraction method, source paths,
    reproduction commands, and additional unsupported-label details."
  secondary:
    href: "/try"
    label: "Try identifying chords in your browser →"
    lead: "Curious how it names them?"
  title: "Read the research note."
decks:
  - "WhatChord is built around musical judgment, but judgment still needs
    evidence. In May 2026, we checked the app’s chord vocabulary against a large
    public corpus of real chord annotations to see what it covers, what it
    misses, and what should matter next."
description:
  "How a large public chord corpus helped validate WhatChord’s chord vocabulary
  and guide future recognition priorities."
group: "technical"
indexOrder: 8
related:
  - "why-chord-naming-is-hard"
  - "chord-recognition-algorithm"
  - "measuring-how-wrong-we-are"
socialDescription:
  "A look at how real-world chord annotations help keep WhatChord’s recognition
  roadmap grounded in music people actually write and play."
socialTitle: "What We Learned From 1 Million Chord Annotations"
tag: "Chord data"
title: "What We Learned From 1 Million Chord Annotations"
---

## Why measure this at all?

A chord recognizer has to make user experience decisions that look small on the
surface but matter a lot in practice. Should a bare fifth be treated as a chord,
or as an interval? Which altered colors deserve first-class names? Is it better
to add more exotic templates, or to improve the ranking and spelling of the
common ones?

Those questions cannot be answered by counting possible
[pitch-class sets](<https://en.wikipedia.org/wiki/Set_theory_(music)>). There
are only 4,096 possible sets in
[12-tone equal temperament](https://en.wikipedia.org/wiki/12_equal_temperament)
(12-TET), but most of them are not useful chord names. The more relevant
question is what chord labels musicians, transcribers, and datasets actually use
when describing real music.

That is where engineering discipline helps. A recognition engine can still be
shaped by musical taste, but the roadmap should not depend only on intuition. We
wanted external validation: compare WhatChord's current chord vocabulary with a
large collection of existing chord annotations, then use the result to decide
where more work would actually help players.

## The data source

The comparison used [ChoCo](https://github.com/smashub/choco), a large
linked-data chord corpus that gathers annotations from many existing datasets
and formats. It includes material derived from sources such as Isophonics, RWC
Pop, Weimar Jazz, USPop2002, Wikifonia, iReal Pro, and others.

That mix is exactly what makes the corpus useful. It is not a perfect model of
what someone will play into a MIDI keyboard, and it is not a benchmark for live
recognition accuracy. It is a broad snapshot of chord-symbol language across
real annotated music.

The analysis looked at converted [JAMS](https://github.com/marl/jams) (JSON
Annotated Music Specification) files from ChoCo and extracted
[Harte-style](https://ismir2005.ismir.net/proceedings/1080.pdf) chord labels
such as <span class="chord">C:maj</span>, <span class="chord">D:min7</span>,
<span class="chord">G:7(b9)</span>, and <span class="chord">F#:hdim7</span>.
Then it removed the root from each label, so C major, E-flat major, and F-sharp
major all count as the same chord body: major.

<div class="callout">
  <p>
    The goal was not to train WhatChord from ChoCo or copy
    corpus-specific behavior into the app. The goal was to ask a
    narrower question: does WhatChord have names for the chord
    families that show up most often in a large real-world corpus?
  </p>
</div>

## The headline result

After excluding labels for no chord, unknown harmony, and empty values, the
snapshot contained 1,097,701 chord observations. Those observations collapsed to
350 distinct chord bodies after root removal.

<table class="article-table">
  <thead>
    <tr>
      <th>Measure</th>
      <th>Count</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>JAMS files scanned</td>
      <td class="mono">16,249</td>
    </tr>
    <tr>
      <td>Chord observations</td>
      <td class="mono">1,097,701</td>
    </tr>
    <tr>
      <td>Distinct full chord labels</td>
      <td class="mono">4,798</td>
    </tr>
    <tr>
      <td>Distinct chord bodies after root removal</td>
      <td class="mono">350</td>
    </tr>
  </tbody>
</table>

Compared with WhatChord's current templates and extension handling, the result
was encouraging:

<table class="article-table">
  <thead>
    <tr>
      <th>Coverage basis</th>
      <th>Supported</th>
      <th>Unsupported</th>
      <th>Coverage</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Observations</td>
      <td class="mono">1,085,031</td>
      <td class="mono">12,670</td>
      <td class="mono">98.85%</td>
    </tr>
    <tr>
      <td>Duration</td>
      <td class="mono">3,082,437</td>
      <td class="mono">37,074</td>
      <td class="mono">98.81%</td>
    </tr>
  </tbody>
</table>

In plain English: most of the chord language in this large mixed corpus is
already inside WhatChord's recognition vocabulary. The current set of supported
chord families is broad enough to cover the overwhelming majority of real
annotated chord material.

## The common chords were the expected ones

The highest-frequency chord bodies were not surprising, which is a good sign.
Major, dominant seventh, minor, minor seventh, major seventh, diminished, sixth,
ninth, and altered dominant material all appeared near the top. Those are
exactly the chord families a practical recognizer should handle well.

<table class="article-table">
  <thead>
    <tr>
      <th>Chord body</th>
      <th>Observations</th>
      <th>WhatChord status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">maj</td>
      <td class="mono">375,189</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">7</td>
      <td class="mono">169,546</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">min</td>
      <td class="mono">123,885</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">min7</td>
      <td class="mono">71,362</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">maj7</td>
      <td class="mono">40,493</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">dim</td>
      <td class="mono">24,612</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">9</td>
      <td class="mono">15,367</td>
      <td>supported</td>
    </tr>
    <tr>
      <td class="mono">7(b9)</td>
      <td class="mono">6,131</td>
      <td>supported</td>
    </tr>
  </tbody>
</table>

This matters because development time is finite. A chord recognizer can always
grow a longer list of labels, but every new label affects ranking. Add too many
marginal templates and the app can become worse at naming common voicings,
especially when
[several chord readings share the same notes](why-chord-naming-is-hard.html).

## The missing labels were instructive

The most common unsupported bodies were not missing mainstream chord families.
They were mostly omitted-tone labels, fifth-only sonorities, and root-only
annotations. Those labels are meaningful in a corpus, but they do not
necessarily make good live chord names.

<table class="article-table">
  <thead>
    <tr>
      <th>Unsupported body</th>
      <th>Observations</th>
      <th>What it describes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">(*3,*5)</td>
      <td class="mono">6,008</td>
      <td>omitted third and fifth</td>
    </tr>
    <tr>
      <td class="mono">(*3,5)</td>
      <td class="mono">1,595</td>
      <td>fifth-only sonority</td>
    </tr>
    <tr>
      <td class="mono">(5)</td>
      <td class="mono">710</td>
      <td>fifth-only sonority</td>
    </tr>
    <tr>
      <td class="mono">(1,*3,*5)</td>
      <td class="mono">623</td>
      <td>root-only sonority</td>
    </tr>
  </tbody>
</table>

This supports an existing WhatChord design choice: dyads are reported as
intervals rather than promoted into chord templates. WhatChord previously
supported a power-fifth chord label, but that made ranking worse for a
piano-focused app. The corpus result did not argue for bringing it back. It
argued for restraint.

The first unsupported labels that looked more like candidate chord qualities
were minor sharp-five forms. They are real, but much rarer than the common chord
families that dominate the corpus.

## What this means for WhatChord

The practical lesson is not "the app is done." It is that the next
highest-impact improvements are probably not a long list of new chord templates.

The data points toward three priorities:

- Keep improving ranking for common ambiguous voicings, because those are the
  cases players will hit most often.
- Keep improving spelling and explanations, because the same recognized chord
  can be more or less useful depending on whether the symbol matches musical
  convention.
- Track rare but real chord families, such as minor sharp-five, without letting
  them disrupt the common cases.

That balance is central to WhatChord's approach. More recognition is only better
when it improves the answer a musician sees. Sometimes the disciplined choice is
to say no to a label, or at least not yet.

## What the numbers do not prove

Corpus coverage is not the same as live analyzer accuracy. A supported chord
body means WhatChord has the vocabulary to name that kind of chord. It does not
prove every voicing from the source material would rank exactly the same way in
the app.

The source material also mixes audio annotations, score-derived annotations,
lead sheets, and converted symbolic formats. That breadth is useful, but it also
means some labels encode conventions from their original source rather than
universal chord-symbol practice.

So the corpus is best understood as a reality check, not a product spec. It
helps keep the recognition roadmap grounded in music people actually annotate
and play, while leaving room for the musical judgment that real-time chord
naming still requires.

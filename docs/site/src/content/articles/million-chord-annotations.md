---
cardDescription:
  "How a large public chord corpus helped validate WhatChord’s chord vocabulary
  and guide future recognition priorities."
cardTitle: "What We Learned From 1 Million Chord Annotations"
decks:
  - "WhatChord is built around musical judgment, but judgment still needs
    evidence. In May 2026, we checked the app’s chord vocabulary against a large
    public corpus of real chord annotations to see what it covers, what it
    misses, and what should matter next."
description:
  "How a large public chord corpus helped validate WhatChord’s chord vocabulary
  and guide future recognition priorities."
featuredDescription:
  "How a large public chord corpus helped validate WhatChord’s chord vocabulary
  and guide future recognition priorities with evidence rather than guesswork."
featuredOrder: 2
group: "technical"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 7
pageTitle: "What We Learned From 1 Million Chord Annotations | WhatChord"
related:
  - "why-chord-naming-is-hard"
  - "chord-recognition-algorithm"
relatedExternal:
  - description:
      "The research project behind automatic key detection: a frozen evaluation
      protocol, external baselines, dated experiment logs, and held-out results."
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey"
    readMore: "Read the research notes →"
    tag: "Key Detection"
    title: "Streaming Key Estimation Research"
socialDescription:
  "A look at how real-world chord annotations help keep WhatChord’s recognition
  roadmap grounded in music people actually write and play."
socialTitle: "What We Learned From 1 Million Chord Annotations"
tag: "Chord data"
title: "What We Learned From 1 Million Chord Annotations"
---

<h2>Why measure this at all?</h2>

<p>
  A chord recognizer has to make user experience decisions that look
  small on the surface but matter a lot in practice. Should a bare
  fifth be treated as a chord, or as an interval? Which altered colors
  deserve first-class names? Is it better to add more exotic
  templates, or to improve the ranking and spelling of the common
  ones?
</p>

<p>
  Those questions cannot be answered by counting possible
  <a href="https://en.wikipedia.org/wiki/Set_theory_(music)"
    >pitch-class sets</a
  >. There are only 4,096 possible sets in
  <a href="https://en.wikipedia.org/wiki/12_equal_temperament"
    >12-tone equal temperament</a
  >
  (12-TET), but most of them are not useful chord names. The more
  relevant question is what chord labels musicians, transcribers, and
  datasets actually use when describing real music.
</p>

<p>
  That is where engineering discipline helps. A recognition engine can
  still be shaped by musical taste, but the roadmap should not depend
  only on intuition. We wanted external validation: compare
  WhatChord’s current chord vocabulary with a large collection of
  existing chord annotations, then use the result to decide where more
  work would actually help players.
</p>

<h2>The data source</h2>

<p>
  The comparison used
  <a href="https://github.com/smashub/choco">ChoCo</a>, a large
  linked-data chord corpus that gathers annotations from many existing
  datasets and formats. It includes material derived from sources such
  as Isophonics, RWC Pop, Weimar Jazz, USPop2002, Wikifonia, iReal
  Pro, and others.
</p>

<p>
  That mix is exactly what makes the corpus useful. It is not a
  perfect model of what someone will play into a MIDI keyboard, and it
  is not a benchmark for live recognition accuracy. It is a broad
  snapshot of chord-symbol language across real annotated music.
</p>

<p>
  The analysis looked at converted
  <a href="https://github.com/marl/jams">JAMS</a> (JSON Annotated
  Music Specification) files from ChoCo and extracted
  <a href="https://ismir2005.ismir.net/proceedings/1080.pdf"
    >Harte-style</a
  >
  chord labels such as <span class="chord">C:maj</span>,
  <span class="chord">D:min7</span>,
  <span class="chord">G:7(b9)</span>, and
  <span class="chord">F#:hdim7</span>. Then it removed the root from
  each label, so C major, E-flat major, and F-sharp major all count as
  the same chord body: major.
</p>

<div class="callout">
  <p>
    The goal was not to train WhatChord from ChoCo or copy
    corpus-specific behavior into the app. The goal was to ask a
    narrower question: does WhatChord have names for the chord
    families that show up most often in a large real-world corpus?
  </p>
</div>

<h2>The headline result</h2>

<p>
  After excluding labels for no chord, unknown harmony, and empty
  values, the snapshot contained 1,097,701 chord observations. Those
  observations collapsed to 350 distinct chord bodies after root
  removal.
</p>

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

<p>
  Compared with WhatChord’s current templates and extension handling,
  the result was encouraging:
</p>

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

<p>
  In plain English: most of the chord language in this large mixed
  corpus is already inside WhatChord’s recognition vocabulary. The
  current set of supported chord families is broad enough to cover the
  overwhelming majority of real annotated chord material.
</p>

<h2>The common chords were the expected ones</h2>

<p>
  The highest-frequency chord bodies were not surprising, which is a
  good sign. Major, dominant seventh, minor, minor seventh, major
  seventh, diminished, sixth, ninth, and altered dominant material all
  appeared near the top. Those are exactly the chord families a
  practical recognizer should handle well.
</p>

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

<p>
  This matters because development time is finite. A chord recognizer
  can always grow a longer list of labels, but every new label affects
  ranking. Add too many marginal templates and the app can become
  worse at naming common voicings, especially when
  <a href="why-chord-naming-is-hard.html"
    >several chord readings share the same notes</a
  >.
</p>

<h2>The missing labels were instructive</h2>

<p>
  The most common unsupported bodies were not missing mainstream chord
  families. They were mostly omitted-tone labels, fifth-only
  sonorities, and root-only annotations. Those labels are meaningful
  in a corpus, but they do not necessarily make good live chord names.
</p>

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

<p>
  This supports an existing WhatChord design choice: dyads are
  reported as intervals rather than promoted into chord templates.
  WhatChord previously supported a power-fifth chord label, but that
  made ranking worse for a piano-focused app. The corpus result did
  not argue for bringing it back. It argued for restraint.
</p>

<p>
  The first unsupported labels that looked more like candidate chord
  qualities were minor sharp-five forms. They are real, but much rarer
  than the common chord families that dominate the corpus.
</p>

<h2>What this means for WhatChord</h2>

<p>
  The practical lesson is not “the app is done.” It is that the next
  highest-impact improvements are probably not a long list of new
  chord templates.
</p>

<p>The data points toward three priorities:</p>

<ul>
  <li>
    Keep improving ranking for common ambiguous voicings, because
    those are the cases players will hit most often.
  </li>
  <li>
    Keep improving spelling and explanations, because the same
    recognized chord can be more or less useful depending on whether
    the symbol matches musical convention.
  </li>
  <li>
    Track rare but real chord families, such as minor sharp-five,
    without letting them disrupt the common cases.
  </li>
</ul>

<p>
  That balance is central to WhatChord’s approach. More recognition is
  only better when it improves the answer a musician sees. Sometimes
  the disciplined choice is to say no to a label, or at least not yet.
</p>

<h2>What the numbers do not prove</h2>

<p>
  Corpus coverage is not the same as live analyzer accuracy. A
  supported chord body means WhatChord has the vocabulary to name that
  kind of chord. It does not prove every voicing from the source
  material would rank exactly the same way in the app.
</p>

<p>
  The source material also mixes audio annotations, score-derived
  annotations, lead sheets, and converted symbolic formats. That
  breadth is useful, but it also means some labels encode conventions
  from their original source rather than universal chord-symbol
  practice.
</p>

<p>
  So the corpus is best understood as a reality check, not a product
  spec. It helps keep the recognition roadmap grounded in music people
  actually annotate and play, while leaving room for the musical
  judgment that real-time chord naming still requires.
</p>

<div class="article-cta">
  <h3>Read the research note.</h3>
  <p>
    The longer write-up includes the extraction method, source paths,
    reproduction commands, and additional unsupported-label details.
  </p>
  <a
    class="btn btn-ghost"
    href="https://github.com/EarthmanMuons/whatchord/blob/main/docs/research/choco-chord-coverage.md"
    >Open the full details</a
  >
  <p class="cta-secondary">
    Curious how it names them?
    <a href="/try">Try identifying chords in your browser →</a>
  </p>
</div>

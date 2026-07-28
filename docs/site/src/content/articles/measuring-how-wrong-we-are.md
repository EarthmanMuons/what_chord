---
cardDescription:
  "A tour of WhatChord’s well-measured bad ideas, and why reproducible negative
  results are as valuable as the experiments that become features."
cardTitle: "We Can Measure Exactly How Wrong We Are"
decks:
  - "I have a lot of ideas about how WhatChord ought to work. This would be more
    impressive if the data agreed with me on more of them."
  - "Our research archive records the ideas that shipped, the ideas that failed,
    and enough detail to run the argument again. Keeping that record is part of
    the work. It is how we keep intuition from quietly turning into product
    behavior."
description:
  "A plain-English tour of WhatChord’s negative research results, and why
  reproducible experiments that stop bad ideas are as valuable as positive
  findings."
group: "technical"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 8
pageTitle: "We Can Measure Exactly How Wrong We Are | WhatChord"
related:
  - "million-chord-annotations"
  - "benchmarking-on-hardware-you-dont-control"
  - "chord-recognition-algorithm"
socialDescription:
  "WhatChord has a growing collection of well-measured bad ideas. Here is why
  reproducible negative results matter as much as features that ship."
socialTitle: "We Can Measure Exactly How Wrong We Are"
tag: "Research practice"
title: "We Can Measure Exactly How Wrong We Are"
---

## A promising idea is not a result

WhatChord watches the notes arriving from a MIDI keyboard and tries to name the
chord, infer the key, and keep both answers readable while real human hands are
rolling notes and leaning on the sustain pedal. It is the sort of problem that
produces wonderfully plausible ideas.

Surely the previous chord will clarify this one. Surely a cadence will reveal
the key. Surely notes held only by the pedal are safe to ignore. Surely a more
sophisticated probability model will outperform the simple one. Surely.

We have built and measured all of those ideas. Many did not help. Several did
exactly what they promised and still made the product worse. A few revealed that
we were trying to fix the wrong layer entirely.

That is good news.

A negative result can save users from a regression, save the codebase from a new
mechanism it must carry forever, and save the next round of research from
repeating an attractive dead end. But it can do those things only if somebody
can tell what was tested, against what, and under which rules. "We tried it
once" is an anecdote. A reproducible negative result is reusable knowledge.

<div class="callout">
  <p>
    Research rarely proves that an idea can never work. It can show that a
    specific mechanism, tested on declared data against a declared baseline,
    did not improve the thing it claimed to improve enough to justify shipping.
    That narrower statement is still extremely useful.
  </p>
</div>

## How we arrange to lose an argument with ourselves

For each serious investigation, we write down the question, the measurements,
and the adoption bar before the result. We divide music by complete piece into a
development set, where ideas may be refined, and a held-out set that stays
sealed until the final configuration is fixed. When testing a proposed change,
we run both the current system and the changed system on the same music. We
measure the difference separately for each piece, then compare those per-piece
results. That keeps one unusually long sonata from counting as more evidence
than many shorter works. We record the exact commands, code versions, corpus
versions, and any known limits of the labels.

The test material is deliberately broad: classical scores and performances,
annotated pop and rock, jazz solos and comping voicings, and targeted blues and
modal examples. An idea that wins in one tradition still has to survive the
others before it becomes a default.

Most importantly, the dated log keeps the null results, reversals, and
corrections. This has already caught our own mistakes: a benchmark command whose
default had drifted away from the app's default, performed-music labels aligned
to the wrong moments, and two research tools quietly broken by a file move. Each
was discoverable because an old result was expected to reproduce and did not.
Reproducibility is not just a courtesy to a future reader. It is an alarm system
for the present.

The held-out music matters for the same reason. One key-detection setting looked
dramatically better at following local keys during development. On the unseen
pieces, the advantage vanished. Its faster reactions were real; the accuracy
story was not. Because the prediction was written down first, the result became
a correction instead of a marketing footnote.

## The cabinet of extremely reasonable ideas

The full record lives in the
[research archive](https://github.com/EarthmanMuons/whatchord/tree/main/research).
Here is the plain-English tour of the ideas we measured and did not adopt as
proposed, including a few that later found a narrower job.

### More music theory will surely help

These experiments come from the
[WhatKey](https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey)
and
[WhatKey Local](https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey-local)
investigations.

- **Hand-written chord-function scores.** Rules such as "a dominant seventh
  strongly suggests this key" handled tidy textbook examples but lost to a
  simpler summary of the notes on real scores. In the calm, section-key detector
  they were eventually removed, improving accuracy and stopping each blues
  seventh from sounding like a move to another key.

- **Chord-progression bonuses.** Cadences and ii-V-I patterns helped an older
  detector speak more often, but added no useful information to the probability
  model that replaced it. At reactive settings they also made blues and
  secondary dominants unstable.

- **Trusting the chord recognizer's confidence.** Down-weighting uncertain chord
  names sounded tailor-made for messy live input. Across clean scores, performed
  piano, stable behavior, and reactive behavior, it changed nothing useful. Six
  null results closed it.

- **A special "this sounds like home" bonus.** A gentle dose did nothing; a
  stronger dose partially fixed the blues while making classical pieces worse.
  Recognizing that the music has returned to its home key requires knowing what
  came before; no rule examining one chord in isolation can provide that
  context.

- **Relative-key nudges.** We tried leaning between relative major and minor
  using the bass, a preceding cadence, and the recent presence or absence of
  minor-defining notes. The signals were inert, too weak, or actively mislabeled
  ordinary minor passages between cadences.

- **Try different standard key profiles.** Some won on the classical ruler, then
  called both blues examples by the wrong key and stopped answering on a Dorian
  vamp. A corpus win was not a product win.

### More elaborate memory will surely help

- **Faster forgetting.** It caught more key changes, exactly as expected, and
  also invented more key changes. The accuracy gain did not survive held-out
  music. Later work let us re-adopt the trade-off honestly in the
  Stable/Balanced/Reactive Key Behavior setting: the modes offer different
  degrees of responsiveness, not progressively better accuracy.

- **Wait for a new key to win twice.** This calmed a few false switches, but the
  extra wait was long enough to miss the short real key changes that faster
  memory had recovered. Hysteresis cost more than it bought every time we
  retested it.

- **Forget per chord instead of per second.** Clean score chords still wanted
  almost no averaging while pedaled performance chords wanted a great deal. The
  disagreement was about how trustworthy each observation was, not the clock
  used to age it.

- **A more sophisticated duration model.** We first swept the simpler "how long
  do keys usually last?" knob across an enormous range. The output barely cared,
  leaving little for an explicit-duration model to improve. That measured
  ceiling saved us from building the larger model.

- **Let the detector infer when a new musical section begins.** Adaptive
  changepoint detection found real changes faster and was genuinely better in
  the most reactive regime. It also mistook colorful harmony for a succession of
  new sections. No setting matched the calm accuracy and stability the product
  was designed to show.

- **Give each behavior mode more tuning knobs.** We tested separate controls for
  memory, decisiveness, and uncertainty. Most reproduced the same responsiveness
  trade-off less cleanly than one understandable memory control, so they stayed
  shared defaults.

- **Assume the first chord is the tonic.** Jazz progressions often start on ii,
  and modal openings exist. The prior created confident early mistakes. The
  successful fix was simpler: remove an arbitrary three-chord waiting rule and
  let the existing uncertainty threshold decide whether the first chord was
  informative.

### The surrounding chords will surely rescue the name

These ideas were measured in
[Chord Context](https://github.com/EarthmanMuons/whatchord/tree/main/research/chord-context)
and the later
[Ensemble Tiebreak](https://github.com/EarthmanMuons/whatchord/tree/main/research/ensemble-tiebreak)
work.

- **Prefer the expected resolution, dominant, or previous root.** Knowing the
  previous chord mostly added no information beyond the current notes and key.
  Following the prior root was especially harmful because consecutive chords
  generally have the discourtesy to change.

- **Follow recent spelling around the circle of fifths.** The first version had
  one lucky setting and failed everywhere around it. A stronger version was
  stable but still too small to adopt. An F-sharp-versus-G-flat preference even
  looked significant only because one corpus contained more F-sharp composers.
  Evidence from a second musical domain later justified the narrow default that
  shipped.

- **Use the next chord to revise an earlier ambiguous name.** It could correct
  one kind of ambiguity with perfect precision, but touched too little music to
  improve key detection. The general feedback idea died; a later, narrower use
  of history survived because some rootless names depended on the detector's
  next key claim.

- **Use surrounding harmony to improve note spelling.** Once the key itself was
  correct, spelling was already about 99.4% right. Almost the entire remaining
  gap came from detecting the wrong key, which no clever speller can repair.

- **Teach the analyzer to ignore melody notes.** A benchmark seemed to show a
  large error class where melody notes pushed the app toward bigger chord names,
  so we considered filtering them out. Counting only notes that sounded at the
  same moment shrank the bucket from 22.8% of events to 1.1%: the original view
  had assembled a melodic line into imaginary chords. Little remained for the
  rule to fix.

- **Add classical augmented-sixth names.** Scores call these sounds augmented
  sixths; the app deliberately uses lead-sheet dominant-seventh names. Adding
  the classical reading, even as an alternative, required a new chord family or
  contextual spelling rule for a difference affecting about 0.7% of events. It
  did not clear the bar.

- **Resolve the remaining rootless chords with better tiebreakers.** Ensemble
  mode misnamed rootless chords that pointed outside the current key, so we
  planned smarter rules for choosing the intended missing root. But the correct
  reading was never generated. No tiebreaker can pick a candidate that does not
  exist; the successful fix expanded the candidate pool, then guarded against
  implausible readings.

### Surely real piano input has an obvious fix

These came from the
[Performed Input](https://github.com/EarthmanMuons/whatchord/tree/main/research/performed-input)
initiative, which replayed real performances through the app's live analysis
path.

- **Wait longer before accepting a chord.** A stricter segmenter discarded more
  of the performance without making the remaining chords more trustworthy.
  Pedal-blurred sonorities are often sustained, not fleeting mistakes.

- **Ignore pedal-held notes.** The filter successfully removed pedal blur and
  also removed the harmony, because pianists use the pedal to hold real chords
  while their hands move. Coverage collapsed and accuracy fell.

- **Match the analyst's root.** In many disagreements the app chose the sounding
  bass while a Roman-numeral analyst chose an implied functional root. That was
  a difference between naming cultures, not an engine defect, so we declined to
  optimize the app away from its stated audience.

- **Re-rank the app's existing alternatives.** We hoped the analyst's chord was
  already ranked second. On nine tenths of disagreement time, it was not among
  the close alternatives at all, leaving the cheap re-ranking idea almost no
  target.

- **Treat the highest extra note as melody.** The extra tone was actually on top
  only about a quarter of the time. The honest version would require tracking
  several musical voices through time, a substantial project for a small
  measured ceiling.

- **Expand the test pool with real octave layouts.** Across nearly eight
  thousand observed layouts, the engine kept the same name 99.3% of the time.
  Textbook stacks were not hiding a voicing-sensitivity problem.

- **Show a "settling" indicator during the display delay.** It would flash 73 to
  168 times per minute, recreating through decoration the flicker the delay had
  just removed from the chord name.

- **Change how the benchmark awards partial credit.** We tried judging the app's
  answer by the chord tones the pianist had played, rather than every tone
  implied by the app's chosen name. It rescued a tiny number of the intended
  augmented-sixth cases but caused far more ordinary incomplete performances to
  lose credit. The trade was overwhelmingly negative, so we kept the old ruler.

### Surely one pricing tweak or extra chord name will do it

The
[Tone Pricing](https://github.com/EarthmanMuons/whatchord/tree/main/research/tone-pricing)
initiative and
[ChoCo coverage study](https://github.com/EarthmanMuons/whatchord/blob/main/research/choco-chord-coverage.md)
tested these ideas against real playing time and more than a million chord
annotations.

- **Make unexplained notes cheaper.** This helped half-played simple chords, not
  the target cases where melody or pedal notes were absorbed into fancy names.
  Pushing farther made the analyzer lazily ignore the notes that make a chord
  interesting.

- **Charge rare fancy names more.** The combined change broke curated musical
  judgments, including the canonical minor-major seventh in harmonic minor, and
  was reverted under its predeclared rule.

- **Charge rare names more except when the key makes them conventional.** The
  engine already had a near-tie rule protecting those names, but the new price
  pushed candidates too far apart for it to run. The exception also sheltered
  most of the original problem. Clever, measured, empty.

- **Add every label found in a large corpus.** The long tail was dominated by
  root-only and fifth-only labels, omissions, and rare spellings. Broad
  expansion risked making common names harder to rank, so most of that
  vocabulary stayed out. One tightly contained omitted-third dominant shell
  earned its way in; the general theory did not.

## What the failures bought

This is not a graveyard of wasted work. Negative experiments produced the
segmenter replay tools, paired comparison machinery, exposure-weighted chord
pools, provenance tracking for held versus pedaled notes, frozen corpora, and
behavioral suites that now guard every later change.

They also pointed toward several wins. Removing clever key-evidence layers made
the shipped detector simpler. Measuring flicker moved the solution from chord
analysis into display policy. Discovering that an ensemble candidate was absent,
not badly ranked, led to the real fix. Testing a cold-start prior exposed that
the waiting gate itself was unnecessary.

The discipline is what lets a result be surprising without becoming negotiable.
We can like an idea, implement it correctly, watch it move the exact mechanism
we predicted, and still decline it because the full product gets worse. We can
also change our minds later when a new ruler shows that the mechanism belongs in
a narrower job.

## The point of keeping the receipts

Positive results are naturally preserved: they become code, release notes, and
screenshots. Negative results disappear unless preserving them is an explicit
part of the method. Once they disappear, every plausible idea becomes new again.

So we keep the protocol, the split, the command, the correction, and the result
that hurt our feelings. A future contributor can reproduce the number, challenge
the premise, add a better corpus, or show that a once-useless mechanism now has
a job. Until then, we know more than "it felt wrong."

We know exactly how wrong we were. Within a 95% confidence interval.

<div class="article-cta">
  <h3>Inspect the evidence, including the inconvenient parts.</h3>
  <p>
    The open research archive contains the protocols, dated experiment
    logs, frozen data splits, reproduction instructions, corrections, and
    results behind these decisions.
  </p>
  <a
    class="btn btn-primary btn-external"
    href="https://github.com/EarthmanMuons/whatchord/tree/main/research"
    >Explore the research archive</a
  >
</div>

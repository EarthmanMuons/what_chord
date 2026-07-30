---
cardDescription:
  "The 24-state hidden Markov model, fading musical evidence, and abstention
  rule behind live key detection."
cardTitle: "Building a Streaming Key Detector"
decks:
  - "Naming the chord you are playing is one problem. Working out what key you
    are in, while you are still playing, is a different one. This is the model
    that does it: 24 competing hypotheses, evidence that fades, and a rule for
    staying quiet when the answer is not clear yet."
description:
  "A technical deep-dive into the hidden Markov model, profile matching, fading
  evidence, key-change predictions, and abstention rule behind WhatChord's live
  key detection."
group: "technical"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 5
pageTitle: "Building a Streaming Key Detector | WhatChord"
related:
  - "chord-recognition-algorithm"
  - "measuring-how-wrong-we-are"
  - "why-chord-naming-is-hard"
socialDescription:
  "24 competing hypotheses, evidence that fades on a half-life, and a rule for
  staying quiet: how WhatChord decides what key you are playing in, live."
socialTitle: "Building a Streaming Key Detector"
tag: "Technical deep-dive"
title: "Building a Streaming Key Detector"
---

## The problem is not a histogram

A _pitch class_ is a note's position within an octave, ignoring which octave it
is in. Middle C, the C above it, and the C three octaves below therefore belong
to the same pitch class. There are twelve pitch classes in all.

The textbook approach to key detection is a correlation. Count how much of each
pitch class a piece contains, compare that histogram against a published
template for each of the 24 major and minor keys, then return the closest match.
It is a good algorithm and about fifty lines of code. For answering "what key is
this song in" after the song has finished, it works well enough that several
standard implementations ship it.

Three constraints make it insufficient on its own.

**The answer has to arrive while the music is still happening.** Our detector
sees the past and only the past. It cannot read ahead to the musical resolution
that would have explained an ambiguous opening, and it cannot go back to revise
a past answer after later chords arrive. That rules out the entire family of
offline techniques that decode a best path over a complete sequence.

**The input is not raw MIDI.** It is the output of
[the chord recognizer](chord-recognition-algorithm.html): a stream of committed
chord events containing the pitch classes that sounded, the chord identity
selected by our recognizer, and how long the chord lasted. The upstream stage
has already made judgment calls, and it is sometimes wrong.

**Sometimes there is no answer, and saying so is correct.** A repeating chord
pattern may have a clear home note without behaving like any of the 24 major and
minor keys the detector knows. Musicians call that kind of pattern a modal vamp.
Two chords into a piece there may not be enough evidence for any answer. A
detector that must always name something will name something wrong, and a key
indicator that confidently flickers between wrong answers is worse than one that
stays blank.

What that combination needs is not a better histogram. It is a model that
carries a _belief_ forward through time, updates it as evidence arrives, and
knows how sure it is.

## Overview: predict, observe, decide

The detector is a
[hidden Markov model](https://en.wikipedia.org/wiki/Hidden_Markov_model) over 24
states, one per key. It never observes the key directly; it observes chords, and
maintains competing explanations for which key is generating them. Each
explanation gets a share of the total probability. One chord event goes in, one
updated distribution comes out.

<div class="pipeline-flow">
  <div class="pf-endpoint">
    Input: one committed chord event (sounding pitch classes,
    selected chord reading, duration)
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Predict</div>
    <div class="pf-sub">
      Carry the previous belief through the transition model: mostly
      stay, sometimes move, nearby keys favored
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Score the evidence</div>
    <div class="pf-sub">
      Correlate the recent pitch content against all 24 key profiles,
      then soften into a probability distribution
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Observe</div>
    <div class="pf-sub">
      Multiply prediction by evidence, then scale the total back to
      100%; this is the new belief
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Claim or abstain</div>
    <div class="pf-sub">
      Speak only if the leading key is far enough ahead of the
      runner-up
    </div>
  </div>
  <div class="pf-endpoint">
    Output: a key and a confidence, or nothing
  </div>
</div>

The next sections unpack those boxes.

## The state space

Twenty-four states: twelve tonics (home notes) times two modes (major and
minor). The belief is a plain array of 24 probabilities that sums to 1,
initialized uniformly at `1/24` each.

<pre><code><span class="kw">final</span> List&lt;<span class="kw">double</span>&gt; _posterior = <span class="kw">List</span>.<span class="fn">filled</span>(<span class="nu">24</span>, <span class="nu">1</span> / <span class="nu">24</span>);</code></pre>

Alongside it is a 12-number pitch-class histogram holding the decaying evidence
described below. The detector also remembers the previous recognized chord, an
event count, and enough timing information to fade old evidence. All of that
state is fixed in size. The app separately keeps the 100 most recent chords for
its history view, but the detector never reads that list, so the cost of an
update is the same on the first chord and the thousandth.

## Predict: what the key is likely to do next

Before looking at the new chord, the belief is carried forward through a
transition model, which encodes one assumption: keys persist. Most of the
predicted probability stays where it is, and the remainder spreads to other keys
with nearer ones favored.

Here, "nearer" means having a similar key signature. C major is closer to G
major than to F-sharp major because G major adds just one sharp while F-sharp
major has six. This distance is conventionally arranged on the
[circle of fifths](https://en.wikipedia.org/wiki/Circle_of_fifths).

Three parameters turn that idea into a 24-by-24 matrix:

<table class="article-table">
  <thead>
    <tr>
      <th>Parameter</th>
      <th>Value</th>
      <th>Meaning</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">selfTransition</td>
      <td class="mono">0.9</td>
      <td>
        Share of the prediction that stays in the current key from one
        event to the next
      </td>
    </tr>
    <tr>
      <td class="mono">fifthsDecay</td>
      <td class="mono">0.5</td>
      <td>
        Multiplier per step of key-signature distance around the
        circle of fifths, so each additional step halves the raw
        weight assigned to a switch
      </td>
    </tr>
    <tr>
      <td class="mono">modeSwitchFactor</td>
      <td class="mono">0.5</td>
      <td>
        Additional discount when the destination flips major to minor
        or back
      </td>
    </tr>
  </tbody>
</table>

A high self-transition is what buys stability. An established belief in C major
survives a bar of chords that lean elsewhere because moving probability to a new
key has a cost. Only sustained contrary evidence pays it. This is the
probability-based version of what a debounce or hysteresis rule approximates,
rather than a separate filter added after the fact.

### Cadences get a discount

One addition modifies the prediction step. Some chord pairs are the musical
equivalent of a period at the end of a sentence: a two-chord move that says "we
have landed here." Musicians call this a cadence. When the detector sees one, it
makes that destination temporarily easier to reach. In the matrix, that means
increasing the transition weight into the arrival key, then scaling the row back
down so all of its probabilities still add up to 1.

<pre><code><span class="cm">// Ordinary row: mass spreads by distance.</span>
<span class="cm">// Cadence row: the target's weight is boosted, then renormalized.</span>
<span class="kw">final</span> rowNorm = <span class="nu">1</span> + (boost - <span class="nu">1</span>) * row[cadenceKey];
<span class="kw">for</span> (<span class="kw">var</span> to = <span class="nu">0</span>; to &lt; <span class="nu">24</span>; to++) {
  <span class="kw">final</span> weight = to == cadenceKey ? row[to] * boost : row[to];
  predicted[to] += mass * weight / rowNorm;
}</code></pre>

The important detail is _where_ this happens. The cadence changes the prediction
made before scoring the new chord, not the chord's evidence score. It gives the
model a credible reason to move at that moment, while ordinary drifting still
pays the full switch cost. If the cadence lands in the key the model already
favors, it reinforces that key instead.

The shipped pattern is deliberately narrow. A tense dominant-seventh chord or
close relative must point toward the next chord's root (the note its name starts
from), and the destination must sound like a stable major or minor chord rather
than another dominant. A plain major chord is not enough. These restrictions
keep ordinary movement, especially blues, from looking like a key change.

## Score the evidence

The observation side asks a narrower question: how well does what we have
recently heard match each of the 24 keys?

Each key has a **profile**, a 12-number template describing how strongly each
pitch class supports that key relative to its proposed home note. This engine
uses profiles derived from a large collection of written music and published by
[Albrecht and Shanahan (2013)](https://online.ucpress.edu/mp/article-abstract/31/1/59/62597/The-Use-of-Large-Corpora-to-Train-a-New-Type-of).
Scoring aligns the recent pitch-class histogram with each possible home note in
both major and minor, then takes the
[Pearson correlation](https://en.wikipedia.org/wiki/Pearson_correlation_coefficient),
a standard measure of how closely two numerical patterns share the same shape.
That gives 24 raw scores.

Two things shape that histogram before it is scored.

**Duration weighting.** Each event is weighted by how long it was held, giving
sustained harmonies more influence than passing chords.

**A decaying window.** Evidence does not accumulate forever; it fades
exponentially on a half-life. This dial turns out to be the single most
consequential number in the system. After one half-life, a chord contributes
half as much as it originally did; after two, it contributes a quarter as much.
A short half-life therefore makes each observation a snapshot of the immediate
chords, which tracks brief detours closely. A long one makes it a summary of the
current section, which absorbs those detours and reports the settled key.

Neither is more accurate in the abstract. Each is right about a different
question, and which one you want is a design decision rather than a correctness
one. The app ships a four-second half-life by default and exposes the choice as
a setting.

### Turning scores into a distribution

The 24 correlations are not probabilities. A
[softmax](https://en.wikipedia.org/wiki/Softmax_function) converts them into an
**emission**, the probability distribution representing the evidence at this
event across all 24 keys. An **emission temperature** controls how strongly the
best-matching profile can pull away from the rest:

<pre><code><span class="kw">final</span> top = scores.<span class="fn">reduce</span>(math.max);
<span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) {
  <span class="cm">// Subtract the max before exponentiating: same result,</span>
  <span class="cm">// no overflow.</span>
  emission[k] = math.<span class="fn">exp</span>((scores[k] - top) / emissionTemperature);
  total += emission[k];
}
<span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) emission[k] /= total;</code></pre>

At the shipped temperature of `0.25` the distribution is fairly sharp: a
well-matched key pulls hard. Raising it flattens the evidence so no single event
can move the belief as much. The value is fixed rather than exposed as a user
setting.

### Choosing major or minor

A prominent residual error in this detector is reporting the wrong mode: C minor
instead of C major. A single rule addresses it. When a clearly major or minor
chord arrives, its root also names a pair of possible keys. A C major chord, for
example, is direct evidence in the choice between the C major and C minor keys.
The rule moves probability toward the member of that pair whose mode matches the
chord.

The containment matters more than the rule. The shift keeps the pair's total
probability unchanged: whatever major gains, minor loses.

<pre><code><span class="kw">final</span> pairSum = emission[majorK] + emission[minorK];
<span class="kw">final</span> factor = math.<span class="fn">exp</span>(modeTilt * direction);
<span class="kw">final</span> major = emission[majorK] * factor;
<span class="kw">final</span> minor = emission[minorK] / factor;
<span class="kw">final</span> rescale = pairSum / (major + minor);
emission[majorK] = major * rescale;
emission[minorK] = minor * rescale;</code></pre>

Because the pair sum is conserved, the rule can decide between C major and C
minor but is structurally incapable of shifting support toward G major or any
other home note. Broader rules that try to interpret a chord's role in a
progression can move evidence toward many possible keys; they are not part of
the shipped configuration. This rule earns its place precisely because it cannot
reach past the two keys it is choosing between.

## Observe

The update itself is deliberately simple: multiply each key's predicted
probability by the evidence for that key, then scale all 24 results so they add
back up to 1.

<pre><code><span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) {
  predicted[k] *= emission[k];
  total += predicted[k];
}
<span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) predicted[k] /= total;</code></pre>

This is the [forward algorithm](https://en.wikipedia.org/wiki/Forward_algorithm)
run in streaming order. After each event, it gives the probability of each key
using everything heard so far and nothing from the future. Its offline
counterpart,
[Viterbi decoding](https://en.wikipedia.org/wiki/Viterbi_algorithm), finds the
single most probable key sequence over a complete piece and would let the ending
explain the beginning. That can produce a more coherent retrospective analysis,
but it is unusable here because the future does not exist yet.

The result is a **posterior**: a model probability rather than an arbitrary
score. It still needs calibration before it can be displayed as real-world
confidence.

## Claim or abstain

At every event the detector ranks all 24 keys. It speaks only if the leader is
ahead of the runner-up by at least a **margin floor**, shipped at `0.3` on the
model's zero-to-one scale.

This is not a confidence display threshold. It decides whether there is an
answer at all. On a modal vamp, several major-or-minor interpretations may
explain the notes similarly well, so the gap opens less often and the detector
is more likely to stay quiet. That is preferable to forcing the music into a key
the model cannot represent faithfully.

Abstention is treated as a first-class outcome throughout: it is never scored as
an error, and the evaluation reports **coverage** (how often the detector
speaks) alongside accuracy. A detector can make its accuracy look good by
refusing every difficult case, or make its coverage look good by guessing every
time, so neither number is meaningful alone.

## Making the confidence number honest

The raw model is systematically overconfident. In the original held-out check,
it reported roughly 91% confidence in situations where it was right about 72% of
the time. Put plainly, a user seeing "91%" would expect about 91 correct answers
out of 100, while the detector was actually producing about 72.

The fix is [temperature scaling](https://en.wikipedia.org/wiki/Platt_scaling), a
one-number correction. Raise every probability to `1/T`, then scale the results
so they add back up to 1. When `T` is above 1, this lowers the leader and shares
more probability with the alternatives.

The value of `T` was fitted using development music with human-authored key
labels. The transformation preserves the candidates' order, so the first-place
key remains first. More importantly, it is applied only after the detector has
decided whether to claim or abstain. The detector's internal arithmetic still
runs on the raw values, so calibration changes the percentage shown to the user
without changing any answer.

## The behavior presets

The app exposes three key detection behaviors as a user setting: Stable,
Balanced, and Reactive. The half-life is the one value that changes the
detector's arithmetic. Each preset also has its own confidence correction and a
stale interval, which controls how long an idle result remains current-looking
before the interface dims it.

<table class="article-table">
  <thead>
    <tr>
      <th>Preset</th>
      <th>Evidence half-life</th>
      <th>Confidence correction (T)</th>
      <th>Dims after</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Stable</td>
      <td class="mono">30 s</td>
      <td class="mono">1.55</td>
      <td class="mono">30 s</td>
    </tr>
    <tr>
      <td>Balanced</td>
      <td class="mono">4 s</td>
      <td class="mono">1.5</td>
      <td class="mono">20 s</td>
    </tr>
    <tr>
      <td>Reactive</td>
      <td class="mono">1 s</td>
      <td class="mono">1.75</td>
      <td class="mono">10 s</td>
    </tr>
  </tbody>
</table>

The confidence correction is the `T` from the previous section. It is fitted
separately for each timescale because raw confidence behaves differently when
the detector remembers a few recent chords instead of a whole section.

The stale interval changes presentation, not inference: it stops an old answer
from looking current after the player goes quiet. After two minutes without a
chord, all three behaviors reset the detector entirely.

Every other detector setting is shared across the three. Transition persistence,
the internal evidence-scoring temperature, and the margin floor can each affect
responsiveness, but less cleanly than the half-life already does. The presets
therefore leave those settings alone.

What the presets trade is responsiveness against steadiness, not accuracy
against inaccuracy. Reactive catches substantially more real key changes and
catches them sooner. The same short memory also lets a brief harmonic detour
look like a new key, so it changes its answer more often when the music never
truly left, and it abstains more often while the evidence is thin. Those are the
same property seen from two sides. Picking a preset means choosing which side
matters more to you.

## Closing the loop

The detected key does not stay in the key indicator. In Auto mode, once the
visible detector makes the same claim on two consecutive chord events, that key
becomes the app's current key. It is then passed to
[the chord recognizer](chord-recognition-algorithm.html), whose ranking rules
can prefer readings that naturally belong to the key, prefer the chord built on
its home note, and choose between two chord names that account for the same
sounding notes.

The app runs a second copy of the detector because the key indicator and chord
naming need different behavior. The visible copy follows the user's Stable,
Balanced, or Reactive setting and may deliberately favor a steady section-level
answer. The internal copy never appears on screen and is always Reactive, so it
can follow shorter local key changes. In Auto mode, it helps Ensemble mode
choose among plausible readings, including chords whose root is implied rather
than played. In every mode, it can also re-rank the immediately preceding
history entry after the next chord supplies evidence that one earlier name makes
better sense. Only the immediately preceding entry can change. That correction
improves the user-facing history only. Live Ensemble naming uses the internal
key directly; the corrected entry is not fed into either detector or used to
name later chords.

Chord recognition produces the events key detection consumes, and key detection
supplies context that chord recognition may rank under. The live chord analyzer
remains memoryless. The visible-key side of this cycle is deliberately weak:
adopting the displayed key changes the chosen chord name on roughly 0.4% of
events, and feeding those changed names back has no measurable effect on key
detection. Tighter coupling would risk the two engines reinforcing each other's
mistakes.

## How the numbers were chosen

The constants above were not chosen arbitrarily. They began as reasonable
starting points from music theory and established modeling practice, then
candidate values were compared on development music with human-authored key
labels. Popular songs and classical scores were evaluated separately. We tracked
not just whether claimed keys were correct, but how often the detector was
willing to answer, how quickly it found real key changes, and how often it
invented them. Focused fixtures supplied specific stress cases such as blues
progressions, jazz progressions, and modal vamps.

Only after the choices were fixed did we run a separate set of held-out pieces
reserved for the final check. Keeping the development and evaluation music
separate matters: tuning and grading on the same pieces can make an improvement
look far more general than it is. The
[research archive](https://github.com/EarthmanMuons/whatchord/tree/main/research)
records the alternatives that failed as well as the settings that shipped.

## What it does not handle

- **Polytonality and atonality.** The model assumes one key at a time from a
  fixed vocabulary of 24, so it cannot represent music that is genuinely in two
  keys at once, or in none.
- **Diatonic modes beyond major and minor.** Dorian, Mixolydian, and the other
  diatonic modes have no state of their own, so a modal passage is scored
  against whichever of the 24 major or minor keys it most resembles.
- **Anything outside twelve-tone equal temperament.** Microtonal intervals and
  fine pitch differences between tuning systems have no representation in the
  standard system of twelve equally spaced notes per octave used by this
  pitch-class model.

## The codebase

The detector is written in [Dart](https://dart.dev/) and lives in
[`packages/whatkey/`](https://github.com/EarthmanMuons/whatchord/tree/main/packages/whatkey).
It consumes the chord-event model from
[`packages/whatchord/`](https://github.com/EarthmanMuons/whatchord/tree/main/packages/whatchord),
the engine described in the companion article. Both are standalone packages with
no framework dependencies; only the app around them is
[Flutter](https://flutter.dev/). The evaluation harness, music-dataset
importers, and tools that compare detector versions on the same pieces live in
[`tool/whatkey/`](https://github.com/EarthmanMuons/whatchord/tree/main/tool/whatkey).

The project is open source under the Zero Clause BSD License, so you are free to
use, modify, and share it however you like.

<div class="article-cta">
  <h3>Watch it follow along.</h3>
  <p>
    WhatChord names chords and tracks the key as you play, on-device.
    Free for iOS and Android, with no subscription and no ads.
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
    Want the evidence?
    <a
      href="https://github.com/EarthmanMuons/whatchord/tree/main/research"
      >Read the research notes</a
    >
  </p>
</div>

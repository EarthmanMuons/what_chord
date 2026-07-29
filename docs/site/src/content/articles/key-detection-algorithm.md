---
cardDescription:
  "The 24-state hidden Markov model, profile-correlation evidence, decaying
  memory, and abstention rule behind live key detection."
cardTitle: "Building a Streaming Key Detector"
decks:
  - "Naming the chord you are playing is one problem. Working out what key you
    are in, while you are still playing, is a different one. This is the model
    that does it: 24 competing hypotheses, evidence that fades, and a rule for
    staying quiet when the answer is not clear yet."
description:
  "A technical deep-dive into the hidden Markov model, profile-correlation
  emissions, decaying evidence window, transition prior, and abstention
  threshold behind WhatChord's live key detection."
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

The textbook approach to key detection is a correlation. Count how much of each
of the twelve pitch classes a piece contains, compare that histogram against a
published template for each of the 24 major and minor keys, and return whichever
key matches best. It is a good algorithm, it is about fifty lines of code, and
for answering "what key is this song in" after the song has finished it works
well enough that several standard implementations ship it.

Three constraints make it insufficient on its own.

**The answer has to arrive while the music is still happening.** The detector
sees the past and only the past. It cannot read ahead to the cadence that would
have explained an ambiguous opening, and it cannot revise what it already
displayed. That rules out the entire family of offline techniques that decode a
best path over a complete sequence.

**The input is not raw MIDI.** It is the output of
[the chord recognizer](chord-recognition-algorithm.html): a stream of committed
chord events containing the pitch classes that sounded, the chosen chord
identity, and how long the chord lasted. The upstream stage has already made
judgment calls, and it is sometimes wrong.

**Sometimes there is no answer, and saying so is correct.** A modal vamp may
have a clear tonal center without fitting any of the 24 major and minor keys the
detector knows. Two chords into a piece there may not be enough evidence for any
answer. A detector that must always name something will name something wrong,
and a key indicator that confidently flickers between wrong answers is worse
than one that stays blank.

What that combination needs is not a better histogram. It is a model that
carries a _belief_ forward through time, updates it as evidence arrives, and
knows how sure it is.

## Overview: predict, observe, decide

The detector is a
[hidden Markov model](https://en.wikipedia.org/wiki/Hidden_Markov_model) over 24
states, one per key. It never observes the key directly; it observes chords, and
infers a probability distribution over which key is generating them. One chord
event goes in, one updated distribution comes out.

<div class="pipeline-flow">
  <div class="pf-endpoint">
    Input: one committed chord event (sounding pitch classes, chosen
    chord identity, duration)
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
      Multiply prediction by evidence, renormalize; this is the new
      belief
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

Everything below is one of those boxes.

## The state space

Twenty-four states: twelve tonics times two modes, where _mode_ means major or
minor. The belief is a plain array of 24 probabilities that sums to 1,
initialized uniform at `1/24` each.

<pre><code><span class="kw">final</span> List&lt;<span class="kw">double</span>&gt; _posterior = <span class="kw">List</span>.<span class="fn">filled</span>(<span class="nu">24</span>, <span class="nu">1</span> / <span class="nu">24</span>);</code></pre>

Alongside it is a 12-number pitch-class histogram holding the decaying evidence
described below. The detector also remembers the previous recognized chord, an
event count, and enough timing information to fade old evidence. All of that
state is fixed in size. The app does keep a growing list of the chords you have
played for its history view, but the detector never reads it, so the cost of an
update is the same on the first chord and the thousandth.

## Predict: what the key is likely to do next

Before looking at the new chord, the belief is carried forward through a
transition model, which encodes one assumption: keys persist. Most of the
probability mass stays where it is, and the remainder spreads to other keys with
nearer ones favored.

Three parameters build the matrix:

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
        Probability mass that stays in the current key from one event
        to the next
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
survives a bar of chords that lean elsewhere, because moving the mass costs
something, and only sustained contrary evidence pays that cost. This is the
principled version of what a debounce or a hysteresis rule approximates, except
that it falls out of the probability arithmetic rather than sitting on top as a
separate filter.

### Cadences get a discount

One addition modifies the prediction step. Some chord pairs are the musical
equivalent of an arrival: a particular two-chord move that says "we have landed
somewhere new." When the detector sees one, it relaxes the persistence for that
one destination, multiplying the transition mass into the arrival key by a boost
and renormalizing the row so the total is still a probability distribution.

<pre><code><span class="cm">// Ordinary row: mass spreads by distance.</span>
<span class="cm">// Cadence row: the target's weight is boosted, then renormalized.</span>
<span class="kw">final</span> rowNorm = <span class="nu">1</span> + (boost - <span class="nu">1</span>) * row[cadenceKey];
<span class="kw">for</span> (<span class="kw">var</span> to = <span class="nu">0</span>; to &lt; <span class="nu">24</span>; to++) {
  <span class="kw">final</span> weight = to == cadenceKey ? row[to] * boost : row[to];
  predicted[to] += mass * weight / rowNorm;
}</code></pre>

The important detail is _where_ this lives. It conditions the transition prior,
not the evidence: it gives the model permission to move at the moment harmony
licenses a key change, while ordinary drifting still pays the full switch cost.
Because each row renormalizes, a cadence in the key you are already in
stabilizes that key rather than leaking mass outward.

The pattern has to be matched narrowly, because two chords that look like an
arrival are not always one. The first must have the distinctive tension of a
dominant-seventh-family chord and point conventionally toward the root of the
next chord. A plain major chord is not enough. The destination must then sound
settled in major or minor, rather than like another chord demanding onward
motion. Without those restrictions, ordinary movement inside a key can read as a
key change every few bars. A plain blues progression is especially vulnerable.

## Score the evidence

The observation side asks a narrower question: how well does what we have
recently heard match each of the 24 keys?

Each key has a **profile**, a 12-number template describing how strongly each
pitch class characterizes it relative to the proposed tonic. Several published
pairs exist; this engine uses the corpus-trained pair from
[Albrecht and Shanahan (2013)](https://online.ucpress.edu/mp/article-abstract/31/1/59/62597/The-Use-of-Large-Corpora-to-Train-a-New-Type-of),
which performs notably better in minor keys than the older probe-tone profiles.
Scoring rotates the recent pitch-class histogram against each tonic in both
modes and takes the
[Pearson correlation](https://en.wikipedia.org/wiki/Pearson_correlation_coefficient),
which gives 24 raw scores.

Two things shape that histogram before it is scored.

**Duration weighting.** Each event contributes in proportion to how long it was
held, so a whole-note chord counts for more than a passing eighth. It is on by
default.

**A decaying window.** Evidence does not accumulate forever; it fades
exponentially on a half-life. This dial turns out to be the single most
consequential number in the system, and it is worth being precise about why. A
short half-life makes each observation a snapshot of the immediate harmony,
which tracks brief excursions closely. A long one makes it a summary of the
current section, which absorbs those excursions and reports the settled key.

Neither is more accurate in the abstract. Each is right about a different
question, and which one you want is a design decision rather than a correctness
one. The app ships a four-second half-life by default and exposes the choice as
a setting.

### Turning scores into a distribution

The 24 correlations are not probabilities. A
[softmax](https://en.wikipedia.org/wiki/Softmax_function) converts them, with a
temperature controlling how decisive a single event is allowed to be:

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
can move the belief much, which trades responsiveness for calm along the same
curve the half-life already controls, which is why only one of the two is
exposed as a user setting.

### One targeted nudge

A prominent residual error in this detector is reporting the wrong mode: C minor
instead of C major. A single rule addresses it. When the chord just played is
rooted on some tonic and has a clearly major or clearly minor quality,
probability shifts toward the matching twin of that pair.

The construction matters more than the rule. The shift is _mass-preserving
within the pair_: whatever major gains, minor loses, and the pair's total is
unchanged.

<pre><code><span class="kw">final</span> pairSum = emission[majorK] + emission[minorK];
<span class="kw">final</span> factor = math.<span class="fn">exp</span>(modeTilt * direction);
<span class="kw">final</span> major = emission[majorK] * factor;
<span class="kw">final</span> minor = emission[minorK] / factor;
<span class="kw">final</span> rescale = pairSum / (major + minor);
emission[majorK] = major * rescale;
emission[minorK] = minor * rescale;</code></pre>

Because the pair sum is conserved, the rule can decide between C major and C
minor but is structurally incapable of shifting support toward G major or any
other tonic. That containment is the whole design. Broader chord-function rules,
which can move evidence toward any key at all, are not part of the shipped
configuration. This one earns its place precisely because it cannot reach past
the two keys it is arbitrating between.

## Observe

The update itself is unremarkable, which is the point of having done the work in
the two previous steps: multiply the prediction by the evidence, renormalize.

<pre><code><span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) {
  predicted[k] *= emission[k];
  total += predicted[k];
}
<span class="kw">for</span> (<span class="kw">var</span> k = <span class="nu">0</span>; k &lt; <span class="nu">24</span>; k++) predicted[k] /= total;</code></pre>

This is the [forward algorithm](https://en.wikipedia.org/wiki/Forward_algorithm)
run causally: after each event, the probability of each key given everything
heard so far and nothing from the future. Its offline counterpart,
[Viterbi decoding](https://en.wikipedia.org/wiki/Viterbi_algorithm), finds the
single most probable key sequence over a complete piece and would let the ending
explain the beginning. It produces better analyses and is unusable here, because
the future does not exist yet.

One consequence worth stating: the update produces a normalized model posterior,
not an arbitrary score squashed into a zero-to-one range. The number attached to
the leading key describes the model's belief under its own assumptions. It still
needs the calibration described below before it can be read as a real-world
estimate of how often that answer is correct.

## Claim or abstain

At every event the detector ranks all 24 keys. It speaks only if the leader is
ahead of the runner-up by at least a **margin floor**, shipped at `0.3`.

This is not a confidence display threshold. It gates whether there is an answer
at all. On a modal vamp, several major-or-minor interpretations may explain the
notes similarly well, so the margin opens less often and the detector is more
likely to stay quiet. That is preferable to forcing the music into a key the
model cannot represent faithfully.

Abstention is treated as a first-class outcome throughout: it is never scored as
an error, and the evaluation reports **coverage** (how often the detector
speaks) alongside accuracy, because either number alone can be gamed by trading
against the other.

## The behavior presets

The app exposes three key detection behaviors as a user setting: Stable,
Balanced, and Reactive. They are not three accuracy tiers, and describing them
that way would be dishonest. The half-life is the one value that changes the
detector's arithmetic. Each preset also has matching display calibration and a
stale interval: how long an idle result remains current-looking before the
interface dims it.

<table class="article-table">
  <thead>
    <tr>
      <th>Preset</th>
      <th>Evidence half-life</th>
      <th>Confidence softening</th>
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

The stale interval changes presentation, not inference: it stops an old answer
from looking current after the player goes quiet. After two minutes without a
chord, all three behaviors reset the detector entirely.

Every other detector dial is shared across the three. The transition
persistence, the emission temperature, and the margin floor can each be set
independently, but every one of them reproduces the same responsiveness
trade-off less cleanly than the half-life already does, so all three presets run
a single value.

What the presets trade is responsiveness against steadiness, not accuracy
against inaccuracy. Reactive catches substantially more real key changes and
catches them sooner. The same short memory that lets it react also lets a
colorful passage look like a new key, so it changes its answer more often on
music that never actually left, and it abstains more often while the evidence is
thin. Those are the same property seen from two sides, and picking a preset is
choosing which side you would rather have.

## How the numbers were chosen

The constants above were not chosen arbitrarily. They began as reasonable
starting points from music theory and established modeling practice, then
candidate values were compared on annotated development music. Popular songs and
classical scores were evaluated separately. We tracked not just whether claimed
keys were correct, but how often the detector was willing to answer, how quickly
it found real key changes, and how often it invented them. Focused fixtures
supplied specific stress cases such as blues progressions, jazz progressions,
and modal vamps.

Only after the choices were fixed did we run a separate set of held-out pieces
reserved for the final check. Keeping the development and evaluation music
separate matters: tuning and grading on the same pieces can make an improvement
look far more general than it is. The
[research archive](https://github.com/EarthmanMuons/whatchord/tree/main/research)
records the alternatives that failed as well as the settings that shipped.

## Making the confidence number honest

The raw posterior is systematically overconfident. In the original held-out
check, the detector claimed roughly 91% confidence in situations where it turned
out to be right about 72% of the time. That gap is normal for this class of
model and it is a problem only because the number is on screen.

The fix is [temperature scaling](https://en.wikipedia.org/wiki/Platt_scaling), a
one-number correction: raise every probability to `1/T`, renormalize, and choose
`T` against labeled data. Above 1 it flattens an overconfident distribution.

The transformation preserves the candidates' order, so the first-place key
remains first. More importantly, it is applied only after the detector has
decided whether to claim or abstain. The detector's internal arithmetic runs on
the raw values, which makes every ranking and decision identical whether or not
the calibrated confidence is displayed.

## Closing the loop

The detected key does not stay in the key indicator. In Auto mode, once the
visible detector makes the same claim on two consecutive chord events, that key
becomes the app's current tonality. It enters the analysis context that
[the chord recognizer](chord-recognition-algorithm.html) runs against, where
several ranking rules consult it: preferring diatonic readings, preferring the
tonic, and deciding between two chords that contain identical notes.

The app also runs a second copy of the detector behind the scenes. It is always
set to Reactive, regardless of the behavior chosen for the visible key
indicator, because chord naming benefits from a faster-moving hint than the
display necessarily should. In Auto mode, that internal key helps the ensemble
ranker choose among plausible chord readings. In every mode, it can also help
re-rank the immediately preceding history entry after the next chord arrives.
That one-event look-ahead is how the record can resolve a brief ambiguity
without pretending that the live key display knew the future.

This correction serves a different purpose from the live feedback loop. A new
chord can reveal which of two earlier readings makes musical sense, evidence
that the causal analyzer could not have had at the time. Such cases are rare,
but revisiting one history entry improves the record without making live
analysis stateful or feeding the revised entry back into either detector.

So the engines form a deliberately limited cycle. Chord recognition produces the
events key detection consumes; key detection supplies context that chord
recognition may rank under. The live chord analyzer itself remains memoryless,
while the history correction is explicitly bounded to one event.

The visible-key side of that loop is deliberately weak. Measured directly,
adopting the displayed key changes the top chord identity on roughly 0.4% of
events, and feeding those corrected identities back has no measurable effect on
key detection. A tighter coupling would risk the two engines reinforcing each
other's mistakes; at this strength they simply inform each other.

## What it does not handle

- **Polytonality and atonality.** The model assumes one key at a time from a
  fixed vocabulary of 24. Music that is genuinely in two keys at once, or in
  none, gets the best single-key description of it, though the margin floor
  means genuinely keyless passages tend to produce abstention rather than a
  confident wrong answer.
- **Modes beyond major and minor.** Dorian, Mixolydian, and the rest have no
  state of their own, so a modal passage is scored against whichever of the 24
  keys it most resembles. In practice the margin opens less often, so the
  detector is more likely to abstain than it is on music that fits the model's
  vocabulary.
- **Anything outside twelve-tone equal temperament.** Microtonal intervals and
  just-intonation distinctions have no representation in the pitch-class model
  the evidence is built from.
- **Retroactive correction of the live display.** The detector is causal by
  requirement, so an opening that only makes sense in hindsight stays as first
  shown. The immediately preceding chord-history entry may be re-ranked once
  after the next chord arrives, when the internal key has moved or the new chord
  resolves a narrowly defined ambiguity. That is the chord list catching up, not
  the key indicator rewriting itself.

## The codebase

The detector is written in [Dart](https://dart.dev/) and lives in
[`packages/whatkey/`](https://github.com/EarthmanMuons/whatchord/tree/main/packages/whatkey).
It consumes the chord-event model from
[`packages/whatchord/`](https://github.com/EarthmanMuons/whatchord/tree/main/packages/whatchord),
the engine described in the companion article. Both are standalone packages with
no framework dependencies; only the app around them is
[Flutter](https://flutter.dev/). The evaluation harness, corpus extractors, and
paired statistics live in
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

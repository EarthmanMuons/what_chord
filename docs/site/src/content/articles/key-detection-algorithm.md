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

Three constraints break it here.

**The answer has to arrive while the music is still happening.** The detector
sees the past and only the past. It cannot read ahead to the cadence that would
have explained an ambiguous opening, and it cannot revise what it already
displayed. That rules out the entire family of offline techniques that decode a
best path over a complete sequence.

**The input is not notes.** It is the output of
[the chord recognizer](chord-recognition-algorithm.html): a stream of committed
chord events, each carrying ranked interpretations with their costs, a duration,
and a bass note. The upstream stage has already made judgment calls, and it is
sometimes wrong.

**Sometimes there is no answer, and saying so is correct.** A modal vamp has no
functional key. Two chords into a piece there is not enough evidence for any
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
    Input: one committed chord event (ranked readings, duration, bass)
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

One more fixed array sits alongside it, holding the decaying evidence described
below, and that is the whole of the detector's memory: two arrays of 24 numbers.
Nothing grows. The app does keep a list of the chords you have played, for the
history view and for relabeling, but the detector never reads it, so the cost of
an update is the same on the first chord and the thousandth.

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
        circle of fifths, so a key one accidental away gets half the
        remaining weight of a neighbor
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
arrival are not always one. The signal only fires on a stricter version of the
pattern that cannot be confused with ordinary movement inside a key, and it
refuses to treat the destination as an arrival if that chord is itself the kind
that usually leads somewhere else. Without those two restrictions a plain blues
progression reads as a key change every few bars.

## Score the evidence

The observation side asks a narrower question: how well does what we have
recently heard match each of the 24 keys?

Each key has a **profile**, a 12-number template describing how strongly each
scale degree characterizes it. Several published pairs exist; this engine uses
the corpus-trained pair from
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
question, and which one you want is a product decision rather than a correctness
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

The most visible residual error in any key detector is reporting the wrong mode:
C minor instead of C major. A single rule addresses it. When the chord just
played is rooted on some tonic and has a clearly major or clearly minor quality,
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

One consequence worth stating: because the update is a genuine Bayesian
posterior, the number attached to the leading key is a real probability rather
than a score that has been squashed into a zero-to-one range. That property is
what makes the abstention rule below meaningful.

## Claim or abstain

At every event the detector ranks all 24 keys. It speaks only if the leader is
ahead of the runner-up by at least a **margin floor**, shipped at `0.3`.

This is not a confidence display threshold. It gates whether there is an answer
at all. On a modal vamp, where two or three keys explain the notes equally well,
the margin never opens and the detector stays quiet indefinitely, which is the
correct behavior rather than a failure to converge.

Abstention is treated as a first-class outcome throughout: it is never scored as
an error, and the evaluation reports **coverage** (how often the detector
speaks) alongside accuracy, because either number alone can be gamed by trading
against the other.

The floor relaxes slightly at a cadence event, on the reasoning that a cadence
is the one moment a trusted structural signal has just moved the belief, so the
detector can afford to be braver exactly there.

## The behavior presets

The app exposes three key detection behaviors as a user setting: Stable,
Balanced, and Reactive. They are not three accuracy tiers, and describing them
that way would be dishonest: they differ in exactly two detector values, the
half-life above and a second number covered in the next section that keeps the
displayed percentage honest at that timescale.

<table class="article-table">
  <thead>
    <tr>
      <th>Preset</th>
      <th>Evidence half-life</th>
      <th>Confidence softening</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Stable</td>
      <td class="mono">30 s</td>
      <td class="mono">1.55</td>
    </tr>
    <tr>
      <td>Balanced</td>
      <td class="mono">4 s</td>
      <td class="mono">1.5</td>
    </tr>
    <tr>
      <td>Reactive</td>
      <td class="mono">1 s</td>
      <td class="mono">1.75</td>
    </tr>
  </tbody>
</table>

Every other dial is shared across the three. The transition persistence, the
emission temperature, and the margin floor can each be set independently, but
every one of them reproduces the same responsiveness trade-off less cleanly than
the half-life already does, so all three presets run a single value.

What the presets trade is responsiveness against steadiness, not accuracy
against inaccuracy. Reactive catches substantially more real key changes and
catches them sooner. The same short memory that lets it react also lets a
colorful passage look like a new key, so it changes its answer more often on
music that never actually left, and it abstains more often while the evidence is
thin. Those are the same property seen from two sides, and picking a preset is
choosing which side you would rather have.

## Making the confidence number honest

The raw posterior is systematically overconfident. Measured across held-out
data, the detector claimed roughly 91% confidence in situations where it turned
out to be right about 72% of the time. That gap is normal for this class of
model and it is a problem only because the number is on screen.

The fix is [temperature scaling](https://en.wikipedia.org/wiki/Platt_scaling):
raise every probability to `1/T`, renormalize, and fit the single parameter `T`
against labeled data. Above 1 it flattens an overconfident distribution.

The critical property is that it is monotonic. It never reorders the candidates,
so the ranked keys, the chosen key, and every abstention decision are
bit-identical before and after. It is applied to displayed probabilities only;
the detector's internal arithmetic runs on raw values. The confidence you read
has been corrected for honesty without the correction touching any decision.

## Closing the loop

The detected key does not stay in the key indicator. Once a claim persists for a
couple of events, it is adopted as the app's current tonality and written into
the analysis context that
[the chord recognizer](chord-recognition-algorithm.html) runs against, where
several ranking rules consult it: preferring diatonic readings, preferring the
tonic, and deciding between two chords that contain identical notes.

So the two engines form a cycle. Chord recognition produces the events key
detection consumes; key detection produces the context chord recognition ranks
under. The chord analyzer itself remains memoryless, and every piece of temporal
information that reaches chord naming arrives through the key.

That loop is deliberately weak in one direction. Measured directly, the adopted
key changes the top chord identity on roughly 0.4% of events, and the effect on
key detection of feeding those corrected identities back is nil. A tighter
coupling would risk the two engines reinforcing each other's mistakes; at this
strength they simply inform each other.

## What it does not handle

- **Polytonality and atonality.** The model assumes one key at a time from a
  fixed vocabulary of 24. Music that is genuinely in two keys at once, or in
  none, gets the best single-key description of it, though the margin floor
  means genuinely keyless passages tend to produce abstention rather than a
  confident wrong answer.
- **Modes beyond major and minor.** Dorian, Mixolydian, and the rest have no
  state of their own, so a modal passage is scored against whichever of the 24
  keys it most resembles. In practice the margin rarely opens on one, and the
  detector stays quiet instead of picking.
- **Anything outside twelve-tone equal temperament.** Microtonal intervals and
  just-intonation distinctions have no representation in the pitch-class model
  the evidence is built from.
- **Retroactive correction of the live display.** The detector is causal by
  requirement, so an opening that only makes sense in hindsight stays as first
  shown. Entries in the chord history are re-named once the following chord
  resolves the ambiguity, but that is the chord list catching up, not the key
  indicator rewriting itself.

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
      href="https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey"
      >Read the research notes</a
    >
  </p>
</div>

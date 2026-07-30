---
cardDescription:
  "How WhatChord turns note-by-note MIDI input into stable chord events, and the
  measurements behind its 200 ms stability window."
cta:
  description:
    "WhatChord turns live MIDI into stable chord names and history, on-device.
    Free for iOS and Android, with no subscription and no ads."
  secondary:
    href: "https://github.com/EarthmanMuons/whatchord/tree/main/research/performed-input"
    label: "Read the performed-input research"
    lead: "Want the evidence?"
  storeBadges: true
  title: "Watch each chord land."
decks:
  - "MIDI does not send chords. It sends note presses and releases one at a
    time. Between a player’s intention and a useful chord event are rolled
    attacks, passing notes, pedal-held tones, and a recognizer that may briefly
    change its mind."
  - "WhatChord uses a small state machine to decide which chord names count,
    where their boundaries belong, and why the app waits one fifth of a second
    before committing."
description:
  "How WhatChord turns continuous, note-by-note MIDI input into stable chord
  events using a pending-challenger state machine, onset-preserving boundaries,
  and a measured 200 ms stability window."
group: "technical"
indexOrder: 5
related:
  - "chord-recognition-algorithm"
  - "key-detection-algorithm"
  - "measuring-how-wrong-we-are"
socialDescription:
  "MIDI sends notes, not chord boundaries. Here is how WhatChord turns a noisy
  stream of live playing into stable chord events, and why it waits 200 ms
  before believing a new name."
socialTitle: "Turning Live MIDI Into Chord Events"
tag: "Technical deep-dive"
title: "Turning Live MIDI Into Chord Events"
---

## MIDI does not contain chord boundaries

Press C, E, and G on a keyboard and the musical idea may be one
<span class="chord">C major</span> chord. The MIDI connection reports three
separate note-on messages. They may arrive a few milliseconds apart, or much
farther apart if the chord is played as an arpeggio. Releases arrive separately
too, while the sustain pedal can keep old notes sounding underneath the next
harmony.

During one ordinary gesture, the sounding-note state might pass through C alone,
then C-E, then C-E-G, then C-E-G-D, and finally C-E-G again. Once enough notes
sound to form a chord, [the chord recognizer](chord-recognition-algorithm.html)
analyzes each new snapshot. Some snapshots are meaningful chords. Others are
just the route a pair of hands took between them.

Recognition and segmentation answer different questions:

- The recognizer asks, “What chord best explains the notes sounding right now?”
- The segmenter asks, “Did that reading last long enough to count as something
  the player meant?”

Without the second question, chord history would fill with brief in-between
shapes. The key detector would treat every one as fresh harmonic evidence, and
the chord name on screen would flicker through interpretations that no musician
intended to hold.

## From snapshots to events

The input path has one more stage than a static chord-recognition diagram
usually shows:

<div class="pipeline-flow">
  <div class="pf-endpoint">
    Input: MIDI note-on, note-off, and sustain-pedal messages
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Sounding-note state</div>
    <div class="pf-sub">
      Merge physically held notes with notes still held by the pedal
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Chord recognition</div>
    <div class="pf-sub">
      Rank the plausible names for the current snapshot
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-box">
    <div class="pf-name">Chord-event segmentation</div>
    <div class="pf-sub">
      Decide whether the leading identity is stable and where its event begins
      and ends
    </div>
  </div>
  <div class="pf-arrow">↓</div>
  <div class="pf-endpoint">
    Output: a stable display reading and committed events for history and key
    detection
  </div>
</div>

A **chord event** is more than a name. It records when the chord began, how long
it lasted, which pitch classes sounded, which one was in the bass, the exact
MIDI voicing, the recognizer’s selected identity, and the nearby alternative
readings available at that moment. It also preserves the tonality and playing
context used for ranking, along with how far apart the candidates scored.
Downstream code can therefore interpret the original decision and measure its
ambiguity without rerunning recognition. The history stays in memory only. The
[streaming key detector](key-detection-algorithm.html) consumes these events
rather than the much noisier stream of raw note changes.

Single notes and intervals still appear in the interface, but they are not chord
events. Capture begins only when the recognizer has a chord candidate, which
currently requires at least three sounding notes.

## Segment identities, not note changes

The segmenter follows the recognizer’s selected **chord identity**: the root,
bass, quality, extensions, and which chord tones are actually present. Together,
these make one reading distinct from another. The segmenter does not start a new
event merely because the sounding MIDI notes changed.

Adding another C to a held C major chord changes the voicing but not its
identity, so the event continues. The same is true when a doubled note is
released. This keeps octave doubling above the bass from turning one held
harmony into several artificial events. Changing the lowest note can instead
change the chord’s inversion, which is a different identity and receives its own
event.

An event snapshots its musical data when that identity first appears.
Same-identity changes do not rewrite the snapshot later. That makes the record
deterministic: its notes, candidate ranking, and analysis context all describe
the same moment.

## A challenger has to earn the change

When the selected identity changes, the segmenter does not immediately end the
current chord. The new identity becomes a **pending challenger**.

If the original identity returns before the challenger survives the 200 ms
stability window, the challenger is discarded. The original chord continues as
one uninterrupted event. A brief added note can therefore produce a fleeting
<span class="chord">Cadd9</span> reading without splitting a held
<span class="chord">C major</span> chord in two.

If the challenger does survive, it becomes the current chord and the previous
one is committed if it lasted long enough. Crucially, the boundary is placed at
the challenger’s original onset, not 200 ms later:

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Time</th>
      <th scope="col">Recognizer output</th>
      <th scope="col">Segmenter state</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">0 ms</td>
      <td>C major</td>
      <td>C major becomes current</td>
    </tr>
    <tr>
      <td class="mono">800 ms</td>
      <td>F major</td>
      <td>F major becomes the pending challenger</td>
    </tr>
    <tr>
      <td class="mono">1,000 ms</td>
      <td>(No change; timer fires)</td>
      <td>F major is accepted; C major ends at 800 ms</td>
    </tr>
  </tbody>
</table>

The decision arrives at 1,000 ms, but the stored history still says the musical
change happened at 800 ms. Waiting for stability adds display and commit
latency; it does not move the recorded timing or shorten the accepted chord.

A release, a drop below three notes, or another loss of a valid chord candidate
closes capture immediately rather than waiting for another timer. Before
handling any observation, including a release, the segmenter first promotes a
challenger whose deadline has passed. A release after that deadline can
therefore commit two events: the old chord through the challenger’s onset, then
the newly accepted chord through the release. If the challenger is still inside
its window, the old chord ends at the challenger’s onset and the unresolved
challenger is discarded. Events that never lasted 200 ms are dropped.

<!-- prettier-ignore -->
<figure class="segmenter-state-diagram">
  <div class="state-priority-rule">
    <strong>Before every observation:</strong> promote any challenger whose 200
    ms deadline has passed.
  </div>
  <div
    class="state-diagram-scroll"
    role="group"
    aria-label="Scrollable chord-event state machine diagram"
    tabindex="0"
  >
    <svg
      viewBox="0 0 780 490"
      role="img"
      aria-labelledby="segmenter-state-title segmenter-state-desc"
    >
      <title id="segmenter-state-title">
        The chord-event segmenter’s three states
      </title>
      <desc id="segmenter-state-desc">
        An eligible chord moves the segmenter from no active chord to tracking
        the current chord. A different identity becomes a pending challenger.
        If the original returns before 200 milliseconds, the challenger is
        discarded. If the deadline passes, the current chord ends at the
        challenger’s onset, is committed if it lasted long enough, and the
        challenger is promoted. Release commits the current chord if it lasted
        long enough, while release before a challenger’s deadline discards that
        challenger.
      </desc>
      <defs>
        <marker
          id="segmenter-arrow"
          viewBox="0 0 10 10"
          refX="9"
          refY="5"
          markerWidth="7"
          markerHeight="7"
          orient="auto-start-reverse"
        >
          <path class="state-arrowhead" d="M 0 0 L 10 5 L 0 10 z"></path>
        </marker>
      </defs>
      <g class="state-nodes">
        <rect class="state-node" x="35" y="190" width="190" height="76" rx="14">
        </rect>
        <text class="state-node-title" x="130" y="220">No active chord</text>
        <text class="state-node-subtitle" x="130" y="244">
          Waiting for eligible input
        </text>
        <rect class="state-node" x="295" y="190" width="190" height="76" rx="14">
        </rect>
        <text class="state-node-title" x="390" y="220">
          Tracking current chord
        </text>
        <text class="state-node-subtitle" x="390" y="244">
          Identity A
        </text>
        <rect class="state-node" x="555" y="190" width="190" height="76" rx="14">
        </rect>
        <text class="state-node-title" x="650" y="220">
          Testing challenger
        </text>
        <text class="state-node-subtitle" x="650" y="244">
          Identity B
        </text>
      </g>
      <g class="state-transitions">
        <path
          class="state-transition"
          d="M 225 211 L 295 211"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="260" y="174">
          Eligible chord
        </text>
        <path
          class="state-transition"
          d="M 295 249 L 225 249"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="260" y="285">Release</text>
        <text class="state-transition-action" x="260" y="303">
          Commit if long enough
        </text>
        <path
          class="state-transition"
          d="M 485 211 L 555 211"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="520" y="174">
          Different identity
        </text>
        <path
          class="state-transition"
          d="M 555 249 L 485 249"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="520" y="285">
          A returns before 200 ms
        </text>
        <text class="state-transition-action" x="520" y="303">
          Discard B
        </text>
        <path
          class="state-transition state-transition-emphasis"
          d="M 650 190 C 650 85, 390 85, 390 190"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="520" y="58">
          B reaches its deadline
        </text>
        <text class="state-transition-action" x="520" y="78">
          Commit A at B’s onset if long enough; promote B
        </text>
        <path
          class="state-transition"
          d="M 650 266 C 650 410, 130 410, 130 266"
          marker-end="url(#segmenter-arrow)"
        ></path>
        <text class="state-transition-label" x="390" y="442">
          Release before B’s deadline
        </text>
        <text class="state-transition-action" x="390" y="462">
          Commit A at B’s onset if long enough; discard B
        </text>
      </g>
    </svg>
  </div>
  <figcaption>
    Matching observations leave the state unchanged. A third identity replaces
    the pending challenger and restarts its clock. Because an overdue challenger
    is promoted first, a later observation may cause more than one transition.
  </figcaption>
</figure>

## One threshold, several jobs

For event capture, 200 ms serves both as the challenger window and the minimum
duration of a committed chord. Those jobs could become separate settings if
research ever gives them different answers, but so far one threshold keeps the
model simple and the behavior easy to reason about.

The same 200 ms decision also governs the visible chord name. Its behavior and
measured effect are covered below.

<div class="callout">
  <p>
    <strong>Two hundred milliseconds is a stability window, not analysis
    time.</strong> The recognizer still runs on every note change. The app
    delays changing the chord name until the new reading has proved that it is
    more than a transient.
  </p>
</div>

## Why 200 milliseconds?

The original 200 ms value was an engineering judgment. It shipped with the first
version of chord history, before there were any recorded performances to test it
against: long enough to reject many finger rolls, short enough to feel like part
of the gesture. The responsible next question was whether that plausible number
held up once it could be measured.

It did, but not because 200 ms emerged as a clear optimum.

The segmenter was extracted into pure, clock-independent Dart so recorded MIDI
performances could pass through the exact state machine used by the app. We then
replayed 50 recorded piano performances with stability windows from 50 to 800
ms. This controlled comparison asks whether changing the window improves key
detection, not how accurate the app is overall. Only events with an answer are
included; either the signature’s major key or its relative minor counts as
agreement. Reactive halved the weight of old evidence every second; Stable did
so every 30 seconds.

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Stability window</th>
      <th scope="col">Committed events</th>
      <th scope="col">Reactive agreement (1 s half-life)</th>
      <th scope="col">Stable agreement (30 s half-life)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">50 ms</td>
      <td class="mono">31,107</td>
      <td class="mono">52%</td>
      <td class="mono">67%</td>
    </tr>
    <tr>
      <td class="mono">100 ms</td>
      <td class="mono">23,334</td>
      <td class="mono">53%</td>
      <td class="mono">68%</td>
    </tr>
    <tr>
      <td class="mono">200 ms</td>
      <td class="mono">15,407</td>
      <td class="mono">55%</td>
      <td class="mono">68%</td>
    </tr>
    <tr>
      <td class="mono">400 ms</td>
      <td class="mono">8,216</td>
      <td class="mono">57%</td>
      <td class="mono">69%</td>
    </tr>
    <tr>
      <td class="mono">800 ms</td>
      <td class="mono">3,699</td>
      <td class="mono">55%</td>
      <td class="mono">63%</td>
    </tr>
  </tbody>
</table>

Shortening the window from 200 to 50 ms doubled the number of events without
helping the Stable result, while Reactive agreement fell from 55% to 52%. The
extra events were mostly transition noise that the key detector did not need.
Raising the window to 400 ms discarded nearly half the events for changes of
only one or two points, neither of which was established as a real improvement.
At 800 ms, only about a quarter as many events remained as at 200 ms. Stable
agreement fell five points, while Reactive did no better than at 200 ms.

That is the useful conclusion: 200 ms sits comfortably on the flat part of the
curve. It filters a large amount of transient input without pretending that
waiting longer can clean up every ambiguity. The study also showed why the key
detector still needs its own fading memory. A sustain-pedal blur can last much
longer than any sensible segmentation window; it is sustained ambiguous
evidence, not a quick mistake.

## The display needed the same gate

History and key detection used the segmenter first. The main chord display
originally did not. It showed the recognizer’s answer after every change to the
sounding notes, even when that answer would never survive long enough to enter
history.

That display now uses the same stability judgment. If a player builds a C major
chord one note at a time, the display first shows the single C note, then a
major third interval after E is added. When G completes the chord, that interval
remains visible while C major proves itself. After 200 ms, the display changes
to C major. The last useful label remains while any notes sound and clears only
on silence, so it never blinks empty during that progression.

We measured **flicker share**, the portion of labeled display time occupied by
names that lasted less than half a second, along with how often the name
changed. We then simulated the display following the segmenter’s decisions over
the same recorded performances.

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Music</th>
      <th scope="col">Flicker share, raw → gated</th>
      <th scope="col">
        Name changes per labeled minute, raw → gated
      </th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Classical piano (12 unseen movements)</td>
      <td class="mono">44.6% → 6.1%</td>
      <td class="mono">292.3 → 38.9</td>
    </tr>
    <tr>
      <td>Pop piano (101 songs)</td>
      <td class="mono">18.7% → 8.2%</td>
      <td class="mono">95.3 → 51.3</td>
    </tr>
  </tbody>
</table>

In both sets, the segmenter-gated display sharply reduced flicker and name
changes without missing any committed chords. That is why the display gate
shipped.

## What the segmenter deliberately gives up

Every stability policy chooses what not to represent. WhatChord will omit an
intentional chord held for less than 200 ms. Fast ornaments and dense runs are
more likely to disappear from chord history altogether. This trades recall for
precision: the app would rather record fewer defensible chords than preserve
every intermediate guess as though it were equally meaningful.

The segmenter also cannot separate a melody from an accompaniment, infer an
unsounded harmony, or clean up a pedal wash that persists beyond the gate. Those
are different problems. Recognition decides what a snapshot means, segmentation
decides whether it lasted, and key detection decides how the accepted sequence
fits together over time. Keeping those responsibilities separate is what makes
each one measurable.

## The codebase

The state machine lives in the pure-Dart
[`ChordEventSegmenter`](https://github.com/EarthmanMuons/whatchord/blob/main/packages/whatchord/lib/src/temporal/chord_event_segmenter.dart).
The app’s
[history provider](https://github.com/EarthmanMuons/whatchord/blob/main/lib/features/history/providers/chord_history_notifier.dart)
owns live capture, timers, and retention, while the
[display provider](https://github.com/EarthmanMuons/whatchord/blob/main/lib/features/theory/state/providers/displayed_chord_provider.dart)
runs its own copy for presentation.

Callers supply the clock rather than the segmenter reading wall time itself.
That makes its behavior deterministic in unit tests and lets
[offline replay](https://github.com/EarthmanMuons/whatchord/blob/main/tool/whatkey/replay_batch.dart)
use the production state machine instead of an approximation. The same code that
decides what counted while someone was playing is therefore the code the
research measures later.

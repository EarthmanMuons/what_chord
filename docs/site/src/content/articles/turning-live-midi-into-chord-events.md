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
it lasted, which pitch classes and bass note sounded, the actual MIDI voicing,
the recognizer’s selected identity, and the nearby alternative readings
available at that moment. The history stays in memory only. The
[streaming key detector](key-detection-algorithm.html) consumes these events
rather than the much noisier stream of raw note changes.

Single notes and intervals still appear in the interface, but they are not chord
events. Capture begins only when the recognizer has a chord candidate, which
currently requires at least three sounding notes.

## Segment identities, not note changes

The segmenter follows the recognizer’s selected **chord identity**: the root,
bass, quality, and represented chord tones that make one reading distinct from
another. It does not start a new event merely because the sounding MIDI notes
changed.

Adding another C to a held C major chord changes the voicing but not its
identity, so the event continues. The same is true when a doubled note is
released. This keeps one held harmony from becoming several artificial events
just because the player redistributed it between octaves.

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
one is committed. Crucially, the boundary is placed at the challenger’s original
onset, not 200 ms later:

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
      <td>F major</td>
      <td>F major is accepted; C major ends at 800 ms</td>
    </tr>
  </tbody>
</table>

The decision arrives at 1,000 ms, but the stored history still says the musical
change happened at 800 ms. Waiting for stability adds display and commit
latency; it does not move the measured beat or shorten the accepted chord.

A release, a drop below three notes, or another loss of a valid chord candidate
closes capture immediately rather than waiting for a timer. The current chord
ends then unless a pending challenger had already appeared. In that case, it
ends at the challenger’s onset and the unproven challenger is discarded. Events
that never lasted 200 ms are dropped. If one pending challenger is replaced by
another, the new challenger starts its own clock.

In compact pseudocode, the central rule is:

```text
same identity:
  keep the current chord and discard any challenger

different identity:
  start or continue a pending challenger

challenger survives 200 ms:
  commit the current chord through the challenger's onset
  promote the challenger, preserving that onset

release:
  end the current chord at the challenger's onset, or at release if none
  commit it if it lasted at least 200 ms
  discard any unresolved challenger
```

## One threshold, several jobs

For event capture, 200 ms serves both as the challenger window and the minimum
duration of a committed chord. Those jobs could become separate settings if
research ever gives them different answers, but so far one threshold keeps the
model simple and the behavior easy to reason about.

The same 200 ms decision also governs the visible chord name. A new name has to
survive the stability window, while the previous stable name remains on screen
as the challenger proves itself. That keeps the display, history, and key
detector in agreement about what counted as a chord.

<div class="callout">
  <p>
    <strong>Two hundred milliseconds is a stability window, not analysis
    time.</strong> The recognizer still runs on every note change. The app
    delays changing the chord name until the new reading has proved that it is
    more than a transient.
  </p>
</div>

## Why 200 milliseconds?

The original 200 ms value was an engineering judgment. It shipped with chord
history before the key detector or its performed-input fixtures existed: long
enough to reject many finger rolls, short enough to feel like part of the
gesture. The responsible next question was whether that plausible number held up
once it could be measured.

It did, but not because 200 ms emerged as a magical optimum.

The segmenter was extracted into pure, clock-independent Dart so recorded MIDI
performances could pass through the exact state machine used by the app. We then
replayed 50 recorded piano performances with stability windows from 50 to 800
ms. This was a controlled comparison, not an estimate of overall app accuracy.
Every row used the same reference labels, so the question was simply whether
changing the window improved the key detector’s result. The last column reports
how often the detector’s answers matched either the major key or relative minor
represented by the score’s written key signature.

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Stability window</th>
      <th scope="col">Committed events</th>
      <th scope="col">Key-signature agreement</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">50 ms</td>
      <td class="mono">31,107</td>
      <td class="mono">67%</td>
    </tr>
    <tr>
      <td class="mono">100 ms</td>
      <td class="mono">23,334</td>
      <td class="mono">68%</td>
    </tr>
    <tr>
      <td class="mono">200 ms</td>
      <td class="mono">15,407</td>
      <td class="mono">68%</td>
    </tr>
    <tr>
      <td class="mono">400 ms</td>
      <td class="mono">8,216</td>
      <td class="mono">69%</td>
    </tr>
    <tr>
      <td class="mono">800 ms</td>
      <td class="mono">3,699</td>
      <td class="mono">63%</td>
    </tr>
  </tbody>
</table>

Shortening the window from 200 to 50 ms doubled the number of events without
improving the result. The extra events were mostly transition noise that the key
detector did not need. Raising the window to 400 ms discarded nearly half the
events for a one-point difference that was not established as a real
improvement. At 800 ms, only about a quarter as many events remained as at 200
ms, and key agreement fell.

That is the useful conclusion: 200 ms sits comfortably on the flat part of the
curve. It filters a large amount of transient input without pretending that
waiting longer can clean up every ambiguity. The study also showed why the key
detector still needs its own fading memory. A sustain-pedal blur can last much
longer than any sensible segmentation window; it is sustained ambiguous
evidence, not a quick mistake.

## The display supplied a second test

History and key detection used the segmenter first. The chord card originally
did not. It showed the recognizer’s answer after every change to the sounding
notes, even when that answer would never survive long enough to enter history.

We measured **flicker share**, the portion of labeled display time occupied by
names that lasted less than half a second, along with how often the name
changed. We then replayed the same performances with the display following the
segmenter’s decisions.

<table class="article-table">
  <thead>
    <tr>
      <th scope="col">Music</th>
      <th scope="col">Flicker share, raw → gated</th>
      <th scope="col">Name changes per minute, raw → gated</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Classical music</td>
      <td class="mono">44.6% → 6.1%</td>
      <td class="mono">292.3 → 38.9</td>
    </tr>
    <tr>
      <td>Pop music</td>
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
more likely to disappear from chord history altogether. This is a precision
trade: the app would rather record fewer defensible chords than preserve every
intermediate guess as though it were equally meaningful.

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

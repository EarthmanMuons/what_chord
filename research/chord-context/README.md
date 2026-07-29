# Chord Context

A musician naming a chord does not look at it in isolation. They know what came
before, where the music is heading, and what key they are in. The app, at the
time this started, saw one snapshot of sounding notes and nothing else. Would
giving it the recent past make it name chords better?

**Status:** complete. Findings validated on
[held-out data](../GLOSSARY.md#development-split-and-held-out-split); every
front shipped, closed by measurement, or costed and handed off.

## What came out

**Mostly the founding hypothesis was wrong.** Measured against a strong
snapshot-plus-key baseline on two annotated classical corpora and a pop/rock
census, the temporal cues were inert or actively harmful once the current key
was already accounted for. Knowing the previous chord added almost nothing that
the current notes and key did not already supply.

The wins came from two adjacent places the measurement surfaced instead.

**Shipped:**

- **The key-functional seventh beats its sixth-chord twin.** Under the
  prevailing key, a minor 7th on the second degree wins over the sixth chord
  built from the same notes. This one enharmonic family turned out to be the
  entire naming headroom on both corpora; the rule lifts clean-pool identity
  accuracy about 2 points with no measured harm, confirmed on held-out data.
- **F sharp, not G flat**, as the six-sharp key in WhatKey's key space, so the
  app spells that key the way scores and pop annotators actually write it. This
  one was adopted, reversed when the evidence turned out to be an artifact of
  one corpus's composers, then re-adopted on evidence from a second musical
  domain.

**Closed by measurement:** live temporal re-ranking (the cues above); a spelling
side-chooser that had one lucky setting and failed around it; an apparent "extra
tones" error class that turned out to be an artifact of how spans were being
viewed; and the spelling residual, which decomposed to 98% key detection error
rather than anything a speller could fix. History relabeling works decisively
but has no downstream value.

**Costed and handed off:** rootless comping voicings became
[Ensemble Mode](../ensemble-mode/README.md), and local-key detection became
[WhatKey Local](../whatkey-local/README.md). Classical augmented-sixth spelling
was scoped at roughly 0.7% of events, spelling-only, and contested for a
lead-sheet audience; it documents a design choice rather than headroom.

## Where this fits

This was the first initiative to ask whether time helps chord naming, and its
answer shaped the two that followed. Both handoffs above became their own
initiatives, and both succeeded, which is worth stating plainly: the founding
hypothesis failed but the measurement that killed it is what found the real
work.

The one temporal mechanism that did prove decisive, relabeling a chord once the
next one arrives, was later adopted in a narrow form by
[WhatKey Local](../whatkey-local/README.md), where it earns its keep on ensemble
naming rather than on solo identity.

## Contents

- [Design and plan](temporal-context-chord-recognition.md): the founding
  document; four tracks, product contract, architecture, plan.
- [Protocol](PROTOCOL.md): the frozen evaluation protocol; rulers, ground-truth
  rules, split discipline, metrics, adoption bar.
- [Data](data/): frozen split definitions and the comping suite.
- [Contextual spelling notes](contextual-spelling-notes.md) and
  [rootless voicings notes](rootless-voicings-notes.md): design sketches for the
  spelling and ensemble tracks.
- [m7/6 family notes](m7-sixth-family-notes.md): the musical review behind the
  shipped seventh-versus-sixth rule, with sources.
- [Log](log/): dated, append-only record of every experiment and decision.

Supporting code is in `tool/chord-context/`, run via the
`research:chord-context-*` mise tasks. Derived artifacts stay in
`build/chord-context/`; the license-gated DCML fixtures are build-only and never
committed.

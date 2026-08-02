# Polychord pilot reviewer guide

Status: draft for an independent-method pilot. This guide and the six pilot
cases test whether the review method is clear. They are not a frozen accuracy
test for WhatChord.

## Who this review is for

This review is intended for musicians with formal music-theory study or
equivalent advanced practical experience. You should be comfortable reading
standard notation, piano-keyboard and piano-roll views, identifying common
triads and seventh chords, and distinguishing chord extensions, slash chords,
and upper-structure voicings.

You do not need programming, MIDI, JSON, music-information-retrieval, or
WhatChord experience. The review normally takes 30 to 45 minutes after a 10 to
15 minute orientation.

## The question we are asking

For this study, a **polychord** is a notational or constructional description:
one musical sonority or short passage is usefully described as two conventional
chordal units in combination.

This does not claim that a listener hears two independent keys. It also does not
ask you to infer a composer's private intention. Judge only the musical evidence
presented in the case.

Each case asks three separate questions:

1. What is the smallest musical unit needed to make the judgment: one
   simultaneous sonority or a short passage unfolding over time?
2. Is a polychord decomposition expected, merely available but less preferable
   than one integrated chord, or misleading?
3. Which kinds of input would contain enough evidence to recover your reading?

Keep the construction judgment in question 2 separate from recoverability in
question 3. A passage can be a valid constructional polychord even when a single
pitch-and-register snapshot cannot recover its layers.

## Construction choices

- **Polychord reading expected:** the evidence supports two conventional chordal
  units, and a polychord name should be available at least as a secondary
  reading.
- **Possible decomposition, but a single-chord reading is preferable:** two
  chordal units can describe the evidence, but an integrated chord, slash chord,
  or established upper-structure reading is the better primary description.
- **A polychord reading would be misleading:** the evidence is better understood
  as one integrated harmony or as a duplicated voicing of one rooted chord.
- **Cannot determine from the instructions or evidence:** the evidence or this
  guide does not support a responsible choice. Explain what is missing or
  unclear; do not force a label.

These choices concern construction and notation, not whether a particular
algorithm succeeds.

## Choose the musical unit

- Choose **one simultaneous sonority** only when all notes needed for your
  reading sound together.
- Choose **a short passage unfolding over time** when the chordal units are
  established by arpeggiation, successive attacks, or coherent motion.

Do not collect every pitch from a passage into an imaginary vertical chord if
those pitches never sound together.

## Describe the chordal layers

For the two polychord choices, add at least two layers. Give each layer a concise
chord identity in the notation you normally use, then assign the notes belonging
to it. The interface shows written note names and derives the machine-readable
values automatically.

For score excerpts, select the pitch names belonging to each layer. Preserve
important spelling in the chord-identity text because the pitch selector is
enharmonically neutral. If the same pitch class belongs to two chord templates,
select it in both layers. For generated note examples, every octave-specific
note must belong to exactly one layer or remain explicitly unassigned; two
separate notes may still share the same pitch class.

For **a polychord reading would be misleading**, describe the preferred single
integrated chord as one layer when a conventional identity is available. It is
also acceptable to use no layer when no such identity is defensible. For
**cannot determine**, layers may be left empty.

Record plausible integrated single-chord readings separately under
**single-chord alternatives**. Do not list alternate spellings of the same
polychord there.

## Judge what each input can recover

Answer all three recoverability questions independently:

- **One split between neighboring notes:** Could the complete layers be obtained
  by sorting the simultaneously sounding notes from low to high and placing one
  boundary between adjacent notes?
- **Any assignment using pitch and register:** Could the layers be recovered
  from the simultaneous octave-specific notes when notes need not form two
  contiguous register blocks?
- **Timing and motion available:** Could attack time, release, sustain-pedal
  state, or coherent motion supply evidence that a snapshot lacks?

Use these response choices:

- **Enough evidence:** the input supports the proposed reading under the stated
  condition.
- **More than one defensible reading:** the input permits the reading, but does
  not justify it over an ordinary integrated-chord alternative.
- **Not enough evidence:** the input cannot contain the notes or relationships
  needed for the reading.
- **Promising, but needs an encoded performance:** the score suggests useful
  timing or motion evidence, but no frame-accurate performance has been encoded.
- **Not known from this case:** the required evidence is absent, so its
  usefulness cannot be judged.

Give a short musical reason for every choice, including uncertainty.

## Independence and uncertainty

Complete the orientation and scored cases without consulting another reviewer,
the research team's initial annotations, or detector output. General reference
works may be consulted, but record anything case-specific that materially
influenced your answer.

The score cases identify the work and location so you can inspect their musical
context. This necessarily means that a familiar example may be recognizable;
the study is initial-label-blinded, not work-blinded. The generated cases use
neutral note views and disclose no intended answer.

Use the assigned pseudonymous reviewer ID, not your name or email. Your
qualifications and contact details are recorded separately from the response.
Download and return the response file without editing it or discussing cases
with the research team. The interface stores a draft only in your browser and
does not submit data to a server.

Technical response fields, validation commands, and the pre-adjudication rules
are documented separately in
[`pilot-response-schema.md`](pilot-response-schema.md). Reviewers do not need
that document to complete the form.

# 2026-07-25: Hollow implied-root key; dyad-shell lead recorded

**Goal.** Promote the implied-root keyboard visual from deferred polish (entry
2026-07-25-05) into the shipped feature, and record the two-note-shell question
as a lead.

**Setup.** App-side UI work only; verified by analyzer and full test suites
(root suite now 229 passing, package unchanged).

**What happened.**

- **Hollow implied-root key.** The live keyboard now draws the implied root of
  an ensemble rootless reading as a hollow outline of the pressed-key highlight,
  on the nearest key with the root's pitch class strictly below the played bass
  (where the covering bassist would be; always within an octave). The painter
  gains an `impliedNoteNumbers` role alongside its existing pressed and
  out-of-structure-pressed vocabulary; the deliberate choice is a new visual
  rather than reusing the Explore pages' muted "pressed but outside the
  structure" fill, whose semantics are the opposite (played but not in the name,
  versus in the name but not played). Scroll centering treats the ghost key as
  part of the framed span so it stays visible, and the key is gated on
  chord-level analysis, so it never appears for dyads.
- **Wiring.** `impliedRootNoteNumbersProvider` (theory) computes the key from
  the chosen candidate and the sounding bass; the set flows through
  `ResizableKeyboardArea` and `ScrollablePianoKeyboard` with empty defaults, so
  the Explore, Scales, and Key pages are untouched.

**Decisions.**

- The hollow key is part of the ensemble launch, per the decision to promote it
  from polish (superseding entry -05 on this point).
- **Dyad-shell lead, recorded and parked.** Chord analysis still requires three
  sounding notes in both modes. Two-note ensemble analysis was considered and
  declined: the measurements only cover three-note-plus voicings (the corpus
  synthesis skipped smaller strips), and a dyad admits an implied reading
  exactly when it is a guide-tone pair, which makes a bare fifth like Eb-Bb read
  as a confident rootless Cm7. The one strong case is the tritone guide-tone
  pair (E-Bb as a C7 shell). If ever revisited, the shape is: promote a dyad to
  chord analysis in ensemble mode only when it admits an implied reading
  (possibly dominant shells only), measured first via two-note strips in the
  rootless synthesis. Not considered worth pursuing now.

**Next.**

- None; this entry closes the addendum. The web bundle regeneration noted in
  entry -05 remains the one outstanding release step.

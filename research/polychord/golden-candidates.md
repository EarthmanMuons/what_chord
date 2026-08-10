# Polychord golden candidates (draft)

Curation draft collected from web sources on 2026-08-02 (log 2026-08-02-02),
corrected after external review (log 2026-08-02-04). These are candidates for
the author-adjudicated internal suite, not independent ground truth. The active,
non-scorable seed is `data/internal-suite/suite-v0.json`; this document remains
the admission backlog rather than an executable ruler. Register details marked
unverified came from analyses rather than scores, and no literature case enters
the active suite until its exact observation is verified against a stable source
(and ideally a recording). The eventual frozen adoption suite remains a later
dated decision per `PROTOCOL.md` and `FRAMEWORK.md`.

Tags: positive (polychord reading expected, at least as an alternative),
boundary (single symbol preferred; polychord at most a pedagogical alternative),
negative guard (must not split). These tags are maintainer judgments, not
external annotations. Every encoded case must additionally declare whether it is
a literature-attested construction, theory-derived boundary, synthetic
regression guard, or unresolved candidate.

## Positive

- **Petrushka chord** (Stravinsky, Petrushka, 1911). C major and F# major are
  combined; pcs {C,E,G}+{F#,A#,C#}. The rehearsal-49 clarinet statement is now
  score-verified (printed p. 64, PDF p. 66 of the UNC scan): it consists of
  concurrent arpeggiated streams, not one snapshot containing two complete
  triads. It is therefore an event-window constructional positive and a
  register-snapshot ineligible case. Other statements still require their own
  verification rather than an assumed orientation or verticalized six-note
  voicing. Analytical literature disputes whether the collection is better
  understood as one octatonic-derived sonority or two triads, so retain both
  readings.
- **Petrushka, third tableau**. Same relation transposed: A major over Eb major.
- **Augurs chord** (Rite of Spring). Eb7 with Fb major; pcs
  {Eb,G,Bb,Db}+{Fb,Ab,Cb}. Stravinsky's four-hand reduction at rehearsal 13 is
  score-verified as Fb2-Ab2-Cb3-Fb3 and Eb3-G3-Bb3-Db4. Eb3 lies below Fb3, so
  the component chords overlap in register and no adjacent-note boundary
  recovers both. This remains a textbook constructional positive, but it is not
  evidence for an adjacent-register detector.
- **Elektra chord** (Strauss). C# major (Db F Ab) over an E-B fifth; pcs
  {C#,F,G#,E,B}. Standard reading is the bitonal synthesis; enharmonic
  single-symbol alternatives exist (7#9 spellings), so both readings should
  surface. Exact octaves unverified.
- **Ives, Psalm 67 opening**. C major (women) over G minor (men); pcs
  {C,D,E,G,Bb} (the layers share G). Trap case: the pc set equals C9 exactly.
  The polychord reading rests entirely on registral/choir segregation, not pitch
  content.
- **Copland, Appalachian Spring opening**. E major over A major; pcs
  {A,B,C#,E,G#} (the layers share E). Trap case: the pc set equals Amaj9
  exactly. Kleppinger (MTO 17.2) labels it a polychord; Amaj9 stays a defensible
  alternative.
- **Holst, Neptune**. E minor and G# minor sounding together; pcs
  {E,G,B}+{G#,B,D#} (shared B, so the initial disjoint detector cannot see it;
  the ruler must decide whether shared tones license the reading).
- **Milhaud, Copacabana** (Saudades do Brasil). B major against G major; pcs
  {G,B,D}+{B,D#,F#} (shared B). This corrects the earlier attribution to
  Corcovado; exact measures and voicing still require score verification.
- **Liszt, Malediction**. F major plus B major, the historical antecedent of
  Petrushka; pcs {F,A,C}+{B,D#,F#}.
- **Fred Steiner, Perry Mason theme**. D major over C minor; pcs
  {D,F#,A}+{C,Eb,G}. Cited directly as a D/Cm polychord.
- **F# major over C** (Lippincott). The auxiliary-diminished/octatonic sound;
  single-symbol alternative C7(b9#11). Polychord notation genuinely used.
- **C major over Ab minor** (Lippincott). Augmented-scale hexatonic sound; pcs
  {C,E,G}+{Ab,Cb,Eb}. The single symbol (Abm(maj7) with added colors) is
  unwieldy, so the polychord name is preferred: the clearest jazz case where the
  stacked name should win outright.

## Boundary (single symbol expected; polychord at most an alternative)

- **Petrushka, “The Shrovetide Fair,” mm. 41–53**. Moreira's Example 17,
  following Cambouropoulos and Huron, analyzes the passage as two triadic
  textural streams: each register group moves in parallel internally, while the
  groups separate through oblique or contrary motion and rhythmic
  differentiation. The first depicted transition is score-excerpt-verified as C
  major below G minor moving to B-flat major below the rearticulated G-minor
  triad. It is the literature-attested construct check for the rigid-motion
  ablation. Moreira also stresses that both streams remain inside G Dorian and
  calls the passage only “in some sense polychordal”; its endpoint collections
  have straightforward C9 and Gm7 readings. Keep motion support separate from a
  user-facing polychord expectation. This is not the rehearsal-49 Petrushka
  chord.
- **Upper-structure triads over a C7 shell** (verified against Piano With Jonny
  and PianoGroove; LH C-E-Bb or E-Bb, RH triad):
  - D major: C13(#11), pcs {C,D,E,F#,A,Bb}
  - Eb major: C7(#9), pcs {C,Eb,E,G,Bb}
  - Gb major: C7(b9#11), pcs {C,Db,E,Gb,Bb}
  - Ab major: C7(#9b13), pcs {C,Eb,E,Ab,Bb}
  - A major: C13(b9), pcs {C,Db,E,A,Bb} (also the gospel passing-chord voicing,
    where players colloquially say "A over C")
- **Maiden Voyage chord** (Hancock). D-A fifth under a C major triad; pcs
  {D,A,C,E,G}. Expected D9sus (or the slash Am7/D), never a two-triad polychord.
- **F/G gospel-pop slash**. F major over a lone G bass; expected G9sus. This is
  the ordinary slash-chord reading and a guard for the unresolved bass-only
  layer scope, not a settled universal definition.
- **D/C ambiguity pair**. Slash reading D/C = {C,D,F#,A}; polychord reading D
  major over C major = {C,D,E,F#,G,A}. Context decides; notation sources
  discourage the horizontal-line form for slash chords precisely because it
  implies the polychord. Encode as two separate cases.
- **Also sprach Zarathustra ending** (Strauss). High B major over low C octaves:
  registral bitonality in the literature, but engine-wise a triad over a foreign
  bass note (B/C) at extreme separation. Exposes the unresolved bass-only-layer
  boundary.
- **Bernstein, West Side Story, Rumble**. C# major triads over alternating C and
  G bass notes; Aziz (Integral 37) calls this simultaneous bitonality, but the
  lower layer is single bass notes, so the case sits on the same bass-only-layer
  boundary as Zarathustra rather than being a clean two-chord positive. Measure
  numbers unverified against the score.
- **Bartok, Bagatelle Op. 6 No. 1**. Notationally bitonal (four sharps against
  four flats), but Bartok called it "simply a Phrygian colored C major": a guard
  against over-eager bitonal labeling of melodic textures.

## Negative guards (must not split)

- **Psalms chord** (Stravinsky, Symphony of Psalms). E minor triad with the
  third doubled across four octaves and extreme spacing; pcs {E,G,B} only. The
  best classical guard: maximal registral spread, one chord.
- **So What chord**. Bottom-up E A D G B (quartal LH, top three notes a
  second-inversion G major). Must read as one sonority (Em7(11) or G6/9 by
  context). Note: the census registral detector as drafted DOES fire on this
  family (triad over a power-dyad lower stack); see log 2026-08-02-02.
- **Kenny Barron Cm11 voicing**. LH C-G-D, RH Eb-Bb-F, two quintal stacks; pcs =
  complete Cm11. Single symbol.
- **McCoy Tyner modal comping**. LH root+fifth or quartal, RH fourth-shapes
  above: one modal sonority despite two separated layers.
- **Drop-2 / drop-3 seventh voicings**. e.g. G-C-E-B for Cmaj7: open spacing of
  one chord.
- **Pop LH root/fifth/octave + RH same-chord triad**. e.g. C-G-C under E-G-C:
  the standard pop texture (blocked by the shared-pitch-class rule).
- **Open-position spread triad (1-5-10)** and **open-voiced sevenths**: wide
  spacing of a single chord's own notes.

## Notation conventions

Polychords are conventionally written as two chord symbols stacked vertically
with a horizontal line between them; slash chords use the diagonal slash plus a
bass note, and sources explicitly discourage the horizontal-line form for slash
chords because it implies a polychord. Persichetti (Twentieth-Century Harmony)
orders major-over-major polychords by consonance via the cycle of fifths; Brandt
and Roemer's copyist standard could not be verified online for
polychord-specific rules (image-only scan), so flag any citation of it as
unverified.

## Principles the cases encode

- The strongest working positive pattern is two familiar chordal units grouped
  by some observable evidence, and it must survive pitch-class traps: Ives
  equals C9 and Copland equals Amaj9 as sets. The first score checks show that
  register is not universal: Petrushka requires an event window and the Augurs
  components overlap in register. Those cases establish the broader musical
  construct but are not evidence that the initial contiguous-register generator
  can recover it.
- Whenever the lower layer contains a dominant third-plus-seventh tritone, the
  single dominant symbol wins (all UST cases).
- Wide spacing of one chord's own notes never fires the split, even at
  four-octave separation.
- Four of the positive cases share a pitch class between the layers (Ives shares
  G, Copland E, Holst B, Milhaud B), so the initial disjoint census excluded all
  four. Schema 3 now measures overlapping pitch-class projections when distinct
  MIDI notes form the two registral groups. Framework v0 permits that
  separate-note case. A true overlapping cover in which one sounded note serves
  both layers remains outside v0.
- Whether a lone bass note (Zarathustra, Rumble) or a bare fifth (Elektra's E-B
  lower layer) can constitute a layer remains musically interesting, but
  Framework v0 excludes incomplete layers from the initial positive generator.
  Keep these as boundary or unresolved cases rather than positive detector
  expectations.

Sources:
[Wikipedia: Petrushka chord](https://en.wikipedia.org/wiki/Petrushka_chord),
[Elektra chord](https://en.wikipedia.org/wiki/Elektra_chord),
[Polychord](https://en.wikipedia.org/wiki/Polychord),
[Polytonality](https://en.wikipedia.org/wiki/Polytonality),
[Saudades do Brasil](https://en.wikipedia.org/wiki/Saudades_do_Brasil),
[Psalms chord](https://en.wikipedia.org/wiki/Psalms_chord),
[So What chord](https://en.wikipedia.org/wiki/So_What_chord),
[Slash chord](https://en.wikipedia.org/wiki/Slash_chord),
[Puget Sound polychords](https://musictheory.pugetsound.edu/mt21c/polychords.html),
[Moreira, MTO 31.4](https://mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html),
[Kleppinger, MTO 17.2](https://mtosmt.org/issues/mto.11.17.2/mto.11.17.2.kleppinger.html),
[Aziz, Integral 37](https://theory.esm.rochester.edu/integral/37-2024/aziz/),
[Lippincott: polychords and slash chords](https://tomlippincott.com/polychords-and-slash-chords),
[PianoGroove USTs](https://www.pianogroove.com/jazz-piano-lessons/upper-structure-triads/),
[Piano With Jonny USTs](https://pianowithjonny.com/piano-lessons/upper-structure-triads-the-ultimate-piano-chord-hack/),
[PianoGroove: Kenny Barron voicing](https://www.pianogroove.com/jazz-piano-lessons/kenny-barron-voicing/),
[The Jazz Piano Site: polychords](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chords/polychords/),
[Contemporary School of Piano: Maiden Voyage](https://www.contemporaryschoolofpiano.com/maiden-voyage-chords-by-herbie-hancock/),
[Hear and Play gospel passing chords](https://hearandplay.com/main/revealed-two-main-uses-of-passing-chords-in-gospel-and-jazz-harmony/).

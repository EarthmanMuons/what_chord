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
  score-verified (printed p. 64, PDF p. 66 of the UNC scan) and transcribed as
  an exact replay window. The B-flat clarinet's written D-major arpeggio sounds
  as C major, while the A clarinet's written A-major arpeggio sounds as F-sharp
  major. The C-major stream remains above the F-sharp-major stream at all six
  paired attacks, establishing `C|F#` for this passage. No frame contains both
  complete triads, so the case is a constructional positive but is ineligible
  for snapshot detection; its frame-by-frame register baseline is empty. Other
  statements still require their own verification rather than an assumed
  orientation or verticalized voicing. Analytical literature disputes whether
  the collection is better understood as one octatonic-derived sonority or two
  triads, so retain both readings.
- **Petrushka, third tableau**. Same relation transposed: A major over Eb major.
- **Augurs chord** (Rite of Spring). Eb7 with Fb major; pcs
  {Eb,G,Bb,Db}+{Fb,Ab,Cb}. Stravinsky's four-hand reduction at rehearsal 13 is
  score-verified as Fb2-Ab2-Cb3-Fb3 and Eb3-G3-Bb3-Db4. Eb3 lies below Fb3, so
  the component chords overlap in register and no adjacent-note boundary
  recovers both. This remains a textbook constructional positive, but it is not
  evidence for an adjacent-register detector.
- **Ives, Psalm 67 opening**. The published opening and Johnson's Example 11
  establish G2-D3-G3-Bb3 in the four lower voices and C4-E4-G4-C5 in the four
  upper voices: G minor below C major, with G supplied by separate notes in both
  layers. Every lower note is below every upper note, so the B-flat 3 to C4
  boundary gives the active suite its first literature-attested positive that
  the adjacent-register generator can recover, as `C|Gm`. Trap case: the pitch
  classes equal C9 exactly, and the observed bass makes the complete
  single-chord alternative `C9/G`. Live input does not carry the score's choir
  assignment, so the secondary annotation remains an author-adjudicated product
  expectation rather than independent ground truth.
- **Herrmann, “The Pass” from The Naked and the Dead**. Moreira's Example 6
  transcribes a sustained G-minor trumpet triad above alternating A-flat-minor
  trombone attacks in the first four measures. At the first lower-triad attack,
  the exact sounding notes are A-flat 3, C-flat 4, E-flat 4 below G4, B-flat 4,
  D5. The pitch-class-disjoint units and adjacent four-semitone boundary make
  `Gm|Abm` the first recoverable literature positive that does not rely on
  duplicated shared pitches. Moreira explicitly notes the possible integrated
  extended-tertian reading; `Abm(maj9,#11)` remains the less concise primary
  alternative rather than being erased.
- **Stravinsky, Three Movements from Petrouchka, printed page 37**. Hutchinson's
  polychord lesson identifies chromatically ascending dominant seventh chords in
  the left hand against repeating G, F, and C triads in the right. The 1922
  score's fourth right-hand attack after _p sub. e staccatissimo_ is G major
  above the second A-flat 7 attack: A-flat 2, C3, E-flat 3, G-flat 3 below G4,
  B4, D5. The source-backed `G|Ab7` positive verifies the symmetric seventh
  scope with disjoint units. Its exact observation also generates the competing
  mechanical identity `Gmaj7|Ab`, so it is a real selector-order guard rather
  than a clean one-candidate demonstration.
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

- **Elektra chord** (Strauss). The conventional analytical decomposition is
  D-flat major over E major, not D-flat major over an E-B bare fifth. Its
  five-note form E-B-Db-F-Ab uses the one sounded A-flat enharmonically as
  G-sharp, completing E major while also serving as the fifth of D-flat major.
  Kramer describes the collection as the conjunction of those two triads, and
  Hutchinson reports the same shared-tone interpretation while also developing a
  functional alternative. The active suite therefore uses an explicitly
  octave-normalized `Db|E` analytical guard rather than claiming an exact score
  transcription. It is a constructional polychord in the literature but a v0
  product boundary: Framework v0 does not let one sounded note fill both layer
  templates, and concise integrated `Db7(#9)` and `E6(b9)` readings remain
  available.
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
- **Maiden Voyage chord** (Hancock). Waters identifies the A-section collection
  as A-minor-seventh over D and gives the pitches {D,E,G,A,C}. The active suite
  uses an openly octave-normalized D-bass-plus-Am7 snapshot, expected as D9sus4
  or Am7/D rather than a polychord. Earlier wording that asserted an exact D-A
  lower fifth beneath a C-major triad was not supported by the scholarly source
  and has been removed.
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
- **Generated two-hand doubled Cmaj7 accompaniment**. Voice C3-E3-G3 in the
  lower hand and E4-G4-B4 in the upper. The hand groups mechanically spell
  `Em|C` through separate E and G instances, but the complete collection, bass,
  and generation recipe are one Cmaj7 chord. The active suite uses this as an
  executable negative guard against treating a convenient hand boundary as two
  chordal layers; its synthetic status is not a claim about corpus prevalence.
- **Cmaj9 exact-assignment ambiguity**. C3-E3-G3-G4-B4-D5-G5 is one generated
  Cmaj9 voicing, but both the boundary below G4 and the boundary above G4 spell
  `G|C`. The assignments differ over whether G4 belongs to the lower or upper
  group. Retain both structural records through selection and deduplication,
  while the product expectation remains the integrated Cmaj9 name.

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
  register is useful but not universal: the Ives opening has an exact contiguous
  split, Herrmann's “The Pass” supplies disjoint complete triads, and the 1922
  _Three Movements_ score supplies a recoverable complete seventh layer.
  Petrushka rehearsal 49 now supplies an exact moving event window, and the
  Augurs components overlap in register. Those two establish the broader musical
  construct but are not evidence that the initial contiguous-register generator
  can recover it.
- A complete lower dominant seventh is not automatically an integrated-chord
  boundary. The single dominant symbol wins when an established extension names
  the upper unit as an upper structure over that root; the source-backed `G|Ab7`
  attack prevents that UST rule from becoming a categorical rejection of every
  seventh-below-triad polychord.
- Wide spacing of one chord's own notes never fires the split, even at
  four-octave separation.
- Four of the positive cases share a pitch class between the layers (Ives shares
  G, Copland E, Holst B, Milhaud B), so the initial disjoint census excluded all
  four. Schema 3 now measures overlapping pitch-class projections when distinct
  MIDI notes form the two registral groups. Framework v0 permits that
  separate-note case. A true overlapping cover in which one sounded note serves
  both layers remains outside v0.
- Whether a lone bass note (Zarathustra, Rumble) or a genuine bare fifth can
  constitute a layer remains musically interesting, but Framework v0 excludes
  incomplete layers from the initial positive generator. Elektra is not that
  case: its standard two-triad analysis reuses A-flat/G-sharp to complete E
  major. Keep actual bass-only and fifth-only examples as boundary or unresolved
  cases rather than positive detector expectations.

Sources:
[Wikipedia: Petrushka chord](https://en.wikipedia.org/wiki/Petrushka_chord),
[Elektra chord](https://en.wikipedia.org/wiki/Elektra_chord),
[Kramer, _Cambridge Opera Journal_ 5.2](https://doi.org/10.1017/S0954586700003967),
[Kaplan, University of Michigan dissertation record](https://hdl.handle.net/2027.42/160545),
[University of Toronto music-theory dissertation list](https://music.utoronto.ca/areas/music-theory/alumni),
[Hutchinson, _Music Analysis_ 45.1](https://doi.org/10.1111/musa.70002),
[Polychord](https://en.wikipedia.org/wiki/Polychord),
[Polytonality](https://en.wikipedia.org/wiki/Polytonality),
[Saudades do Brasil](https://en.wikipedia.org/wiki/Saudades_do_Brasil),
[Psalms chord](https://en.wikipedia.org/wiki/Psalms_chord),
[So What chord](https://en.wikipedia.org/wiki/So_What_chord),
[Slash chord](https://en.wikipedia.org/wiki/Slash_chord),
[Puget Sound polychords](https://musictheory.pugetsound.edu/mt21c/polychords.html),
[IMSLP: Petrushka](https://imslp.org/wiki/Petrushka_%28Stravinsky%2C_Igor_Fyodorovich%29),
[Johnson, MTO 23.4, Example 11](https://mtosmt.org/issues/mto.17.23.4/johnson_examples.php?id=10&nonav=true),
[Moreira, MTO 31.4](https://mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html),
[Kleppinger, MTO 17.2](https://mtosmt.org/issues/mto.11.17.2/mto.11.17.2.kleppinger.html),
[Aziz, Integral 37](https://theory.esm.rochester.edu/integral/37-2024/aziz/),
[Waters, _Jazz Educators Journal_ 33.1](https://experts.colorado.edu/display/pubid_94229),
[Hancock: _Maiden Voyage_](https://www.herbiehancock.com/music/discography/album/maiden-voyage/),
[Lippincott: polychords and slash chords](https://tomlippincott.com/polychords-and-slash-chords),
[PianoGroove USTs](https://www.pianogroove.com/jazz-piano-lessons/upper-structure-triads/),
[Piano With Jonny USTs](https://pianowithjonny.com/piano-lessons/upper-structure-triads-the-ultimate-piano-chord-hack/),
[PianoGroove: Kenny Barron voicing](https://www.pianogroove.com/jazz-piano-lessons/kenny-barron-voicing/),
[The Jazz Piano Site: polychords](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chords/polychords/),
[Hear and Play gospel passing chords](https://hearandplay.com/main/revealed-two-main-uses-of-passing-chords-in-gospel-and-jazz-harmony/).

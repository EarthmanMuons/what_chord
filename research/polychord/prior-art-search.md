# Polychord prior-art search record

Status: scoping evidence, last screened 2026-08-02. This record supports log
`2026-08-02-05`; it is not a systematic-review protocol or a frozen publication
bibliography.

## Claim boundary

The strongest claim supported by the present search is:

> Within the documented search scope, we found no published computational method
> or evaluated dataset whose output is a named polychord decomposition inferred
> from observed pitches, MIDI, score, or audio.

This claim is provisional. It does not mean that the field is barren, that no
software detects polychords, or that a WhatChord implementation would be the
first computational detector. At least three software implementations precede
this initiative: mingus, ChordRecGen, and musicpy. musicpy 7.15 is an actively
released package with a documented polychord split routine and is mandatory
baseline prior art.

The potential research contribution is therefore an explicit task definition, a
score-verified and independently annotated ruler, an evaluation method, and an
evaluated register-licensed detector. Any paper must disclose the software,
notation, corpus-reduction, and patent prior art below.

## Provenance correction

The first draft of log -05 said that 48 queries were recorded. Forty-eight
queries were reported as having been run in the exploratory sweep, but their
literal strings and result dispositions were not committed or otherwise
retained. That sweep cannot be independently replayed and must not be cited as
if it can. Its term families and stated limitations remain useful orientation.

To repair the record without inventing retrospective evidence, a new exact
52-query screen was run on 2026-08-02. The literal strings are below. The screen
used the product's US-index web search, manually inspected the returned results,
and followed material results to primary documentation where possible. Search
rankings are dynamic and raw result-page snapshots were not retained, so this is
a rerunnable query record, not an archival search capture.

The new screen materially changed the conclusion by surfacing musicpy and a 2024
patent whose use of "polyharmonic" is adjacent but not equivalent. This is why
the record now distinguishes published method novelty from implementation prior
art.

## Inclusion and screening rules

Included as direct method prior art: a system that accepts observed musical
content and returns two or more named chordal layers for one simultaneity.

Included as adjacent prior art: software that performs that task without a paper
or evaluation; syntax that accepts or stores polychords; corpus work that
normalizes them away; methods for concurrent-key perception or inference;
patents that represent, generate, transcribe, or align polychordal or
"polyharmonic" material.

Excluded from the direct-method category: human ear-training exercises,
analytical prose, ordinary single-label chord recognition, sequential local-key
estimation, source or voice separation without chord-layer naming, and the
unrelated PolyChord cosmology sampler. Exclusions were retained as terminology
evidence when they clarified a false trail.

## Exact query record

### Primary 24-query terminology screen

The first four query groups found no published direct method. They returned
music theory, perception, ear-training, ordinary chord recognition, and
unrelated uses of the same words. The first group surfaced musicpy's detector;
the fourth surfaced sequential "multiple key estimation" and current bitonality
perception work. The fifth and sixth groups checked adjacent vocabulary and MIR
venues; no direct method appeared.

Polychord:

1. `"polychord detection" music`
2. `"polychord recognition" music`
3. `"polychord identification" music`
4. `"polychord estimation" music`

Bichord and polyharmony:

5. `"bichord detection" harmony music`
6. `"bichord recognition" harmony music`
7. `"polyharmony detection" music`
8. `"polyharmony recognition" music`

Superimposition:

9. `"superimposed triads" detection music`
10. `"superimposed triads" recognition music`
11. `"triadic superposition" computational music`
12. `"chord superposition" recognition music`

Concurrent keys:

13. `"polytonality detection" music`
14. `"polytonality induction" computational music`
15. `"bitonality detection" music`
16. `"multiple key estimation" simultaneous music`

Layer and multi-label vocabulary:

17. `"harmonic stratification" computational music`
18. `"chordal layers" detection music`
19. `"multi-label chord recognition" simultaneous chords`
20. `"hierarchical chord recognition" polychord`

Venue and index probes:

21. `site:archives.ismir.net polychord music`
22. `site:transactions.ismir.net polychord`
23. `site:arxiv.org polychord "chord recognition" music`
24. `site:dblp.org polychord music`

### Twenty-eight targeted follow-up queries

These queries verified the material hits, distinguished naming from parsing or
polyphonic transcription, and checked bibliographic details. They found musicpy,
ChordRecGen, the Impro-Visor syntax, the Casio and Microsoft polychord patents,
the 2024 "polyharmonic" performance-feedback patent, and the 2026 Wolf-Wuest
perception study. They did not find a peer-reviewed direct method or evaluated
corpus.

musicpy:

25. `musicpy poly_chord_first GitHub polychord detection`
26. `site:github.com/Rainbow-Dreamer/musicpy poly_chord_first`
27. `musicpy detect polychord algorithm documentation`
28. `musicpy PyPI polychord`

Patent terminology:

29. `site:patents.google.com Todor Fay polychord chord each track selected`
30. `site:patents.google.com "polyharmonic music recognition"`
31. `"SYSTEM AND METHOD FOR AUTOMATED REAL-TIME FEEDBACK OF A MUSICAL PERFORMANCE" patent`
32. `site:patents.justia.com Todor C Fay polychord`
33. `"The chord for each track is selected" polychord`
34. `"chord of the polychord" patent`
35. `Todor C Fay musical patent chord tracks`
36. `Todor Fay Casio patent musical polychord`

Impro-Visor and corpus handling:

37. `Impro-Visor leadsheet polychord backslash specification`
38. `site:cs.hmc.edu/~keller/jazz/improvisor polychord backslash`
39. `site:github.com/Impro-Visor/Impro-Visor polychord backslash`
40. `Impro-Visor polychords lower chord Bunks Weyde`

Grey-literature implementations:

41. `GitHub ChordRecGen polychord`
42. `"ChordRecGen"`
43. `github polychord recognition chord detector`
44. `github polychord identification MIDI`

Current perception bibliography:

45. `"Detection of clash of keys in a non-dichotomous task" DOI`
46. `site:music-psychology.de "Detection of Clash of Keys"`
47. `site:doi.org "Detection of Clash of Keys"`
48. `"e225" bitonality detection music psychology`

Pedagogical-source verification:

49. `Ulehla Contemporary Harmony "Extension to the 7th in bass and treble"`
50. `"Extension to the 7th" Ulehla harmony`
51. `Ulehla Contemporary Harmony bibliography edition publisher`
52. `Kostka "listener must be able to perceive" polychord`

## Material findings and implementation pins

### Automatic naming software

- **musicpy 7.15.** PyPI published version 7.15 on 2026-06-19; its source
  distribution SHA-256 is
  `b6e10025648632a666ce99b0647655158a87dc554ebd9edbb9547d87fbf2a3e1`. The
  documentation says `poly_chord_first=True` splits before the wider detector.
  Source function `detect_polychord_split` treats fewer than six ordered notes
  as a bass note plus upper chord; for six or more it divides the
  register-ordered input at `N // 2` and detects each half. It is an inference
  implementation, not merely a parser. Repository HEAD observed for this screen:
  `159f5f91beab56ad27d40869bf62f75c14980a6e`.
- **ChordRecGen.** The README documents recursive recognition of additional
  chords from leftover MIDI notes and returns multiple `Chord` objects inside a
  `ChordGroup` for a polychord. It has no release or published evaluation, but
  it is direct software prior art. Repository HEAD observed for this screen:
  `3790a4df5f1c3bbef4ff0a27c43ddacc020a6639`.
- **python-mingus.** Its contiguous-slice enumeration and failure modes are
  documented in log -02. Repository HEAD observed for this screen:
  `6558cacffeaab4f084a3eedda12b0e86fd24c430`.

These versions are discovery pins. A baseline experiment must archive or lock
the exact executable dependency, record the runtime, and retain raw outputs.

### Parsing, notation, and corpus normalization

- Impro-Visor's official reference card distinguishes slash chords from
  polychords and accepts `D\C7`, upper chord first.
- Bunks and Weyde (2022) report 12 polychords in 2,612 Impro-Visor progressions
  and reduce them to their lower structure for contrafact comparison. This is
  evidence of annotations being erased, not a detection method.
- MusicXML 4.0 permits multiple harmony-chord groups inside one `harmony`
  element; its developer notes describe separation for polychords and alternate
  bass. Dorico supports polychord entry, and MuseScore Studio 4.6 added pipe
  entry in June 2025.
- The survey did not find a polychord operator in Harte syntax, JAMS, Humdrum
  `**harm`, DCML, RomanText, or MEI. Before publication, pin versions and add a
  conformance example for each format rather than relying on this negative
  documentation reading alone.

### Patent boundary

- Casio US 4,966,052 (filed 1989, granted 1990) defines upper and lower
  structured chords, includes omitted members and bass-only cases, and encodes
  or generates them in an electronic instrument. Calling it a definition "with
  no algorithm behind it" is inaccurate; it is not, however, an automatic
  polychord naming method.
- Microsoft US 5,900,567 (filed 1997, granted 1999) plays separate tracks
  against function-associated members of a polychord progression. It is
  generation and representation prior art, not inference from observed notes.
- US 2024/0274022 A1 uses "polyharmonic music recognition" for resolving
  harmonically redundant notes in transcription and aligning performed chords
  with a score. It does not infer chord-over-chord names. Its terminology must
  still be disclosed so a novelty search cannot be accused of ignoring the
  phrase.

## Theory and perception source integrity

Publication-ready anchors:

- Vincent Persichetti, _Twentieth-Century Harmony: Creative Aspects and
  Practice_, W. W. Norton, 1961, p. 135. The quotation and page used in log -05
  must be checked against the physical or licensed edition before submission.
- Gabriel Moreira, "Bernard Herrmann's Harmonic Polytonality," _Music Theory
  Online_ 31.4 (2025). This is the current terminology and auditory-grouping
  anchor.
- Carol Krumhansl and Mark Schmuckler, "The Petroushka Chord: A Perceptual
  Investigation," _Music Perception_ 4.2 (1986), DOI 10.2307/40285359.
- William Forde Thompson and Shulamit Mor, "A Perceptual Investigation of
  Polytonality," _Psychological Research_ 54 (1992), DOI 10.1007/BF00937134.
- Anna Wolf and Bastian Wuest, "Detection of Clash of Keys in a Non-Dichotomous
  Task," _Jahrbuch Musikpsychologie_ 34 (2026), DOI 10.5964/jbdgm.225. This
  current study describes an intertwined percept as predominant and supplies
  open data, code, and stimuli at OSF (`https://osf.io/sj3da`).

Working notes that are not yet publication-ready citations:

- The Kostka perceptual condition was recovered from a secondary course term
  sheet, not from a pinned edition. Treat it as a paraphrase until the exact
  edition and page are verified.
- Ludmila Ulehla's _Contemporary Harmony: Romanticism Through the Twelve-Tone
  Row_ was bibliographically identified as Advance Music, 1994,
  ISBN 9783892210610. The quoted upper-structure anti-pattern in log -05 was not
  recovered in a primary preview, so it cannot be quoted in a paper until a page
  is checked.
- Candidate-list web sources are discovery aids only. Every frozen positive and
  boundary case still requires score verification and a stable score citation.

## Stable source ledger

- musicpy detector documentation:
  <https://musicpy.readthedocs.io/en/latest/The%20algorithm%20to%20determine%20the%20chord%20type%20of%20any%20group%20of%20notes%20according%20to%20the%20logic%20of%20music%20theory/>
- musicpy source: <https://github.com/Rainbow-Dreamer/musicpy>
- musicpy release: <https://pypi.org/project/musicpy/>
- ChordRecGen: <https://github.com/derrickward/ChordRecGen>
- python-mingus source:
  <https://github.com/bspaans/python-mingus/blob/master/mingus/core/chords.py>
- Impro-Visor reference card:
  <https://www.cs.hmc.edu/~keller/jazz/improvisor/Impro-VisorRefCard.pdf>
- Bunks and Weyde, _Jazz Contrafact Detection_:
  <https://arxiv.org/abs/2208.00792>
- MusicXML 4.0 `harmony`:
  <https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/harmony/>
- MusicXML developer notes: <https://www.musicxml.com/for-developers/>
- Dorico polychord entry:
  <https://www.steinberg.help/r/smG7cEyn9Yoc8gImwjJTGQ/CrXg4FfCFhS~Drg5zzDb3Q>
- MuseScore Studio 4.6: <https://musescore.org/en/4.6>
- Casio US 4,966,052: <https://patents.google.com/patent/US4966052A/en>
- Microsoft US 5,900,567: <https://patents.google.com/patent/US5900567A/en>
- US 2024/0274022 A1: <https://patents.google.com/patent/US20240274022A1/en>
- Moreira, MTO 31.4:
  <https://www.mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.pdf>
- Krumhansl and Schmuckler: <https://doi.org/10.2307/40285359>
- Thompson and Mor: <https://doi.org/10.1007/BF00937134>
- Wolf and Wuest: <https://doi.org/10.5964/jbdgm.225>
- Palmer, "On the Assignment of Structure in Music Performance":
  <https://doi.org/10.2307/40285708>
- Hove, Keller, and Krumhansl, "Sensorimotor Synchronization with Chords
  Containing Tone-Onset Asynchronies": <https://doi.org/10.3758/BF03193772>
- Tillmann and Bharucha, "Effect of Harmonic Relatedness on the Detection of
  Temporal Asynchronies": <https://doi.org/10.3758/BF03194732>
- Borchert, Micheyl, and Oxenham, "Perceptual Grouping Affects Pitch Judgments
  Across Time and Frequency": <https://doi.org/10.1037/a0020670>

## Required search work before a publication claim

1. Run a protocolized full-text sweep of all ISMIR and TISMIR proceedings, plus
   ICMC and SMC, and preserve the exact query, date, index, returned metadata,
   and inclusion decision in a machine-readable artifact.
2. Repeat the term matrix in at least one bibliographic index with reliable
   coverage (for example, Scopus or Web of Science if access is available), and
   add German, French, Portuguese, and Russian terminology with a qualified
   translator or domain expert.
3. Perform a proper patent-family and non-patent-citation search. The three
   patents above are disclosures, not a patent clearance opinion.
4. Snowball references and citations from Moreira, the three perception papers,
   Bunks and Weyde, musicpy, ChordRecGen, and the Casio/Microsoft patents.
5. Have a second researcher independently screen the direct-method candidates
   and reconcile disagreements. Preserve the exclusion reasons.

Until those steps are complete, use "we found no published method within the
documented search scope," never "the field is barren," "definitive," or "no
prior art exists."

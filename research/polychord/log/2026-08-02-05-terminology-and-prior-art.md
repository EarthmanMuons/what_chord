# 2026-08-02: Deep due diligence: terminology, prior art, conventions

**Goal.** Terminology-aware due diligence before the scope decisions, per the
review (log -04) and the WhatKey lesson that terminology mismatches hide
discoverable prior work. Three parallel surveys: computational prior art under
all term variants; theory and perception terminology conventions, anchored by a
full read of Moreira (MTO 31.4); and software, annotation syntaxes, and the
publication landscape. Search scope recorded at the end.

**Verdict: a provisional publication gap, with direct software prior art.**
Within the documented search scope, no published computational method or
evaluated dataset was found whose output is a named polychord decomposition
inferred from observed pitches, MIDI, score, or audio. That is the strongest
supportable claim. It is not a claim that no implementation exists: musicpy 7.15
has an actively released and documented fixed-split detector, ChordRecGen
recursively names leftover notes as additional chords, and mingus performs
unranked slice enumeration. All three are direct software prior art and must be
disclosed and compared as baselines.

The concept also appears as parseable input notation (Impro-Visor's leadsheet
grammar reserves backslash for polychords, `D\C7`, explicitly to stay
unambiguous from slash chords); as a vocabulary nuisance deliberately erased
(Bunks and Weyde 2022 found 12 polychords in the Impro-Visor corpus and mapped
them to their lower structure); and in patents that define, encode, or generate
polychords. Casio US 4,966,052 is more than a definition, though it does not
infer a name from observed notes; Microsoft US 5,900,567 assigns tracks to
members of a polychord progression. US 2024/0274022 A1 uses "polyharmonic music
recognition" for redundant-note transcription and score alignment, not
chord-over-chord naming. The papers and vocabularies checked still use one
sonority label at a time: concurrent "multiple key estimation" results were
sequential local-key estimation, and voice-separation work did not name harmonic
layers. The exact claim boundary, 52-query rerun, implementation pins, and
source ledger are in `../prior-art-search.md`.

**Terminology conventions the initiative adopts.** The field's usage, mapped to
sources with the remaining citation gaps stated explicitly:

- **Polychord** is the sanctioned term for the thing WhatChord would name: a
  construction/notation claim about chord-over-chord, with no key claim.
  Persichetti (Twentieth-Century Harmony, p. 135, verbatim): "A polychord is the
  simultaneous combination of two or more chords from different harmonic
  areas... Clear grouping of the chordal units is a requisite of polyharmony,
  and rearranging the tones of these units can destroy the polychordal
  organization." Registral grouping is definitional in the pedagogical
  tradition. A secondary course term sheet summarizing Kostka adds the
  perceptual condition that separate harmonic entities must be heard; the exact
  Kostka edition and page are not yet pinned, so this remains a paraphrase, not
  a publication-ready quotation. **Bichord** is available for the strict
  two-triad case (Milhaud, Murphy, Heine, Moreira). The Persichetti
  transcription likewise needs checking against the identified physical or
  licensed edition before publication.
- **Bitonality/polytonality** assert simultaneous keys and are contested words
  (Berger and van den Toorn dismissed them for the Petrushka repertoire via the
  octatonic reading; Tymoczko's 2002-03 MTS exchange rehabilitates a modest
  version and coins **polyscalarity** precisely to avoid the perception claim).
  Avoid in user-facing text and in the suite's expected readings.
- **Superimposition** is the neutral construction-side verb; **stratification**
  (Cone 1962) names a temporal/formal process of juxtaposed blocks, not a
  stacked sonority, and must not be used for voicings. **Polyharmony** is a
  loose practice word, not a precise term.
- **Upper structure** (jazz) names a register-separated triad expressing one
  function over a shell; the tradition treats it as a single chord symbol. A
  working note derived from Ulehla states the relevant anti-pattern: extending
  the harmony through the seventh in both registers can unite the treble tones
  with the bass root as one higher-numbered chord. The book is identified, but
  the exact page and wording were not recovered from a primary preview; use this
  as a ruler hypothesis, not a citable authority, until the page is verified.

**Perception: register alone does not deliver independent layers.** Moreira (MTO
31.4, on Herrmann's polychords) supplies the criteria list, from Huron 2016
after Bregman: onset synchrony, parallel motion, close harmonic relation, close
register, and homogeneous timbre favor integration; their opposites favor
segregation, as matters of degree. His verdict on the Augurs chord: polychordal
in construction, but "onset synchrony and pitch proximity among the two chordal
layers... make it very difficult for most listeners to separate the two
harmonies perceptually," a single fused stream. Krumhansl and Schmuckler (1986)
found the arpeggiated Petrushka layers fuse: dichotic presentation could not
separate them, and the combined percept was an amalgamation consistent with the
octatonic reading rather than two keys. Thompson and Mor (1992) found that even
wide registral separation of two keys did not lead listeners to associate each
key with its register. Implication, feeding open decision 1: an engine with
pitch-and-register input cannot honestly claim perceptually independent layers;
it can honestly name a notational chordal decomposition, which is exactly what
the pedagogical polychord is. Moreira's fusion findings are the reason to claim
less, not obstacles to the feature.

Wolf and Wuest (2026), published after the older perception anchors, likewise
describe the intertwined percept as predominant in their non-dichotomous
key-clash task and release data, code, and stimuli. This makes the perception
survey current through the initiative date without changing the claim boundary:
perception of concurrent keys is adjacent evidence, not ground truth for a
notational decomposition detector.

**Notation conventions, and an ordering trap.** Textbook notation stacks two
chord symbols with a horizontal line (never a slash; sources explicitly
discourage the horizontal line for slash chords because it implies a polychord).
Engraving software exposes the convention directly: Dorico supports native entry
(popover `D|C7`, upper chord first, with stacked or side-by-side rendering), and
MuseScore Studio 4.6 (June 2025) added pipe entry (`F|C`) with stacked
rendering. Impro-Visor's backslash also puts the upper chord first (`D\C7` is a
D triad extending C7). Moreira's own backslash notation is the reverse (lower
chord on the left, `Dm\G#m` has Dm below). Our census notation (upper|lower,
e.g. F#|C) matches the engraver convention; any future user-facing symbol must
document its order explicitly. On the encoding side, MusicXML's harmony element
has a dormant polychord slot (repeated harmony-chord groups; the kind element
documentation mentions polychords by name), while Harte, JAMS, Humdrum harm
(which suggests two parallel harm spines for polytonal works), DCML, RomanText,
and MEI have no polychord operator in the versions inspected; chord-symbol (npm)
documents its non-support. That negative standards result must be version-pinned
before publication. musicpy, ChordRecGen, and mingus all emit or represent
inferred polychord names by different heuristics.

**Publication assessment.** A plausible contribution survives due diligence, but
"no detector" does not. Realistic shape: an ISMIR full paper framed as
"polychord naming lacks an explicit task definition, independently annotated
evaluation set, and evaluated detector," contributing the hand-authored ruler,
the exposure census, a polychord-aware metric, baseline comparisons, and the
register-licensed decomposition detector; TISMIR dataset article is the
alternative if the ruler and census are the core. Template precedents: Harte
2005 (syntax plus data), Burgoyne 2011 (Billboard annotation methodology),
Humphrey and Bello 2015 (vocabulary and annotation quality as the bottleneck),
Koops 2019 (annotator subjectivity; sets the agreement bar), JAAH 2018,
RomanText 2019 (ISMIR accepts format papers). Citation neighbors: Jiang 2019
(chord structure decomposition, single-symbol recomposition), Chen 2020 (chord
jazzification, the symbol-to-voicing inverse of our direction), McFee and Bello
2017, Rowe and Tzanetakis 2021, ChoCo 2023, GCT 2014. Reviewers will demand: a
second independent annotator with agreement statistics on the ruler (the
highest-leverage preparation item); a polychord-aware evaluation metric with
partial credit (a Harte-syntax stacking extension plus comparator would itself
be citable); reproducibility (release the ruler, census code, and a reference
implementation of the licensing rule; a closed engine alone will not pass); a
non-circular census (log -04's complete hand-dispositioned fire table is the
right shape); and redistributable or stably-referenced corpora. musicpy 7.15 and
mingus are mandatory executable baselines; ChordRecGen should be included if its
archived toolchain can be made reproducible.

**Search scope (for the novelty claim).** The exploratory sweep reported 48
queries, DBLP title probes, and fourteen targeted full-text checks, but the
literal query strings and dispositions were not retained. It cannot support a
replayability claim. A replacement 52-query screen, recorded verbatim in
`../prior-art-search.md`, covered polychord, bichord, polyharmony,
superimposition, concurrent-key, layer, multi-label, MIR-venue, implementation,
patent, perception, and source-verification vocabulary. Known limitations
remain: no protocolized full-text sweep of every ISMIR/TISMIR, ICMC, or SMC
paper; no bibliographic index with guaranteed coverage; no multilingual sweep
beyond the earlier single French probe; no archival capture of search results;
patent space sampled rather than systematically searched. "PolyChord" is also a
heavily cited astrophysics sampler, "bichord" often means a dyad in
transcription DSP, and "chord decomposition" in MIR often means factoring one
label into components.

**Plain-English reading.** We found a narrower and more credible opportunity
than the first pass claimed. We did not find a published, evaluated method for
naming two stacked chords, but working software already attempts the task, most
notably musicpy. That gives us baselines instead of a blank field. The
music-theory world has settled words for the construction: what we would show is
a polychord, a statement about how the notes are built and written. Perception
research says even famous examples often fuse into one sound, so the feature
should describe structure and never claim what the listener perceives. A
score-verified ruler, second annotator, explicit metric, baseline comparison,
and reproducible search are the work that could make the result publishable.

**Next.** Ratify the product and evidence semantics together, then score-verify
and encode a small pilot ruler before freezing the full suite. In parallel with
that pilot, build pinned baseline adapters for musicpy and mingus so their
behavior informs the annotation guidelines rather than being consulted only
after the ruler is fixed. Decision 2 can cite Thompson and Mor, Krumhansl and
Schmuckler, and Wolf and Wuest against any perception claim from register alone;
decision 3 includes a second annotator if publication remains an objective.

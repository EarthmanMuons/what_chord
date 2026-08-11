# 2026-08-10: Correct Elektra and admit the overlapping-cover boundary

**Goal.** Fill the preregistered one-sounded-note overlapping-cover cell without
misclassifying the Elektra chord as a complete upper triad over a bare lower
fifth, and without presenting an analytical octave normalization as a literal
score transcription.

**Setup.** Work began from repository commit `34d3441f`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

## Source correction

The earlier candidate record described the Elektra chord as D-flat major above
an E-B fifth. That account names only the visibly lower two notes of the common
five-note stack and misses the enharmonic role of its top A-flat.

The stronger scholarly trail establishes the distinction:

- Richard Kaplan's 1985 University of Michigan dissertation defines compound
  chords as elements of two or more triads or seventh chords and identifies the
  Elektra chord as a notable example. The stable repository record is
  <https://hdl.handle.net/2027.42/160545>; its PDF is restricted to University
  of Michigan users.
- Lawrence Kramer describes Elektra's five-note collection as a conjunction of
  D-flat major and E major in _Cambridge Opera Journal_ 5.2 (1993), pp. 141-165,
  DOI <https://doi.org/10.1017/S0954586700003967>.
- Kyle Hutchinson's 2020 University of Toronto dissertation, _Harmonic Function
  in the Late Nineteenth-Century Chromatic Tonality of Wagner and Strauss_, pp.
  201-205, records the absolute-pitch form E-B-Db-F-Ab and reports the
  prevailing two-triad analysis: the upper D-flat triad's fifth also functions
  enharmonically as the lower E-major triad's third. Hutchinson then develops a
  competing function- and voice-leading-based reading. An indexed full-text copy
  supplied the page-level check; no stable open institutional full text was
  found. The University of Toronto's official dissertation list confirms the
  author, year, and title:
  <https://music.utoronto.ca/areas/music-theory/alumni>.
- Hutchinson's later peer-reviewed treatment, _Music Analysis_ 45.1 (2026), pp.
  3-39, emphasizes that the Elektra chord has accumulated multiple harmonic and
  voice-leading interpretations rather than treating the two-triad account as
  uncontested perceptual ground truth: <https://doi.org/10.1111/musa.70002>.

A public-domain 1908 piano-vocal score was also inspected as a primary-score
context check:

- Richard Strauss, _Elektra_, piano-vocal reduction by Otto Singer;
- Adolph Furstner plate A.5654F, Sibley Music Library scan, IMSLP151615;
- 248 PDF pages;
- SHA-256 `9f7e8f52f42c2f439aa704ed6870530130b33f3c9da932e2bdf6a12538798568`;
  and
- catalog <https://imslp.org/wiki/Elektra_(Strauss,_Richard)>.

The opening pages and the surrounding score locations cited by the analyses were
rendered and visually inspected. The reduction confirms that this is a
registered, contextual sonority rather than an abstract unordered set, but it
does not justify treating one simplified five-note close-position stack as the
exact orchestral voicing for every occurrence. The suite case is therefore
explicitly generated and theory-derived. The score scan is contextual evidence,
not the exact case source.

Equivalent acquisition and inspection commands are:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/elektra-vocal-score-sibley.pdf \
  'https://s9.imslp.org/files/imglnks/usimg/4/4f/IMSLP151615-PMLP55122-Strauss_-_Elektra_VS_Sibley.1802.16776.pdf'
shasum -a 256 tmp/pdfs/elektra-vocal-score-sibley.pdf
pdfinfo tmp/pdfs/elektra-vocal-score-sibley.pdf
pdftoppm -f 4 -l 4 -png -r 200 -singlefile \
  tmp/pdfs/elektra-vocal-score-sibley.pdf \
  tmp/pdfs/elektra-vs-page-004
pdftoppm -f 18 -l 19 -png -r 200 \
  tmp/pdfs/elektra-vocal-score-sibley.pdf \
  tmp/pdfs/elektra-vs-page
```

## Exact guard

The generated observation places the literature-attested pitch set in ascending
close position:

| MIDI | Observation spelling | E-major role | D-flat-major role |
| ---- | -------------------- | ------------ | ----------------- |
| 40   | E2                   | root         |                   |
| 47   | B2                   | fifth        |                   |
| 49   | Db3                  |              | root              |
| 53   | F3                   |              | third             |
| 56   | Ab3                  | G#3, third   | Ab3, fifth        |

The observation has five physical MIDI notes, not six. MIDI 56 is assigned to
both analytical units with a unit-specific enharmonic spelling. That makes both
units complete major triads in the construction record while preserving the fact
that Framework v0 cannot generate or display the decomposition: v0 requires a
distinct sounded-note instance for every layer assignment.

The construction notation is `Db|E`, following Hutchinson's upper- and
lower-triad description. `Db7(#9)` and `E6(b9)` remain explicit integrated
alternatives. The product class is `boundary`, every v0 snapshot input condition
is ineligible, and the register baseline is empty.

## Schema decision

The old `polychord-internal-suite/1` contract required construction units to be
disjoint at the MIDI-note level. Silently weakening that invariant would make
old and new suite documents mean different things under one schema identifier.
The active seed therefore moves to `polychord-internal-suite/2`.

Schema 2 permits note reuse only when all of these executable conditions hold:

1. the construction is a two-unit polychord;
2. `one-sounded-note-overlap` is declared;
3. exactly one observed MIDI note occurs in both unit assignments;
4. the two assignments still cover every observed note; and
5. the product expectation remains a Framework-v0 boundary.

The validator rejects undeclared reuse, a false overlap feature, reuse of more
than one note, use on another construction kind, and a positive or
negative-guard product class. The exception records an analytical boundary; it
does not widen the register candidate generator, split census, or product scope.

## Verification

The completed change was checked with:

```sh
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/adoption-suite-plan.md \
  research/polychord/golden-candidates.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/log/2026-08-10-23-elektra-overlap-boundary.md \
  research/polychord/data/internal-suite/suite-v0.json
git diff --check
```

The final evidence pins are:

- adoption-suite plan:
  `1ceee3181986a1fa6249903efeaac13195d2b865f2ae4a7a8f13486876e580ae`;
- internal-suite schema:
  `daa2851cca88f8c0fdd3673423b183250f3b9ceb6213c93c396317a8acc5bb74`;
- internal-suite validator:
  `f163c5cfb4e6bfb92a95f6360bd9a7fc2504b017e46dad07953acab1d910414e`;
- internal-suite tests:
  `31ad9c84d7a8bebd67243240d166072f423779621b924c42d9ab338cc5fe34f9`; and
- fourteen-case internal suite:
  `1d21baaf06fe58bfaf4f9e28bd6fa5395d26e8565af5e82391bf60fa37e15844`.

Final validation passed all 177 polychord Python tests, all 14 internal-suite
cases, Python lint and formatting, Markdown and JSON formatting, and
`git diff --check`.

**Plain-English reading.** Elektra was not evidence that a two-note fifth should
be accepted as a chord layer. In the standard two-triad analysis, its fifth note
does double duty: the same key is heard as A-flat in D-flat major and G-sharp in
E major. The research suite now records that musical analysis while also
requiring the proposed v0 feature to abstain, because a five-note MIDI snapshot
does not contain two separate copies of that shared note.

**Decisions.** Correct Elektra from the bare-fifth backlog to the
one-sounded-note overlapping-cover boundary. Keep the exact suite observation
synthetic and theory-derived, preserve the competing integrated analyses, and
version the suite schema rather than weakening schema 1 in place.

**Next.** Continue the still-open abstention cells with a genuinely
source-backed lone-bass or bare-fifth case and an ordinary accompaniment
voicing. Do not use Elektra to satisfy either one.

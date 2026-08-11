# 2026-08-10: Admit disjoint and seventh-layer source positives

**Goal.** Fill the two recoverable static-positive cells left open by
`adoption-suite-plan.md`: one source-attested polychord with
pitch-class-disjoint units and one with a complete common seventh-chord layer.
Require exact, recoverable voicings and preserve competing integrated or
structural readings.

**Setup.** Work began from clean repository commit `0480ae80`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

The disjoint lead came from Daniel Moreira, “Weird, Menacing, and Colorful:
Bernard Herrmann's Harmonic Polytonality,” _Music Theory Online_ 31.4 (2025),
DOI `10.30535/mto.31.4.5`. The article describes the two minor triads in “The
Pass” as autonomous, registrally distinct layers and explains that its backslash
notation orders the lower unit first. The official examples PDF provides the
exact transcription:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-2025.pdf \
  https://www.mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.pdf
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-examples.pdf \
  https://www.mtosmt.org/issues/mto.25.31.4/moreira_examples.pdf
shasum -a 256 \
  tmp/pdfs/moreira-2025.pdf \
  tmp/pdfs/moreira-examples.pdf
pdfinfo tmp/pdfs/moreira-examples.pdf
pdftoppm -f 5 -l 5 -png -r 600 \
  tmp/pdfs/moreira-examples.pdf \
  tmp/pdfs/moreira-example
```

The article-text PDF had SHA-256
`7d7f6313c418096189e64d252e576318a33eaac317f2674304024a72a70ccb8d`. The 24-page
examples PDF had SHA-256
`09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`. Only its
digest and source reference enter the suite; the copyrighted PDF and render
remain uncommitted verification artifacts.

The seventh-layer lead came from Robert Hutchinson's open _Music Theory for the
21st-Century Classroom_, section 32.4. Figure 32.4.3 identifies a passage from
the third of Stravinsky's _Three Movements from Petrouchka_ as chromatically
ascending dominant seventh chords in the left hand against repeating G, F, and C
triads in the right. The linked performance covers 8:07 through 8:15 of the
third movement. Exact notes were verified against the public-domain 1922
solo-piano score linked from IMSLP:

```sh
curl -L --max-time 30 \
  -o /tmp/pugetsound-polychords.html \
  https://musictheory.pugetsound.edu/mt21c/polychords.html
shasum -a 256 /tmp/pugetsound-polychords.html
curl -L --max-time 30 \
  -o tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  'https://petruccilibrary.us/autoindex/index.php?dir=imslp-us_files%2FStravinsky_Igor_1971%2F&file=Stravinsky_-_Petrushka_3mvts.pdf'
shasum -a 256 tmp/pdfs/stravinsky-petrushka-3mvts.pdf
pdfinfo tmp/pdfs/stravinsky-petrushka-3mvts.pdf
pdftoppm -f 37 -l 37 -png -r 600 -singlefile \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  tmp/pdfs/stravinsky-page-37
```

The textbook HTML snapshot had SHA-256
`7b59a70a0ea33bdc88242afbb459451e3b547593b471d837bcee7af7d2e00904`. The 37-page
score had SHA-256
`90d0b14d929697f33762eacb715c3331a6ebf0faf1e722e0f50598241ebf5664`. The suite
pins the score digest and records Hutchinson's pedagogical identification in the
source metadata. The HTML snapshot, PDF, and render remain uncommitted
verification artifacts.

The admitted observations are:

| Source and attack                                                                    | Lower source unit                          | Upper source unit                   | MIDI notes             |
| ------------------------------------------------------------------------------------ | ------------------------------------------ | ----------------------------------- | ---------------------- |
| Herrmann, “The Pass,” first notated measure, first A-flat-minor attack               | A-flat minor: A-flat 3, C-flat 4, E-flat 4 | sustained G minor: G4, B-flat 4, D5 | 56 59 63 / 67 70 74    |
| Stravinsky, printed page 37, fourth right-hand attack after _p sub. e staccatissimo_ | A-flat 7: A-flat 2, C3, E-flat 3, G-flat 3 | G major: G4, B4, D5                 | 44 48 51 54 / 67 71 74 |

Both observations are simultaneous states, not aggregates across arpeggios. Both
are pitch-class-disjoint across the source units and have one exact
adjacent-register boundary. The Herrmann attack is asynchronous in the score:
the G-minor triad is already sustained when the A-flat-minor triad attacks. That
history supports the source analysis but is not manufactured as event data in
the snapshot suite.

The exact structural and suite checks were:

```sh
python3 tool/polychord/register_candidates.py \
  56 59 63 67 70 74
python3 tool/polychord/register_candidates.py \
  44 48 51 54 67 71 74
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
  research/polychord/log/2026-08-10-21-source-positive-admissions.md
git diff --check
```

The final evidence pins are:

- unchanged Framework v0:
  `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615`;
- amended adoption-suite plan:
  `9572316c6d3af3105c4d73c30e5c3b31f0c476a39cd73e2115b538d9044af9ca`;
- amended internal-suite schema:
  `317e45300238b86a5f627058dbfe0c23bdf1f891b0e5c9a56ef783aa10334dda`;
- amended internal-suite validator:
  `b3df80b53a5cb32ab07741e64ed7a9f5f4e3b6e822b04cd48fcb3a2da3e7f07f`;
- internal-suite tests:
  `e722421fc485556c4718a4ce79837cb551313d7656cbbfbf0aa1c53aaf7998a7`; and
- twelve-case internal suite:
  `d870099d3b1d9ad694c513dfc9f9938eef56c5f695bf2b1940dff78fabfcfae8`.

Final validation passed all 166 polychord Python tests, all 12 internal-suite
cases, Python lint and formatting, Markdown and JSON formatting, and
`git diff --check`.

## What happened

The Herrmann snapshot produces exactly one register candidate. The mechanical
generator serializes the enharmonic lower root as G-sharp minor, while the score
and Moreira spell it A-flat minor. The source-resolved product symbol is
therefore `Gm|Abm`; the generator's neutral diagnostic symbol remains `Gm|G#m`.
Moreira explicitly acknowledges the possible extended-tertian reading of this
root relation, so `Abm(maj9,#11)` remains recorded as a less concise
single-chord alternative.

The Stravinsky snapshot produces two register candidates. The intended
source-hand boundary yields G major over A-flat dominant seventh, mechanically
serialized as `G|G#7` and source-spelled as `G|Ab7`. An earlier boundary instead
assigns A-flat, C, and E-flat to A-flat major and folds the left-hand G-flat
into G major seven above it, mechanically serialized as `Gmaj7|G#`. That
competing identity is not deleted: it makes the case a source-backed test that
selection must not follow generator iteration order.

Not every verticality in the ascending-seventh passage is a positive under the
working product semantics. Some alignments share a root or have a concise
integrated dominant-extension name. The admitted `G|Ab7` attack has different
roots, disjoint complete units, and no concise conventional single-chord name.
It therefore supplies the missing complete-seventh positive without weakening
the framework's upper-structure boundary.

The validator now treats `disjoint-pitch-class-layers` and
`multiple-structural-identities` as executable scope claims. A case carrying the
first tag must have nonintersecting unit pitch-class sets; a case carrying the
second must actually generate at least two distinct ordered chord identities.

**Plain-English reading.** The suite no longer relies on generated examples to
show that the first detector can handle ordinary two-triad polychords or a full
seventh chord. Both behaviors now have exact published musical examples. The
Stravinsky example also catches a realistic failure mode: the same notes admit
another mechanically valid split, so later code must make an explicit musical
choice instead of accepting the first result it encounters.

**Decisions.** Admit both observations as literature-attested positives in the
non-scorable author-adjudicated suite. Preserve source spellings separately from
the generator's neutral pitch-class spelling. Keep the Herrmann integrated
alternative and both Stravinsky structural candidates visible. Mark event input
unavailable rather than reconstructing timing from notation or a recording.
Treat the disjoint and complete-seventh construction-anchor cells as satisfied,
but do not freeze or score the adoption suite.

**Next.** Resolve the remaining source-coverage work in the preregistered order,
starting with a moving or arpeggiated literature construction represented by an
exact replay rather than a false vertical snapshot. Continue filling the named
abstention guards before defining or evaluating a selector. Do not read the held
POP909 reserve.

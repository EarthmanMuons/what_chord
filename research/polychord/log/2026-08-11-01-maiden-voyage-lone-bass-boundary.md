# 2026-08-11: Admit the Maiden Voyage lone-bass boundary

**Goal.** Fill the preregistered source-backed lone-bass-or-bare-fifth cell
without relying on the contested Zarathustra ending, an unverified Rumble
measure, or an unsupported reconstruction of Hancock's piano voicing.

**Setup.** Work began from clean repository commit `ea6a8324`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

## Search and source decision

The focused follow-up used these query families:

- `Herbie Hancock Maiden Voyage chord voicing D A C E G scholarly analysis PDF`;
- `"Maiden Voyage" "D9sus" Hancock analysis`;
- `"Maiden Voyage" "Am7/D" Hancock`;
- `site:mtosmt.org "Maiden Voyage" Hancock chord`;
- `Herbie Hancock Maiden Voyage exact piano voicing "D A" "G C E"`;
- `"Maiden Voyage" "D and A" left hand voicing`;
- `"Maiden Voyage" "D-A" "C major triad"`; and
- `Keith Waters "What is Modal Jazz?" 2000 journal` plus title-and-example
  variants.

Keith Waters's peer-reviewed _Jazz Educators Journal_ article, "What Is Modal
Jazz?", supplies the strongest accessible analytical record. Its discussion of
Example 3 identifies the A-section accompaniment as `A-7/D` and explicitly gives
the five pitches D, E, G, A, and C. The artifact metadata identifies _Jazz
Educators Journal_ 33.1 (July 2000), pp. 53-55, ISSN 0730-9791, and ProQuest
document 1368405. The inspected artifact is:

- <https://docdrop.org/download_annotation_doc/Waters---2000---What-is-Modal-Jazz-buxx4.pdf>;
- SHA-256 `94ff0ba22f83df4283b1b0e6f600b0a55b72629ccba0345514749e6de42af78f`;
  and
- target discussion on article p. 53, downloaded PDF page 4.

The University of Colorado Boulder publication record independently confirms the
author, article title, year, volume, issue, and page range:
<https://experts.colorado.edu/display/pubid_94229>. Hancock's official album
page independently describes _Maiden Voyage_ as harmony based on dominant-based
sus chords:
<https://www.herbiehancock.com/music/discography/album/maiden-voyage/>.

Two weaker trails were not used as exact evidence. A piano-teaching page and a
user report describe particular hand voicings, but neither is a stable scholarly
or primary score source. An Alfred jazz-band preview was also downloaded and
visually inspected. It is Erik Morales's later transposed arrangement, not a
transcription of Hancock's 1965 piano part, so it cannot establish the target
observation. Its rejected-context artifact has SHA-256
`0e38bdbaec1d32366dd56eb005480d70d49994853d6a6e1aa47ddeb4cb3a6e10`.

This corrects the earlier candidate wording. The evidence supports a complete
A-minor-seventh chord over a lone D bass. It does not establish the previously
asserted D-A lower fifth beneath a C-major triad.

## PDF inspection

The PDF workflow rendered the article discussion rather than relying only on
search-result snippets or extracted text:

```sh
mkdir -p tmp/pdfs
curl -L --max-time 30 \
  'https://docdrop.org/download_annotation_doc/Waters---2000---What-is-Modal-Jazz-buxx4.pdf' \
  -o tmp/pdfs/waters-2000-what-is-modal-jazz.pdf
shasum -a 256 tmp/pdfs/waters-2000-what-is-modal-jazz.pdf
pdfinfo tmp/pdfs/waters-2000-what-is-modal-jazz.pdf
pdftoppm -f 4 -l 4 -png -r 250 \
  tmp/pdfs/waters-2000-what-is-modal-jazz.pdf \
  tmp/pdfs/waters-page
```

The ProQuest-generated copy omits Example 3's notation image but retains
Waters's complete prose identification and exact pitch collection. That is
enough to preserve the named slash-chord division, but not enough to claim exact
octaves.

## Exact analytical normalization

The suite therefore records an analytical normalization, not a transcription:

| MIDI | Spelling | Assigned unit |
| ---- | -------- | ------------- |
| 38   | D2       | lone D bass   |
| 57   | A3       | Am7 root      |
| 60   | C4       | Am7 third     |
| 64   | E4       | Am7 fifth     |
| 67   | G4       | Am7 seventh   |

This preserves all and only Waters's pitch classes and his `A-7/D` division. The
large octave placement merely makes the source-established bass-versus-upper
relationship explicit. It makes no claim about the register of Hancock's
recorded attack.

The construction kind is `upper-structure`, the product class is `boundary`, and
the preferred single-sonority labels are `D9sus4` and `Am7/D`. Framework v0 must
emit no polychord because the lower unit is one note rather than a complete
common chord. The fixed register generator also emits no candidate.

## Schema decision

The internal suite previously represented only literal score records and fully
synthetic generation recipes. Recasting this case as either would erase an
important provenance distinction. Schema 2 now also accepts an `analysis` source
record containing a stable citation, source identifier, artifact digest, page
location, and explicit normalization recipe.

The new `lone-bass-lower-unit` feature is executable. It requires:

1. an `upper-structure` construction;
2. a `boundary` product expectation;
3. exactly one `bass-note` unit containing only the observation's lowest note;
   and
4. exactly one other unit whose quality is in the unchanged Framework-v0 common
   chord vocabulary.

The validator also rejects `bass-note` construction units that omit the scope
feature. `bass-note` is not added to `POLYCHORD_QUALITIES` or the register
generator, so this admission records the exclusion boundary without widening the
proposed detector.

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
  research/polychord/log/2026-08-11-01-maiden-voyage-lone-bass-boundary.md \
  research/polychord/data/internal-suite/suite-v0.json
git diff --check
```

The final evidence pins are:

- adoption-suite plan:
  `20099a7a4138d145923075fb2c2d58497b1000233fc7b20555af47c9b9182c82`;
- internal-suite schema:
  `33b707d4791003db2dd311a0ddbb480b68139736c5a7de2986a83c9cedbe7143`;
- internal-suite validator:
  `49a0c65afa144905d5aea89f20e96d09570cb2f66c59e13ffc1248cced77e9b6`;
- internal-suite tests:
  `b92cf2f7b7def8774a075b8e9774422e8df0529a7cd37c2c3b3c51268b14d9c2`; and
- seventeen-case internal suite:
  `3605ac1b61f9f821c08058b82e8f12f9502fcaa6a40c1eb5af5e537a34385be9`.

Final validation passed all 189 polychord Python tests, all 17 internal-suite
cases, Python lint and formatting, Markdown and JSON formatting, and
`git diff --check`.

**Plain-English reading.** _Maiden Voyage_ is a useful boundary precisely
because musicians can describe its opening harmony as a complete Am7 chord over
D while D remains only a bass note. That slash-chord decomposition is
source-backed, but it does not turn the bass into a second chord. The v0
polychord feature should therefore abstain.

**Decisions.** Replace the unsupported bare-fifth description with Waters's
source-backed lone-bass analysis. Admit a disclosed octave normalization, make
the lone-bass exclusion executable, and leave the complete-layer generator
unchanged.

**Next.** Audit the preregistered input-condition and scorer controls before
freezing the adoption suite. A genuine source-backed bare-fifth case remains
useful future coverage but is no longer a v0 freeze prerequisite.

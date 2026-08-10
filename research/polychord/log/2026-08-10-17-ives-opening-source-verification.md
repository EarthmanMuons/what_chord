# 2026-08-10: Verify the Ives opening as a recoverable positive

**Goal.** Determine whether the opening of Charles Ives's _Psalm 67_ supplies a
literature-attested positive whose exact score voicing is eligible for the
frozen Framework-v0 adjacent-register generator. Preserve the integrated chord
alternative and record a negative result if the assumed register split does not
survive score verification.

**Setup.** Work began from clean repository commit `6bbf8ba2`. The target was
selected in log 2026-08-10-16 because it exercises both the separate-note
shared-pitch-class rule and the C9 pitch-set trap. This is source verification
for the non-scorable internal suite, not an independent annotation or accuracy
test.

The analytical source is Thomas Johnson, “Tonality as Topic: Opening A World of
Analysis for Early Twentieth-Century Modernist Music,” _Music Theory Online_
23.4 (2017), DOI `10.30535/mto.23.4.7`. Section 6.7 describes G-minor bass
voices and C-major treble voices; Example 11 reproduces the opening reduction
and calls out the C-major treble triad inside a framework of multiple triads.
The official example image was retrieved and pinned with:

```sh
curl -L --max-time 30 \
  -o /tmp/ives-johnson-ex11.png \
  https://mtosmt.org/issues/mto.17.23.4/johnson_ex11.png
shasum -a 256 /tmp/ives-johnson-ex11.png
```

The 920-by-296-pixel image had SHA-256
`3f8894e1a2df77fe001cd76ebaff5b382d42fb42b59fb26e6ec4baaddabcf75c`.

The score cross-check was the publicly displayed first-page preview of the 1939
Associated Music Publishers edition. It shows the original divided soprano,
alto, tenor, and bass parts plus Ives's rehearsal reduction. It was retrieved
only to `/tmp` and was not copied into the repository:

```sh
curl -L --max-time 30 \
  -o /tmp/ives-psalm67-preview.jpg \
  'https://imgv2-1-f.scribdassets.com/img/document/391492928/original/3694007c68/1?v=1'
shasum -a 256 /tmp/ives-psalm67-preview.jpg
```

The 768-by-1024-pixel preview had SHA-256
`96ca1a2a2d4c638bb53b5bf95af115997ad62145a825b4aae753158c02f9d0b7`. The source
page was
`https://www.scribd.com/document/391492928/Charles-E-Ives-Sixty-seventh-Psalm-Cor`.
The preview carries the publisher's copyright notice; it is a verification
artifact, not redistributable project data.

A public MuseScore user transcription was also inspected as a secondary visual
cross-check. Its source page was
`https://musescore.com/user/2214291/scores/5589282`, and its first-page image
had SHA-256 `8d2e280f008a50e347bcc4514050f2363efe8b110d2312bb81b5207365888d47`.
It is not an authoritative source and does not support the case's epistemic
status. The suite pins the peer-reviewed MTO example, and the original-edition
preview supplies the direct score cross-check.

The verified opening snapshot is:

| Score group                   | Chord   | Sounding notes    | MIDI notes  |
| ----------------------------- | ------- | ----------------- | ----------- |
| Tenor and bass, four voices   | G minor | G2 D3 G3 B-flat 3 | 43 50 55 58 |
| Soprano and alto, four voices | C major | C4 E4 G4 C5       | 60 64 67 72 |

The two chordal units share pitch class G through the separate notes G3 and G4.
Every lower-voice note is below every upper-voice note, with a two-semitone
boundary from B-flat 3 to C4. No timing, articulation, choir label, or perceived
stream separation is inferred from the static snapshot.

The exact structural check was:

```sh
python3 tool/polychord/register_candidates.py \
  43 50 55 58 60 64 67 72
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/golden-candidates.md \
  research/polychord/log/2026-08-10-17-ives-opening-source-verification.md
git diff --check
```

The final evidence pins are:

- unchanged Framework v0:
  `a5d83115be7d700e007110fe8f1313d435ad456f4c122f5f7d184baf423a212a`;
- unchanged register candidate implementation:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- unchanged internal-suite schema:
  `6f8f1c216575f97906ce6ecd22fedaacc1d5406708406f13df5f491fefcfa190`;
- unchanged internal-suite validator:
  `82d098942724f4a773bf7cdc7b707efba6e85370a8fe780872a739d8c4f54b80`;
- internal-suite tests:
  `2ef88c49f059a7d5ce531da3f770229019320f41bc405da2a67d683013f6cf69`; and
- ten-case internal suite:
  `0d190af2eac2243fe93c0a70e0f8f2632f11ea27a358ebdf69c073251faaebb7`.

Final validation passed all 155 polychord Python tests, all ten internal-suite
cases, Python lint and formatting, Markdown formatting, JSON formatting, and
`git diff --check`.

## What happened

The register generator emitted exactly one candidate. It split after B-flat 3,
assigned all four lower notes to G minor and all four upper notes to C major,
reported shared pitch class G, and serialized the construction as `C|Gm`.

The pitch-class union is exactly C9, while the observed bass is G. The exact
single-chord alternative for this voicing is therefore `C9/G`. This also exposed
an imprecision in the analogous synthetic layered case, whose exact voicing has
the same bass; its alternative was corrected from `C9` to `C9/G` without
changing its construction, register candidate, or product class.

Johnson discusses the passage using the language of a polytonal framework, not
as a computational polychord label. The source-attested fact needed here is
narrower: it explicitly separates conventional G-minor and C-major chordal units
into lower and upper voices. Classifying that construction as a secondary `C|Gm`
polychord is the Framework-v0 product-policy inference. It does not assert two
perceived keys or independent auditory streams.

**Plain-English reading.** This is the first real score example in the active
suite where the simple register proposal finds exactly the two chords described
by the musical analysis. It is still not an easy naming case: the same notes
make an ordinary C9 chord over G. WhatChord can therefore propose the polychord
as a useful second description without pretending that register makes the
single-chord reading wrong.

**Decisions.** Admit the opening as a literature-attested positive in the
author-adjudicated internal suite. Preserve `C9/G` as the primary single-chord
alternative, mark the adjacent-register snapshot eligible, mark unrestricted
pitch-and-register interpretation ambiguous, and leave timestamped-event input
unavailable. Do not treat choir assignment, analytical terminology, or the
maintainer's product expectation as data available to the live detector. Do not
commit or redistribute either score image.

**Next.** Begin the output-and-evaluation contract before implementing an engine
lever: define the composite result type, how a secondary polychord annotation
coexists with the primary chord, spelling and spoken forms, history and
accessibility behavior, abstention, metrics, and the adoption threshold. Do not
spend the held POP909 reserve or score the current author-adjudicated seed.

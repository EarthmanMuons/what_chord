# 2026-08-11: Plan the automatic timestamped-MIDI suite

**Goal.** Fix the version-2 suite boundary, audit the frozen suite's temporal
coverage, and identify which source evidence is still required before an exact
automatic selector can be preregistered.

**Setup.** Tracked files began at clean commit
`5a68fe7c85d80f423b8dab16cceb444e0906230e`. No selector output, new corpus
outcome, or held POP909 song was read. Source PDFs, HTML, audio, and renders
were kept as uncommitted temporary verification artifacts. The design began from
these fixed inputs:

- v2 selection plan:
  `a0becd9110df7e4be3081f2cf3b4bafeb5cc518330a01dd1412bc4d9738cfaad`;
- v2 output contract:
  `83bf6a5f182b3b720d4d21863964ddf5a9a2da35014f2ef9d24e3c657b94d81c2`;
- frozen internal suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- frame-replay manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`;
- onset support rule:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`; and
- motion support rule:
  `50886b62cf5e361148af3b05fd015f0e75a54eb5f4a36fac4ac690f07d57e083`.

This was a coverage and source-audit step, not a measurement of selector
performance. The already exposed v1 suite and corpus outcomes remained
development evidence.

## Frozen-suite audit

The exact inventory command was:

```sh
jq -r \
  '.cases[] | [.id, .productExpectation.class,
  .inputEligibility.timestampedEventStream.status,
  .inputEligibility.timestampedEventStream.reason,
  .observation.kind] | @tsv' \
  research/polychord/data/internal-suite/suite-v0.json
```

Only three of 17 frozen cases contain an eligible timestamped event stream:

1. Petrushka rehearsal 49 is a source-attested positive with complete replay
   history, but no replay frame contains a complete structural candidate. It is
   an automatic-positive coverage exclusion and an executable expected
   `no-structural-candidate` decision, not a false negative and not permission
   to verticalize the event-window union.
2. The Shrovetide second attack is a source-attested construction and product
   boundary. Its exact source-to-target transition receives positive oblique
   support from the frozen motion rule, while the target collection is exactly
   Gm7. It is the required source-backed warning that positive motion support
   cannot authorize a display by itself.
3. The layered `C|Gm` replay is a synthetic positive with separated held onset
   cohorts. It establishes cue and binding mechanics but cannot be the sole
   evidence for a musically useful licensing branch.

The remaining 14 cases have no frame-accurate event history. Their frozen
construction labels and static generator expectations remain valuable but cannot
be silently promoted to v2 temporal scores. The audit therefore favors a new
automatic suite that pins the whole frozen suite by digest and references its
case identifiers instead of copying and editing those records.

## Motion source lead

Robert Hutchinson's open _Music Theory for the 21st-Century Classroom_, section
32.4, identifies the final polychordal passage in Stravinsky's _Three Movements
from Petrouchka_ as chromatically ascending dominant seventh chords in the left
hand against a repeating G-F-C triad cycle in the right. The cited public-domain
1922 piano score was downloaded, hashed, rendered, and inspected at original
resolution:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/polychords-textbook.html \
  https://musictheory.pugetsound.edu/mt21c/polychords.html
curl -L --max-time 30 \
  -o tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  'https://petruccilibrary.us/autoindex/index.php?dir=imslp-us_files%2FStravinsky_Igor_1971%2F&file=Stravinsky_-_Petrushka_3mvts.pdf'
shasum -a 256 \
  tmp/pdfs/polychords-textbook.html \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf
pdfinfo tmp/pdfs/stravinsky-petrushka-3mvts.pdf
pdftoppm -f 37 -l 37 -png -r 600 -singlefile \
  tmp/pdfs/stravinsky-petrushka-3mvts.pdf \
  tmp/pdfs/stravinsky-page-37
```

The textbook snapshot has SHA-256
`7b59a70a0ea33bdc88242afbb459451e3b547593b471d837bcee7af7d2e00904`. The 37-page
score has SHA-256
`90d0b14d929697f33762eacb715c3331a6ebf0faf1e722e0f50598241ebf5664`.

The first two attacks after _p sub. e staccatissimo_ form this candidate
transition:

| Endpoint | Lower source unit    | Upper source unit | Sounding MIDI notes      |
| -------- | -------------------- | ----------------- | ------------------------ |
| Source   | F7: F2 A2 C3 Eb3     | G major: G4 B4 D5 | `41 45 48 51 / 67 71 74` |
| Target   | Gb7: Gb2 Bb2 Db3 Fb3 | F major: F4 A4 C5 | `42 46 49 52 / 65 69 72` |

The structural checks were:

```sh
python3 tool/polychord/register_candidates.py \
  41 45 48 51 67 71 74
python3 tool/polychord/register_candidates.py \
  42 46 49 52 65 69 72
python3 tool/polychord/register_candidates.py \
  44 48 51 54 67 71 74
bin/chord-name 42 46 49 52 65 69 72
```

The source produces exactly `G|F7`. The target produces `Fmaj7|F#` at the first
valid boundary and `F|F#7` at the source-hand boundary. The latter is the
source-spelling `F|Gb7`. Under a register-role-preserving correspondence, F7 to
Gb7 is an exact plus-one-semitone translation and G major to F major is an exact
minus-two-semitone translation. This is a threshold-free contrary-motion
hypothesis under the unchanged `rigid-layers-oblique-or-contrary/1` rule, and it
can bind support to the intended assignment even though the target contains a
competing structural identity.

The primary analyzer reports G-flat dominant seventh with sharp nine and sharp
eleven for the target. That is retained as a parallel integrated diagnostic, not
used as a truth label or selector input.

This passage was not admitted as an automatic positive. Its full event window,
source spelling, product expectation, competing alternatives, and continuous
200-millisecond display eligibility must be fixed in a later dated source
admission before any selector output is read. If the source cannot support the
display dwell without a favorable tempo choice, it remains a motion construct
check rather than an automatic display-positive case.

## Onset source audit

The official MTO article, examples PDF, Example 6 page, and audio for Moreira's
Herrmann analysis were acquired and pinned:

```sh
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-article.html \
  https://www.mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-examples.pdf \
  https://www.mtosmt.org/issues/mto.25.31.4/moreira_examples.pdf
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-example-6.html \
  'https://www.mtosmt.org/issues/mto.25.31.4/moreira_examples.php?id=5&nonav=true'
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-the-pass.mp3 \
  https://www.mtosmt.org/issues/mto.25.31.4/moreira_audio_ex05.mp3
shasum -a 256 \
  tmp/pdfs/moreira-article.html \
  tmp/pdfs/moreira-examples.pdf \
  tmp/pdfs/moreira-example-6.html \
  tmp/pdfs/moreira-the-pass.mp3
pdftoppm -f 5 -l 5 -png -r 600 -singlefile \
  tmp/pdfs/moreira-examples.pdf \
  tmp/pdfs/moreira-example-6
```

The final SHA-256 digests are:

- article HTML:
  `1e1525247749fbc5f4578b236658ee6111132665e91653f3440ef0feebb9e72f`;
- examples PDF:
  `09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`;
- Example 6 HTML:
  `08088d304a6d0d2f11cae19e1d80669c40249ffc5945074a437624a0954c3755`; and
- official audio:
  `84bb6602bc0f66b130b82304118ebeda45ed6e96a4c5f605de3e7d86c9f31e37`.

Moreira describes and notates a sustained G-minor triad against intermittent
A-flat-minor and F-sharp-minor attacks. The first A-flat-minor attack is the
already verified `56 59 63 / 67 70 74` structural positive. The source therefore
supports the onset-ordering premise.

It does not establish the 200-millisecond onset-separation threshold. The score
excerpt contains no local tempo, so assigning milliseconds from notation could
decide the ablation result by construction. The official audio is a stereo film
mix and does not provide authoritative per-note attacks for all six candidate
notes. An exploratory, unregistered spectral-flux probe was rejected before its
output was used because the mixed soundtrack produced many non-note-specific
transients. No onset measurement from that probe enters the plan or suite.

The onset branch therefore remains diagnostic unless a later source provides
defensible note-level timing and a matched onset-positive integrated guard. The
synthetic 400-millisecond replay remains a mechanics control, not source-valid
licensing evidence.

## Decision

Create `automatic-suite-v2-plan.md` as the preregistered construction plan for a
new `polychord-automatic-suite/1` artifact under
`data/automatic-suite/suite-v0.json`. Pin and reference all 17 frozen cases
without rewriting them. Score construction coverage, cue interpretation,
automatic decision, and display transitions separately.

A cue branch can license display only after it has one evidence-complete,
source-attested automatic positive that remains continuously authorized through
the 200-millisecond gate, a source-backed cue-positive guard, and the complete
synthetic contract matrix. A first selector may be motion-only. Onset remains
diagnostic until its source-timing gap is filled; the two branches do not
receive artificially symmetric status.

No version-2 suite, scorer, selector, or implementation exists yet. The held
POP909 reserve remains untouched.

The final document pins are:

- automatic-suite plan:
  `0900d74010f8eb33a99233aea49b49bd7a12aed8bdcb4c4a5967d716305542f4`;
- amended v2 selection plan:
  `d992c3b7e85c0d83b14ea18b4422d91d1c456cf988b07e7720c99d71ace1a8aa`; and
- amended protocol:
  `351d0e66c78d2059f8611a44fa17990f8bcea7e23d4e42aca8429b9591938e79`.

**Next.** Verify and encode the Stravinsky contrary-motion window, with a
source-supported display dwell, as the first prospective automatic source
positive. If that admission succeeds, build the separate automatic-suite schema
and non-scorable seed around the frozen coverage plan before specifying a
selector.

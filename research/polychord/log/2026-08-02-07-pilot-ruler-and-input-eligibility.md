# 2026-08-02: Pilot ruler and input eligibility

**Goal.** Define a small annotation-method pilot without selecting only the
canonical examples that the existing adjacent-register census can recover.

**Setup.** Repository commit `7858146d`. No corpus fixture or held-out split was
read. Public score scans were downloaded to `/tmp/polychord-pdfs` and were not
added to the repository. The exact acquisition and verification commands were:

```sh
curl -L --max-time 30 https://archive.org/download/ptrouchkascn00stra/ptrouchkascn00stra.pdf -o /tmp/polychord-pdfs/petrouchka.pdf
curl -L --max-time 30 https://archive.org/download/lesacreduprintem00stra_3/lesacreduprintem00stra_3.pdf -o /tmp/polychord-pdfs/rite.pdf
curl -L --max-time 30 https://archive.org/download/lesacreduprintem00stra_2/lesacreduprintem00stra_2.pdf -o /tmp/polychord-pdfs/rite-full-score.pdf
pdfinfo /tmp/polychord-pdfs/petrouchka.pdf
pdfinfo /tmp/polychord-pdfs/rite.pdf
pdfinfo /tmp/polychord-pdfs/rite-full-score.pdf
pdftoppm -png -r 600 -f 66 -l 66 -singlefile /tmp/polychord-pdfs/petrouchka.pdf /tmp/polychord-pdfs/petrouchka-page-066-hi
pdftoppm -png -r 400 -f 18 -l 18 -singlefile /tmp/polychord-pdfs/rite.pdf /tmp/polychord-pdfs/rite-page-018-hi
pdftoppm -png -r 350 -f 19 -l 19 -singlefile /tmp/polychord-pdfs/rite-full-score.pdf /tmp/polychord-pdfs/rite-full-page-019-hi
shasum -a 256 /tmp/polychord-pdfs/petrouchka.pdf /tmp/polychord-pdfs/rite-full-score.pdf /tmp/polychord-pdfs/rite.pdf
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
```

**What happened.** The score checks changed the task definition in a useful way:

- In the 1911 full score of _Petrouchka_ held by the UNC Music Library
  (`ptrouchkascn00stra`, SHA-256
  `8c753ed9ddc37e61d7fb1a261fd350cbe7b529d9bc957e9c2efcfab953532d64`), rehearsal
  49 is on printed page 64, PDF page 66. The two clarinets establish the
  familiar triads through concurrent arpeggiation. The passage does not justify
  inventing a single observed snapshot containing both complete triads.
- In Stravinsky's four-hand reduction of _Le sacre du printemps_
  (`lesacreduprintem00stra_3`, SHA-256
  `6871f14d62c39eeaa7a1482c644947870bbb30b297f0ed2b89321dad85f35495`), the first
  Augurs chord at rehearsal 13 is on printed page 16, PDF page 18. The
  transcribed layers are Fb2-Ab2-Cb3-Fb3 and Eb3-G3-Bb3-Db4. Eb3 from the Eb7
  layer lies below Fb3 from the Fb-major layer, so no adjacent-note split yields
  both complete chords. The 1921 orchestral score (`lesacreduprintem00stra_2`,
  SHA-256 `b54506e9a1d4ed2b7aeb3617ce0d1e39f0acf42d97edf48b1668cb1ba5430613`)
  confirms the passage at rehearsal 13, printed page 11, PDF page 19.
- The old census unit test called a widely separated synthetic transposition
  "Augurs." It measured the intended common-chord profile, but it was not the
  score voicing. It is now labeled as a synthetic analogue.

The draft pilot contains two score-checked constructional positives and four
synthetic controls. Two controls use the identical MIDI snapshot for a
shared-tone C-over-G-minor construction and an integrated C9, differing only in
onset cohorts. Every case records construction tag and input eligibility
separately. The pilot is explicitly non-scorable and all independent-review
fields remain pending.

**Plain-English reading.** A musical example can genuinely be made from two
chords even when WhatChord's current list of held notes cannot prove that. If
such an example were scored as an ordinary detector miss, the test would punish
the detector for information it never received. If it were omitted, the test
would be biased toward the detector. Separate construction and eligibility
labels avoid both errors.

**Decisions.** The ruler unit may be a snapshot or an event window. It must not
turn moving notes into a fictional simultaneous chord. Construction truth and
eligibility for adjacent-register snapshots, general pitch-and-register
snapshots, and timestamped event streams are separate annotations. The pilot
must pass independent review before its labels can inform a frozen ruler or any
accuracy number.

**Next.** Have a second annotator apply `pilot-annotation.md` to blinded cases,
record disagreements, and adjudicate the rubric. Then encode a frame-accurate
MIDI replay for the matched shared-tone controls and at least one moving
score-derived example. Product semantics can then be scoped either to the
recoverable subset or to a broader detector with explicitly measured temporal
evidence.

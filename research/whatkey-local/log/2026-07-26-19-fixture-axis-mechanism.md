# 2026-07-26: Why the Isophonics fixture axis was not exactly zero

**Goal.** Answer, with evidence, why cell C did not reproduce cell A exactly on
Isophonics (fourth-decimal drift) while When-in-Rome reproduced exactly; no new
holdout information is spent (the analysis reads existing artifacts, plus one
reproduction check of cell A's committed configuration).

**What happened.**

1. Reproduction check first: today's engine under the `whatKeyPaper2026` recipe
   on the paper fixtures reproduces the committed July 7 Isophonics test
   artifact byte for byte. There is no engine drift under the pinned recipe; the
   reproduction contract is airtight.
2. Field-level fixture diff (paper versus current-profile generation): notes,
   timing, durations, and basses are identical on every event of both corpora.
   Only `candidates` differ: 53 Isophonics events (45 dev, 8 test, across 13
   tracks) and 2 When-in-Rome events (both dev) carry a different top identity
   under the current analysis profile.
3. Every one of the 8 Isophonics test-track flips is the same reading: F major6
   to D minor7. That is lever 0 (the chord-context m7-versus-6 key-context
   policy) applied under the fixtures' pinned C major generation context; the
   paper-era profile predates it.
4. The path into key detection: emissions read pitch classes (identical), but
   the mode tilt reads the top identity. F major6 is a major-tonic quality
   rooted on F; D minor7 is a minor-tonic quality rooted on D. The flipped
   events tilt a different parallel pair, nudging the posterior enough to move a
   handful of margin-adjacent claims, which is the fourth-decimal drift in cell
   C. When-in-Rome's two flips sit in dev pieces, so its test cell reproduced
   exactly.

A correction for the record of the surrounding discussion: an initial
split-membership pass keyed fixtures by id instead of title and wrongly reported
all 53 flips as dev-side; the correct split is 45 dev, 8 test as above. Entry
-18's conclusions are unaffected (the fixture axis is negligible in magnitude
and the detector delta carries the result), but the mechanism is now attributed
precisely rather than rounded to zero.

**Plain-English reading.** The two fixture generations play identical notes; the
only difference is that today's engine sometimes names one voicing differently
(the famous F6-versus-Dm7 call, decided by the key-aware naming shipped in
chord-context). The key detector listens mostly to the notes, but its mode tilt
listens to the name, so eight renamed chords across the test tracks moved a few
borderline claims by a fraction of a tenth of a point.

**Decisions.** None; characterization only.

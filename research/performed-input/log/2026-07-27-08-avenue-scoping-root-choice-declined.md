# 2026-07-27: Avenue scoping: root-choice declined, ornament bucket reframed

**Goal.** Scope the two engine avenues from log -07 before proposing changes:
size the root-choice convention bucket precisely, and verify the mechanism
behind the ornament-absorption bucket.

**Setup.** A scratchpad probe over A0 development disagreement time (method
recorded here; same segment walk as the census) classified same-member-set
namings, seventh-only family misses, and third misses, with bass position for
the member-identical cases. Mechanism check: raw ASAP MIDI for the flagship
ornament sample (7-2 Largo opening) with press durations and pedal states.

**What happened.**

Root-choice bucket, measured:

- Member-identical namings (the m6/half-diminished and diminished-seventh
  rotation dualities) are 5.8% of disagreement time, 2.3% of displayed time.
- 98% of that time, the app's chosen root is the sounding bass. The top pairs
  are the app's bass-rooted diminished7 versus the analyst's inverted viio
  figures (42/43/65), then major6/minor6 versus ii65-family figures.
- Assessment: this is not an engine defect but a naming-culture difference the
  ruler makes visible. Analysis mode optimizes musician-expected naming of the
  observed voicing, and a player holding G-Bb-D-E with G in the bass expects
  Gm6, not Eo65 spelled from a root two-thirds up the stack. Flipping the
  convention would chase a 2.3-point ceiling on this ruler while regressing the
  naming philosophy (and the oracle-pool m6 conventions) the app is built on.
  Declined as engine work; the members tier already credits every one of these
  segments, which is the ruler saying the same thing.

Ornament-absorption bucket, mechanism check:

- The hypothesis from log -07 was pedal blur: short ornament presses sustained
  into the chord by the pedal. The flagship sample falsifies it: in 7-2's
  opening, the C# against D minor is a melody note physically held for 1.53
  seconds with the pedal up, over accompaniment notes held for 8 seconds. The
  app names Dm(maj7) because a genuine, seconds-long sonority contains exactly
  that chord.
- The real shape is melody-over-accompaniment: the engine has no concept of a
  melodic voice riding above a held harmony, so slow movements convert every
  non-chord melody dwell into an extended-chord rename. Transient filtering
  would not touch this case. Some of the bucket may still be pedal-blur;
  splitting it needs snapshots that carry per-note provenance (held versus
  pedal-sustained, press duration), which the current extraction discards when
  it merges the sounding set.

**Plain-English reading.** One of the two engine leads dissolved on contact:
where the app and the analyst pick different roots for the same stack of notes,
the app is siding with the player's bass and the jazz naming the product
promises, so we decline to chase the analyst there. The other lead got more
interesting: the app's strangest displays on slow movements come from melody
notes lingering over held chords, a structural blind spot, not a timing filter.
The next measurement has to see which notes were held by fingers versus the
pedal before any mechanism is worth proposing.

**Decisions.**

- Root-choice convention change: declined, with the numbers above as the record.
  The exact-tier residual it represents is reclassified as ruler culture, not
  engine error; engine-attention time shrinks to roughly 18% of disagreement
  (about 7% of displayed), concentrated in the melody-over-accompaniment shape.
- Ornament bucket renamed to melody-absorption pending the provenance split; no
  mechanism proposed until the split exists.

**Next.** Extend `sounding_snapshots` to carry per-note provenance (held versus
pedal-sustained, press duration) behind an option that leaves existing consumers
byte-identical, regenerate a provenance-labeled arm, and split the
melody-absorption bucket into held-melody versus pedal-blur versus true
transients. That census decides whether the mechanism conversation is about
voicing structure, pedal handling, or both.

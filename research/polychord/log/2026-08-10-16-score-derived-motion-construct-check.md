# 2026-08-10: Check rigid motion against a scholarly score example

**Goal.** Determine whether the frozen rigid-layer motion rule recognizes the
specific source-attested triadic-stream behavior that motivated it, without
reinterpreting the zero-positive POP909 exposure result or converting motion
support into a product label.

**Setup.** Work began from clean repository commit `f40b1912`. The selected
source was not an unseen or preregistered evaluation case. It was chosen after
the POP909 null result in log 2026-08-10-15 because Moreira's Example 17 is the
scholarly score example already cited in the frozen motion contract. The check
is therefore explicitly post hoc and construct-oriented.

The source is Daniel Moreira, “Weird, Menacing, and Colorful: Bernard Herrmann's
Harmonic Polytonality,” _Music Theory Online_ 31.4 (2025), DOI
`10.30535/mto.31.4.5`. Example 17 reproduces Igor Stravinsky's “The Shrovetide
Fair,” mm. 41–53 from _Petrouchka_. The article analyzes the passage as two
three-note textural streams, with parallel motion inside each stream and oblique
or contrary motion between them.

The official example image was retrieved and pinned with:

```sh
curl -L --max-time 30 \
  -o /tmp/moreira_ex17.png \
  https://www.mtosmt.org/issues/mto.25.31.4/moreira_ex17.png
shasum -a 256 /tmp/moreira_ex17.png
```

The 5000-by-893-pixel image had SHA-256
`9278955cb63cab32c2675aeee9e257cc4c1e0e4d34ca11229781ba7106d7565f`. The first
two depicted attacks were transcribed as:

| Endpoint | Lower source unit       | Upper source unit  | Sounding MIDI notes |
| -------- | ----------------------- | ------------------ | ------------------- |
| Source   | C4 E4 G4, C major       | Bb4 D5 G5, G minor | 60 64 67 70 74 79   |
| Target   | Bb3 D4 F4, B-flat major | Bb4 D5 G5, G minor | 58 62 65 70 74 79   |

The score shows new attacks rather than ties. The replay therefore releases and
reattacks all six notes at the boundary. One notated quarter-note interval is
normalized to 500 milliseconds, velocity is fixed at 96, and simultaneous
releases are serialized before attacks. Those are representational choices, not
claims about performed timing, MIDI delivery, or dynamics. Every same-timestamp
intermediate frame remains explicit and has zero dwell.

The exact validation and interpretation commands were:

```sh
python3 tool/polychord/frame_replay.py \
  research/polychord/data/frame-replay/stravinsky-shrovetide-oblique-motion.json
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/motion_support.py \
  --fixture \
  research/polychord/data/frame-replay/stravinsky-shrovetide-oblique-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 17
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/golden-candidates.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/motion-support-ablation.md \
  research/polychord/log/2026-08-10-16-score-derived-motion-construct-check.md
git diff --check
```

The final evidence pins are:

- fixture: `f0c5d955fa97409bea437d3bc729d5560a7d3f229f8a6c8262cc86103dce877b`;
- eight-fixture replay manifest:
  `022a3a578293a64400b76da5ba57e0ab28d6338eeab49e1b2b7a4c4a49684688`;
- unchanged motion implementation:
  `89cb372cb8f3055779624d4d4870c08381d5da65c24531fde5de1791152c61cf`;
- motion tests:
  `fc8112ac94d985679a7154d50273d2c23f6bedddd596bb606e2eeb73781aaf08`;
- internal-suite schema:
  `6f8f1c216575f97906ce6ecd22fedaacc1d5406708406f13df5f491fefcfa190`;
- internal-suite validator:
  `82d098942724f4a773bf7cdc7b707efba6e85370a8fe780872a739d8c4f54b80`; and
- nine-case internal suite:
  `94159e07ce7cbdaed1e3737d022705a5b7a2323344a1b741a462ee66a081a153`.

Final validation passed all 154 polychord Python tests, all eight replay
fixtures, all nine internal-suite cases, Python lint and formatting, Markdown
formatting, JSON parsing, and `git diff --check`.

## What happened

Both endpoints generated exactly one complete adjacent-register candidate. The
source decomposition was G minor over C major; the target was G minor over
B-flat major. The unspelled target generator currently serializes the lower root
as A-sharp (`Gm|A#`), while the source-preserving construction record uses
`Gm|Bb`. That is a presentation-spelling boundary, not a difference in the
detected pitch structure.

Under the register-role-preserving hypothesis:

- the lower layer was an exact MIDI-set translation of -2 semitones;
- the upper layer was an exact MIDI-set translation of 0 semitones;
- both chord identities followed their translations;
- no sounding note instance was retained because the score rearticulates both
  groups;
- the between-layer class was `oblique`; and
- motion support was `positive` with reason `rigid-layer-translations-oblique`.

The register-role-exchanging hypothesis had no exact layer translations and
remained neutral. The frozen implementation was not changed.

The target endpoint was added to the author-adjudicated internal suite as a
literature-attested **boundary**, not a positive product expectation. Its two
source-attested triads share B-flat and D through separate MIDI-note instances,
but their pitch-class union is exactly Gm7. The source endpoint similarly has a
compact C9 reading. Moreira also places both streams inside one G-Dorian space.

Adding this case exposed a validator contradiction: resolved construction
notation had been required to appear in `expectedPolychords` even though all
boundary and negative cases are required to keep that list empty. The validator
and schema were corrected so source-established layer order remains separate
from product authorization. A regression test now fixes that distinction.

**Plain-English reading.** The strict motion rule is not dead code. It
recognizes the kind of grouped chord motion described by the scholarly source
that motivated it. But this same passage shows why a motion cue cannot decide
the displayed name by itself: the moving groups are real in the score, while
each observed note collection also has a very ordinary single-chord name.

**Decisions.** Retain the frozen rigid-motion rule unchanged. Treat this as one
post-result construct check, not a prevalence, accuracy, independent-validation,
or product-safety result. Keep the source construction symbol `Gm|Bb`, the
generator's current unspelled `Gm|A#` output, and the product boundary as three
separate records. Do not promote positive motion support directly to a displayed
polychord.

**Next.** Score-verify and encode a literature-attested positive whose exact
voicing is eligible for the v0 adjacent-register generator. Ives's _Psalm 67_
opening is the highest-priority candidate because it exercises shared pitch
classes and the C9 pitch-set trap. If the score does not support the assumed
register split, record that result rather than manufacturing a positive. Do not
spend the held POP909 reserve or loosen the motion rule in the meantime.

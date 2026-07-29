# 2026-07-07: Progression detectors land a paired coverage win

**Goal.** Build the design plan's section 2e progression-pattern layer, the
mechanism that attacks modulation with evidence (cadences into the new key)
rather than forgetting speed, and the first with a plausible shot at blues.

**Setup.** New `ProgressionKeyDetector` in `lib/features/key/`: scores chord
_transitions_ per key rather than chord contents. Patterns: authentic cadence
(dominant-family on the fifth degree to a tonic-quality chord, with a
root-position bonus and a smaller score for a tritone-less V triad),
leading-tone resolution, ii-V motion with a ii-V-I completion bonus, deceptive
cadence, secondary-dominant resolutions onto diatonic degrees, bass falling a
fifth onto the tonic, and a plagal return (IV to I). The major-key tonic quality
set includes dominant7 so a blues I7 reads as home, not V-of-IV. Confidence is
the decayed, weighted _sum_ of pattern points, not points per event: patterns
are sparse, and a recent cadence must keep its vote rather than being diluted by
pattern-less transitions. Shared 24-key plumbing extracted to `KeySpace`
(canonical tonalities, scale masks), used by all detectors.

Integrated into the hybrid as a third, independently ablatable term:

```text
correlation
  + functionalBlend  * evidence points per weighted event
  + progressionBlend * decayed progression point sum
```

Harness: `--detector progression` (standalone, diagnostic) and
`--progression-blend X` on the hybrid.

```sh
for pb in 0.02 0.05 0.1; do
  dart run tool/whatkey/harness.dart \
    --fixtures build/whatkey-fixtures/when-in-rome-v1 \
    --split-file research/whatkey/data/splits/when-in-rome-v1.json \
    --detector hybrid --progression-blend "$pb" \
    --out "build/whatkey-harness/wir-dev-hybrid-p$pb"
done
python3 tool/whatkey/compare.py \
  build/whatkey-harness/wir-dev-hybrid-p0.02/report.json \
  build/whatkey-harness/wir-dev-hybrid-b0.1/report.json
python3 tool/whatkey/compare.py \
  build/whatkey-harness/wir-dev-hybrid-p0.02/report.json \
  build/whatkey-harness/wir-dev-hybrid-b0.1/report.json --metric coverage
dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/pop-jazz-v1 \
  --detector hybrid --progression-blend 0.02 \
  --out build/whatkey-harness/pop-jazz-v1-hybrid-p0.02
```

**Results, development split** (hybrid, blend on top of champion config):

| progression blend | coverage | exact | MIREX | modulations |
| ----------------- | -------- | ----- | ----- | ----------- |
| 0 (champion)      | 0.74     | 0.54  | 0.64  | 120/399     |
| 0.02              | 0.79     | 0.55  | 0.65  | 133/399     |
| 0.05              | 0.80     | 0.53  | 0.63  | 130/399     |
| 0.1               | 0.81     | 0.50  | 0.61  | 131/399     |

Paired at 0.02 vs champion: exact is a dead wash (+0.011, p = 0.97, 20/22/15);
**coverage is a decisive win** (+0.052 per piece, CI95 [+0.026, +0.081], p =
0.0008, 29/12/18), with 13 more modulations matched and spurious switches
unchanged (median 0, p90 2). Higher blends buy nothing further and start costing
accuracy.

**Results, behavioral suite** (blend 0.02): all steady-key probes stay exact
1.00 with zero spurious switches; ambiguous fixtures 8/8 and 7/7; the modulating
ii-V-I chain jumps to 0.43 exact with zero spurious (champion: 0.20; the
evidence model alone: 0.40, but with flapping). **Blues still fails (exact 0.00,
claims F)**, for a newly precise reason: the plagal-return pattern breaks the
I7/IV7 symmetry in principle, but our 12-bar fixture is a single chorus ending
on the V7 turnaround, so the C-confirming cadence at the loop seam never occurs.
A unit test with the seam (G7 to C7 across the loop boundary) claims C
correctly. A two-chorus blues fixture would test the realistic looping case, but
the behavioral suite is pinned by the protocol freeze, so that addition is
deferred to a pop-jazz-v2 fixture set with an amendment.

**Plain-English reading** (terms in [../../GLOSSARY.md](../../GLOSSARY.md)):

- The new layer listens for the grammar of harmony (this chord _resolving_ to
  that one) instead of just which notes are common. Grammar is rare but very
  informative, so its votes are kept at full strength until they age out, rather
  than being averaged away by ordinary chord changes.
- On the corpus it did not make the detector more right, but it made it **speak
  far more often while staying just as right**: where the histogram saw a
  near-tie and stayed quiet, a cadence now breaks the tie. Speaking 5% more
  often at unchanged accuracy is a statistically solid win (the p = 0.0008
  coverage result), and the kind that matters for the app, where silence is a
  blank indicator.
- Blues taught us something subtle: hearing C7 go to F7 genuinely sounds like an
  arrival in F; what tells your ear the song is in C is coming _back_. Our test
  chart plays the twelve bars exactly once and stops before coming back, so the
  detector never gets the punchline. The fix is a fairer test (two choruses),
  not a smarter trick.

**Decisions.**

- `progressionBlend = 0.02` is the new default (champion: hybrid, functional
  0.1, progression 0.02, 30 s half-life), adopted on a significant paired
  coverage win at unchanged accuracy with modulation improvement, per the
  protocol's coverage-and-accuracy-pair framing.
- Progression confidence is a decayed sum, not per-event normalized; recorded
  here because it deliberately differs from the evidence model's semantics.
- The plagal-return pattern was added mid-development after the blues analysis
  showed the I7/IV7 cadence symmetry; it is a legitimate classical tonic signal,
  not a blues special case.
- A two-chorus blues fixture goes to a future pop-jazz-v2 set via protocol
  amendment; the v1 single-chorus probe stays as-is, documenting the limitation.

**Next.** Candidates, by expected value: the pop-jazz-v2 amendment with the
two-chorus blues; the deferred default-profile revisit (Temperley pairs looked
stronger, needs the paired treatment); ASAP performed-input fixtures, where
confidence weighting gets its real test.

# 2026-08-10: Admit the doubled-accompaniment negative guard

**Goal.** Fill the preregistered ordinary-accompaniment cell with an exact
voicing that the register generator must propose as two complete triads while
the product policy must retain one conventional integrated chord.

**Setup.** Work began from clean repository commit `59ff4e18`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

## Case construction

The generated snapshot is a two-hand C-major-seventh accompaniment-form voicing:

| Register group | Spelled notes | MIDI notes | Local shape |
| -------------- | ------------- | ---------- | ----------- |
| lower hand     | C3 E3 G3      | 48 52 55   | C major     |
| upper hand     | E4 G4 B4      | 64 67 71   | E minor     |

Across the full observation, the pitch-class set is exactly C-E-G-B and the bass
is C. E and G are doubled as distinct notes across the two hands. The
author-adjudicated construction is therefore one Cmaj7 chord, not a claim that
the two hand shapes are independent harmonic layers. Its synthetic status also
makes no claim that this exact voicing is frequent in a measured population.

The adjacent G3-to-E4 boundary nevertheless satisfies the frozen register
candidate contract exactly:

- lower unit: C major, MIDI 48, 52, 55;
- upper unit: E minor, MIDI 64, 67, 71;
- gap: nine semitones;
- shared pitch classes: E and G, supplied by separate notes; and
- structural symbol: `Em|C`.

This is intentionally a stronger guard than an open chord that produces no
candidate. It requires a later selector to distinguish a familiar integrated
seventh chord from a mechanically valid decomposition. The expected product
class is `negative-guard`, the only accepted single-chord alternative is
`Cmaj7`, and the unranked register baseline must still contain `Em|C`.

## Executable scope claim

The new `doubled-integrated-accompaniment` scope feature is not a descriptive
tag. The suite validator requires every case carrying it to satisfy all of the
following:

1. the adjudicated construction is `integrated-chord`;
2. the product class is `negative-guard`;
3. at least two observed pitch classes occur in separate MIDI notes; and
4. at least one generated register candidate shares two or more of those doubled
   pitch classes across its proposed units.

The validator rejects the feature on a layered construction, on a boundary or
positive product case, or on doubled register groups that generate no
different-root shared-tone candidate. This keeps the coverage claim tied to the
actual failure mode.

The rule does not claim that every doubled chord is accompaniment, nor does it
introduce a generic rejection of every candidate whose union has a compact
single-chord name. It fixes one exact policy case before a selector is chosen.

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
  research/polychord/log/2026-08-10-24-doubled-accompaniment-guard.md \
  research/polychord/data/internal-suite/suite-v0.json
git diff --check
```

The final evidence pins are:

- adoption-suite plan:
  `807d6f59eb08ca8fe641bf2bb8de1e6cd19bd9e34e924ccdcadfd5672e8630ce`;
- internal-suite schema:
  `c8958380f887fc5e6e254f8a8f06292dd0667452c9b6d007f84baf84b3cde38a`;
- internal-suite validator:
  `84643bf0594df217f3f33e480401c2883678a60bb2c7ac35574dab1cc80a19e7`;
- internal-suite tests:
  `fe0389ae32f9b9556f9d5e3e024a801d9b8fd8a22d661914acc3a07141734619`; and
- fifteen-case internal suite:
  `fd2ff4afb9d8423baa3f4e3151ca6e40dc6526490f0c2090a49fe37aa5319b7f`.

Final validation passed all 182 polychord Python tests, all 15 internal-suite
cases, Python lint and formatting, Markdown and JSON formatting, and
`git diff --check`.

**Plain-English reading.** Two hands can each happen to form a familiar triad
while the musician is simply playing one seventh chord. This generated case
forces the future selector to recognize that distinction: the low notes spell C
major and the high notes spell E minor, but together they form Cmaj7.

**Decisions.** Admit the exact Cmaj7 snapshot as a synthetic regression guard,
require the mechanical `Em|C` proposal, and make the ordinary-accompaniment
coverage claim executable. Do not generalize this one case into a selector rule
before the adoption suite is frozen.

**Next.** Resolve the still-open exact-assignment ambiguity cell if the
contiguous-boundary model can produce it. If it cannot, record the exhaustive
demonstration required by the adoption plan. Keep the source-backed lone-bass or
bare-fifth boundary open in parallel rather than forcing an analytically
contested example into the suite.

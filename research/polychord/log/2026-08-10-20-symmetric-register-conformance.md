# 2026-08-10: Validate symmetric register conformance

**Goal.** Execute the structural matrix preregistered in
`adoption-suite-plan.md` before searching for additional source cases or
implementing a product selector. Verify that all five common chord qualities
work symmetrically in both layer roles without treating generated constructions
as product positives.

**Setup.** Work began from clean repository commit `92aa0b5a`. No selector
exists, no product-policy score was computed, no corpus was read, and the held
POP909 reserve remained untouched.

The new harness deterministically enumerates:

- five lower-layer qualities by five upper-layer qualities;
- all 11 nonzero upper-root intervals relative to the lower root; and
- all 12 chromatic transpositions.

This gives the preregistered 3,300 ordered identity combinations. Each case uses
root-position lower notes from the MIDI-36 octave and upper notes from the
MIDI-72 octave. The required result is narrow: the intended ordered identity and
exact lower/upper MIDI-note assignment must occur exactly once among the
generator's candidates. The case may contain other mechanically valid
candidates; the report retains every one.

Eleven focused controls separately cover inversions and octave doubling; zero,
one, and multiple shared pitch classes; one-semitone and wide register
boundaries; same-root, incomplete-shell, and one-note-overlapping-cover
exclusions; two identities in one observation; and two exact assignments for one
identity.

The harness embeds its command, working directory, base commit, dirty state,
Python version, generator schema, and generator and harness digests. The full
2.3 MB synthetic report is reproducible and contains all 984 ambiguous matrix
cases and all 1,140 additional candidates. It remains under ignored `build/`
rather than adding mechanically generated detail to the repository.

## Result

All 3,300 intended identities and exact assignments were present, with zero core
failures. All 11 focused controls passed.

The core matrix produced 4,440 candidates in total:

- 2,316 combinations produced exactly one candidate;
- 828 produced two candidates; and
- 156 produced three candidates.

Thus 984 of 3,300 combinations produced at least one additional identity, for
1,140 additional candidates. None of the canonical root-position matrix cases
produced a second assignment for its target identity. The separate focused case
proved that assignment ambiguity is nevertheless structurally possible:
`C3 E3 G3 G4 B4 D5 G5` produces `G|C` both before and after assigning G4 to the
lower group. The candidates have different exact note assignments and must not
be collapsed before selection.

Target layer pairs covered zero through three shared pitch classes:

- 1,032 combinations shared none;
- 1,584 shared one;
- 564 shared two; and
- 120 shared three.

The canonical matrix's target boundaries ranged from 14 through 40 semitones;
the focused controls separately passed a one-semitone boundary and a 23-semitone
boundary. These are conformance inputs, not a claim that such voicings are
equally common or equally likely to merit a user-facing label.

The ambiguity count is structural exposure, not a false-positive rate. It does
not identify which candidate a musician would prefer and cannot justify a
selector. It does demonstrate why generator success, identity deduplication, and
product selection must remain separate.

## Commands and pins

```sh
python3 tool/polychord/register_conformance.py \
  --out build/polychord/register-conformance-v1.json
python3 tool/polychord/register_conformance.py \
  --verify build/polychord/register-conformance-v1.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/log/2026-08-10-20-symmetric-register-conformance.md
git diff --check
```

The committed Python test discovery passed all 162 tests.

SHA-256 pins:

- generated conformance report:
  `00234efa005f25258b30e760ceb5f3d89ecc6e68badd470b968fa1ae02a31704`;
- unchanged register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- conformance harness:
  `a6e6240edd71f1c5a0d097fe1846932e389f0d221cd51a1c50a1d6ee9d13e627`; and
- conformance tests:
  `c4a114ef2fe2d282b0ff688d296d94023a645ba099d6ad3946d99d3c5be96331`.

**Decisions.** The symmetric common-chord generator scope is mechanically
implemented and guarded against an upper-triad-only regression. Keep every
additional identity and assignment visible to later selection and diagnostics.
Do not promote any generated matrix case to the product-policy positive set.

**Next.** Resume source work for the missing adoption cells: first a recoverable
source-attested disjoint positive, then a recoverable source-attested positive
with a complete seventh-chord layer. Record an honest negative search and narrow
the selectable scope rather than substituting an arbitrary synthetic positive if
either cell cannot be supported.

# 2026-08-10: Admit the exact-assignment ambiguity guard

**Goal.** Fill the preregistered same-identity exact-assignment cell with the
voicing already proven feasible by the frozen register-conformance work. Keep
identity ambiguity, assignment ambiguity, and product policy as separate
records.

**Setup.** Work began from clean repository commit `28cc76c5`. No selector was
implemented or read, no product-policy score was computed, no corpus was read,
and the held 808-song POP909 reserve remained untouched.

## Prior structural evidence

Log 2026-08-10-20 preregistered and ran the symmetric register-conformance
harness. Its focused `multiple-assignments` control established that
C3-E3-G3-G4-B4-D5-G5 produces the ordered identity `G|C` twice with different
exact note assignments. The relevant frozen evidence pins were:

- register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- conformance harness:
  `a6e6240edd71f1c5a0d097fe1846932e389f0d221cd51a1c50a1d6ee9d13e627`; and
- generated conformance report:
  `00234efa005f25258b30e760ceb5f3d89ecc6e68badd470b968fa1ae02a31704`.

The present admission does not rerun a search for a favorable case. It promotes
that previously disclosed focused control into the product-policy suite.

## Exact observation and assignments

The generated observation is MIDI 48, 52, 55, 67, 71, 74, and 79, spelled
C3-E3-G3-G4-B4-D5-G5. Its pitch-class set is C-D-E-G-B over bass C, exactly
Cmaj9, with G sounding in three octaves.

The register generator must retain both candidates:

| Split    | Lower assignment | Upper assignment | Gap          | Identity |
| -------- | ---------------- | ---------------- | ------------ | -------- |
| after G3 | C3 E3 G3         | G4 B4 D5 G5      | 12 semitones | G over C |
| after G4 | C3 E3 G3 G4      | B4 D5 G5         | 4 semitones  | G over C |

Both lower groups reduce to C major and both upper groups reduce to G major.
Both share pitch class G through separate sounded notes. They differ only in
whether G4 is assigned to the upper or lower group.

The construction record treats all seven notes as one integrated Cmaj9 chord.
The product class is `negative-guard`, with no expected polychord and `Cmaj9` as
the single-chord alternative. This generated policy case does not claim that a
`G|C` analysis is universally invalid; it requires abstention for this exact
observation and declared construction.

## Executable distinction

The new `multiple-exact-assignments` scope feature groups generated candidates
by ordered lower root and quality plus upper root and quality. It then requires
at least one group to contain two distinct pairs of lower and upper MIDI-note
assignments.

This is deliberately different from `multiple-structural-identities`:

- `G|C` and `F|D` would be two identities, regardless of their assignments;
- the two candidates here are one `G|C` identity with two assignments.

The validator rejects the feature on a one-candidate case and on the
source-backed `G|Ab7` case, whose two register candidates have different
identities rather than repeated assignments for one identity.

The suite validator also gains `major-ninth` as an integrated construction
quality so it can verify the Cmaj9 pitch set directly. The Framework-v0
polychord vocabulary remains unchanged because `major-ninth` is not added to the
candidate generator's five supported layer qualities.

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
  research/polychord/log/2026-08-10-25-exact-assignment-ambiguity.md \
  research/polychord/data/internal-suite/suite-v0.json
git diff --check
```

The final evidence pins are:

- adoption-suite plan:
  `6ba59d6b8516f405aa5ecde7ad5231aaf4feb8298fa54df50cb287dc7c9245c2`;
- internal-suite schema:
  `b3c66b9434de799bc9767a0b4774a6d20d28e35e25bcb2d42ad0b8e7b8cc0c98`;
- internal-suite validator:
  `fda41502b9dd7e68f3bb8aa9e2de7805f17ed9ae88f3b3167de4eab059f7a162`;
- internal-suite tests:
  `cc70b689234283cd966de8699733aafc173c8d339c0482383819bb74af1ea19a`; and
- sixteen-case internal suite:
  `35ea20e9af44a9847304b07d8a8eeb5155cbc282e90658800e078abb429378ab`.

Final validation passed all 185 polychord Python tests, all 16 internal-suite
cases, Python lint and formatting, Markdown and JSON formatting, and
`git diff --check`.

**Plain-English reading.** Moving one middle G across the proposed split does
not change either chord name: both partitions still say G major over C major.
The two candidates are therefore not duplicate data, because they make different
claims about which notes belong to which layer. The future selector must retain
that distinction internally even though this exact case should be shown simply
as Cmaj9.

**Decisions.** Admit the conformance-derived voicing as a synthetic integrated
Cmaj9 negative guard. Make same-identity assignment ambiguity executable and
keep major ninth outside the polychord layer vocabulary.

**Next.** The remaining product-policy guard is a genuinely source-backed
lone-bass or bare-fifth boundary. Verify a cleaner source than the analytically
contested Zarathustra ending before admitting it. After that, audit the
input-condition and scorer controls before freezing the suite.

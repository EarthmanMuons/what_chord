# Register-only polychord selector v1

Status: preregistered specification for `polychord-register-policy/1`. No
implementation result, internal-suite score, development-corpus result, or held
result had been read when this version was fixed. This is a conservative
product-policy hypothesis, not a universal definition of polychordality or a
perceptual model.

The decision and its provenance are recorded in log 2026-08-11-04.

## Purpose and scientific boundary

`polychord-register-candidates/1` deliberately enumerates every structurally
valid adjacent-register decomposition in the symmetric five-quality vocabulary.
This selector performs the separate task of choosing at most one exact
assignment for a secondary annotation or abstaining.

The author-adjudicated suite and its expected policies were available while this
rule was designed. The suite is therefore a product-conformance ruler, not an
unseen test set. Preregistration fixes the rule before its executable output is
read and, more importantly, before development-corpus fire dispositions can be
used to tune it. Passing the suite will mean exact agreement with the declared
policy cases, not independent accuracy.

## Frozen inputs

This specification depends on the following exact artifacts:

| Artifact                   | SHA-256                                                            |
| -------------------------- | ------------------------------------------------------------------ |
| Framework v0               | `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615` |
| Output/evaluation contract | `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44` |
| Register-candidate schema  | `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538` |
| Register generator         | `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250` |
| Frozen adoption suite      | `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403` |
| Exact scorer               | `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9` |

Changing any of the first four dependencies requires a new selector identifier.
Changing the frozen suite or scorer follows the suite-amendment rule instead of
silently redefining this selector's ruler.

## Admissible evidence

The selector consumes only:

- the sorted, distinct sounding MIDI notes for one frame; and
- the complete ordered candidates emitted for that frame by
  `polychord-register-candidates/1`, including each layer identity, exact note
  assignment, shared pitch classes, and adjacent register gap.

The surrounding decision path may suppress the result when the existing primary
analysis is not displayable, as already required by `polychord-output/1`. The
selector itself does not inspect the primary chord identity, alternative names,
candidate costs, key context, source labels, suite fields, or corpus
annotations. This keeps the secondary policy independent of changes in
single-chord ranking and avoids using one analyzer hypothesis as ground truth
for another.

Onset and motion support remain diagnostic, one-sided evidence. Release/pedal
evidence remains uninterpreted. None of them affects selection in version 1. The
same registered static voicing must therefore receive the same raw decision with
or without temporal history.

## Exact definitions

A layer's pitch-class set is the set of its assigned MIDI notes modulo 12. The
observed collection is the union of the two layer sets. Candidate identity is
the ordered tuple of upper root and quality followed by lower root and quality;
it does not include note assignment.

The selector recognizes the following pitch-class masks only for its
**integrated-tertian veto**. These masks do not enlarge the allowed polychord
layer vocabulary.

### Compact integrated collections

A collection is compact-integrated when, at some chromatic root, it exactly
matches one of:

| Name             | Root-relative pitch classes |
| ---------------- | --------------------------- |
| dominant seventh | 0, 4, 7, 10                 |
| major seventh    | 0, 4, 7, 11                 |
| minor seventh    | 0, 3, 7, 10                 |
| major sixth      | 0, 4, 7, 9                  |
| minor sixth      | 0, 3, 7, 9                  |

This test is transposition-invariant and does not require the matching root to
be a proposed layer root. It expresses the narrow policy that octave doubling or
hand separation does not turn one complete ordinary sixth or seventh chord into
a displayed polychord.

### Rooted ninth collections

A candidate is rooted-ninth-integrated when the full collection, relative to the
candidate's lower root, exactly matches the lower triad's ordinary ninth form:

| Lower quality | Integrated name | Exact collection |
| ------------- | --------------- | ---------------- |
| major         | dominant ninth  | 0, 2, 4, 7, 10   |
| major         | major ninth     | 0, 2, 4, 7, 11   |
| minor         | minor ninth     | 0, 2, 3, 7, 10   |

The major row represents dominant ninth and major ninth respectively. This rule
is orientation-sensitive: an alternative single-chord spelling rooted somewhere
other than the proposed lower unit does not satisfy it.

### Rooted seventh-extension collections

For a candidate with a complete seventh chord as its lower layer, remove the
lower layer's pitch classes from the full collection and express every remaining
pitch class relative to the lower root. The candidate is
rooted-seventh-extension-integrated when the remainder is nonempty and is a
subset of the corresponding palette:

| Lower quality    | Allowed added intervals |
| ---------------- | ----------------------- |
| dominant seventh | 1, 2, 3, 5, 6, 8, 9     |
| major seventh    | 2, 6, 9                 |
| minor seventh    | 2, 5, 9                 |

The dominant palette contains the conventional altered and natural tensions but
deliberately excludes a simultaneous major seventh above a complete dominant
seventh. The major- and minor-seventh palettes retain their conventional tertian
colors. The rule is based on pitch content and lower-layer function; it does not
consult the primary analyzer's preferred spelling.

A candidate receives the integrated-tertian veto when any of the three tests
above succeeds. This is a conservative v1 boundary between a useful
chord-over-chord annotation and an ordinary integrated or upper-structure
reading. It is not a claim that musicians never use polychord notation for the
same pitch collection.

## Deterministic selection algorithm

For one registered frame:

1. Generate the complete candidate list with `polychord-register-candidates/1`.
   If it is empty, abstain with `no-structural-candidate`.
2. Group candidates by ordered composite identity. Remove every identity having
   more than one exact upper/lower MIDI-note assignment. Version 1 has no
   evidence for choosing one such assignment merely because one boundary is
   wider.
3. Remove every remaining candidate that receives the integrated-tertian veto.
4. If no candidate remains, abstain with `not-selected-by-policy`.
5. Find the greatest `gapSemitones` among the remaining candidates. There is no
   minimum gap threshold.
6. If exactly one candidate has that greatest gap, select its exact identity and
   assignment. If two or more candidates tie at the greatest gap, abstain with
   `multiple-unresolved-identities`.

The order above is normative. Candidate serialization order, neutral research
spelling, root pitch height, and layer cardinality are never tie-breakers.
Selections carry no abstention reason. If the outer decision path has no
displayable primary result, it suppresses any raw selection with the already
frozen `primary-not-displayable` reason.

Research diagnostics must retain the complete original candidate list and, for
each candidate, its identity-group size, the result of each of the three
integrated-tertian tests, its register gap, whether it survived, and the final
frame decision. These fields explain a decision; they are not additional input
evidence or user-facing confidence.

The widest adjacent gap is a deterministic register-grouping hypothesis, not a
perceptual threshold. The selector abstains on an exact gap tie because the
available evidence does not distinguish the assignments. The later
200-millisecond stability gate remains unchanged and is not part of raw
selection.

## Preregistered ablations

The implementation must report the full selector and all three ablations below.
They are diagnostic comparisons fixed in advance, not candidates from which a
winner may be chosen after seeing results.

| Selector ID                                                   | Change from the full selector                                                   |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `polychord-register-policy/1`                                 | None                                                                            |
| `polychord-register-policy-without-integrated-tertian-veto/1` | Skip step 3                                                                     |
| `polychord-register-policy-without-assignment-veto/1`         | Keep all identities in step 2, then apply steps 3 through 6 to exact candidates |
| `polychord-register-policy-without-gap-resolution/1`          | After steps 1 through 4, select only when exactly one candidate remains         |

The no-assignment-veto ablation may select one exact assignment only when it is
the unique greatest-gap candidate; an exact gap tie still abstains. Every
ablation uses the same frozen generator and evidence restrictions. Only the full
selector is eligible to satisfy the v1 adoption path.

## Evaluation and change control

After this document is committed, implementation proceeds in this order:

1. implement a pure-Python reference selector and rule-level tests without
   changing the frozen generator or scorer;
2. implement the equivalent pure-Dart register-candidate path and selector while
   preserving all primary-analyzer outputs;
3. establish Python/Dart decision equivalence on the already-pinned 3,300-case
   structural conformance matrix and its focused controls before scoring;
4. produce complete, suite-pinned prediction artifacts for the full selector and
   every ablation, then score them once with the frozen exact scorer;
5. record every per-case result, not only the gate summary;
6. run implementation-shaped proposal and stable-display exposure on each
   declared development corpus and disposition every display fire; and
7. run the required single-chord regression, baseline, performance,
   accessibility, and note-storm checks before any adoption decision.

Rule tests must cover all 12 transpositions of every exact integrated mask, each
allowed and forbidden seventh-extension interval, orientation sensitivity,
multiple assignments for one identity, multiple identities with unique and tied
greatest gaps, and invariance to candidate input order. Generated controls do
not receive product labels and do not extend the frozen ruler.

The 808-song POP909 reserve remains untouched. Suite failure, an unsafe
development fire, or a newly discovered structural counterexample may motivate
`polychord-register-policy/2`, but version 1 is not edited to erase that result.
A semantic implementation defect may be corrected and rerun only with the
defect, affected artifact, and both implementation hashes recorded.

Prior-art systems are compared under separately pinned adapters. They do not
alter this selector and are not used as labels. Any later temporal cue that
changes a selection requires a new preregistered selector version or named
ablation under the output contract.

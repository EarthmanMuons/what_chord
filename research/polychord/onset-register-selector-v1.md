# Onset-licensed register selector

Status: preregistered product-policy specification for
`polychord-onset-register-policy/1`. No implementation, product-suite
prediction, prior-art comparison, new development output, or held output has
been read under this selector identity.

This selector is an author-adjudicated product hypothesis. It is deliberately
conservative and incomplete; it is not a perceptual model or a claim that all
polychords have separated attacks.

## Frozen dependencies

| Artifact                            | SHA-256                                                            |
| ----------------------------------- | ------------------------------------------------------------------ |
| Product-completion plan             | `d8c8de418fc5fda1cfd2ad5648632057a84be9c806431f1e4141a767fba16eb3` |
| Framework v0                        | `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615` |
| Output/evaluation contract v1       | `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44` |
| Register-candidate schema           | `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538` |
| Register-selector v1 specification  | `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff` |
| Preserved automatic-output contract | `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee` |
| Onset-evidence schema               | `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1` |
| Timing sensitivity preregistration  | `957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522` |
| Timing sensitivity result           | `18a723cd2f47853dbe688ba38eb1cb1e2266bcf2ee0508e7767867dfeebef6fe` |
| Corrected timing-guard decision     | `2d3a5c430fe4497261076c903b99aa85a0c42eeb418f140893dcf3c724ae9931` |
| Dart register generator             | `8554bb1eb18baa63c8707085039cd8f5480e1d5556c9998b0d93f0c37e4741db` |
| Dart register selector              | `b362196dfe29ee95e19f7fe5888d94459662436dd5573ec94319da59d7c0a0ca` |

`product-output-contract-v3.md` is the paired output contract created in the
same prospective decision. Its final digest is recorded in log 2026-08-13-09.
The tables and ordering below are normative rather than an implicit call to the
older selector.

## Admissible input

For one normalized timestamped-MIDI frame, the selector consumes only:

- the sorted, distinct sounding MIDI notes and their reset-scoped note-on
  identities;
- every candidate from `polychord-register-candidates/1`; and
- one exact candidate-bound onset record from
  `coherent-separated-onsets-50-80ms/product-1` for every candidate.

It does not consume the primary chord or alternatives, note spelling, key,
source identity, suite labels, corpus annotations, sustain as a categorical
signal, motion, a prior selector result, or display state.

## Product onset cue

`coherent-separated-onsets-50-80ms/product-1` is orientation-neutral and uses
these inclusive parameters:

```text
withinLayerCohortSpanMaximumMs = 50
betweenLayerSeparationMinimumMs = 80
```

For each layer, form the closed interval from the earliest through latest known
onset of its assigned currently sounding notes. History is `incomplete` and
support is `null` when any assigned note lacks a current reset-scoped note-on
identity.

With complete history:

1. `lowerWithinCohortSpanMaximum` is true when the lower interval spans at most
   50 milliseconds.
2. `upperWithinCohortSpanMaximum` is true under the same inclusive rule.
3. If the lower interval ends strictly before the upper begins, the order is
   `lower-then-upper` and the gap is upper earliest minus lower latest.
4. If the upper interval ends strictly before the lower begins, the order is
   `upper-then-lower` and the gap is lower earliest minus upper latest.
5. Otherwise the order is `overlapping` and the gap is zero.
6. Support is positive only when both span booleans are true and the gap is at
   least 80 milliseconds. Layer order does not affect support.

Positive records contain only `separate-coherent-onset-cohorts`. Neutral reason
codes occur in this exact order when applicable:

1. `lower-span-exceeds-maximum`;
2. `upper-span-exceeds-maximum`; and
3. `between-layer-separation-below-minimum`.

Incomplete records contain only `onset-history-incomplete`.

These values name a product rule, not a listener threshold. The 80-millisecond
minimum is the stricter of the two lower onset profiles already exposed and
boundary-guarded in the development record. The 50-millisecond within-layer
maximum remains an unvalidated but fixed product parameter. Changing either
value creates a new cue and selector identity.

## Integrated-tertian predicates

The predicates are copied into this selector so its behavior stands alone. They
classify candidates only for a conservative product veto and do not expand the
layer vocabulary.

A collection is compact-integrated when its unique pitch-class set, relative to
any chromatic root, exactly equals one of:

| Name             | Root-relative pitch classes |
| ---------------- | --------------------------- |
| dominant seventh | 0, 4, 7, 10                 |
| major seventh    | 0, 4, 7, 11                 |
| minor seventh    | 0, 3, 7, 10                 |
| major sixth      | 0, 4, 7, 9                  |
| minor sixth      | 0, 3, 7, 9                  |

A candidate is rooted-ninth-integrated when the complete collection relative to
the candidate's lower root exactly equals one of:

| Lower quality | Integrated name | Root-relative pitch classes |
| ------------- | --------------- | --------------------------- |
| major         | dominant ninth  | 0, 2, 4, 7, 10              |
| major         | major ninth     | 0, 2, 4, 7, 11              |
| minor         | minor ninth     | 0, 2, 3, 7, 10              |

For a complete seventh-chord lower layer, remove its pitch classes from the full
collection and express every remaining pitch class relative to the lower root.
The candidate is rooted-seventh-extension-integrated when that remainder is
nonempty and is a subset of:

| Lower quality    | Allowed added intervals |
| ---------------- | ----------------------- |
| dominant seventh | 1, 2, 3, 5, 6, 8, 9     |
| major seventh    | 2, 6, 9                 |
| minor seventh    | 2, 5, 9                 |

`integratedTertian` is true when any of the compact, rooted-ninth, or
rooted-seventh-extension predicates is true.

## Exact selection algorithm

Candidate identity is the ordered upper and lower root pitch class and quality.
Exact candidate equality additionally includes both complete MIDI-note
assignments.

For every frame:

1. Generate the complete canonical candidate list. If it is empty, abstain with
   `no-structural-candidate`.
2. Count exact assignments for every ordered identity across the unfiltered
   list. Remove every candidate whose identity has more than one assignment. If
   no candidate remains, abstain with `ambiguous-exact-assignment`.
3. Evaluate all three integrated-tertian predicates for every original
   candidate. Remove every remaining candidate for which any predicate is true.
   If no candidate remains, abstain with `integrated-tertian-reading`.
4. Retain only remaining candidates whose exact onset record is complete and
   positive. If none remains and at least one candidate entering this step has
   complete neutral support, abstain with `layer-separation-not-supported`.
   Otherwise abstain with `missing-layer-separation-history`.
5. Select the sole positive survivor with its exact identity, assignment, and
   sounding-instance binding. The invariant below proves that a valid input
   cannot contain more than one positive survivor.

Every comparison is inclusive where stated. Candidate enumeration order,
identity spelling, root height, layer cardinality, onset order, velocity,
primary ranking, and prior display state are never tie-breakers.

This selector intentionally keeps the v1 exact-assignment veto even when onset
records differ between assignments. That sacrifices possible coverage rather
than allowing a temporal rule to resolve a structural ambiguity in the first
product version.

### Positive-survivor uniqueness

For two different adjacent-register split points, take any note in the nonempty
register interval between them. At the earlier split that note is in the upper
layer while every note below the earlier split is in the lower layer. Positive
support therefore requires their onset intervals to be separated by at least 80
milliseconds. At the later split those same notes are together in the lower
layer, whose complete onset interval must span at most 50 milliseconds. Both
conditions cannot hold because 80 is greater than 50.

The five-quality exact vocabulary also yields at most one identity for either
side of a fixed split. Therefore at most one exact structural candidate can have
positive onset support in a valid frame. Assignment and integrated-tertian
removal cannot increase that count. This makes register-gap ranking unnecessary
and prevents a structural heuristic from overriding candidate-bound temporal
evidence. The implementation must assert this invariant, and any violation is an
implementation or contract defect rather than a musical abstention result.

## Diagnostics and reason precedence

Each original candidate retains:

- identity assignment count;
- compact, rooted-ninth, and rooted-seventh-extension results;
- its complete onset cue record and aggregate support;
- removal by assignment, integrated-tertian, or support stage;
- final selection status.

The frame retains the candidate list after each numbered stage. The single
abstention reason is the first stage that empties or fails to uniquely resolve
that list. This defines the exact precedence:

```text
no-structural-candidate
ambiguous-exact-assignment
integrated-tertian-reading
layer-separation-not-supported
missing-layer-separation-history
```

At the support stage, neutral precedes missing history when both occur because a
complete application of the cue is stronger diagnostic information than an
incomplete one. Per-candidate traces retain both conditions.

A selection has no reason code. Primary-display suppression occurs only in the
outer authorization reducer and never rewrites this raw decision.

## Change control and evaluation

The implementation must provide independent Python and pure-Dart paths and
establish exact equivalence before the product suite or new corpus output is
read. Tests must cover all 12 transpositions of the integrated masks, both onset
orders, exact and just-outside 50/80-millisecond boundaries, incomplete history,
same-identity assignment ambiguity, positive-survivor uniqueness across the
complete structural matrix, shared-tone and disjoint candidates, and
candidate-order invariance.

The product suite, scorer, baseline adapters, development exposure, app
integration, and held run remain separate prospective steps. A failure may
motivate `polychord-onset-register-policy/2`; this specification is not edited
to erase its result.

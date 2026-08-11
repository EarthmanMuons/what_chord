# 2026-08-11: Preregister the register-only selector

**Goal.** Fix one deterministic product selector and its diagnostic ablations
after the author-adjudicated adoption suite was frozen, but before implementing
or reading any selector output.

**Setup.** Work began from clean repository commit `c2168a3e`. The frozen suite
had SHA-256 `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`.
No selector implementation, prediction artifact, score, development-corpus
display result, or held POP909 item was available or read.

The design did inspect the already-frozen framework, product expectations,
candidate baselines, primary-single-chord alternatives, and guard rationales.
That is disclosed rather than presented as blind model development: this suite
is an author-adjudicated product-conformance ruler whose policy cases informed
the selector hypothesis. Preregistration prevents later executable outcomes or
corpus dispositions from silently tuning version 1; it does not turn the suite
into independent ground truth.

## Decision

Adopt `register-selector-v1.md` as the exact specification for
`polychord-register-policy/1`. The selector uses only the observed registered
notes and the complete `polychord-register-candidates/1` output. It does not use
the primary chord identity, alternative ranking, costs, key, temporal support,
source metadata, or case labels.

Version 1 has three explicit policy components:

1. identities with more than one exact note assignment remain unresolved and are
   removed;
2. a theory-derived integrated-tertian veto removes ordinary compact sixth and
   seventh collections, lower-rooted ninth collections, and conventional
   additions to a complete lower seventh chord; and
3. the unique widest adjacent register gap resolves remaining multiple
   candidates, with no minimum gap and abstention on a tie.

This separates the relevant musical claims. Repeated pitch classes are not
categorically rejected: the compact test asks whether the combined pitch-class
set is exactly one declared ordinary sixth or seventh chord. The integrated test
is rooted and content-based, so the existence of any single-chord alternative
somewhere in the analyzer does not automatically veto a candidate. Assignment
ambiguity is kept distinct from identity ambiguity, and generator iteration
order is never a selector.

The preregistered comparison includes three leave-one-component-out ablations:
without the integrated-tertian veto, without the assignment veto, and without
widest-gap resolution. They must all be reported, but only the full selector is
eligible for the v1 adoption path. This is a fixed ablation, not permission to
choose whichever variant looks best after scoring.

The selector-specific candidate dispositions remain diagnostic details. Frozen
prediction artifacts continue to use the existing output-contract reasons:
`no-structural-candidate`, `not-selected-by-policy`,
`multiple-unresolved-identities`, and, when imposed by the outer decision path,
`primary-not-displayable`. The frozen scorer and reason-code contract therefore
do not change.

## Interpretation

The rule operationalizes a conservative register-licensed annotation. It does
not claim that the integrated masks are universal notation laws, that the widest
gap proves perceptual separation, or that temporal neutrality is evidence
against a polychord. The full selector is deterministic and transposition
invariant, contains no fitted numeric threshold or weighted confidence, and can
be implemented independently in Python and pure Dart.

The primary analyzer remains untouched. Temporal onset and motion results stay
one-sided diagnostics under v1, while release/pedal evidence remains raw. Any
cue that later changes a selection requires a new preregistered selector version
or named ablation.

## Verification and pins

The decision-only change was checked with:

```sh
npx prettier --write --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/register-selector-v1.md \
  research/polychord/log/2026-08-11-04-register-selector-preregistration.md
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/register-selector-v1.md \
  research/polychord/log/2026-08-11-04-register-selector-preregistration.md
git diff --check
```

Final SHA-256 pins:

- selector specification:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`;
- protocol: `0a1dea2eec754bd1c9f5b62615430ecc73625d7b1221970dde006d83da6bcdb3`;
- unchanged frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- unchanged framework:
  `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615`;
- unchanged output/evaluation contract:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`;
- unchanged register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`; and
- unchanged exact scorer:
  `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9`.

**Plain-English reading.** The mechanical split finder can offer several ways to
divide the notes, including familiar one-chord voicings. The first selector will
stay silent when the note assignment is genuinely unresolved or the notes fit
one narrowly declared ordinary chord pattern. Otherwise it chooses the one
candidate separated by the largest register gap. We have fixed that policy and
its comparisons before letting executable results influence it.

**Next.** Commit this preregistration as its own scientific boundary. Then
implement the reference and pure-Dart selectors without scoring or measuring
until their rule-level equivalence is established.

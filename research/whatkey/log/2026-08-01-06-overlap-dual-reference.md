# 2026-08-01: Compare two references on the same performances

**Goal.** Run predeclared analysis R3: hold the 36 performed inputs, paper and
reflex claim streams, common-claim event mask, and label cardinality fixed while
comparing analyst-declared key contexts with notated key-signature collections.

**Setup.** The scorer is clean commit
`adb862aed112ba767b9ba33658e67cdce6abb827`. It verified the corrected overlap
fixtures, both frozen claim files, and ASAP annotations against the hashes in
log entry 2026-08-01-01. The command was:

```sh
python3 tool/whatkey/revision_reanalysis.py dual-reference \
  --fixtures build/whatkey-fixtures/asap-wir-nc-v2 \
  --asap-annotations build/whatkey-corpora/asap-dataset/asap_annotations.json \
  --claims paper=build/whatkey-harness/asap-wir-v2pw-paper/claims.json \
  --claims reflex=build/whatkey-harness/asap-wir-v2pw-reflex/claims.json \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/overlap-dual-reference.json
```

The output records a clean repository and has local SHA-256
`f744221dac03df846f30391d32493f2f93bd933424acb77d2dae95dde73902d8`. Both
reference labels and every detector claim were mapped to 12 diatonic-collection
classes: major maps to its tonic pitch class and minor to its relative-major
tonic. This deliberately discards major/minor identity so the analyst and
key-signature views have the same ontology.

**What happened.** All 36 pieces and 10,395 events have both references. The two
references agree on 0.6465 of events in the per-piece macro and 0.6434 when
events are pooled. The common-claim mask contains 8,160 events: 0.7699 per piece
and 0.7850 pooled. These counts and each package's coverage exactly match R2's
unfiltered view. An independent event-by-event audit reproduced all 10,395
signature classes through the existing `asap_extract.labels_at` function, so
R3's timestamp lookup is identical to the project's original ASAP labeling path.

On the same common-claim events:

| Reference                        | Paper exact | Reflex exact | Paper-reflex difference, exploratory CI95 |
| -------------------------------- | ----------: | -----------: | ----------------------------------------: |
| Analyst-declared key context     |      0.5809 |       0.6614 |                -0.0806 [-0.1373, -0.0256] |
| Notated key-signature collection |      0.6262 |       0.5466 |                +0.0796 [+0.0289, +0.1276] |

The piece-level interaction,

`(paper - reflex under key signature) - (paper - reflex under analyst key)`,

is `+0.1602`, with exploratory bootstrap CI95 `[+0.1184, +0.2046]`. It is
positive on 31 pieces, negative on 2, and zero on 3. In secondary own-claim
views, paper has 0.8954 coverage and scores 0.5637/0.6191 under
analyst/signature references; reflex has 0.8456 coverage and scores
0.6563/0.5334. The ranking reversal is therefore not created by restricting to
the claim intersection.

These 12-class analyst accuracies are higher than R2's 24-key exact values
because a relative major/minor claim now shares the reference collection. They
must not be substituted into a 24-key accuracy table without naming the changed
ontology.

**Plain-English reading.** Neither detector output changed. The only scoring
change was which documented notion of key served as the answer: the analyst's
current key context or the collection implied by the score's key signature.
Reflex fits the analyst reference better; paper fits the key-signature reference
better. Because the references themselves disagree on more than a third of
events, an accuracy number without its reference definition hides a major part
of the task.

**Decisions.** Treat R3 as direct evidence that reference provenance and
semantics are part of the evaluation task and can reverse a detector-package
ranking on fixed inputs and outputs. This is stronger construct-validity
evidence than the paper's cross-corpus juxtaposition. Do not describe it as
proof that annotation timescale alone caused the reversal: the references also
differ in analytical purpose and evidential source. Do not call the key
signature an oracle or argue that either reference is the uniquely correct
answer. Both are valid for different questions, exactly as the editors noted.
Limit generalization to these Beethoven performances and these two package
configurations. Report the 12-class mapping, reference agreement, common-claim
coverage, and exploratory status wherever the interaction is used.

**Next.** Commit the R3 record, then run R4's eight development-only cells. R4
will separate memory and functional evidence inside each evaluation regime; it
cannot by itself separate repertoire from reference practice across corpora.

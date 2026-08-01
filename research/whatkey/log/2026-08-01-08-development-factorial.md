# 2026-08-01: Separate memory and functional evidence on development data

**Goal.** Run predeclared analysis R4: cross 1/30-second evidence memory with
functional blend 0/0.1 on the frozen When in Rome and Isophonics development
splits while holding every other historical paper setting fixed.

**Setup.** The eight detector cells were generated on clean commit
`d3ee062f45496df9be3ad74d5d686e87a71058a6` using the commands in log entry
2026-08-01-01. The provenance correction in entry -07 was then committed as
`1334f101d91c0894216ae230471925dd170ec3f0`. No detector cell was rerun after
that correction. The clean scorer command was:

```sh
python3 tool/whatkey/revision_reanalysis.py factorial \
  --when-in-rome-fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --isophonics-fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --run-root build/whatkey-revision \
  --bootstrap-seed 20260801 --bootstrap-resamples 20000 \
  --out build/whatkey-revision/development-factorial.json
```

The output records a clean repository and has local SHA-256
`1f7cedfe8d599f552cfbae7a51d6081f54214fffc2eac0400ed7fa919a28e916`. The scorer
verified the frozen fixture manifests and splits, all eight claim/report pairs,
the development split designation, claim alignment, and every pinned detector
setting. No held-out detector run or held-out scoring was performed.

**Cohorts.** When in Rome contributes 59 pieces and 3,694 exact-scorable events.
Three or four pieces are absent from particular accuracy contrasts because at
least one compared cell has no claims, leaving 55 or 56 paired pieces. Coverage
uses all 59. Isophonics contributes 183 development tracks, of which 180 have
24-key reference events; all 180 enter every exact and coverage contrast, over
15,234 scorable events. The three modal tracks remain in the archived harness
behavior summaries but not in 24-key correctness.

The descriptive cell means are:

| Corpus       | Memory | Functional | Macro exact on claims | Macro coverage |
| ------------ | -----: | ---------: | --------------------: | -------------: |
| When in Rome |    1 s |        0.0 |                0.5457 |         0.6803 |
| When in Rome |    1 s |        0.1 |                0.6005 |         0.7641 |
| When in Rome |   30 s |        0.0 |                0.4338 |         0.7836 |
| When in Rome |   30 s |        0.1 |                0.5136 |         0.8239 |
| Isophonics   |    1 s |        0.0 |                0.7356 |         0.7910 |
| Isophonics   |    1 s |        0.1 |                0.6289 |         0.8148 |
| Isophonics   |   30 s |        0.0 |                0.7753 |         0.9212 |
| Isophonics   |   30 s |        0.1 |                0.7132 |         0.9259 |

The predeclared paired exact effects, with direction named in each row, are:

| Corpus       | Contrast                               | Mean effect | Exploratory CI95   |   n |
| ------------ | -------------------------------------- | ----------: | ------------------ | --: |
| When in Rome | 30 s minus 1 s, functional 0           |     -0.1038 | [-0.1695, -0.0416] |  56 |
| When in Rome | 30 s minus 1 s, functional 0.1         |     -0.0885 | [-0.1588, -0.0208] |  55 |
| When in Rome | functional 0.1 minus 0, memory 1 s     |     +0.0629 | [+0.0259, +0.1006] |  56 |
| When in Rome | functional 0.1 minus 0, memory 30 s    |     +0.0813 | [+0.0400, +0.1278] |  55 |
| When in Rome | functional effect at 30 s minus at 1 s |     +0.0172 | [-0.0298, +0.0682] |  55 |
| Isophonics   | 30 s minus 1 s, functional 0           |     +0.0397 | [-0.0001, +0.0786] | 180 |
| Isophonics   | 30 s minus 1 s, functional 0.1         |     +0.0843 | [+0.0408, +0.1289] | 180 |
| Isophonics   | functional 0.1 minus 0, memory 1 s     |     -0.1066 | [-0.1437, -0.0704] | 180 |
| Isophonics   | functional 0.1 minus 0, memory 30 s    |     -0.0621 | [-0.0985, -0.0283] | 180 |
| Isophonics   | functional effect at 30 s minus at 1 s |     +0.0445 | [+0.0091, +0.0807] | 180 |

Coverage moves with the settings and must accompany accuracy. Thirty-second
memory raises coverage on both corpora: by +0.1033/+0.0598 on When in Rome and
+0.1302/+0.1111 on Isophonics at functional 0/0.1, with all four intervals
excluding zero. Functional evidence raises When in Rome coverage by +0.0838 at 1
s and +0.0403 at 30 s, although the latter interval grazes zero. On Isophonics
it raises coverage by +0.0238 at 1 s but is effectively neutral at 30 s
(+0.0046, interval spanning zero). Thus the opposite exact effects are not
opposite abstention directions: functional evidence increases or preserves
coverage in both regimes while helping exact accuracy in one and hurting it in
the other.

Secondary diagnostics have the expected responsiveness tradeoff. Moving from 1
to 30 s reduces median switches from 5 to 1 on When in Rome and from 5/6 to 0 on
Isophonics, but matches fewer annotated changes. At 1 s, functional evidence
raises When in Rome modulation matches from 184 to 212; at 30 s the counts are
120 and 119. These diagnostics are descriptive and do not replace the paired
primary outcomes.

**Plain-English reading.** The paper and reflex packages had bundled two knobs:
how long evidence persists and whether chord function contributes to the
emission. R4 separates them. Against When in Rome analyst contexts, short memory
wins whether function is absent or present, and function helps whether memory is
short or long. Against Isophonics tonality regions, the numerical memory
ordering goes the other way at both functional levels, while function hurts at
both memory levels. The Isophonics pure-emission memory interval just touches
zero, and only Isophonics shows a clear memory-by-function interaction: the
functional penalty is smaller at 30 s.

**Decisions.** Treat R4 as post-hoc/explanatory evidence that both memory and
the functional ingredient have evaluation-regime-dependent value; the package
crossover is not merely an artifact of bundling those settings. Replace the
manuscript's asymmetric full-stack Isophonics ablation claim with these
functional-only contrasts if the ingredient result remains in the revision. Do
not claim that annotation timescale causes either reversal: the cross-regime
comparison still changes repertoire, observations, reference provenance,
semantics, and annotation practice, and R4 does not provide a formal
corpus-by-setting interaction. Do not tune from these cells, adopt a new
configuration, or present the bootstrap intervals as confirmatory. Report
coverage beside claimed-event accuracy.

**Next.** Commit this result record, update the revision claim architecture,
then continue the pre-edit queue with the offline-comparison audit.

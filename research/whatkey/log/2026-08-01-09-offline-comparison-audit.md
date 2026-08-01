# 2026-08-01: Offline comparison and held-out inference audit

**Goal.** Audit the submitted paper's comparison with music21 whole-piece
analyzers: reproduce every number, verify the paired-test implementation at the
small held-out sample sizes, identify which inputs, outputs, references, event
masks, and metrics are shared, and determine what comparison language the
evidence supports.

**Setup.** This is a read-only audit of immutable, one-shot held-out artifacts,
not a new detector run or a replacement statistical analysis. The repository was
at `98ef27e66f7354d81112a14dee964635d04f0358`. The archived reports are under
`research/whatkey/results/test-split-2026-07-07/`; their detector metadata pins
music21 10.1.0 and the paper-era WhatKey configurations. The relevant SHA-256
values are:

| Artifact                                      | SHA-256                                                            |
| --------------------------------------------- | ------------------------------------------------------------------ |
| `tool/whatkey/compare.py`                     | `c106e029fa301ea989b8462b5e6a070a41889df47a8b231ea7499fc0ee889b49` |
| Isophonics paper report                       | `090d4122f0c75d5fd075730808ad2f0a33d833d0056155921f3b83e260bbb173` |
| Isophonics reflex report                      | `f6536b987c8de891960a19a71e091a345474725afe5f068e3c7fb39f151239fd` |
| When in Rome paper report                     | `44be63956f0d9aa32579b5d74f12db14daa99ff615dd44f263e79c2da3d6e712` |
| When in Rome reflex report                    | `6f8869a7fdff74835ad28ba3dd01e984ac07d01ce823c9507356e62e289f4877` |
| Isophonics Temperley-Kostka-Payne report      | `f62ec789acc661907669da65da274f0e0f5a628edf663df8625f0f4cc661dab4` |
| Isophonics Krumhansl-Schmuckler report        | `906befd0799bfb3cb029f7b8639cd5994dda7c3b332e23ac122b6cce51c44b6c` |
| Isophonics Aarden-Essen report                | `1976623236968ae1b553b751f9d1808deaa12047413d8be2374036774543fda0` |
| Krumhansl-Schmuckler common-event-mask report | `6e5387efd80660ee4201ee32872e9b8af8cbb30e09c652aee47c2760aa571993` |

The submitted comparisons reproduce with:

```sh
for baseline in temperleykostkapayne krumhanslschmuckler aardenessen; do
  python3 tool/whatkey/compare.py \
    research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/report.json \
    "research/whatkey/results/test-split-2026-07-07/test-iso-m21-$baseline/report.json"
done

python3 tool/whatkey/compare.py \
  research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/report.json \
  research/whatkey/results/test-split-2026-07-07/test-iso-m21-ks-matched/report.json

jq -r '.perPiece[] | select(.annotatedChanges > 0) |
  [.title, .events, .annotatedChanges] | @tsv' \
  research/whatkey/results/test-split-2026-07-07/test-iso-hmm-shipped/report.json
```

The normal-approximation implementation was independently reconstructed from the
report deltas, and an exhaustive conditional sign-flip distribution over the
nonzero average ranks was calculated as a sensitivity check:

```sh
python3 - <<'PY'
import json
import math
from pathlib import Path

root = Path("research/whatkey/results/test-split-2026-07-07")
pairs = [
    ("When in Rome reflex - paper", "test-wir-hmm-reflex", "test-wir-hmm-shipped"),
    ("Isophonics paper - reflex", "test-iso-hmm-shipped", "test-iso-hmm-reflex"),
    (
        "Isophonics paper - offline KS",
        "test-iso-hmm-shipped",
        "test-iso-m21-krumhanslschmuckler",
    ),
]
for label, a_dir, b_dir in pairs:
    a = json.loads((root / a_dir / "report.json").read_text())
    b = json.loads((root / b_dir / "report.json").read_text())
    a_by_title = {piece["title"]: piece for piece in a["perPiece"]}
    b_by_title = {piece["title"]: piece for piece in b["perPiece"]}
    values = []
    for title in sorted(a_by_title.keys() & b_by_title.keys()):
        a_piece = a_by_title[title]
        b_piece = b_by_title[title]
        if a_piece["labeledClaimed"] and b_piece["labeledClaimed"]:
            values.append(
                a_piece["exactOnClaimed"] - b_piece["exactOnClaimed"]
            )
    nonzero = [value for value in values if abs(value) > 1e-12]
    ordered = sorted(enumerate(nonzero), key=lambda item: abs(item[1]))
    ranks = [0.0] * len(nonzero)
    tie_sizes = []
    index = 0
    while index < len(ordered):
        end = index + 1
        while end < len(ordered) and math.isclose(
            abs(ordered[end][1]),
            abs(ordered[index][1]),
            rel_tol=0,
            abs_tol=1e-12,
        ):
            end += 1
        rank = ((index + 1) + end) / 2
        tie_sizes.append(end - index)
        for position in range(index, end):
            ranks[ordered[position][0]] = rank
        index = end
    w_plus = sum(
        rank for rank, value in zip(ranks, nonzero) if value > 0
    )
    n = len(nonzero)
    mean = n * (n + 1) / 4
    variance = n * (n + 1) * (2 * n + 1) / 24
    variance -= sum(size**3 - size for size in tie_sizes) / 48
    z = (abs(w_plus - mean) - 0.5) / math.sqrt(variance)
    asymptotic_p = math.erfc(z / math.sqrt(2))
    doubled_ranks = [round(2 * rank) for rank in ranks]
    counts = {0: 1}
    for rank in doubled_ranks:
        next_counts = counts.copy()
        for subtotal, count in counts.items():
            next_counts[subtotal + rank] = next_counts.get(subtotal + rank, 0) + count
        counts = next_counts
    observed = round(2 * w_plus)
    total_rank = sum(doubled_ranks)
    distance = abs(2 * observed - total_rank)
    extreme = sum(
        count
        for subtotal, count in counts.items()
        if abs(2 * subtotal - total_rank) >= distance
    )
    exact_p = extreme / 2**n
    print(label, len(values), n, asymptotic_p, exact_p)
PY
```

The statistical interpretation was checked against the current
[SciPy Wilcoxon documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wilcoxon.html),
which describes the same zero removal, average ranks, tie-adjusted asymptotic
calculation, and the finite-sample role of sign permutations. The distinction
between an unsuccessful superiority test and evidence of noninferiority was
checked against Ahn, Park, and Lee's
[review of equivalence and noninferiority testing](https://doi.org/10.1148/radiol.12120725).
The analyzer-family characterization was checked against the
[music21 discrete-analysis documentation](https://music21.org/music21docs/moduleReference/moduleAnalysisDiscrete.html).

**What happened.**

### Calculation and masks

The submitted table values reproduce from the archived reports. There are 41
held-out Isophonics tracks and 3,565 fixture events. Three wholly modal tracks
have no reference in the paper's 24-state major/minor ontology, leaving 38
exact-scorable tracks. The post-submission R1 cohort audit pairs accuracy and
coverage on that cohort: WhatKey has macro coverage 0.8841 and macro exact
accuracy on claims 0.7316 over 2,886 claims and 3,260 scorable events. The
submitted all-track coverage was 0.8843; the accuracy value was already based on
the same 38 scorable tracks and is unchanged.

| System                                             | Coverage |  Exact |  MIREX |
| -------------------------------------------------- | -------: | -----: | -----: |
| WhatKey, causal and selective                      |   0.8841 | 0.7316 | 0.7823 |
| music21 Temperley-Kostka-Payne, constant per track |   1.0000 | 0.6371 | 0.7404 |
| music21 Krumhansl-Schmuckler, constant per track   |   1.0000 | 0.6241 | 0.7264 |
| music21 Aarden-Essen, constant per track           |   1.0000 | 0.5582 | 0.6900 |

The submitted paired Krumhansl-Schmuckler comparison also reproduces: mean
WhatKey-minus-baseline exact difference `+0.1075`, bootstrap CI95
`[-0.0082, +0.2284]`, 11/12/15 wins/losses/ties, and two-sided signed-rank
`p=0.2539`. Temperley-Kostka-Payne has the strongest baseline point estimate;
the corresponding descriptive audit is `+0.0945`, CI95 `[-0.0341, +0.2264]`,
12/11/15, `p=0.3859`. Aarden-Essen is `+0.1735`, CI95 `[+0.0550, +0.2976]`,
14/7/17, `p=0.0239`. Only the Krumhansl-Schmuckler comparison was part of the
original reported inferential plan, so the other two checks do not create new
confirmatory claims.

The report called “matched coverage” is more accurately a **common-event-mask
sensitivity analysis**. It externally restricts the always-claiming
Krumhansl-Schmuckler output to events on which WhatKey claimed; it does not move
the analyzer to an 0.88-coverage operating point. Its report contains 3,160
events across all 41 tracks, including 2,886 scorable events in the 38-track
major/minor cohort. On that common scorable mask, Krumhansl-Schmuckler has
0.6250 exact versus WhatKey's 0.7316; the paired difference is `+0.1066`, CI95
`[-0.0094, +0.2281]`, with the same 11/12/15 and `p=0.2539`. The sensitivity
check therefore rules out differential claimed-event selection as the source of
the point-estimate gap, but it does not establish superiority or noninferiority.

### Statistical implementation

`compare.py` correctly pairs tracks by title, excludes pieces lacking scored
claims from an accuracy comparison, averages tied absolute ranks, drops exact
zero differences, and applies the documented tie and continuity corrections. Its
seeded percentile bootstrap interval is for the **mean per-track accuracy
difference**, while the signed-rank p-value tests symmetry of the distribution
of paired differences around zero. They are complementary summaries with
different estimands, not two forms of the same test.

The exact conditional sign-flip sensitivity results are:

| Held-out contrast             | Pairs | Nonzero pairs | Asymptotic p | Exact sign-flip p |
| ----------------------------- | ----: | ------------: | -----------: | ----------------: |
| When in Rome reflex - paper   |    16 |            16 |       0.0465 |            0.0443 |
| Isophonics paper - reflex     |    38 |            34 |       0.0386 |            0.0374 |
| Isophonics paper - offline KS |    38 |            23 |       0.2539 |            0.2593 |

The small-sample sensitivity calculation does not change any threshold-level
reading. It supports retaining the predeclared normal-approximation results and
describing the exact values only as an audit; substituting a test after seeing
the held-out outcomes would be inappropriate.

The offline comparison's confidence interval includes both a small negative
difference and a substantial positive difference. Failure to reject zero in a
superiority test is not evidence that the systems are equivalent or that WhatKey
is noninferior. No scientifically justified noninferiority margin was
prespecified, and none should be invented after inspecting the test split.

### Task alignment

Both systems ultimately use the same Isophonics-derived harmonic timeline, but
they do not receive the same representation or solve the same output task:

| Dimension        | WhatKey paper detector                                                              | music21 reference analyzers                                                       |
| ---------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Source material  | Harte chord annotations rendered as synthetic chord-tone voicings                   | The same synthetic fixture voicings                                               |
| Direct input     | Causal ranked chord identities, costs, timing, duration, and voicing from WhatChord | All fixture MIDI notes and durations assembled into one music21 stream            |
| Future context   | None                                                                                | Entire track                                                                      |
| Output           | Event-level key or abstention; claims may change                                    | One major/minor key repeated at every event                                       |
| Reference        | Active Isophonics tonality-region annotation at each event                          | The same eventwise tonality-region annotation, despite the constant global output |
| Primary accuracy | On WhatKey's claimed, 24-state-scorable events, macro-averaged by track             | On all 24-state-scorable events, macro-averaged by track                          |
| Common-mask view | Its existing claimed events                                                         | Same events selected after the analyzer has answered                              |

Neither system is run on the original audio. WhatKey is constrained by
causality, but it has a higher-level chord-recognition representation, may
abstain, and can match region changes. music21 has hindsight and full coverage,
but the configured analyzer must return one constant key. The reference itself
contains 22 annotated changes in 6 of the 41 tracks. Consequently, this is not a
one-directionally “strictly harder” comparison: the systems have different
advantages, and the eventwise table measures a streaming region tracker against
constant whole-track reference points rather than evaluating two systems for the
same conventional global-key task.

The frozen protocol also contains a predeclared global-key diagnostic that
reduces WhatKey to its duration-weighted majority claim and scores every system
against the first major/minor reference region. This makes the output
cardinality more alike, but the first region is still only a proxy for a
whole-song reference. Descriptively, over 38 tracks, WhatKey majority is 0.7895
exact / 0.8316 MIREX, followed by Temperley-Kostka-Payne at 0.6579 / 0.7632,
Krumhansl-Schmuckler at 0.6316 / 0.7342, and Aarden-Essen at 0.5789 / 0.7132.
These already archived diagnostics can clarify task alignment if reported, but
they do not rescue a parity claim.

### Baseline characterization

The three music21 rows are not three independent modern system families. They
are alternative weight profiles within music21's
`KeyWeightKeyAnalysis`/Krumhansl-Schmuckler-style correlation implementation.
They are defensible as classic, maintained, executable profile-correlation
reference analyzers. They are not a state-of-the-art comparison set and do not
bound neural, audio-based, or stronger offline local-key systems. The
Aarden-Essen row requires special restraint because music21's documentation
states that the provenance of its minor weights is uncertain and recommends the
weights only for major. The strongest safe collective label is “classic music21
profile-correlation reference analyzers,” not “standard offline key finders” if
the latter implies comprehensive or current coverage.

**Plain-English reading.** The numbers are real and reproducible, and the
small-sample statistics are not broken. What is broken is the submitted
interpretation. A difference that is not statistically significant cannot prove
that WhatKey is “at least as good,” and these systems are not running the same
race: one can look ahead but must give one answer for a song; the other cannot
look ahead but may change its answer and decline difficult events. The table
remains useful for scale and sanity checking, but it is supporting context
rather than a result about parity with offline methods.

**Decisions.**

- Retire “at least parity,” “at least on par,” “no worse,” “strictly harder
  setting,” and any implication that `p>0.05` establishes equivalence or
  noninferiority.
- If retained, make the eventwise table a secondary descriptive comparison on
  the same fixture-derived harmonic material and tonality-region scorer. State
  the higher WhatKey point estimate and the interval's uncertainty without a
  directional inferential conclusion.
- Call the restricted Krumhansl-Schmuckler result a common-event-mask
  sensitivity analysis, not matched coverage. Explain that it controls the
  evaluated event subset rather than the analyzer's behavior.
- Describe the baselines as three music21 profile variants or classic
  profile-correlation reference analyzers, not independent state-of-the-art
  systems.
- State both sides of the task mismatch. Do not order them globally by
  difficulty.
- Consider the predeclared global-key diagnostic as a more output-aligned
  descriptive supplement, but retain its first-reference-region limitation and
  do not promote it into a new confirmatory claim.
- Keep the recorded Wilcoxon results. The exact sign-flip calculations are
  sensitivity checks only and do not replace the prespecified test.
- Do not run a new held-out detector, choose a post-hoc noninferiority margin,
  or import later detector results to strengthen this comparison.

**Next.** Audit subsequent WhatKey research only for findings that make the
submitted paper stale, overbroad, or incorrect. Then resolve the claim
architecture before editing the title, abstract, and conclusion.

// WhatKey paper. Build: typst compile main.typ (or mise research:whatkey-paper).
// All numbers trace to dated entries in research/whatkey/log/ and the
// committed one-shot artifacts in research/whatkey/results/.
//
// Layout: compact two-column archival draft. A formal submission should be
// ported to the target venue's template; set `anonymous` to true to strip
// identifying material for double-blind review drafts.

#import "@preview/lilaq:0.4.0" as lq

// Bump for committed/shareable paper drafts; use +1, +2 for same-day drafts.
#let draft-version = "v2026.8.1"

// Override without editing: typst compile --input anonymous=true main.typ
#let anonymous = sys.inputs.at("anonymous", default: "false") == "true"

// Shared figure palette (Tol vibrant, colorblind- and print-safe): every
// series color in every figure comes from here, never a package default.
#let fig-blue = rgb("#0077bb")
#let fig-orange = rgb("#ee7733")
#let fig-red = rgb("#cc3311")

#set document(
  title: "Reference Definitions Reverse Detector Rankings in Streaming Key Estimation",
  author: if anonymous { "Anonymous" } else { "Aaron Bull Schaefer" },
  date: none,
)
#set page(
  paper: "us-letter",
  margin: (x: 1.9cm, y: 2.2cm),
  columns: 2,
  numbering: "1",
)
#set columns(gutter: 0.9cm)
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#show heading: set text(size: 10.5pt)
#show table: set text(size: 8pt)
#show table.cell.where(y: 0): strong
#set table(stroke: (x, y) => if y == 0 { (bottom: 0.6pt) } else { none })
#show figure.caption: set text(size: 8.5pt)
#set figure(gap: 0.6em)

#place(top + center, scope: "parent", float: true)[
  #text(size: 14.5pt, weight: "bold")[
    Reference Definitions Reverse Detector Rankings \
    in Streaming Key Estimation
  ]

  #v(0.4em)
  #if anonymous [
    Anonymous submission
  ] else [
    Aaron Bull Schaefer
    #h(0.3em)
    #text(size: 8.5pt)[#link("https://orcid.org/0009-0007-9030-7469")[
      (ORCID 0009-0007-9030-7469)
    ]]
  ]

  #v(0.2em)
  #if anonymous [
    #text(size: 9pt)[Preprint #draft-version.]
  ] else [
    #text(size: 9pt)[Preprint #draft-version. Project name WhatKey.]
  ]
  #v(0.6em)
]

*Abstract.* A streaming key estimator must predict after each event without
future input and may abstain when its evidence is insufficient. Its score also
depends on what the reference means by "key." We define a selective-prediction
protocol measuring coverage, claimed-event accuracy, stability, and key-change
lag, and use two frozen causal detector packages to test reference sensitivity.
On 36 Beethoven performances, we hold the inputs, detector outputs, common
claimed events, and a 12-class diatonic-collection ontology fixed. Analyst-
declared key contexts and active notated key-signature collections have mean
per-piece agreement 0.65 and reverse the package ranking: the long-memory minus
short-memory accuracy difference changes from -0.081 to +0.080 (exploratory
difference of differences +0.160, CI95 [+0.118, +0.205]). Development analyses
support the consequence for model selection: independently crossing evidence
memory and a harmonic-function term produces opposite accuracy effects across
When in Rome and Isophonics reference regimes, with coverage reported alongside
accuracy. Restricting the same performed-input analysis to longer-persistence
analyst-key segments also shifts relative accuracy toward the long-memory
package, without establishing a sharp threshold. These results do not make one
reference uniquely correct or isolate temporal granularity from repertoire in
the cross-corpus evidence. They show that reference provenance, semantics,
persistence, and tonal ontology are part of the task definition and must
accompany streaming key-estimation scores.

= Introduction <sec-intro>

A musician playing a MIDI keyboard motivates a causal key indicator: after each
recognized chord, the estimator must name a key or withhold judgment, without a
second pass or future context. Incremental tonal interpretation is not new.
Weber's analysis already treated a listener's tonal understanding as something
revised while events unfold @weber1846 @moreno2003, and modern perceptual and
interactive systems have studied real-time tonality induction @rowe2000
@toiviainen2003. Retrospective and in-time readings are both valid; they answer
different analytical questions. This paper studies the narrower computational
case of causal streaming inference from chord-recognition output.

That information boundary changes the evaluation. The observations are
uncertain symbolic events: ranked chord identities, voicings, timing, and hold
duration produced by an upstream recognizer. The detector may abstain, so
coverage and accuracy on claims must be read together. It may also change its
answer, making stability, key-change matching, lag, and time-to-first-claim
relevant. These requirements motivate the protocol in @sec-protocol, but they do
not settle a more basic question: what reference makes a prediction correct?

The corpora used here supply three different constructs. When in Rome gives an
analyst-declared key context inside a functional analysis. Isophonics supplies
time-aligned tonality-region annotations. ASAP supplies active notated key
signatures, which identify a major/relative-minor collection rather than a
unique tonic and mode. Their temporal persistence differs, but so do their
provenance, semantics, repertoire, and tonal assumptions. Calling them merely
"local" and "section" keys hides those differences.

The central experiment holds the performed inputs and both detector outputs
fixed, maps predictions and references to the same 12 diatonic collections, and
changes only whether scoring follows the analyst context or the notated key
signature. The reference choice reverses which frozen detector package scores
better (@sec-reference). This result is not the familiar observation that a
long window is smoother. It shows empirically that two documented notions of
key can select different systems on unchanged predictions.

The contributions are therefore ordered as follows. First, a controlled
reference-construct analysis demonstrates the ranking reversal and quantifies
the disagreement between the references. Second, independent memory/function
crosses and a piece-aware segment-persistence analysis show how the evaluation
regime changes model selection without attributing every cross-corpus effect to
timescale alone (@sec-reference). Third, a frozen causal HMM family and a
selective-prediction protocol provide an interpretable experimental instrument,
held-out checks, and reproducible artifacts (@sec-model, @sec-heldout). The HMM
architecture, the idea of in-time analysis, and the classic offline reference
analyzers are not claimed as novel.

= Related work <sec-related>

Distributional key finding begins with the Krumhansl-Schmuckler probe-tone
profiles @krumhansl1990 and revisions such as Temperley's @temperley1999, with
corpus-trained profiles improving minor-mode behavior @albrecht2013. Temporal
structure enters through Bayesian and hidden Markov treatments @temperley2007
@raphael2004. The closest architectural analogue here is justkeydding
@napoles2019, an HMM over profile emissions for global and local key. Neural
symbolic-harmony systems also estimate local key within larger retrospective
analyses @micchi2020 @napoles2021. Our HMM remains deliberately close to this
interpretable lineage.

Global key conventionally characterizes a whole song, piece, or movement;
local-key estimation emits finer-grained predictions @weiss2020 @napoles2020.
That output distinction is independent of the information boundary: either task
may be causal or retrospective. Nor does a local-key sequence uniquely encode
music-theoretical modulations and tonicizations @napoles2020. The reference must
therefore be described operationally rather than inferred from the word
"local."

Sequential key induction has a substantial literature. Rowe reviewed key
finders for interactive performance that operate as material arrives @rowe2000;
Toiviainen and Krumhansl modeled continuously developing listener judgments
@toiviainen2003; and Chuan and Chew presented a real-time polyphonic-audio key
finder @chuan2005. Listener experiments likewise show that perceived modulation
depends on the preceding musical context @mizener2022. These precedents make
causality an established task choice, not this paper's novelty. This study
instead contributes selective prediction from chord-recognition events and a
controlled analysis of reference sensitivity.

Reference design is especially consequential across repertoires. The
major/minor ontology fits much common-practice analysis but does not exhaust
popular tonal organization. The repeated Am-F-C-G axis progression can support
both A-minor/Aeolian and C-major hearings @richards2017, and experiments on
rotations of the same four chords show that chord identity and metric placement
both influence perceived center @shea2025. Six-based minor and other
major/minor mixtures further resist a forced binary reading @declercq2021.
Abstention can express insufficient evidence among modeled labels; it cannot
represent a confident modal, blues-based, or dual-tonic answer outside the
24-state space.

Evaluation follows the MIREX weighted score for near-key errors @mirex, applied
only within our corpora. The reference sources are not interchangeable. When in
Rome is a meta-corpus of human functional analyses encoded in RomanText
@wheninrome @tymo2019. Isophonics provides time-aligned tonality regions,
normalized through ChoCo @isophonics2009 @choco2023. ASAP provides score and
performance alignment plus key-signature metadata @asap2020. @sec-data traces
how each source is transformed and what agreement with it can mean.

Bayesian online changepoint detection (BOCPD) @adams2007 is evaluated as an
adaptive-memory alternative to fixed decay. Recent autoregressive extensions
address within-regime dynamics @tsaknaki2025; our categorical implementation is
a secondary model analysis rather than part of the central contribution.

= Task and evaluation protocol <sec-protocol>

*Task.* The input is a causal stream of chord events from the application's
capture path: each event carries ranked chord candidates with explanation costs,
the sounding voicing, the analysis-time tonality context, a timestamp, and a
hold duration. An event is one held chord, not one keystroke: the capture path
aggregates pedal-aware sounding notes and commits an event only after its chord
identity persists past a debounce and minimum-duration gate, so finger rolls and
passing voicings are absorbed upstream of the detector. After each event the
detector outputs either a ranked list of (key, confidence) hypotheses or an
explicit abstention. It never sees the future and is never re-run on edited
history. The key space is the 24 major and minor keys over pitch classes;
enharmonic spelling is a presentation concern. This ontology is a modeling
choice, not a universal account of tonality. A source annotation outside it is
unscorable for 24-key accuracy rather than evidence that the detector should
have abstained.

*Metrics.* The top-ranked claim is scored. Accuracy-like metrics are reported in
the selective-prediction frame @elyaniv2010: coverage (how often the detector
makes a claim) and accuracy on claimed events form an inseparable pair, and
abstentions are never counted as errors. Exact accuracy is complemented by the
MIREX-weighted score, which grants partial credit for musically close misses
(fifth 0.5, relative 0.3, parallel 0.2) @mirex. At zero coverage, however,
accuracy on claims is undefined rather than perfect, so an always-abstaining
system cannot win the evaluation.

Temporal behavior gets three measurements. An annotated key change is *matched*
when the detector claims the new key before the next change, and its *lag* is
counted in events; unmatched changes are reported as censored counts, never
averaged into lag. A switch between claims is *spurious* only when the
annotation did not change and the new claim is not the annotated key, so a
lagged catch-up onto the right key is never penalized twice. Its per-piece
distribution includes only pieces with at least one exact local-key reference;
raw switches and time to first claim remain behavioral summaries over every
piece. Annotated changes require adjacent non-null references, so null-reference
regions enter neither the matched-change count nor the lag denominator.
*Time-to-first-claim* counts events before the detector first commits. These
counts are long-tailed, so each is summarized by the per-piece median and 90th
percentile (p90) rather than a mean. Ambiguity-labeled events (hand-authored
fixtures only) accept abstention or any acceptable key.

Two diagnostics complete the picture. Selective-prediction behavior is the
coverage-accuracy curve swept over the abstention threshold, with the selected
operating point marked. For probabilistic detectors we also report top-label
posterior reliability: events are binned by the posterior probability of the
leading key (ten equal-width bins) and compared with exact correctness,
alongside expected calibration error (ECE), negative log likelihood, and Brier
score. Reliability is separate from abstention: a detector can abstain
informatively while still being overconfident in its posterior probabilities.

*Statistics.* Every adoption decision compares two configurations piece by
piece, using the Wilcoxon signed-rank test and a seeded-bootstrap 95% confidence
interval on the mean per-piece difference. The piece is the unit of analysis
because events within a piece are strongly dependent and a few long pieces
dominate pooled counts; pooled event accuracy is never decisive. The signed-rank
test assumes no distributional form for these small samples. P-values on
development data served model selection and are uncorrected for multiplicity;
confirmatory weight rests on the original predeclared held-out result package
(@sec-heldout). Bootstrap intervals added in the revision analyses are labeled
exploratory or descriptive according to their protocols.

*Protocol discipline.* The protocol was frozen before detector tuning, with
changes recorded as dated amendments. Development/test splits were frozen per
corpus before the first experiment on it (by piece, and by composer where the
corpus allows); all original tuning, ablation, and model selection ran on
development splits. The paper-era held-out result package was declared before
its single execution. After editorial screening, four revision analyses were
declared in a dated protocol before execution: a scorable-cohort correction, a
piece-aware segment reanalysis, a dual-reference sensitivity analysis, and a
development-only memory/function grid. They do not tune a new system or promote
post-hoc results into the original confirmatory record. The evaluation harness
structurally strips labels before events reach a detector.

= Data and reproducibility <sec-data>

Evaluation uses *fixtures*: versioned event streams containing the chord
recognizer's candidate rankings, observed voicings, timing metadata, and a
parallel reference stream read only by the scorer. Fixtures are generated under
a fixed neutral analysis context: the recognizer never sees a reference key, so
its tonality-sensitive ranking rules cannot leak the answer into the
observations. Results are comparable only within a fixture version because each
fixture embeds a specific frozen chord-recognition profile.

@tab-corpora separates repertoire, observation construction, and reference
provenance. The first three sets have frozen development/test splits. The
ASAP-WiR overlap is evaluation-only and supports both performed-input analyst
contexts and, in the revision analysis, the active ASAP key-signature
collection.

#place(top, scope: "parent", float: true)[
  #figure(
    table(
      columns: (auto, auto, auto, auto),
      align: (left, left, left, right),
      table.header([corpus], [repertoire / input], [reference], [pieces / events]),
      [When in Rome @wheninrome],
      [common-practice / score-derived],
      [analyst-declared key context],
      [77 / 5,207],

      [ASAP @asap2020],
      [classical piano / performed MIDI],
      [active key-signature collection],
      [60 / 19,546],

      [Isophonics @isophonics2009 @choco2023],
      [popular songs / synthesized voicings],
      [time-aligned tonality region],
      [224 / 19,062],

      [ASAP-WiR overlap],
      [Beethoven / performed MIDI],
      [analyst context and signature collection],
      [36 / 10,395],
    ),
    caption: [Evaluation sets and their reference constructs. Repertoire,
      observation construction, and reference provenance change together in
      cross-corpus comparisons.],
  ) <tab-corpora>
]

The When in Rome subset contains 77 common-practice works by Bach, Brahms,
Schubert, Beethoven, and Mozart. Its RomanText `key` field is the analyst's
current interpretive context; an applied-chord figure can mark a tonicization
without changing that field. The fixtures contain 514 explicit key changes and
455 events with applied-chord slash figures, so “analyst context” must not be
read as “every tonicization.”

The Isophonics set contains 224 popular recordings, mostly the Beatles, with
Queen, Zweieck, and Carole King also represented; all 41 held-out tracks are
Beatles recordings. The source describes its keys as time-aligned tonality
regions, not uniformly whole-song labels, and notes that changes may be omitted.
Plain major/minor regions map into the detector's ontology. Seven tracks contain
568 modal or no-key events outside it; three held-out tracks are wholly modal.
They remain in the frozen split but are excluded from both accuracy and coverage
in the corrected 38-track 24-key cohort (@sec-heldout).

ASAP key signatures are not analyst-stated local keys. At each event the
signature defines an acceptable major/relative-minor pair; it cannot identify a
unique tonic and mode and may remain notationally unchanged across an analytical
modulation. For the dual-reference analysis, both signature pairs and
major/minor analyst contexts are mapped to the corresponding 12 diatonic-
collection classes.

The overlap transfers When in Rome analyst contexts onto ASAP performances of
the same Beethoven sonata movements through score-performance downbeat
alignment. Its per-movement measure offset is calibrated by content: agreement
between sounding pitches and analyst chords must peak sharply at zero when
labels are slid by whole measures. The project corrected erroneous offsets in
11 of 36 movements before peer review; 347 of 10,395 event labels changed, and
all reported conclusions retained their direction.

Performed fixtures are created by offline replay of recorded MIDI with sustain
semantics through the production chord analyzer, three-note gate, and event-
segmentation core. The detector later consumes the stored events in causal
timestamp order. This exercises the core musical-analysis path on performed
input; it is not an end-to-end live-user, transport, latency, display, or
usability evaluation.

A small hand-authored pop/jazz suite supplies behavioral regressions outside all
pooled statistics. The repository contains the open fixtures, split files,
evaluation harness, paired-comparison code, dated logs, and frozen result
artifacts. License-gated fixtures remain in local builds generated from pinned
upstream checkouts. Named paper-era analysis profiles and detector recipes
reproduce the original fixtures and all nine frozen result directories even
though later application defaults have changed.

= Model family and frozen packages <sec-model>

The detector family is intentionally interpretable: profile matches,
key-relative chord-function scores, and a decaying progression score, with no
learned embeddings. Its floor is a duration-weighted, exponentially decaying
pitch-class histogram ranked against all 24 rotations of the corpus-trained
Albrecht-Shanahan major/minor profiles @albrecht2013. A functional term scores
diatonic membership, dominant function, and leading-tone function; the broader
progression term scores a decaying history of several cadential patterns.

Two frozen packages organize the principal comparisons. The *long-memory
package* uses 30-second profile emissions with functional and progression blends
at zero. The *short-memory package* uses 1-second emissions plus functional
blend 0.1; its progression blend is also zero. Both use the same HMM, duration
weighting, abstention rule, and same-tonic mode cue. These packages were selected
under different development reference regimes before the original held-out
evaluation. They are experimental configurations, not current application
defaults.

The detector family is a causal HMM over the 24 major and minor keys. It keeps a
filtered posterior and updates it by the forward algorithm only; no Viterbi
decoding or future context is used. At each event, the update is:

#block(
  width: 100%,
  breakable: false,
  inset: 4pt,
  stroke: (paint: luma(70%), thickness: 0.4pt),
  radius: 2pt,
)[
  ```text
  for each pitch class p:
    histogram[p] =
      sum over prior events i of:
        duration_i
        * 2^(-age_i / half_life)
        * indicator(p in voicing_i)

  for each candidate key:
    profile_score[key] =
      correlation(histogram, key_profile[key])

  emission = softmax(profile_score / temperature)
  prior =
    transpose(transition) * previous_posterior
  posterior = normalize(emission * prior)
  ```
]

Multiplication in the last line is elementwise. In words: the profile scores
become an event-level likelihood over keys, the previous belief is advanced
through the transition model to form a prior, and the two are combined and
renormalized into the filtered belief after the current event.

In the long-memory configuration, `key_profile` is the Albrecht-Shanahan
major/minor profile set @albrecht2013. Each event's contribution to the
histogram is multiplied by its duration, and `half_life = 30 s` means that
contribution halves after 30 seconds. The softmax temperature is 0.25,
sharpening the profile-correlation scores into a more selective likelihood. The
transition matrix assigns 0.9 probability to remaining in the same key; the
remaining mass is distributed over other keys with decay by circle-of-fifths
signature distance. The frozen detector withholds its first two events. From the
third event onward, it reports the posterior's top key and probability only when
the margin between the top two probabilities is at least 0.3; otherwise it
abstains. The three-event warm-up and margin floor are independent claim gates.

Two modeling constraints matter for interpreting the results. First, the decayed
histogram and the HMM's state persistence are both memories, and evidence
entering one is carried forward by the other. An early configuration fed the HMM
emission scores that already integrated 30 s of history and expected the
transitions to supply key tracking on top; the posterior saturated and lagged
behind corrections. The two mechanisms therefore hold distinct jobs: the
histogram defines what one observation is, and the transitions supply
persistence across hidden keys. Second, the emission memory controls how local
each observation is. The next section measures how its value, and the value of
functional evidence, changes across explicitly defined reference regimes.

= Reference-dependent evaluation <sec-reference>

== Fixed outputs, different references

The primary analysis asks whether two documented reference constructs select
the same detector on unchanged material. It uses all 36 ASAP-WiR Beethoven
performances and the frozen long- and short-memory claim streams. Analyst keys,
key signatures, and detector claims are mapped to 12 diatonic-collection
classes: a minor key shares a class with its relative major. This gives both
references the same cardinality while deliberately discarding major/minor
identity. The primary event mask contains the 8,160 events on which both
packages claim and both references exist.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    table.header([reference], [long], [short], [long - short, CI95]),
    [analyst key context], [0.581], [0.661], [-0.081, \[-0.137, -0.026\]],
    [key-signature collection], [0.626], [0.547], [+0.080, \[+0.029, +0.128\]],
  ),
  caption: [Exact accuracy on common claims under two references, macro-averaged
    by performance in a shared 12-class ontology. Intervals are exploratory
    paired bootstrap intervals. Neither detector output changes.],
) <tab-dual-reference>

Mean per-piece reference agreement is only 0.6465. Under the analyst context,
the short-memory package leads; under the active key-signature collection, the
long-memory package leads (@tab-dual-reference). The piece-level difference of
differences is +0.1602, with exploratory CI95 [+0.1184, +0.2046]; 31 of 36
pieces have a positive interaction. The same reversal appears when each package
is evaluated on its own claims, so the common-event restriction does not create
it.

This is a reference-construct sensitivity result, not a contest to identify the
one correct reference. An analyst's current key context and the collection
implied by a notated signature answer different valid questions. The result is
also not a pure timescale manipulation: source, semantics, and persistence all
change with the reference. What the design establishes directly is that the
reference definition can reverse model selection while performances and
predictions remain fixed.

== Memory and function across references

The two frozen packages bundle memory and functional evidence, so their reversal
alone cannot say which ingredient matters. A predeclared revision grid crosses
half-life `{1, 30}` seconds with functional blend `{0, 0.1}` on both development
sets while fixing every other paper-era setting (@tab-grid). It is exploratory
mechanism evidence: the corpora still differ in repertoire, observation
construction, and reference practice.

#figure(
  table(
    columns: (1.2fr, 0.45fr, 1fr, 1fr),
    align: (left, center, center, center),
    table.header([reference regime], [func.], [1 s], [30 s]),
    [WiR contexts], [0.0], [0.546 / 0.680], [0.434 / 0.784],
    [WiR contexts], [0.1], [0.601 / 0.764], [0.514 / 0.824],
    [Isophonics regions], [0.0], [0.736 / 0.791], [0.775 / 0.921],
    [Isophonics regions], [0.1], [0.629 / 0.815], [0.713 / 0.926],
  ),
  caption: [Development cell means when memory and functional evidence are
    crossed independently; detector cells report exact accuracy / coverage.
    Exact accuracy is conditional on claims; WiR is When in Rome.],
) <tab-grid>

On When in Rome, 30-second minus 1-second exact accuracy is -0.104 without
functional evidence and -0.089 with it; both exploratory intervals exclude zero.
On Isophonics the corresponding effects are +0.040 (CI95 [-0.0001, +0.0786])
and +0.084 (CI95 [+0.041, +0.129]). Function helps
When in Rome at either memory (+0.063 and +0.081) and harms Isophonics at either
memory (-0.107 and -0.062); all four functional-effect intervals exclude zero.
Longer memory raises coverage in every pair, while functional evidence raises or
preserves it, so the opposite exact-accuracy effects are not produced by
opposite abstention directions.

The familiar smoothing explanation correctly anticipates that persistent
references may reward longer evidence windows. It does not by itself predict
the magnitude of the reference disagreement in @tab-dual-reference or the sign
change of a modeling ingredient in @tab-grid. Those are the evaluation and
model-selection consequences established here.

#figure(
  placement: auto,
  lq.diagram(
    width: 7.4cm,
    height: 4.6cm,
    xscale: "log",
    xaxis: (
      ticks: (
        (1, [1]),
        (2, [2]),
        (4, [4]),
        (8, [8]),
        (15, [15]),
        (30, [30]),
        (60, [60]),
      ),
      subticks: none,
    ),
    yaxis: (subticks: none),
    xlabel: [emission half-life (s)],
    ylabel: [exact accuracy on claimed],
    legend: (position: right + horizon, dy: -1.5em),
    lq.plot(
      (1, 2, 4, 8, 15, 30, 60),
      (0.724, 0.736, 0.753, 0.760, 0.758, 0.759, 0.759),
      mark: "s",
      color: fig-blue,
      label: [Isophonics regions],
    ),
    lq.plot(
      (1, 2, 4, 8, 15, 30, 60),
      (0.590, 0.550, 0.493, 0.476, 0.459, 0.486, 0.483),
      mark: "o",
      color: fig-orange,
      label: [WiR contexts, +func.],
    ),
    lq.plot(
      (1, 2, 4, 8, 15, 30, 60),
      (0.538, 0.497, 0.434, 0.382, 0.372, 0.404, 0.401),
      mark: "^",
      color: fig-red,
      label: [WiR contexts, profile],
    ),
  ),
  caption: [Descriptive development sweep. When in Rome exact accuracy declines
    strongly to 15 s and partially rebounds; Isophonics rises to a broad plateau
    from 8 s. Coverage rises with memory in all three series. No one memory
    setting is favored by both reference regimes.],
) <fig-dose>

@fig-dose sweeps the emission-memory half-life from 1 to 60 seconds on both
development corpora. The plotted series confirm the endpoint pattern without
being strictly monotonic: both When in Rome curves reach a minimum at 15 s and
partially rebound, while Isophonics reaches a plateau by 8 s. The R4 endpoint
contrasts above supply the paired uncertainty for newly emphasized inference;
the full inspected sweep is descriptive.

== Reference persistence on performed input

The overlap also permits a within-reference descriptive analysis. Each event
keeps its projected analyst context; the analysis only restricts eligibility to
contexts that persist for at least 0, 12, 20, or 32 score measures. It therefore
changes the event subset, not the labels assigned to identical events. The
thresholds and pooled direction had already been inspected, so @tab-persistence
uses piece-level summaries and descriptive intervals rather than a new
confirmatory threshold claim.

#figure(
  table(
    columns: (0.7fr, 0.4fr, 1fr, 1fr, 1fr),
    align: (center, center, center, center, center),
    table.header([min. span], [n], [long], [short], [diff. / CI95]),
    [0], [36], [0.895 / 0.502], [0.846 / 0.605], [-0.103, \[-0.158, -0.046\]],
    [12], [36], [0.909 / 0.600], [0.863 / 0.628], [-0.028, \[-0.084, +0.029\]],
    [20], [35], [0.907 / 0.625], [0.864 / 0.624], [+0.001, \[-0.067, +0.069\]],
    [32], [30], [0.913 / 0.691], [0.875 / 0.644], [+0.046, \[-0.030, +0.120\]],
  ),
  caption: [Piece-level ASAP-WiR results as evaluation is restricted to longer-
    persistence analyst-key segments. Detector cells report coverage / exact
    accuracy; spans are score measures. Intervals are descriptive paired
    bootstrap intervals. Contributing pieces and coverage change with the
    filter.],
) <tab-persistence>

Relative accuracy shifts progressively from the short-memory package toward the
long-memory package as the minimum segment span rises. The same trend remains on
the common-claim events: long-minus-short exact accuracy moves from -0.093 to
+0.033. Only the all-event short-memory advantage has an interval excluding
zero; the later near tie and long-memory lead are descriptive. This supports an
association between reference persistence and package fit, not a sharp
12-measure crossover or proof that persistence alone explains the cross-corpus
results.

Together, the three analyses establish different levels of evidence. The
dual-reference result directly holds predictions fixed. The development grid
shows that package bundling does not create the memory and functional patterns.
The persistence analysis connects those patterns to a measured temporal property
within one performed-input analyst reference. Repertoire and observation
construction remain alternative contributors to the broader When in Rome versus
Isophonics contrast.

== Secondary ablations and selective prediction

The original factorial also tested the decaying progression-score emission
blend, duration weighting, and recognizer-confidence weighting. The progression
blend did not improve the HMM cells; duration weighting improved both principal
development regimes (+0.02 to +0.05 exact) and was retained; recognizer-
confidence weighting was inert in five paired comparisons. These verdicts apply
to the mechanisms tested, not to all uses of harmonic motion or recognizer
uncertainty. In particular, post-submission product work adopted a narrower
cadence-conditioned transition mechanism; it does not reverse the frozen
negative for the broader emission-side progression score and is not part of the
paper's result package.

Sweeping the posterior-margin floor traces the selective-prediction curve in
@fig-sweep. Higher thresholds reduce coverage while raising accuracy on the
remaining claims. An all-abstaining detector would have zero coverage and no
claimed-event accuracy; it cannot score as a useful system. The margin floor of
0.3 was selected on development data before held-out execution. That point is
evaluated as a coverage-accuracy pair, with stability and latency reported
separately.

#figure(
  lq.diagram(
    width: 7.4cm,
    height: 4.4cm,
    xaxis: (subticks: none),
    yaxis: (subticks: none),
    xlabel: [coverage (fraction of events claimed)],
    ylabel: [exact accuracy on claimed],
    lq.plot(
      (
        0.970,
        0.962,
        0.954,
        0.945,
        0.937,
        0.930,
        0.922,
        0.912,
        0.903,
        0.882,
        0.856,
      ),
      (
        0.768,
        0.769,
        0.770,
        0.772,
        0.773,
        0.774,
        0.775,
        0.777,
        0.779,
        0.783,
        0.785,
      ),
      mark: "o",
      color: fig-blue,
    ),
    lq.scatter(
      (0.922,),
      (0.775,),
      mark: "d",
      size: 7pt,
      color: fig-red,
    ),
  ),
  caption: [Selective-prediction behavior of the frozen long-memory package on
    the Isophonics development split, swept over the
    posterior-margin floor (0 to 0.6). Moving left raises the margin required to
    speak, so coverage falls; moving up means the remaining claims are more
    often correct. The marked point is the evaluated operating point (floor
    0.3).],
) <fig-sweep>

= Mode disambiguation <sec-mode>

On mode-resolved corpora the residual errors sort into MIREX classes:
fifth-neighbor confusions, relative-pair confusions (shared signature), and
parallel-pair confusions (shared tonic). Mode errors, the most user-visible
class since an indicator displays major or minor, were about 10% of claims on
both mode-resolved development regimes after fixing a detector package.

The design constraint that works is mass preservation within a musically related
pair: if a cue only redistributes evidence between two hypotheses that share an
invariant, it can help choose between them while leaving every other key
untouched.

*Parallel pairs (selected).* Parallel keys share the tonic pitch class, and
practical minor borrows the raised sixth and seventh, so the discriminating
evidence collapses to roughly one pitch class, easily outvoted in a
12-dimensional correlation. Symbolic observations change that: when the played
chord is rooted on a candidate tonic and its quality is one a tonic chord can
carry (plainly major or minor), that quality is the most direct mode cue
available. The cue is applied as a log-odds tilt within the parallel pair after
the emission softmax, then rescaled so the pair's total emission is unchanged.
By construction it cannot move tonic evidence at all, which rules out the
failure mode of two less constrained ancestors, an unconditional bonus for tonic
chords and the functional rules of @sec-model, both of which could fight
modulation tracking. Strength 2 was selected after a 0.25-to-4 sweep with a
broad 2-to-4 plateau: paired exact wins in both development regimes (Isophonics
+0.016, p = 0.030; When in Rome +0.030, p = 0.029), parallel confusion roughly
halved everywhere measured (4% to 2% of claims on Isophonics). Across the
Isophonics sweep, coverage varied within 1.2 percentage points, spurious p90
remained 1, and matched annotated changes rose from 82 to 102 of 192.

*Relative pairs (measured negative).* The same pattern generalizes with the key
signature as the conserved quantity. But here the evidence is structurally
weaker. In a parallel pair, hearing the rival's tonic chord is rare mode
mixture; in a relative pair it is ordinary diatonic harmony (A minor's tonic
triad is just the vi chord of C major), so isolated chord quality fires
constantly for the wrong twin. Two sharpened cues were built and swept: a
bass-gated tilt (fires only when the chord's root is also its bass) and a
cadential-bigram tilt (a dominant-quality chord resolving down a fifth onto a
home-quality chord). This particular cadence cue is inert.
The bass cue works mechanically (relative confusion 6% to 4% of claims) but
misses paired significance on Isophonics (+0.007, p = 0.055), trends
negative on the other (-0.009, p = 0.056), and doubles spurious p90; unlike the
parallel tilt's broad plateau, it turns harmful at strength 2, the signature of
a weak signal. Not adopted; retained in code as a measured negative.

*Fifth pairs (not adopted).* Fifth neighbors conserve neither tonic nor
signature, and every key has two of them, so there is no pair to redistribute
within. Discriminating a key from its dominant *is* the modulation problem, and
any chord-quality nudge between fifth neighbors recreates the unconditional
tonic bonus rejected above. Empirically the residual fifth errors also lack an
exploitable shape, splitting nearly evenly between the dominant and subdominant
sides (57/43 and 56/44 on the two mode-resolved corpora).

One pattern explains all three outcomes: a tilt is worth what its invariant is
worth. Parallel keys share a tonic, and the discriminating evidence is rare and
decisive, so the cue was adopted. Relative keys share only a signature, and the
discriminating evidence is everyday harmony, so the cue was too weak. Fifth
neighbors share nothing, so there is no pair to tilt within at all.

= Adaptive temporal models <sec-adaptive>

*Explicit-duration modeling (HSMM).* The HMM's fixed self-transition implies
geometric key-dwell times: at every event the key survives with the same
probability. An HSMM (hidden semi-Markov model) would replace that with a richer
dwell-time family. Before building one we measured whether the system even
responds to the parameter an HSMM would refine: sweeping the self-transition
from 0.7 to 0.98 (mean dwell roughly 3 to 50 events) moves every metric along
the coverage-accuracy curve rather than off it (Isophonics exact within 0.008,
spurious p90 1 through 0.95 and 2 at 0.98). The probe does not prove explicit-
duration modeling useless for key estimation; it shows there is little headroom
at the selected long-memory Isophonics operating point.

*Bayesian online changepoint detection, built and measured.* The dwell probe
addresses the changepoint prior (constant-hazard BOCPD implies the same
geometric dwell) but not BOCPD's distinct contribution, the adaptive evidence
window: instead of decaying evidence through a fixed 30 s half-life, BOCPD
infers where the current section started and pools evidence back to that point.
We built the constant-hazard detector for the 24-key space @adams2007 with
emission conventions identical to the frozen long-memory HMM (including the
mode tilt), so any difference is attributable to the window (@tab-bocpd).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, center, center, center, center),
    table.header([config], [cov], [exact], [matched changes], [spur med/p90]),
    [HMM, long], [0.92], [0.775], [94/192], [0/1],
    [BOCPD h=1/200], [0.88], [0.715], [161/192], [5/14],
    [BOCPD T=0.5], [0.89], [0.765], [135/192], [2/7],
    [BOCPD T=1.0], [0.90], [0.769], [115/192], [0/4],
  ),
  caption: [BOCPD versus the frozen long-memory HMM on the Isophonics
    development set. Here `h` is the constant changepoint hazard and `T` is
    emission temperature. The adaptive window matches more annotated changes,
    but no tuning recovers the long-memory stability point.],
) <tab-bocpd>

The adaptive window increases annotated-change matching by 70% because evidence
resets at inferred starts. The same reactivity degrades stability under the
Isophonics reference, and softening the per-event evidence does not recover the
long-memory point (best cell: exact wash, p = 0.51, spurious p90 4 versus 1).
At matched reactivity BOCPD does outperform the HMM's fast setting (0.765 exact
at 135 matched changes versus 0.736 at 141 for the HMM at a 2 s half-life), so
adaptive windowing can improve responsiveness without being preferred by this
reference regime. Its false alarms occur within stable annotated regions, where
the independent-given-key assumption is weakest. Autoregressive extensions
target analogous within-regime dependence in continuous series @tsaknaki2025,
but those Gaussian remedies have no direct analog for categorical chord
emissions; the broader emission-side progression score tested here did not
repair the limitation.

= Held-out evaluation <sec-heldout>

The original paper-era held-out manifest was declared before execution and then
frozen: it evaluates the long-memory package on all three splits, the
short-memory package on the two mode-resolved splits, three music21 @music21
profile-correlation analyzers on Isophonics, and a descriptive mode-confusion
breakdown. Later product investigations reused some held-out pieces, so they are
not independent new tests; no later result is used here. The original artifacts
and the declared R1 correction are preserved with the project.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, center, center),
    table.header([split], [scorable / total], [coverage], [exact]),
    [Isophonics], [38 / 41], [0.884], [0.732],
    [WiR], [18 / 18], [0.811], [0.587],
    [ASAP], [10 / 10], [0.830], [0.683],
  ),
  caption: [The frozen long-memory package on the three held-out splits.
    Three wholly modal Isophonics tracks have no event in the 24-state ontology
    and are excluded from both accuracy and coverage, while remaining in the
    frozen split. ASAP is scored against acceptable major/minor realizations of
    its key signatures.],
) <tab-test>

The long-memory package retains substantial coverage across all three inputs
(@tab-test). Development-to-test changes differ by corpus (Isophonics exact
falls from 0.775 to 0.732; When in Rome rises from 0.434 to 0.587), so these
small splits support a generalization check rather than a precise estimate of
deployment performance.

*The predeclared package ordering reverses across references.* Against When in
Rome analyst contexts, the short-memory package exceeds the long-memory package
(0.649 versus 0.587 exact; paired difference +0.062, CI95 [+0.004, +0.121],
p = 0.047; 16 paired pieces), at lower coverage (0.745 versus 0.811). Against
Isophonics region labels, the long-memory package exceeds the short-memory
package (0.732 versus 0.556; +0.175, CI95 [+0.040, +0.315], p = 0.039; 38
pieces), at higher coverage (0.884 versus 0.793). These are two within-regime
tests, not a formal interaction test, and the packages bundle memory with
functional weighting. They are therefore a generalization check consistent
with the fixed-output R3 interaction, not its substitute.

*Descriptive external reference points.* @tab-baselines reports three classic
offline whole-piece profile-correlation analyzers from music21 on the held-out
Isophonics songs.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    table.header([system], [coverage], [exact], [MIREX]),
    [frozen long package], [0.884], [0.732], [0.782],
    [Temperley-Kostka-Payne @temperley2007], [1.00], [0.637], [0.740],
    [Krumhansl-Schmuckler @krumhansl1990], [1.00], [0.624], [0.726],
    [Aarden-Essen @aarden2003], [1.00], [0.558], [0.690],
  ),
  caption: [Descriptive held-out Isophonics reference points for the causal,
    abstaining long-memory package and three offline whole-piece
    profile-correlation analyzers.],
) <tab-baselines>

The long-memory package has the highest point estimate, while
Temperley-Kostka-Payne is the strongest whole-piece reference point. The
submitted Krumhansl-Schmuckler contrast is +0.108 with a CI spanning zero
([-0.008, +0.228], p = 0.25); restricting that analyzer to the detector's
claimed-event mask yields 0.625, not an independently matched-coverage operating
point. No equivalence, noninferiority, or superiority test was specified.
Moreover, the systems have different output forms and information: each
offline analyzer reads the entire song and returns one key, whereas the causal
package may change or abstain event by event. The table therefore supplies
familiar descriptive context, not a claim of parity with the offline key-
estimation literature.

The descriptive confusion mix is: exact 72%, fifth 7%, relative 5%, parallel 2%,
other 14%. This pooled exact rate differs from the per-piece mean in @tab-test;
the parallel row matches the mode tilt's development effect exactly.

*Posterior calibration.* Raw filtered posteriors are overconfident: on claimed
exact-labeled development events, the mean top posterior is 0.929 against 0.772
exact accuracy (expected calibration error, ECE, 0.157). Overconfidence does not
affect ranking, abstention, or any paired accuracy claim, but it matters the
moment the probability is displayed. Post-hoc temperature scaling @guo2017, fit
once on the development split (T = 1.55, negative log-likelihood argmin),
reduces held-out claimed-event ECE from 0.192 to 0.041. Because the transform is
monotone and display-only, the held-out claims are byte-identical to the
frozen artifacts, which simultaneously verifies that the calibration pass took
nothing from test data.

= Limitations <sec-limitations>

The primary R3 result is deliberately narrow: two frozen detector packages, 36
Beethoven performances, their common claimed events, and a shared 12-class
diatonic-collection scoring ontology derived from 24-state outputs. It isolates
the reference definition while holding input and output fixed, but it does not
establish the size or direction of the effect for other repertoires, ontologies,
or detectors. R3 and R4 were declared during revision after the editorial
concern was known and are exploratory; their intervals quantify uncertainty but
do not convert them into preregistered confirmatory tests.

Neither reference is ground truth. Analyst-declared contexts and active notated
key-signature collections encode different musical questions, and either may be
debatable in ambiguous passages. The broader cross-corpus contrasts also change
repertoire, observation construction, and reference provenance together.
Reference persistence is one measured contributor, not a complete causal
explanation.

The detector ontology contains only 12 major and 12 minor states. Modal, blues,
mode-mixture, and tonic-ambiguous loops can fall outside it or admit multiple
reasonable readings; three wholly modal Isophonics test tracks are consequently
excluded from 24-state accuracy and coverage. They remain in the frozen split
as a separate behavioral audit. The recognizer is also part of the measurement
chain: fixtures embed its chord rankings, so recognizer changes require
regenerating fixtures before comparison.

“Streaming” here means causal evaluation during offline replay of recorded
performed MIDI. The study does not measure wall-clock latency, transport
failures, interface behavior, or musician judgments in a live session. Its
30-second and 1-second packages are frozen experiment recipes, not the current
application defaults; post-submission product tuning neither updates nor
validates these paper-era results.

Held-out splits contain only 10 to 41 pieces, and later product work reused some
of them. The offline comparison is limited to three classic profile-correlation
analyzers with different information and output forms. In particular,
justkeydding @napoles2019 did not build reproducibly in our environment, so no
claim is made against it or newer score-based systems. Corpus licensing further
prevents redistribution of two gated fixture sets; the project instead records
pins, derived facts, splits, commands, and evaluation artifacts.

Finally, calibration is reference-relative just like accuracy. The display
temperature in @sec-heldout is fit for correctness against the Isophonics
region reference; it need not be calibrated against analyst contexts or another
musical interpretation.

= Conclusion <sec-conclusion>

The reference construct is part of the streaming key-estimation task. On fixed
Beethoven performances, detector outputs, common claimed events, and a shared
12-class diatonic-collection ontology, analyst-declared key contexts and active
notated key-signature collections reverse the ranking of the same two frozen
detector packages. The long-minus-short contrast changes from -0.081 under the
analyst reference to +0.080 under the notated-signature reference, a +0.160
paired interaction whose interval excludes zero.

The supporting analyses delimit that result. A development grid reproduces the
opposing memory effects and shows that the functional cue itself helps under
When in Rome contexts and hurts under Isophonics regions. Within the overlap,
longer-persistence analyst contexts progressively favor the long-memory package,
but without a sharp threshold. The original held-out package reversal provides
a separate generalization check while bundling two design choices and changing
corpus as well as reference.

The engineering contribution is a reproducible causal selective-prediction
protocol over recorded performed MIDI: coverage, accuracy on claims, change
lag, and spurious switching are reported together, and the detector may abstain
when evidence is insufficient. This study does not establish offline parity or
end-to-end live usability. It establishes a narrower prerequisite for valid
comparison: publications and benchmarks should name what their references
encode, including their provenance, temporal granularity, and treatment of
tonicization, signature, mode, and ambiguity.

Future work should repeat the fixed-output dual-reference design across
repertoires and detector families, expand beyond the 24 major/minor states, and
evaluate the causal system with musicians in live interaction. Those extensions
can test whether the reversal generalizes; they should not collapse distinct
reference constructs into a single undifferentiated “key accuracy.”

#heading(numbering: none)[Competing Interests]

The author has no competing interests to declare.

#v(0.6em)
#line(length: 100%, stroke: 0.5pt)
#if anonymous [
  #text(size: 8pt)[
    Reproducibility: protocol, dated experiment logs, corpus pins, frozen
    splits, evaluation harness, and held-out evaluation artifacts live in the
    project repository. Every number traces to a dated log entry and a report
    with its generating command. The repository link is withheld for
    double-blind review and will appear here upon acceptance.
  ]
] else [
  #text(size: 8pt)[
    Reproducibility: protocol, logs, corpus pins, splits, harness, and held-out
    evaluation artifacts live under #link(
      "https://github.com/EarthmanMuons/whatchord/tree/main/research/whatkey",
    )[`research/whatkey/`] in the WhatChord repository. Every number traces to a
    dated log entry and a report with its generating command. \
    #link(
      "https://github.com/EarthmanMuons/whatchord",
    )[https://github.com/EarthmanMuons/whatchord]
  ]
]

#bibliography("refs.yml", style: "ieee")

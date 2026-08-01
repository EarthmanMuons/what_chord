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

*Abstract.* What key is a passage in while the music is still unfolding? An
analyst may describe a temporary move to a new key even when the written key
signature does not change. A detector that follows the local move and one that
retains the broader key can therefore receive opposite scores depending on
which annotations are treated as the answer. We study this evaluation problem
for causal key estimation from recognized chords, where a system predicts after
each event or abstains. On 36 Beethoven performances, we score the same outputs
from a responsive short-memory detector and a stable long-memory detector
against analyst-declared key contexts and active key-signature collections. We
map both references to a common 12-category representation and compare events
where both detectors make a claim. The references agree at a mean per-piece
rate of 0.65 and reverse the detector ranking: the long-minus-short accuracy
difference changes from -0.081 to +0.080 (exploratory interaction +0.160, CI95
[+0.118, +0.205]). Development analyses show corresponding changes in the value
of memory and harmonic-function evidence. Neither reference is uniquely
correct, and the cross-corpus evidence does not isolate annotation persistence
from repertoire. The result is instead methodological: key-estimation scores
must identify what their reference annotations mean.

= Introduction <sec-intro>

A passage can move temporarily to another key even while its written key
signature remains unchanged. A responsive detector may follow that local move;
a more stable detector may retain the broader key. Neither behavior is
inherently wrong. Which detector appears better depends on what the annotations
used for evaluation are intended to describe.

That problem is easy to overlook because a benchmark score makes its labels
look like a neutral answer key. In practice, music datasets encode different
notions of key: an analyst's current interpretive context, a time-bounded
tonality region, or the collection implied by a written key signature. These
notions differ in meaning and persistence. If a benchmark does not state which
one it measures, an accuracy comparison may conflate a detector's quality with
its agreement with a particular annotation practice.

We examine this problem in a streaming setting motivated by a musician playing
a MIDI keyboard. After every recognized chord, the system must name a key or
withhold judgment using only the music heard so far. This causal boundary makes
responsiveness, stability, and abstention visible, but our main question is more
basic: can the definition of the reference answer change which detector wins?

The central experiment uses 36 recorded Beethoven performances with two
documented references: analyst-declared key contexts and active notated key
signatures. We hold the performed input and both detectors' predictions fixed,
translate all answers to the same 12 diatonic collections, and compare only
events where both detectors speak. The references agree on roughly two thirds
of events and reverse the ranking of a responsive short-memory configuration and
a stable long-memory configuration (@sec-reference).

The paper contributes this controlled demonstration, supporting analyses of
memory and reference persistence, and a causal evaluation protocol that reports
how often a detector speaks as well as how often it is correct. The claim is not
that one reference is the true key, or that annotation persistence explains
every difference between datasets. It is that the meaning of the reference
labels is part of the task definition and must accompany a key-estimation score.

= Related work <sec-related>

Distributional key finding begins with the Krumhansl-Schmuckler probe-tone
profiles @krumhansl1990 and revisions such as Temperley's @temperley1999, with
corpus-trained profiles improving minor-mode behavior @albrecht2013. Bayesian
and hidden Markov models add temporal structure @temperley2007 @raphael2004.
The closest architectural analogue here is justkeydding @napoles2019, an HMM
over profile emissions for global and local key; neural harmony systems also
estimate local key within larger retrospective analyses @micchi2020
@napoles2021. Our detector remains deliberately close to this interpretable
lineage.

Global key conventionally characterizes a whole song, piece, or movement;
local-key estimation emits finer-grained predictions @weiss2020 @napoles2020.
That output distinction is independent of the information boundary: either task
may be causal or retrospective. Nor does a local-key sequence uniquely encode
music-theoretical modulations and tonicizations @napoles2020. The reference must
therefore be described operationally rather than inferred from the word
"local."

Sequential key induction also has a substantial history. Weber treated tonal
understanding as something revised while events unfold @weber1846 @moreno2003;
interactive and perceptual studies later modeled key from the evidence available
so far @rowe2000 @toiviainen2003 @chuan2005. Perceived modulation likewise
depends on preceding context @mizener2022. Causality is therefore an established
task choice rather than this paper's novelty.

Reference design is especially consequential across repertoires. The
major/minor answer space fits much common-practice analysis but does not exhaust
popular tonal organization. The repeated Am-F-C-G axis progression can support
both A-minor/Aeolian and C-major hearings @richards2017, and experiments on
rotations of the same four chords show that chord identity and metric placement
both influence perceived center @shea2025. Six-based minor and other
major/minor mixtures further resist a forced binary reading @declercq2021.
Abstention can express insufficient evidence among modeled labels; it cannot
represent a confident modal, blues-based, or dual-tonic answer outside the
24-state space.

The reference sources are not interchangeable. When in Rome contains human
functional analyses encoded in RomanText @wheninrome @tymo2019; Isophonics
provides time-aligned tonality regions @isophonics2009 @choco2023; and ASAP
provides aligned performances and key-signature metadata @asap2020. @sec-data
traces how each source is transformed and what agreement with it can mean.

= Task and evaluation protocol <sec-protocol>

*Task.* The input is a causal stream of recognized chord events. Each event
summarizes the candidate chord identities, sounding voicing, timestamp, and hold
duration for one stable sonority. After every event, the detector returns a
ranked list of keys with confidence values or explicitly abstains. It never sees
future events or revises its earlier output. The modeled answer space contains
the 12 major and 12 minor keys; annotations outside that space are unscorable
rather than evidence that the detector should have abstained. @sec-data
describes how performed notes become stored events without exposing reference
labels to the recognizer or detector.

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

The coverage-accuracy curve is traced by sweeping the abstention threshold, with
the selected operating point marked. This shows whether abstention actually
concentrates the detector's errors rather than merely reducing its output.

*Statistics and analysis discipline.* Comparisons use the piece, not the event,
as the unit of analysis because events within a piece are dependent and long
pieces would dominate pooled counts. We report Wilcoxon signed-rank tests and
seeded-bootstrap 95% intervals on mean paired differences. Development/test
splits and the protocol were fixed before detector selection; all tuning and
ablation used development data. The held-out configuration comparison was specified
before test execution (@sec-heldout). The dual-reference, segment-persistence,
and 2x2 analyses were designed after inspection of the cross-corpus pattern and
are exploratory or descriptive. Labels are structurally removed before an event
reaches either the chord recognizer or key detector.

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
contexts and the active ASAP key-signature collection.

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
    caption: [Evaluation sets and their reference definitions. Repertoire,
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
Plain major/minor regions map into the detector's answer space. Seven tracks contain
568 modal or no-key events outside it; three held-out tracks are wholly modal.
They remain in the full split but are excluded from both accuracy and coverage
in the 38-track 24-key scoring cohort (@sec-heldout).

ASAP key signatures are not analyst-stated local keys. At each event the
signature defines an acceptable major/relative-minor pair; it cannot identify a
unique tonic and mode and may remain notationally unchanged across an analytical
modulation. For the dual-reference analysis, both signature pairs and
major/minor analyst contexts are mapped to the corresponding 12 diatonic-
collection classes.

The overlap transfers When in Rome analyst contexts onto ASAP performances of
the same Beethoven sonata movements through score-performance downbeat
alignment. Each movement's measure offset is calibrated by content: agreement
between sounding pitches and analyst chords must peak sharply at zero when
labels are slid by whole measures. Movements without a unique, content-
consistent offset are rejected rather than silently aligned.

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
upstream checkouts. Versioned analysis profiles and detector recipes pin the
observation and detector configurations used here independently of mutable
software defaults.

= Two streaming detectors <sec-model>

The detector is deliberately simple enough to inspect. It summarizes the recent
pitch classes, gives older chords progressively less weight, and compares that
summary with profiles for the 24 major and minor keys @albrecht2013. An optional
functional term asks whether a chord behaves as expected in each candidate key.

Two fixed configurations organize the principal comparisons. The *long-memory
configuration* gives accumulated chord evidence a 30-second half-life and does
not use the functional term. The *short-memory configuration* uses a 1-second
half-life and adds the functional term at weight 0.1. Both use the same HMM,
duration weighting, abstention rule, and same-tonic mode cue. They were selected
against different development references and fixed before held-out evaluation;
neither is proposed as universally best.

The mode cue uses a recognized tonic chord's major or minor quality to
redistribute evidence only between the major and minor keys sharing that tonic.
It preserves the pair's total evidence, so it cannot favor another tonic or
create a key change by itself.

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

The decayed histogram and the HMM transition model both preserve information,
but they play different roles: the histogram defines how much recent musical
evidence forms the current observation, while the transition model discourages
the hidden key from changing at every chord. The experiments below vary the
first form of memory while keeping the second fixed.

= Reference-dependent evaluation <sec-reference>

== Fixed outputs, different references

The primary analysis asks whether two documented reference definitions select
the same detector on unchanged material. It uses all 36 ASAP-WiR Beethoven
performances and the fixed long- and short-memory claim streams. Analyst keys,
key signatures, and detector claims are mapped to 12 diatonic-collection
classes: a minor key shares a class with its relative major. This gives both
references the same cardinality while deliberately discarding major/minor
identity. The primary event mask contains the 8,160 events on which both
configurations claim and both references exist.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    table.header([reference], [long], [short], [long - short, CI95]),
    [analyst key context], [0.581], [0.661], [-0.081, \[-0.137, -0.026\]],
    [key-signature collection], [0.626], [0.547], [+0.080, \[+0.029, +0.128\]],
  ),
  caption: [Exact accuracy on common claims under two references, macro-averaged
    by performance in a shared 12-class representation. Intervals are exploratory
    paired bootstrap intervals. Neither detector output changes.],
) <tab-dual-reference>

Mean per-piece reference agreement is only 0.6465. Under the analyst context,
the short-memory configuration leads; under the active key-signature collection,
the long-memory configuration leads (@tab-dual-reference). The piece-level difference of
differences is +0.1602, with exploratory CI95 [+0.1184, +0.2046]; 31 of 36
pieces have a positive interaction. The same reversal appears when each configuration
is evaluated on its own claims, so the common-event restriction does not create
it.

This is sensitivity to the reference definition, not a contest to identify the
one correct reference. An analyst's current key context and the collection
implied by a notated signature answer different valid questions. The result is
also not a pure timescale manipulation: source, semantics, and persistence all
change with the reference. What the design establishes directly is that the
reference definition can reverse model selection while performances and
predictions remain fixed.

== Memory and function across references

The two fixed configurations bundle memory and functional evidence, so their reversal
alone cannot say which ingredient matters. An exploratory 2x2 grid, specified
before those cells were run, crosses half-life `{1, 30}` seconds with functional
blend `{0, 0.1}` on both development sets while fixing every other setting
(@tab-grid). The corpora still differ in repertoire, observation construction,
and reference practice.

#figure(
  table(
    columns: (1.2fr, 0.45fr, 1fr, 1fr),
    align: (left, center, center, center),
    table.header([reference], [func.], [1 s], [30 s]),
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
partially rebound, while Isophonics reaches a plateau by 8 s. The 2x2 endpoint
contrasts above supply paired uncertainty; the full inspected sweep is
descriptive.

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

Relative accuracy shifts progressively from the short-memory configuration toward the
long-memory configuration as the minimum segment span rises. The same trend remains on
the common-claim events: long-minus-short exact accuracy moves from -0.093 to
+0.033. Only the all-event short-memory advantage has an interval excluding
zero; the later near tie and long-memory lead are descriptive. This supports an
association between reference persistence and configuration fit, not a sharp
12-measure crossover or proof that persistence alone explains the cross-corpus
results.

Together, the three analyses establish different levels of evidence. The
dual-reference result directly holds predictions fixed. The development grid
shows that bundling does not create the memory and functional patterns.
The persistence analysis connects those patterns to a measured temporal property
within one performed-input analyst reference. Repertoire and observation
construction remain alternative contributors to the broader When in Rome versus
Isophonics contrast.

== Abstention behavior

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
  caption: [Selective-prediction behavior of the fixed long-memory configuration on
    the Isophonics development split, swept over the
    posterior-margin floor (0 to 0.6). Moving left raises the margin required to
    speak, so coverage falls; moving up means the remaining claims are more
    often correct. The marked point is the evaluated operating point (floor
    0.3).],
) <fig-sweep>

= Held-out evaluation <sec-heldout>

The held-out manifest was declared before execution. It evaluates the long-
memory configuration on all three splits, the short-memory configuration on the
two splits whose references distinguish major from minor, and three music21
@music21 profile-correlation analyzers on Isophonics. The resulting claim
streams are fixed, and every cohort restriction reported below depends only on
the reference labels.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, center, center),
    table.header([split], [scorable / total], [coverage], [exact]),
    [Isophonics], [38 / 41], [0.884], [0.732],
    [WiR], [18 / 18], [0.811], [0.587],
    [ASAP], [10 / 10], [0.830], [0.683],
  ),
  caption: [The fixed long-memory configuration on the three held-out splits.
    Three wholly modal Isophonics tracks have no event in the 24-key answer space
    and are excluded from both accuracy and coverage, while remaining in the
    frozen split. ASAP is scored against acceptable major/minor realizations of
    its key signatures.],
) <tab-test>

The long-memory configuration retains substantial coverage across all three
inputs (@tab-test). Development-to-test changes differ by corpus (Isophonics exact
falls from 0.775 to 0.732; When in Rome rises from 0.434 to 0.587), so these
small splits support a generalization check rather than a precise estimate of
deployment performance.

*The predeclared ordering reverses across references.* Against When in
Rome analyst contexts, the short-memory configuration exceeds the long-memory
configuration
(0.649 versus 0.587 exact; paired difference +0.062, CI95 [+0.004, +0.121],
p = 0.047; 16 paired pieces), at lower coverage (0.745 versus 0.811). Against
Isophonics region labels, the long-memory configuration exceeds the short-memory
configuration (0.732 versus 0.556; +0.175, CI95 [+0.040, +0.315], p = 0.039; 38
pieces), at higher coverage (0.884 versus 0.793). These are two within-reference
tests, not a formal interaction test, and the configurations bundle memory with
functional weighting. They are therefore a generalization check consistent
with the fixed-output interaction, not its substitute.

*Descriptive external reference points.* @tab-baselines reports three classic
offline whole-piece profile-correlation analyzers from music21 on the held-out
Isophonics songs.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    table.header([system], [coverage], [exact], [MIREX]),
    [fixed long configuration], [0.884], [0.732], [0.782],
    [Temperley-Kostka-Payne @temperley2007], [1.00], [0.637], [0.740],
    [Krumhansl-Schmuckler @krumhansl1990], [1.00], [0.624], [0.726],
    [Aarden-Essen @aarden2003], [1.00], [0.558], [0.690],
  ),
  caption: [Descriptive held-out Isophonics reference points for the causal,
    abstaining long-memory configuration and three offline whole-piece
    profile-correlation analyzers.],
) <tab-baselines>

The long-memory configuration has the highest point estimate, while
Temperley-Kostka-Payne is the strongest whole-piece reference point. The
Krumhansl-Schmuckler contrast is +0.108, but its interval spans zero
([-0.008, +0.228], p = 0.25), and no superiority or equivalence test was
specified. More importantly, the systems answer different questions: each
offline analyzer reads the entire song and returns one key, whereas the causal
configuration may change or abstain after each chord. The table supplies
familiar context, not evidence that the streaming system matches or surpasses
the offline key-estimation literature.

= Limitations <sec-limitations>

The primary dual-reference result is deliberately narrow: two fixed detector
configurations, 36 Beethoven performances, their common claimed events, and a
shared 12-class diatonic-collection representation derived from 24-key outputs. It
isolates the reference definition while holding input and output fixed, but it
does not establish the size or direction of the effect for other repertoires,
answer spaces, or detectors. The dual-reference and 2x2 analyses were designed
after inspection of the cross-corpus pattern and are exploratory; their
intervals quantify uncertainty but do not convert them into preregistered
confirmatory tests.

Neither reference is ground truth. Analyst-declared contexts and active notated
key-signature collections encode different musical questions, and either may be
debatable in ambiguous passages. The broader cross-corpus contrasts also change
repertoire, observation construction, and reference provenance together.
Reference persistence is one measured contributor, not a complete causal
explanation.

The detector's answer space contains only 12 major and 12 minor keys. Modal, blues,
mode-mixture, and tonic-ambiguous loops can fall outside it or admit multiple
reasonable readings; three wholly modal Isophonics test tracks are consequently
excluded from 24-state accuracy and coverage. They remain in the frozen split
as a separate behavioral audit. The recognizer is also part of the measurement
chain: fixtures embed its chord rankings, so recognizer changes require
regenerating fixtures before comparison.

“Streaming” here means causal evaluation during offline replay of recorded
performed MIDI. The study does not measure wall-clock latency, transport
failures, interface behavior, or musician judgments in a live session. The
30-second and 1-second configurations are fixed experimental recipes, not an
end-to-end application evaluation.

Held-out splits contain only 10 to 41 pieces. The offline comparison is limited
to three classic profile-correlation analyzers with different information and
output forms. In particular, justkeydding @napoles2019 did not build
reproducibly in our environment, so no claim is made against it or newer score-
based systems. Corpus licensing further prevents redistribution of two gated
fixture sets; the project instead records pins, derived facts, splits, commands,
and evaluation artifacts.

= Conclusion <sec-conclusion>

A detector can appear better or worse depending on what the reference calls the
key. On the same Beethoven performances and the same detector outputs, analyst-
declared key contexts favor the short-memory configuration by 0.081, while
notated key-signature collections favor the long-memory configuration by 0.080.
The resulting paired interaction is +0.160, with an interval excluding zero.

The supporting analyses clarify rather than erase that result. Memory and
functional evidence have opposing effects under the two development reference
regimes; longer-persistence analyst contexts progressively favor longer memory;
and the configuration reversal reappears on held-out data. Repertoire and
observation construction still differ across the broader corpus comparison, so
the fixed-output dual-reference experiment remains the cleanest evidence.

The study also provides a reproducible protocol for a causal detector that may
abstain, reporting coverage, accuracy on claims, change lag, and spurious
switching together. It does not establish offline parity or end-to-end live
usability. Its narrower conclusion is more fundamental: a key-estimation score
cannot be interpreted without knowing what kind of key its reference encodes.
Benchmarks should therefore state the reference's source, temporal granularity,
and treatment of tonicization, signature, mode, and ambiguity.

Future work should repeat the fixed-output design across repertoires and
detector families, expand beyond major and minor keys, and evaluate the causal
system with musicians in live interaction.

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

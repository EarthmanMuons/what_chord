// WhatKey paper. Build: typst compile main.typ (or mise research:whatkey-paper).
// All numbers trace to dated entries in research/whatkey/log/ and the
// committed one-shot artifacts in research/whatkey/results/.
//
// Layout: compact two-column archival draft. A formal submission should be
// ported to the target venue's template; set `anonymous` to true to strip
// identifying material for double-blind review drafts.

#import "@preview/lilaq:0.4.0" as lq

// Bump for committed/shareable paper drafts; use +1, +2 for same-day drafts.
#let draft-version = "v2026.7.30"

// Override without editing: typst compile --input anonymous=true main.typ
#let anonymous = sys.inputs.at("anonymous", default: "false") == "true"

// Shared figure palette (Tol vibrant, colorblind- and print-safe): every
// series color in every figure comes from here, never a package default.
#let fig-blue = rgb("#0077bb")
#let fig-orange = rgb("#ee7733")
#let fig-red = rgb("#cc3311")

#set document(
  title: "Streaming Key Estimation with Abstention from Live Chord-Recognition Output",
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
    Streaming Key Estimation with Abstention \
    from Live Chord-Recognition Output
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

*Abstract.* Most key-detection research is retrospective: a system reads a
complete score or recording and then reports its key. We study the interactive
version of the problem. A musician plays a MIDI keyboard, a chord recognizer
names each chord as it lands, and a key detector must decide after every chord
which key the player is in, or admit that the evidence is not yet sufficient. We
define an evaluation protocol for this streaming task that measures abstention,
stability, and key-change lag alongside accuracy, and we evaluate a family of
causal detectors on four annotated corpora. The selected system is a hidden
Markov model (HMM) run strictly forward over pitch-profile evidence, with one
constrained cue that separates major from minor keys sharing the same tonic. The
central finding is that the detector's evidence memory selects which kind of
annotated key it reports: short memory tracks the brief local keys marked by
music analysts, long memory tracks the section-level keys of song annotations,
and neither setting is simply more accurate, so accuracy comparisons between key
detectors are incomplete without the label timescale. Most added complexity
fails to help: weighting by the chord recognizer's confidence, progression
rules, and adaptive changepoint models all leave the selected operating point
unimproved. On held-out pop songs, the causal, abstaining detector performs at
least on par with standard offline key finders that read the entire song before
answering.

= Introduction <sec-intro>

A musician improvises at a MIDI keyboard while an application identifies each
chord as it is played. A natural next feature is a key indicator: a small
display answering, from the playing alone, "what key am I in right now?" Key
finding is one of the oldest problems in music information retrieval, so it
sounds like a solved problem waiting to be wired in. It is not: nearly all
published key finding is retrospective, reading a complete score or recording
and only then reporting a key, either one label for the whole piece or a local
analysis computed with the entire piece in view. A live indicator enjoys no such
hindsight, and its setting differs from the literature's in three compounding
ways.

First, the detector is *causal and streaming*. It only ever sees the past, and
it must update after each chord, from someone noodling with finger rolls, pedal
blur, and wrong notes. There is no second pass and no lookahead, so the
whole-sequence Viterbi decodings that dominate published HMM key finding are
unavailable by construction.

Second, the observations are *uncertain and symbolic at the chord level*. The
input is neither ground-truth notes nor audio chroma but the output of a chord
recognizer: ranked candidate identities with explanation costs (the recognizer's
own measure of how well the sounding notes fit each candidate), plus the
voicing, timing, and hold duration of each committed chord. The detector
therefore knows each chord's root, quality, and bass, an unusual asset, but the
recognizer itself can be wrong, an unusual noise source.

Third, *abstention is a first-class outcome*. Some music hovers deliberately
between keys; a two-chord modal vamp has no single right answer, and asserting
one confidently is worse than staying quiet.

These constraints change what counts as a good answer. A detector can score well
on conventional accuracy while flickering between keys, guessing through
ambiguous passages, and trailing every key change; whole-piece evaluation
notices none of this. We therefore measure coverage (how often the detector
speaks) and accuracy on claimed events as an inseparable pair, along with
stability, modulation lag, and time-to-first-claim. Defining the task this
carefully pays off beyond the interactive setting: the load-bearing choice in
the final system is the length of the detector's evidence memory, and what that
dial selects is which kind of annotated "key" the detector reports, brief local
tonicizations or the broader section key. Accuracy comparisons between key
detectors are under-specified until the evaluation says which target counts as
correct.

The paper's contributions follow that arc. We define the task and an evaluation
protocol for streaming key estimation with abstention, frozen before tuning,
with piece-level paired statistics for every adoption decision, a held-out
evaluation performed exactly once, and a fixture-based reproducibility design
(@sec-protocol, @sec-data). We establish the timescale finding between corpora,
within one corpus on identical performed input, and on held-out data with
significance in both directions (@sec-timescale). We map which symbolic and
temporal additions earn their keep: one adopted cue, a mass-preserving
same-tonic mode tilt (@sec-mode), against measured negatives for
recognizer-confidence weighting, progression rules, relative-pair tilts, and
adaptive temporal models (@sec-timescale, @sec-mode, @sec-adaptive). What these
measurements leave standing is a validated, interpretable baseline: a causal HMM
over profile-correlation emissions with posterior-margin abstention (@sec-model)
that reaches at least parity with offline whole-piece baselines on held-out data
(@sec-heldout).

= Related work <sec-related>

Distributional key finding begins with the Krumhansl-Schmuckler probe-tone
profiles @krumhansl1990 and their revisions @temperley1999, with corpus-trained
profiles improving minor-mode behavior @albrecht2013. These methods estimate key
from pitch-class distributions and remain important baselines because they are
simple, reproducible, and musically interpretable. The selected detector in this
paper keeps that interpretability: its emissions are profile correlations rather
than learned sequence embeddings.

Temporal structure enters key and harmony estimation through Bayesian and hidden
Markov treatments @temperley2007 @raphael2004. The closest published analogue of
our final detector is justkeydding @napoles2019, an HMM over profile emissions
for global and local key. Neural symbolic-harmony systems also estimate local
key as one head of a larger harmonic-analysis task, for example models using
Roman numeral corpora and multitask architectures @micchi2020 @napoles2021.
Those systems demonstrate the value of local-key estimation, but they analyze
complete scores offline, where our detector must filter causally over
chord-recognition events and abstain when the evidence is thin.

Real-time tonal tracking has also been studied outside the profile/HMM family.
Chew's Spiral Array and Center of Effect Generator frame key finding as movement
in a geometric tonal space, tracking an evolving tonal center as notes
accumulate @chew2000. Our setting differs in the observation layer: the detector
receives symbolic chord identities and candidate rankings from an upstream
recognizer rather than raw pitch collections.

Bayesian online changepoint detection (BOCPD) @adams2007 tracks a posterior over
how long the current regime has lasted, making it the natural adaptive-memory
alternative to a fixed decay. Recent extensions model within-regime dynamics to
suppress false alarms @tsaknaki2025. We build the constant-hazard version for
the 24-key space and measure where its adaptivity helps and where it conflicts
with the selected section-key operating point.

Evaluation practice follows the MIREX audio key task's weighted scoring @mirex
for near misses, applied to our own corpora (scores are not comparable to MIREX
leaderboards, which are audio-based on different data). Ground truth spans two
annotation cultures, a distinction central to @sec-timescale. Analyst-marked
local keys record every brief modulation: When in Rome's RomanText analyses
@wheninrome @tymo2019. Section-level keys name a stable home key: Isophonics
song keys via the ChoCo chord corpus @choco2023 @isophonics2009, and the key
signatures of the ASAP performed piano MIDI corpus @asap2020.

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
enharmonic spelling is a presentation concern.

*Metrics.* The top-ranked claim is scored. Accuracy-like metrics are reported in
the selective-prediction frame @elyaniv2010: coverage (how often the detector
makes a claim) and accuracy on claimed events form an inseparable pair, and
abstentions are never counted as errors. Exact accuracy is complemented by the
MIREX-weighted score, which grants partial credit for musically close misses
(fifth 0.5, relative 0.3, parallel 0.2) @mirex.

Temporal behavior gets three measurements. An annotated key change is *matched*
when the detector claims the new key before the next change, and its *lag* is
counted in events; unmatched changes are reported as censored counts, never
averaged into lag. A switch between claims is *spurious* only when the
annotation did not change and the new claim is not the annotated key, so a
lagged catch-up onto the right key is never penalized twice.
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
confirmatory weight rests on the pre-declared held-out evaluation, performed
exactly once (@sec-heldout).

*Protocol discipline.* The protocol was frozen before detector tuning, with
changes recorded as dated amendments. Development/test splits were frozen per
corpus before the first experiment on it (by piece, and by composer where the
corpus allows); all tuning, ablation, and model selection ran on development
splits; the test splits were evaluated exactly once, with the result set
declared in advance (@sec-heldout). The evaluation harness structurally strips
labels before events reach a detector.

= Data and reproducibility <sec-data>

Evaluation uses *fixtures*: versioned event streams containing the chord
recognizer's candidate rankings, the observed voicings, timing metadata, and a
parallel label stream read only by the scorer. Fixtures are generated under a
fixed neutral analysis context: the recognizer never sees the annotated key, so
its tonality-sensitive ranking rules cannot leak ground truth into the
observations. Results are comparable only within a fixture version, because
fixture contents embed a specific version of the chord-recognition engine.

Four fixture sets span two annotation cultures and three input conditions
(@tab-corpora). The first three have frozen development/test splits. The
ASAP-WiR overlap is evaluation-only: every configuration run against it was
declared in advance because the set exists specifically to test whether the
timescale effect survives on identical performed input.

#place(top, scope: "parent", float: true)[
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto),
      align: (left, left, left, right, right),
      table.header([corpus], [input], [labels], [pieces], [events]),
      [When in Rome @wheninrome],
      [quantized scores],
      [analyst local keys (local-key)],
      [77],
      [5,207],

      [ASAP @asap2020],
      [performed piano MIDI],
      [key signatures (section-key, mode-unknown)],
      [60],
      [19,546],

      [Isophonics @isophonics2009 @choco2023],
      [synthesized voicings],
      [song keys (section-key, mode-resolved)],
      [224],
      [19,062],

      [ASAP-WiR overlap],
      [performed piano MIDI],
      [analyst local keys (local-key)],
      [36],
      [10,395],
    ),
    caption: [Evaluation corpora. Development/test splits are frozen for the
      first three; the overlap corpus is evaluation-only (every configuration
      run on it was committed in advance).],
  ) <tab-corpora>
]

The overlap corpus transfers When in Rome analyst keys onto ASAP performances of
the same Beethoven sonata movements through the performance-to-score downbeat
alignment, giving real tonic-and-mode ground truth on performed input. The
transfer's per-movement measure offset is calibrated by content (agreement
between sounding pitches and analyst chords must peak sharply at a whole-measure
offset of zero when all labels are slid sideways), which guards the label
quality this corpus's evaluation-only role depends on. A small hand-authored
pop/jazz suite (12-bar blues, modal vamps, deliberately ambiguous loops) serves
as a per-fixture behavioral regression battery outside all pooled statistics.
Performed corpora are replayed through the capture path of @sec-protocol, so
detectors see the events they would see live.

The repository contains the open fixtures, split files, evaluation harness,
paired-comparison script, dated experiment logs, and the committed artifacts of
the single held-out evaluation. License-gated corpora are not committed: their
extractors refuse to write inside the research directory and must be rerun
locally from pinned upstream checkouts. This means the paper's reported numbers
are auditable from committed reports and commands, while redistribution remains
bounded by each source corpus's terms.

= Model family and selected detector <sec-model>

The detector family was restricted to components a musician could inspect
(profile matches, chord-function scores, cadence votes), with no learned
embeddings; the selected detector is the simplest member that survived
measurement. The family's floor is profile correlation: a duration-weighted,
exponentially decaying pitch-class histogram, with all 24 rotations of a
major/minor profile pair ranked by Pearson correlation, using the corpus-trained
profile values of Albrecht and Shanahan @albrecht2013 (whose original algorithm
pairs them with Euclidean distance). On top of it, two symbolic layers were
built: a weighted-evidence layer scoring key-relative chord functions (diatonic
membership, dominant and leading-tone function), and a progression layer voting
on cadential transition patterns. The resulting three-way hybrid (correlation
base plus small functional and progression blend terms) beat the floor on early
local-key development runs (+0.096 exact per piece, p = 0.003), but the
ablations of @sec-timescale later removed both layers from the selected
section-key configuration. Except for the constrained same-tonic mode cue of
@sec-mode, chord-identity features proved useful mainly for the local-key
version of the task; the selected section-key configuration is deliberately
close to a pure profile model.

The selected detector is a causal HMM over the 24 major and minor keys. It keeps
a filtered posterior and updates it by the forward algorithm only; no Viterbi
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

In the selected configuration, `key_profile` is the Albrecht-Shanahan
major/minor profile set @albrecht2013. Each event's contribution to the
histogram is multiplied by its duration, and `half_life = 30 s` means that
contribution halves after 30 seconds. The softmax temperature is 0.25,
sharpening the profile-correlation scores into a more selective likelihood. The
transition matrix assigns 0.9 probability to remaining in the same key; the
remaining mass is distributed over other keys with decay by circle-of-fifths
signature distance. At each event, the detector reports the posterior's top key
and its probability only when the margin between the top two probabilities is at
least 0.3; otherwise it abstains.

Two modeling constraints matter for interpreting the results. First, the decayed
histogram and the HMM's state persistence are both memories, and evidence
entering one is carried forward by the other. An early configuration fed the HMM
emission scores that already integrated 30 s of history and expected the
transitions to supply key tracking on top; the posterior saturated and lagged
behind corrections. The two mechanisms therefore hold distinct jobs: the
histogram defines what one observation is, and the transitions supply
persistence across hidden keys. Second, the emission memory controls how local
each observation is; the next section shows that this dial selects between
annotation targets.

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
      label: [Isoph. (section key)],
    ),
    lq.plot(
      (1, 2, 4, 8, 15, 30, 60),
      (0.590, 0.550, 0.493, 0.476, 0.459, 0.486, 0.483),
      mark: "o",
      color: fig-orange,
      label: [WiR (local key), +func.],
    ),
    lq.plot(
      (1, 2, 4, 8, 15, 30, 60),
      (0.538, 0.497, 0.434, 0.382, 0.372, 0.404, 0.401),
      mark: "^",
      color: fig-red,
      label: [WiR (local key), pure],
    ),
  ),
  caption: [Emission-memory dose-response on the two development annotation
    scales. The curves run in opposite directions with no interior optimum: the
    dial selects the reported timescale. Coverage rises with memory on both
    scales (0.77 to 0.93 on Isophonics); the section-key plateau spans 8-60 s.
    "Pure" means profile-correlation emissions only; "+func." adds the early
    chord-function evidence term.],
) <fig-dose>

= The timescale finding <sec-timescale>

Key annotations come in two cultures. Analysts marking local keys (When in Rome)
record every tonicization, however brief: a typical piece carries about seven
key regions, each only a few chords long. Song keys and key signatures
(Isophonics, ASAP) instead name the key of a whole section and absorb short
excursions into it. We call these *local-key* and *section-key* annotations. A
detector graded against local keys is rewarded for reacting immediately; one
graded against section keys is rewarded for staying put.

@fig-dose sweeps the emission-memory half-life from 1 to 60 seconds on both
development corpora, a dose-response design: memory length is the dose, accuracy
on claimed events the response. The two label cultures answer in opposite
directions. Against local-key labels, accuracy only falls as memory grows, and
the detector catches half as many key changes. Against section-key labels,
accuracy climbs to a broad plateau from 8 s outward, and longer memory keeps
buying coverage and stability (the p90 spurious-switch count falls from 7 to 1).
There is no interior optimum to find; the result is the crossover between
annotation targets, not a best smoothing value.

#figure(
  lq.diagram(
    width: 7.4cm,
    height: 4.4cm,
    xaxis: (ticks: (0, 12, 20, 32), subticks: none),
    yaxis: (subticks: none),
    xlabel: [minimum annotated segment length (measures)],
    ylabel: [exact accuracy on claimed],
    legend: (position: bottom + right),
    lq.plot(
      (0, 12, 20, 32),
      (0.52, 0.62, 0.64, 0.68),
      mark: "s",
      color: fig-blue,
      label: [30 s memory (section-key)],
    ),
    lq.plot(
      (0, 12, 20, 32),
      (0.61, 0.62, 0.62, 0.62),
      mark: "o",
      color: fig-orange,
      label: [1 s memory (local-key)],
    ),
  ),
  caption: [The crossover within a single corpus on identical performed input
    (ASAP-WiR overlap): filtering to longer analyst key segments, the
    long-memory configuration climbs and overtakes the short-memory one by
    12-measure segments, which stays flat. The same recordings, sliced by label
    granularity, reorder the two configurations. Accuracy pools claimed events
    under each segment filter.],
) <fig-segment>

Could the crossover instead reflect input noise, or some other difference
between the corpora? Three controls say no. First, noise: on the evaluation-only
overlap corpus, identical performed recordings scored against analyst local keys
still prefer short memory (0.61 vs 0.52 exact on claims, the leftmost points of
@fig-segment), matching the clean-score result. Second, corpus identity: the
crossover reproduces *within* that single corpus when the same claims are
re-scored by annotated segment length (@fig-segment); the long-memory
configuration overtakes as segments lengthen, while the short-memory one stays
flat. Third, the crossover holds on held-out data with significance in both
directions (@sec-heldout).

The application conclusion is a choice, not a claim that one timescale is
universally better: a glanceable key indicator should report the section, so the
selected configuration uses 30 s memory and deliberately absorbs brief
tonicizations. The research conclusion is that cross-paper accuracy comparisons
are under-specified without the label timescale: the same detector moves by tens
of points when the annotation scale changes.

*Ablations.* Four candidate ingredients were tested in every combination, a
16-cell factorial run once per annotation scale: the functional and progression
blends of @sec-model, duration weighting (a chord's evidence counts in
proportion to how long it was held), and recognizer-confidence weighting
(evidence is discounted when the recognizer's top two chord readings were nearly
tied). Each came back with a clean verdict. The functional blend flips sign with
the annotation scale: removing it is a significant paired win on section-key
labels, yet on local-key labels it is load-bearing (+0.061 exact, CI95 [+0.019,
+0.108], p = 0.010), direct evidence that the functional rules are excursion
detectors. The progression blend had earned its place under an earlier
architecture, and that value washes out under the HMM. Duration weighting helps
on both scales (+0.02 to +0.05 exact) and is kept. Recognizer-confidence
weighting is inert in five out of five paired tests, a useful negative because
exploiting the recognizer's confidence was a natural hypothesis for this
setting. The selected emissions are therefore pure profile correlation. As a
bonus nobody engineered, a long-standing behavioral failure vanished with the
deleted rules: the functional layer had been hearing every tonic seventh chord
in a 12-bar blues as a pull toward the subdominant, and with it gone the blues
probes finally read correctly.

Abstention earns its place at this operating point. Sweeping the
posterior-margin floor traces the coverage-accuracy curve of @fig-sweep, which
rises monotonically as the detector grows choosier: abstentions are informative,
not random.

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
  caption: [Selective-prediction behavior: the coverage-accuracy curve of the
    selected configuration on the Isophonics development split, swept over the
    posterior-margin floor (0 to 0.6). Moving left raises the margin required to
    speak, so coverage falls; moving up means the remaining claims are more
    often correct. The marked point is the selected operating point (floor
    0.3).],
) <fig-sweep>

= Mode disambiguation <sec-mode>

On mode-resolved corpora the residual errors sort into MIREX classes:
fifth-neighbor confusions, relative-pair confusions (shared signature), and
parallel-pair confusions (shared tonic). Mode errors, the most user-visible
class since an indicator displays major or minor, were about 10% of claims on
both annotation scales once the timescale trade was filtered out.

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
broad 2-to-4 plateau: paired exact wins on both annotation scales (Isophonics
+0.016, p = 0.030; When in Rome +0.030, p = 0.029), parallel confusion roughly
halved everywhere measured (4% to 2% of claims on Isophonics), and no stability
cost on the section-key development set.

*Relative pairs (measured negative).* The same pattern generalizes with the key
signature as the conserved quantity. But here the evidence is structurally
weaker. In a parallel pair, hearing the rival's tonic chord is rare mode
mixture; in a relative pair it is ordinary diatonic harmony (A minor's tonic
triad is just the vi chord of C major), so isolated chord quality fires
constantly for the wrong twin. Two sharpened cues were built and swept: a
bass-gated tilt (fires only when the chord's root is also its bass) and a
cadential-bigram tilt (a dominant-quality chord resolving down a fifth onto a
home-quality chord). The cadence cue is inert, echoing the progression ablation.
The bass cue works mechanically (relative confusion 6% to 4% of claims) but
misses paired significance on the primary scale (+0.007, p = 0.055), trends
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
spurious p90 pinned at 1). The probe does not prove explicit-duration modeling
useless for key estimation; it shows there is little headroom at the selected
operating point.

*Bayesian online changepoint detection, built and measured.* The dwell probe
addresses the changepoint prior (constant-hazard BOCPD implies the same
geometric dwell) but not BOCPD's distinct contribution, the adaptive evidence
window: instead of decaying evidence through a fixed 30 s half-life, BOCPD
infers where the current section started and pools evidence back to that point.
We built the constant-hazard detector for the 24-key space @adams2007 with
emission conventions identical to the selected HMM (including the mode tilt), so
any difference is attributable to the window (@tab-bocpd).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, center, center, center, center),
    table.header([config], [cov], [exact], [modulations], [spur med/p90]),
    [HMM, selected], [0.92], [0.775], [94/192], [0/1],
    [BOCPD h=1/200], [0.88], [0.715], [161/192], [5/14],
    [BOCPD T=0.5], [0.89], [0.765], [135/192], [2/7],
    [BOCPD T=1.0], [0.90], [0.769], [115/192], [0/4],
  ),
  caption: [BOCPD versus the selected HMM on the section-key development set
    (Isophonics dev). Here `h` is the constant changepoint hazard and `T` is
    emission temperature. The adaptive window improves modulation detection but
    no tuning recovers the selected stability point.],
) <tab-bocpd>

The adaptive window delivers its promise: modulation matching jumps by 70%,
because evidence resets at inferred section starts. But the same reactivity
breaks section-key stability, and no tuning recovers the selected operating
point: softening the per-event evidence walks BOCPD back along the frontier
without reaching the HMM (best cell: exact wash, p = 0.51, spurious p90 still 4
versus 1). One finding is worth keeping: at matched reactivity BOCPD dominates
the HMM's fast settings (0.765 exact at 135 modulations versus 0.736 at 141 for
the HMM at a 2 s half-life), so adaptive windowing has real value for local-key
tracking; it simply was not selected for the section-key task studied here. The
false alarms are within-section harmonic movement, exactly where BOCPD's
independent-given-key assumption is weakest. Autoregressive extensions target
the analogous within-regime dependence in continuous series @tsaknaki2025, but
those Gaussian remedies have no direct analog for categorical chord emissions,
and our domain's substitute, the progression layer, is measured inert.

= Held-out evaluation <sec-heldout>

The test splits were evaluated exactly once, with the result set declared before
any run: the selected configuration on all three splits; the local-key reference
configuration on the two mode-resolved splits; the music21 @music21 baselines on
Isophonics, with paired and matched-coverage comparisons; and a descriptive
mode-confusion breakdown. The complete artifacts are committed with the project.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (left, right, center, center, center, center),
    table.header([split], [pieces], [cov], [exact], [mods], [spur]),
    [Isophonics], [41], [0.88], [0.732], [10/22], [0/3],
    [WiR], [18], [0.81], [0.587], [39/115], [0/1],
    [ASAP], [10], [0.83], [0.683], [-], [0/0],
  ),
  caption: [The selected configuration on the three held-out splits. `mods` is
    matched annotated modulations; `spur` is median/p90 spurious switches. WiR
    is When in Rome; ASAP is scored with acceptable keys because labels are
    mode-unknown key signatures.],
) <tab-test>

Generalization is clean (@tab-test): Isophonics dips modestly from development
(0.775 to 0.732), When in Rome comes in far above it (0.434 to 0.587, easier
held-out pieces), and stability holds everywhere; the differences run in both
directions, not the uniform degradation a tuned-to-development configuration
would show.

*The held-out crossover is significant in both directions.* The short-memory
local-key configuration is better when judged against local-key labels (0.649 vs
0.587 exact, paired +0.062, CI95 [+0.004, +0.121], p = 0.047). The selected
section-key configuration is better when judged against section-key labels
(0.732 vs 0.556, paired +0.175, CI95 [+0.040, +0.315], p = 0.039), while also
avoiding the local-key configuration's spurious switches (0/3 vs 5/11 med/p90).

*External comparison.* @tab-baselines compares against music21's offline
whole-piece analyzers on the held-out songs.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    table.header([system], [coverage], [exact], [MIREX]),
    [this work (causal, abstaining)], [0.88], [0.732], [0.782],
    [Temperley-Kostka-Payne @temperley2007], [1.00], [0.637], [0.740],
    [Krumhansl-Schmuckler @krumhansl1990], [1.00], [0.624], [0.726],
    [Aarden-Essen @aarden2003], [1.00], [0.558], [0.690],
  ),
  caption: [Held-out Isophonics test split: the causal, abstaining detector
    against offline whole-piece baselines.],
) <tab-baselines>

The causal detector's point estimate leads every offline analyzer, including at
matched coverage (Krumhansl-Schmuckler restricted to our claimed events: 0.63).
The paired test is a wash (+0.108, CI95 [-0.008, +0.228], p = 0.25), so the
defensible claim is *at least parity under a more constrained setting*: the
baselines read each entire song before answering; this detector never sees the
future, abstains on the ambiguous 12%, and reports posterior probabilities and
streaming stability metrics offline systems do not have.

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
committed one-shot artifacts, which simultaneously verifies that the calibration
pass took nothing from test data.

= Limitations <sec-limitations>

The label timescale is a construct of the annotation culture, and our central
finding is precisely that results are relative to it; we mitigate by reporting
both annotation scales, but neither scale is "the truth."

Residual error contains genuine ambiguity (relative twins share every pitch
class; mode-mixture passages and dominant prolongations can reasonably be
notated different ways), so ceilings are below 1.0 and unknown.

The recognizer sits inside the loop: fixtures embed its rankings, so recognizer
changes can change detector results and require regenerating fixtures before
comparison.

Corpus licensing constrains redistribution (two corpora are noncommercial- or
research-gated; we commit derived facts, splits, and evaluation artifacts, not
the gated fixtures).

Test splits are small (10 to 41 pieces), which the paired statistics respect but
cannot cure. Stronger neural local-key systems are offline and score-hungry; we
compare only against baselines runnable on our fixtures. In particular,
justkeydding @napoles2019, the closest published analogue, did not build
reproducibly in our environment, so no comparison claim is made against it in
either direction.

Calibration is task-relative, exactly like accuracy: the temperature-scaled
display of @sec-heldout is calibrated to section-key correctness on pop
material, and against local-key labels the same display remains overconfident.

= Conclusion <sec-conclusion>

This paper asked whether a live application can tell a musician what key they
are in, from chord-recognition output alone, without ever seeing ahead. The
answer is yes, and with less machinery than expected. Under a frozen protocol,
paired statistics, and a held-out evaluation performed exactly once, a causal
HMM over profile-correlation evidence, plus one constrained major-versus-minor
cue, reports section keys at least on par with offline baselines that read the
whole song first. The route there was largely simplification guided by
measurement: functional and progression rules help only when the target is
local-key tracking, recognizer-confidence weighting is inert, and adaptive
temporal models trade stability for reactivity. The lasting methodological
lesson is that key-detection accuracy is label-timescale dependent. The same
detector looks better or worse depending on whether the reference labels mark
brief tonicizations or section keys, so the annotation scale is part of the task
definition, not a detail of the dataset.

Two follow-ups are natural. Local-key tracking deserves treatment as a task in
its own right rather than as an ablation of the section-key detector: short
memory, the functional blend, and adaptive windowing all have measured value in
that regime. And the fixture design's deliberately neutral analysis context
leaves open a closed-loop question, whether feeding the detector's tonality
belief back into chord recognition improves the chord identities enough to
change key tracking, which requires evaluating the coupled system rather than a
fixed event stream.

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

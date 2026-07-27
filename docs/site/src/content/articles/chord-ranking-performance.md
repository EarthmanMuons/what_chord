---
cardDescription:
  "Why the chord comparator is non-transitive, why that forces an O(n²) Copeland
  linearization, and how we cut its cost by an order of magnitude without
  changing what a musician sees."
cardTitle: "Optimizing an Algorithm That’s Quadratic by Design"
decks:
  - "WhatChord names the chord you are playing, in real time. Doing that well
    means generating plausible names and ranking them. That ranking step turned
    out to eat almost all of the engine’s compute because it cannot use an
    ordinary sort. In June 2026 we set out to make it fast: first by shaving
    constant factors, then by questioning a hidden requirement that had made the
    larger optimization look impossible."
description:
  "Naming a chord means ranking every plausible name, a step that can’t use an
  ordinary sort. Why WhatChord’s ranking is quadratic by design, and how we made
  it an order of magnitude faster without changing the answer a musician sees."
group: "technical"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 5
pageTitle: "Optimizing an Algorithm That’s Quadratic by Design | WhatChord"
related:
  - "chord-recognition-algorithm"
  - "benchmarking-on-hardware-you-dont-control"
  - "million-chord-annotations"
socialDescription:
  "Ranking a chord’s possible names can’t use an ordinary sort, which makes it
  quadratic by design. The optimizations that worked, the ones that didn’t, and
  the reframe that cut the cost tenfold."
socialTitle: "Optimizing an Algorithm That’s Quadratic by Design"
tag: "Technical deep-dive"
title: "Optimizing an Algorithm That’s Quadratic by Design"
---

## What the engine is doing

WhatChord is an app that watches the notes you play on a MIDI keyboard and names
the chord as you play it. Press C-E-G together and it shows
<span class="chord">C major</span>. That sounds like a dictionary lookup, and
for that example it nearly is. The trouble is that real playing is rarely so
tidy: the same notes can carry several legitimate names depending on the
surrounding music, players leave notes out and add color tones, and a chord can
get spread across both hands. So the engine does not look chords up. It treats
naming as a _ranking_ problem: list every plausible interpretation, score how
well each one fits, then put them in the order a musician would expect to read.

Two terms worth explaining:

- A **voicing** is the specific set of notes being played, including which one
  is lowest (the bass). "C-E-G" and "E-G, then C an octave up" are two voicings
  of the same chord.
- A **candidate** is one possible name for a voicing. The four notes C-E-G-A can
  be read as <span class="chord">C6</span> or <span class="chord">Am7</span>,
  among others, so the engine produces many candidates per voicing and has to
  choose and order them.

This article is about the last step in the process, the ranking. When we built a
reproducible benchmark and measured where the engine spends its time on a cache
miss, the answer was lopsided: **ranking is roughly 99% of it; scoring is about
1%.** An uncached analysis of a common seventh chord takes a few milliseconds,
and nearly all of that time goes toward putting the already-scored candidates in
order.

## Why ranking can't use an ordinary sort

To sort a list, you hand the language a _comparator_: a function that takes two
items and reports which should come first. Every general-purpose sort assumes
that function describes a
[consistent ordering](https://en.wikipedia.org/wiki/Weak_ordering), and in
particular that it is
[transitive](https://en.wikipedia.org/wiki/Transitive_relation): if A belongs
before B, and B before C, then A must belong before C. Violate that and the
sort's result is undefined. It will not usually crash, but it can drop items in
nonsensical positions.

WhatChord's comparator is deliberately not transitive. Most of the time it ranks
two candidates by their fit score, but two kinds of musical override can outrank
the score:

- **Hard rules** are structural overrides for the cases where the higher score
  is simply the wrong name (preferring, say, an altered dominant chord over a
  diminished-slash respelling that fits the raw notes but reads worse). A hard
  rule can promote a lower-scoring reading over a higher-scoring one no matter
  how wide the gap.
- **Tie-breakers** apply only when two candidates score within a small window of
  each other (0.20 points, a constant the code calls `nearTieWindow`), capturing
  musical heuristics that a single number can't.

Because a hard rule ignores the size of the score gap, you can end up with a
cycle: A beats B, B beats C, and C beats A. No single ordering satisfies all
three at once, so there is nothing coherent for a sort to return. Hand a cyclic
comparator to a general sort and the outcome can depend on the candidates'
starting order.

So the engine does not sort. It _linearizes_ the relation, turning the web of
pairwise preferences into one ordered list:

<pre><code><span class="cm">// beats[i][j] == true  =&gt;  candidate i should rank above j.</span>
<span class="cm">// The relation may contain cycles: a &gt; b &gt; c &gt; a.</span>
<span class="kw">List</span>&lt;Candidate&gt; <span class="fn">linearize</span>(<span class="kw">List</span>&lt;Candidate&gt; cands, <span class="kw">List</span>&lt;<span class="kw">List</span>&lt;<span class="kw">bool</span>&gt;&gt; beats) {
  <span class="kw">final</span> result = &lt;Candidate&gt;[];
  <span class="kw">final</span> remaining = { ...allIndices };
  <span class="kw">while</span> (remaining.isNotEmpty) {
    <span class="cm">// Prefer a maximal element: one beaten by nothing still remaining.</span>
    <span class="kw">var</span> pick = <span class="fn">firstUnbeaten</span>(remaining, beats);
    <span class="cm">// No maximal element means a cycle. Break it by Copeland win-count:</span>
    <span class="cm">// how many of the others this candidate beats. Global over remaining.</span>
    pick ??= <span class="fn">mostWins</span>(remaining, beats);
    result.<span class="fn">add</span>(cands[pick]);
    remaining.<span class="fn">remove</span>(pick);
  }
  <span class="kw">return</span> result;
}</code></pre>

Two important points. First, to know whether a candidate is "beaten by nothing
remaining," you need the full matrix of pairwise results: every `beats[i][j]`
combination. Building that matrix is `n²` calls to the comparator, where `n` is
the number of candidates. Second, when a cycle blocks progress, the tie-break
borrows [Copeland's method](https://en.wikipedia.org/wiki/Copeland%27s_method)
from voting theory: count how many of the others each candidate beats, and take
the one that beats the most. That count is **global**, summed over every
remaining candidate. That global count is why several appealing shortcuts are
unsafe.

## The cost is real, and it grows with the chord

The engine builds a candidate for every
[reasonable pairing of a root note with a chord shape it can find in the voicing](chord-recognition-algorithm.html),
so the candidate count climbs steeply as you add notes:

<table class="article-table">
  <thead>
    <tr>
      <th>Voicing</th>
      <th>Notes</th>
      <th>Candidates</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>C major triad</td>
      <td class="mono">3</td>
      <td class="mono">25</td>
    </tr>
    <tr>
      <td>Cmaj7</td>
      <td class="mono">4</td>
      <td class="mono">43</td>
    </tr>
    <tr>
      <td>Cm7</td>
      <td class="mono">4</td>
      <td class="mono">46</td>
    </tr>
    <tr>
      <td>C7</td>
      <td class="mono">4</td>
      <td class="mono">48</td>
    </tr>
    <tr>
      <td>Cmaj9</td>
      <td class="mono">5</td>
      <td class="mono">67</td>
    </tr>
    <tr>
      <td>Six-note voicing</td>
      <td class="mono">6</td>
      <td class="mono">90</td>
    </tr>
    <tr>
      <td>Seven-note dense</td>
      <td class="mono">7</td>
      <td class="mono">131</td>
    </tr>
  </tbody>
</table>

Even a plain three-note triad produces 25 candidates. We keep a test set of
deliberately adversarial, ambiguous voicings (an "oracle corpus," so called
because each case has a known-correct answer to check against), and there the
count runs a median of about 75 candidates and a maximum of 143. Building the
pairwise matrix for 75 candidates means over 5,000 calls to the comparator, a
function the code calls `_decide`. Each call historically scanned all 21 hard
rules before settling anything. Because the matrix pits every candidate against
every other, the work grows with the _square_ of the candidate count: it is
[O(n²)](https://en.wikipedia.org/wiki/Big_O_notation). That is where the time
went.

The goal was to cut that cost without changing the output. The benchmark kept us
honest by recording exact operation counts, such as how many candidates were
built and how many comparisons were run. Those integers depend only on the input
and the code, never on the hardware, so an accidental algorithm change would
show up as a changed count instead of hiding inside noisy timings.

## Win #1: gate the hard-rule scan

The first observation is that almost none of the 21 hard rules can possibly
apply to a given pair. Each rule fires only for a specific structural pairing
(an altered-fifth dominant against a remote spelling, a complete triad against a
deficient inverted reading, and so on), and crucially that condition is
**candidate-local**: it depends only on a single candidate's quality,
extensions, or precomputed features, never on the candidate it is being compared
against.

So each rule gets a _gate_: a quick test on a single candidate that is
guaranteed to say "yes" whenever the rule could possibly apply. Once per
candidate, we precompute a
[bitmask](<https://en.wikipedia.org/wiki/Mask_(computing)>), an integer whose
bits flag which rules that candidate is eligible for. For a pair, the bitwise
AND of their two masks is exactly the set of rules both are eligible for, and we
check only those.

<pre><code><span class="cm">// Precompute once per candidate: O(n * rules), not O(n^2).</span>
<span class="kw">final</span> gateMasks = [<span class="kw">for</span> (<span class="kw">final</span> c <span class="kw">in</span> cands) <span class="fn">gateMaskFor</span>(c)];

<span class="cm">// A rule needs one operand in each role, so it can only fire when</span>
<span class="cm">// both candidates pass its gate. Skipped rules would return null.</span>
<span class="kw">final</span> shared = gateMasks[i] &amp; gateMasks[j];
<span class="kw">for</span> (<span class="kw">final</span> rule <span class="kw">in</span> <span class="fn">rulesIn</span>(shared)) { ... }</code></pre>

A skipped rule would have returned null anyway, so this is **provably
output-identical**, not just empirically validated. Candidate generation and
scoring are untouched, the generation counters stay byte-identical, and the
ranking golden plus the cycle and hard-rule unit tests pass unchanged. A
too-narrow gate would silently drop a real decision, so those test suites are
the safety net.

Result: timing for uncached analysis of the adversarial corpus dropped about
**27%**, and everyday voicings sped up 1.2 to 1.7x. This is a constant-factor
win: the same pairwise work, done faster. The algorithm is still O(n²).

## What didn't work, part 1: splitting the gate by role

That single combined gate is broad for rules whose "other" side is common, like
"any slash chord" or "any seventh chord." One refinement is to split each gate
into two halves, a role A and a role B, and fire a rule for a pair only when the
two candidates fill opposite roles:
`(maskA[i] & maskB[j]) | (maskB[i] & maskA[j])`.

We implemented it across all 21 rules. It stayed output-identical, with
unchanged counters and passing tests. It delivered 1 to 3% on typical voicings
and roughly 0% on the dense corpus, inside benchmark noise. We reverted it.

The combined gate had already captured the big win: skipping pairs where
_neither_ candidate is eligible. Splitting roles only trims pairs where both
candidates are eligible in the same role, a thin slice, and the second mask
doubles the precompute. After the combined gate, the bottleneck is no longer the
hard-rule scan. It is the O(n²) machinery itself: the pairwise matrix and the
linearizing.

## Why candidate reduction broke ranking

If 25 candidates for a triad feels wasteful, the direct move is to generate or
keep fewer of them. Shrinking the candidate set attacks the n² term directly.
Unfortunately, it is unsafe because the Copeland count is global.

- **Keeping the top N by score** throws away lower-scoring candidates before the
  ranking runs. But the tie-break is a global Copeland count, so removing
  candidates changes everyone else's win total. That can reshuffle the
  alternatives the app shows the user. This holds for any N and any cutoff; the
  problem is that the dropped candidates were part of what the survivors were
  measured against.
- **Dropping candidates earlier, at generation time,** has the identical
  problem. You might restrict which roots or chord templates are allowed to
  produce candidates, but any candidate removed before ranking is gone from
  everyone's win total just the same.
- The only drop that is provably safe is a
  [Condorcet loser](https://en.wikipedia.org/wiki/Condorcet_loser_criterion): a
  candidate that loses to every other and beats none, with no hard-rule win to
  its name. But finding one requires the full pairwise comparison we were trying
  to avoid in the first place.

So candidate reduction looked like a dead end. We set it aside and tried to
compute the same full ranking faster.

## What didn't work, part 2: the sorted-rank redesign

The next redesign kept the exact same output and tried to compute it faster.
Start from a cheap first guess at the order: sort by score, breaking ties by
root note. Call that the _seed order_. The expensive comparator agrees with this
cheap seed order on almost every pair. It can only disagree in two situations:

- a hard rule fired, which can only happen between two candidates the gate masks
  already flag as eligible; or
- a tie-breaker overruled the score, which can only happen between two
  candidates scoring within 0.20 of each other.

Every other pair already matches the seed order by construction. The theory was
that simple voicings, the common live-play case, would take a fast exit: check
for out-of-order pairs only in the two places one can hide, and if there are
none, return the seed order untouched, skipping the whole n² matrix. If any turn
up, fall back to the full linearizer.

Before building it, we profiled to confirm the redesign even targets the right
cost. Temporary phase timers inside ranking, over the oracle corpus:

<table class="article-table">
  <thead>
    <tr>
      <th>Phase</th>
      <th>Share of ranking</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Pairwise matrix build</td>
      <td class="mono">97.0%</td>
    </tr>
    <tr>
      <td>Linearize</td>
      <td class="mono">2.1%</td>
    </tr>
    <tr>
      <td>Features</td>
      <td class="mono">0.4%</td>
    </tr>
    <tr>
      <td>Gate-masks</td>
      <td class="mono">0.4%</td>
    </tr>
    <tr>
      <td>Seed-sort</td>
      <td class="mono">0.1%</td>
    </tr>
  </tbody>
</table>

Building the matrix is 97% of ranking, and within that the n² loop of `_decide`
calls is 99.8% (allocating the matrix itself is 0.2%). Fewer comparisons were
the right target.

We built it with a safety harness that runs both the fast path and the full
algorithm during tests and asserts they produce the same order (the check is
compiled out of release builds). It was correct. It also **never triggered.**

The fast path fired on **zero of every voicing we measured, including a plain C
major triad.** Every measured voicing has at least one near-tie pair somewhere
down its long candidate list that a tie-breaker flips, and a single out-of-order
pair forces the full fallback. The detection pass added work without finding a
usable fast path, for a net loss of about 1%.

We then tried to re-rank only the _entangled_ candidates rather than all n, the
ones linked by a near-tie or a shared hard rule. To find out how big those
tangles get, we grouped candidates into connected clusters with a
[union-find](https://en.wikipedia.org/wiki/Disjoint-set_data_structure). The
table below shows how much of each candidate set was in the largest connected
cluster. A value near 100% means the localized fallback would still have to
re-rank almost everything:

<table class="article-table">
  <thead>
    <tr>
      <th>Input set</th>
      <th>Candidates</th>
      <th>Largest cluster share</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Oracle corpus</td>
      <td class="mono">75 median / 143 max</td>
      <td class="mono">99% median / 100% max</td>
    </tr>
    <tr>
      <td>C major triad</td>
      <td class="mono">25</td>
      <td class="mono">100%</td>
    </tr>
    <tr>
      <td>Cm7 / C7</td>
      <td class="mono">46 / 48</td>
      <td class="mono">100% / 100%</td>
    </tr>
    <tr>
      <td>Cmaj9 / Cm11</td>
      <td class="mono">67 / 90</td>
      <td class="mono">99% / 100%</td>
    </tr>
  </tbody>
</table>

The biggest tangle is essentially the whole candidate set. Scores are packed
closely enough that the within-0.20 near-tie links chain through almost
everything, so re-ranking just the tangle means re-ranking nearly everything
anyway. There is nothing small to isolate.

## Win #2: make each comparison cheaper

Since n² is intrinsic (candidates cannot be safely dropped, the relation has no
locality), the only lever left is the cost of a single `_decide` call. Measuring
where pairs go, over a corpus pass:

<table class="article-table">
  <thead>
    <tr>
      <th>Pairs</th>
      <th>Share</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Skippable (score alone decides)</td>
      <td class="mono">20%</td>
    </tr>
    <tr>
      <td>Call <code>_decide</code></td>
      <td class="mono">80%</td>
    </tr>
    <tr>
      <td>…of which reach a tie-break</td>
      <td class="mono">5% of all pairs</td>
    </tr>
  </tbody>
</table>

The tie-break scan is not the cost; only 5% of pairs reach it. The bulk is the
roughly 75% of pairs that are hard-rule-eligible but beyond the tie window: they
call `_decide`, run the gated hard-rule loop, and then decide on score anyway.
That loop still iterated all 21 rules checking the mask bit even when one or two
bits were set, about 18 million wasted iterations per corpus pass. Two
output-identical fast paths address that:

- **Score short-circuit:** in the pairwise matrix loop, when the shared gate
  mask is empty (no hard rule can fire) and the score gap exceeds
  `nearTieWindow`, set the result straight from score and skip `_decide`
  entirely, along with its allocation.
- **Set-bit iteration:** inside `_decide`, walk only the set bits of the shared
  mask, lowest first to preserve rule order, instead of scanning all 21 rules.

Both are provably identical to the old output, carry none of the Copeland
reshuffle risk, and together bought about **4%** on the adversarial corpus. One
guess turned out wrong along the way: we expected these comparisons to churn
through a lot of short-lived memory. But after the short-circuit removed about
20% of the per-comparison allocations, total allocation barely moved, so a
fancier allocation-free version was not worth building.

That was the end of the safe per-pair wins. The gate-mask index and the per-pair
fast paths are bankable and provably identical, but the residual is the n²
iteration over densely-scored candidates. Under the constraint we were holding,
there was no lever left. Together, the safe optimizations delivered roughly a
30% improvement.

## The reframe: we were answering the wrong question

Every conclusion above, the dead-end pruning and the intrinsic n², is correct
under one assumption: **byte-identical output.** We had been protecting the
exact order of every candidate. That was stronger than what the app needs.

The user-facing contract has exactly two guarantees:

1. the chosen #1 chord is preserved;
2. the set of surfaced alternatives is preserved.

The _order_ of alternatives #2 and beyond is not a guarantee. Near-tie
alternatives are often
[enharmonic](https://en.wikipedia.org/wiki/Enharmonic_equivalence) respellings
of one sound, the same notes written different ways, and their relative order
was already being settled by an arbitrary fallback (sort by root note). So the
Copeland reshuffle that the dead-end argument treats as disqualifying only ever
moves output that was never pinned down in the first place. The earlier
reasoning answered "can we prune with byte-for-byte identical output?" (no). The
product question is "can we prune without breaking the promise to the user?"
(yes).

<div class="callout">
  <p>
    Pruning never changes a head-to-head comparison between two
    surviving candidates. It only changes the global Copeland count
    used when the linearizer has to break a cycle. That count is
    partly an artifact: a candidate’s total is padded by every
    obviously wrong reading it happens to beat, which says little
    about how it compares with another plausible reading. Dropping the
    unsurfaceable tail removes that padding. The result is not a more
    correct order, since the Copeland count was never a measure of
    musical quality. It is a <em>less arbitrary</em> fallback, no
    longer swayed by how many discarded readings each candidate
    happened to beat.
  </p>
</div>

## Choosing the prune margin

The prune keeps every candidate scoring within a fixed margin of the top score
(`rankingPruneMargin`) and drops the rest before ranking. The catch is that this
margin is a **correctness threshold, not a tuning knob**. If it is ever smaller
than the gap at which a candidate could still have been shown to the user, the
prune deletes something the user was supposed to see. That makes it a worst-case
bound, so it would be a mistake to set it from an average or a
[standard deviation](https://en.wikipedia.org/wiki/Standard_deviation): a
typical-case band would be most likely to fail on the rare cases the margin is
supposed to protect.

How far below the top score can a still-shown candidate sit? Call that the
_surfaced gap_. Our first estimate was simple and wrong: hard-rule reach plus
the 0.20 near-tie window, about 1.8. But the engine surfaces every candidate
down to the lowest-ranked near-tie one, and the linearizer is not strictly
ordered by score, so a deeper reading can be lifted into the shown band. The
measured surfaced gap is the binding number, not the reach.

The three columns below separate the pieces: _reach_ is how far below the top
score a hard rule can promote a winner, the _alternatives band_ is how far down
the ranked list the surfaced set extends, and the _surfaced gap_ is the largest
score gap for any shown candidate. We measured all three on the engine with
pruning turned off:

<table class="article-table">
  <thead>
    <tr>
      <th>Corpus</th>
      <th>Reach</th>
      <th>Alternatives band</th>
      <th>Surfaced gap</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Oracle (real)</td>
      <td class="mono">1.283</td>
      <td class="mono">1.443</td>
      <td class="mono">1.599</td>
    </tr>
    <tr>
      <td>Common (real)</td>
      <td class="mono">1.429</td>
      <td class="mono">1.443</td>
      <td class="mono">1.599</td>
    </tr>
    <tr>
      <td>Dense 7–12 (adverse)</td>
      <td class="mono">0.484</td>
      <td class="mono">2.858</td>
      <td class="mono">2.858</td>
    </tr>
  </tbody>
</table>

We expected dense 8-plus-note voicings, lacking any clean template fit, to
compress scores and keep the margin safe. The reach half of that is right: it
collapses from 1.28 to 0.48 as scores compress. But reach is not the binding
term. The alternative band moves the opposite way, because more candidates and
more hard-rule cycles let the linearization pull deeper readings upward, so the
surfaced gap _grows_ to 2.858 on dense clusters.

A multi-seed adversarial sweep (5,000+ dense voicings, sizes 7 to 12) held the
ceiling at 2.858 (an 8-note cluster), with only four voicings above 2.5.
Performance was essentially flat across margins: the oracle corpus kept about 10
candidates at margin 2.0, 15 at 3.0, and 20 at 4.0, all a greater-than-94%
reduction in n² pairs against the roughly 86-candidate baseline. Speed did not
pick the number; correctness did. We took **3.0**: it clears the 2.858
adversarial ceiling, keeps every surfaced reading on all three corpora, and
changes nothing a musician sees.

## Checking the golden failures

Pruning did break three of our _golden tests_, the cases where we pin exact
expected output. Before relying on "order is not a contract," we checked that
those three changes were arbitrary rather than musically meaningful,
cross-checking against outside references the way we do for naming questions.

Each broken case had the same shape: the #1 pick was unchanged, and the shuffle
was between alternatives at _identical_ scores that
[spell the same sound two different ways](why-chord-naming-is-hard.html#enharmonic-spelling)
(for example <span class="chord">A♭7♯5♯11</span> versus
<span class="chord">G♯7♭5♭13</span>), separated only by the root-note fallback.
There is no musically correct order between them, so pinning one was
over-specification. We loosened the goldens at the source rather than case by
case: the expected alternatives assertion became an unordered containment check,
so every expected alternative must still surface, but its order is free.

## Locking it in

The bound is empirical, so we wrote two guards to keep the margin honest:

- A `candidatesRanked` counter makes the prune a deterministic benchmark signal.
  Generation is unchanged because the prune runs after it; without this counter,
  the largest algorithmic change we have made would show up only in noisy time.
  It falls from 11,983 to 2,120 on the oracle corpus.
- A guard test raises the margin to infinity to recover the unpruned ranking,
  measures the surfaced gap across the oracle corpus and a dense sweep, and
  fails if it ever reaches the production margin. A future scoring or ranking
  change that widens the gap past 3.0 then fails CI instead of quietly dropping
  an alternative.

## Result

The #1 pick and the surfaced alternatives set stayed unchanged across both real
corpora. Only 6 oracle cases and 7 common cases reordered alternatives #2 and
beyond, the explicitly non-contract part. Uncached ranking time dropped
**86.7%** on the oracle corpus and **91.7%** on the common pool; the memory the
analysis holds onto fell about 3.5%.

This does not reduce the O(n²) complexity. A dense voicing with no clear winner
still ranks a full set, because the prune cannot drop candidates near the top
score. It removes the long tail of unsurfaceable readings that common and
adversarial cases were paying full ranking cost to order.

## The takeaway

The most expensive constraint in this work was one we imposed on ourselves and
never stated: byte-identical output. Under that constraint, the safe
optimizations were constant-factor only. The tenfold win did not come from a
more clever algorithm. It came from comparing the constraint to what the product
promises.

The gate masks and per-pair fast paths are still in the engine, still provably
identical, and still earning their roughly 30% on top. But the headline number
came from removing a guarantee the app did not actually need.

<div class="article-cta">
  <h3>See the speed for yourself.</h3>
  <p>
    WhatChord identifies chords in real time, on-device. Free for iOS
    and Android, with no subscription and no ads.
  </p>
  <div class="store-badges store-badges-spaced">
    <a
      href="https://apps.apple.com/us/app/whatchord-midi/id6758409779"
    >
      <img
        class="store-badge"
        src="../images/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg"
        alt="Download on the App Store"
      />
    </a>
    <a
      href="https://play.google.com/store/apps/details?id=com.earthmanmuons.whatchord"
    >
      <img
        class="store-badge"
        src="../images/GetItOnGooglePlay_Badge_Web_color_English.svg"
        alt="Get it on Google Play"
      />
    </a>
  </div>
  <a
    class="btn btn-ghost"
    href="https://github.com/EarthmanMuons/whatchord"
    ><svg
      class="github-icon"
      viewBox="0 0 16 16"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        d="M6.766 11.328c-2.063-.25-3.516-1.734-3.516-3.656 0-.781.281-1.625.75-2.188-.203-.515-.172-1.609.063-2.062.625-.078 1.468.25 1.968.703.594-.187 1.219-.281 1.985-.281.765 0 1.39.094 1.953.265.484-.437 1.344-.765 1.969-.687.218.422.25 1.515.046 2.047.5.593.766 1.39.766 2.203 0 1.922-1.453 3.375-3.547 3.64.531.344.89 1.094.89 1.954v1.625c0 .468.391.734.86.547C13.781 14.359 16 11.53 16 8.03 16 3.61 12.406 0 7.984 0 3.563 0 0 3.61 0 8.031a7.88 7.88 0 0 0 5.172 7.422c.422.156.828-.125.828-.547v-1.25c-.219.094-.5.156-.75.156-1.031 0-1.64-.562-2.078-1.609-.172-.422-.36-.672-.719-.719-.187-.015-.25-.093-.25-.187 0-.188.313-.328.625-.328.453 0 .844.281 1.25.86.313.452.64.655 1.031.655s.641-.14 1-.5c.266-.265.47-.5.657-.656"
      /></svg
    ><span>View source on GitHub</span></a
  >
  <p class="cta-secondary">
    Prefer not to install?
    <a href="/try">Try identifying chords in your browser →</a>
  </p>
</div>

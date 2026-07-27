---
cardDescription:
  "Reference-normalized time, deterministic operation counters, and a calibrated
  noise model: how we measured engine changes reproducibly on shared CI runners."
cardTitle: "Benchmarking on Hardware You Don’t Control"
decks:
  - "You cannot optimize what you cannot measure. And a hot code path is hard to
    measure on the shared cloud machines that run your tests, where you control
    neither the hardware nor what else is running on it. These are the
    techniques that keep WhatChord’s benchmark numbers comparable from one
    machine to the next, down to changes too small to see in raw wall-clock
    time."
description:
  "How to benchmark hot code reproducibly on shared cloud machines you don’t
  control: normalize time to a fixed reference workload, lean on exact operation
  counts, and model the run-to-run noise."
group: "technical"
image: "/images/homepage_social.jpg"
imageAlt: "WhatChord: Identify chords. Understand harmony."
indexOrder: 6
pageTitle: "Benchmarking on Hardware You Don’t Control | WhatChord"
related:
  - "chord-ranking-performance"
  - "chord-recognition-algorithm"
  - "million-chord-annotations"
socialDescription:
  "Wall-clock time isn’t comparable across machines. A toolkit for trustworthy
  benchmarks anyway: deterministic operation counters, a reference-workload
  ratio, adaptive sampling, and a calibrated noise model."
socialTitle: "Benchmarking on Hardware You Don’t Control"
tag: "Technical deep-dive"
title: "Benchmarking on Hardware You Don’t Control"
---

<h2>Why wall-clock time lies</h2>

<p>
  WhatChord names the chord you are playing, in real time, from the
  notes arriving over a MIDI connection. The part that does the
  naming,
  <a href="chord-recognition-algorithm.html">the analysis engine</a>,
  runs on every change to the keys you are holding, so it sits on a
  <em>hot path</em>: code that runs constantly and has to stay fast.
  When we set out to make it faster, we hit a problem before changing
  a line. We could not trust our own measurements.
</p>

<p>
  The problem fits in one number. Some of the
  <a href="chord-ranking-performance.html">ranking optimizations</a>
  were worth about 4%. On a hot path that is worth shipping, but it is
  smaller than the run-to-run variation an ordinary laptop shows when
  a background task wakes up mid-benchmark, and far smaller than the
  gap between two CI runners of different vintages. Wall-clock time is
  hardware-dependent and noisy, and a benchmark that reports raw
  milliseconds cannot tell an improvement from a runner that was less
  busy that minute.
</p>

<p>
  The clean fix is to control the hardware: a dedicated benchmark
  machine with its CPU frequency locked and nothing else running.
  Tools like
  <a href="https://valgrind.org/docs/manual/cg-manual.html"
    >Cachegrind</a
  >
  and <a href="https://github.com/andrewrk/poop">poop</a> sidestep
  timing altogether by counting instructions instead, simulated in one
  case and read from hardware performance counters in the other. Both
  are worth using when you can. We could not justify dedicated
  hardware for one app’s benchmark, and we wanted numbers that a
  contributor’s laptop and a rented CI runner could both reproduce, so
  we went the other way: make the numbers themselves far less
  hardware-dependent.
</p>

<p>
  What follows is the toolkit we landed on: exact operation counts
  wherever possible, and for the time you still have to measure, a
  reference-workload ratio, adaptive sampling, a calibrated noise
  model, and a regression gate that separates statistical significance
  from practical significance. Our harness lives in
  <a
    href="https://github.com/EarthmanMuons/whatchord/tree/main/benchmark"
    ><code>benchmark/</code></a
  >
  and replays fixed inputs through
  <code>ChordAnalyzer.analyze</code>, but nothing below is specific to
  chords. It does assume a workload like ours, though: CPU-bound,
  deterministic, and in-process. The counters transfer anywhere, but
  reference-workload normalization has little to offer when the
  bottleneck is I/O, the network, or a user interface rather than the
  CPU the reference measures.
</p>

<h2>Count operations before you time anything</h2>

<p>
  Timing, however carefully sampled, is fundamentally analog. The most
  valuable measurements in the harness are the ones that are not timed
  at all: deterministic counters of the work the algorithm does.
</p>

<p>
  The recipe is to give each stage of your pipeline a counter for its
  unit of work. Ours count cache hits and misses, roots considered,
  templates evaluated, candidates produced, and candidates ranked;
  yours might count nodes visited, rows scanned, or bytes hashed.
  These are integers that depend only on the input and the code, never
  on the hardware. On a fixed corpus, any change to a counter is a
  real algorithmic change, full stop, with zero noise to argue about.
</p>

<p>
  Counters also move before milliseconds do. A scan that quietly stops
  being incremental, a cache that stops hitting, a prune that drops
  too much: each shows up as an exact changed integer long before it
  surfaces as a bump in a noisy time series. That makes them a
  semantic regression check as much as a performance metric, catching
  the unintended algorithm change that timing would have absorbed into
  its error bars.
</p>

<p>
  They can cost nothing in production. Ours sit behind a compile-time
  flag and are stripped out entirely by the compiler in normal builds.
  Most compiled languages have an equivalent switch, whether a
  <code>const</code> in Dart, a <code>cfg</code> attribute in Rust, or
  the preprocessor in C.
</p>

<div class="callout">
  <p>
    An example from our engine, which first generates candidate chord
    names for the notes being played and then ranks them, with ranking
    dominating the cost. When we later
    <a href="chord-ranking-performance.html"
      >pruned low-scoring candidates before ranking</a
    >, two counters on a fixed corpus told the story:
    <code>candidatesRanked</code> fell from 11,983 to 2,120 while
    <code>candidatesProduced</code> held exactly still, corroborating
    that generation did the same amount of work. Golden tests, cases
    with pinned expected output, proved the results themselves had not
    changed. The largest performance change we have shipped is
    recorded as exact, hardware-independent integers.
  </p>
</div>

<h2>Normalize time to a reference workload</h2>

<p>
  What counters cannot see is a constant-factor win: the same
  operations, executed faster. For that you still need time, and the
  key move is to stop reporting time and start reporting a
  <em>ratio</em>. Alongside the code under test, the harness times a
  fixed reference workload on the same machine, in the same run, and
  divides:
</p>

<pre><code><span class="cm">// Both are timed on the same machine, in the same process.</span>
<span class="kw">final</span> normalized = engineTime / referenceTime;</code></pre>

<p>
  A slower machine inflates both the numerator and the denominator, so
  the ratio holds roughly constant. The result is dimensionless: “the
  engine took this many reference-workloads of time.” That number is
  comparable across machines in a way milliseconds never are, which is
  what lets a baseline recorded on one machine judge a run on another,
  at least between machines of the same broad class.
</p>

<p>
  The reference should burn the same resource your hot path burns.
  Ours is a fixed amount of integer arithmetic that allocates no
  memory, chosen because the engine is compute-bound: the reference
  tracks raw CPU speed without dragging in the
  <a
    href="https://en.wikipedia.org/wiki/Garbage_collection_(computer_science)"
    >garbage collector</a
  >
  or memory bandwidth. If your hot path is memory-bound, an integer
  loop is the wrong yardstick, and the reference should stream memory
  the same way your code does.
</p>

<p>
  Be clear-eyed about what the ratio cancels. It removes hardware
  differences only to the degree that the code under test responds to
  hardware the same way the reference does, and a real engine also
  touches allocation, branch prediction, and cache, so two machines
  with a different balance of memory speed to compute speed will
  disagree a little even on the ratio. In practice the ratio absorbs
  the first-order difference between machines, raw CPU speed, and
  leaves a much smaller residual. The counters catch what the ratio
  misses on the algorithmic side, and the noise model below keeps the
  residual from raising false alarms.
</p>

<h2>Decide what the benchmark exercises</h2>

<p>
  If the code under test has a cache, the cache-hit rate of your input
  set silently becomes a parameter of the benchmark. Split the paths
  and report them separately:
</p>

<ul>
  <li>
    <strong>Cold:</strong> every call a cache miss, the full pipeline
    every time. The worst case and the most sensitive regression
    signal.
  </li>
  <li>
    <strong>Warm:</strong> every call a hit, served from the engine’s
    LRU cache of recent results. It stays near zero at any scale and
    serves only as a “the cache is working” sanity line, not a tuning
    target.
  </li>
</ul>

<p>
  The input sets deserve the same scrutiny, because “is it faster?”
  and “is it faster on the cases that matter?” are different
  questions. We replay two corpora: an
  <strong>oracle corpus</strong> of hand-reviewed, deliberately nasty
  voicings borrowed from our correctness test suite, and a
  <strong>common voicing pool</strong> of everyday chord types across
  their inversions, approximating real playing. The benchmark replays
  only the voicings; their known-correct answers stay with the tests,
  which own correctness. The standing rule is to never judge a change
  by the stress corpus alone. A slowdown that only shows up on 12-note
  chromatic clusters is worth knowing about, but it should not be
  confused with one that touches a <span class="chord">Cmaj7</span>.
</p>

<h2>Memory, in three numbers</h2>

<p>
  A single “memory used” figure misleads, because raw byte counts move
  for reasons unrelated to the code under test: runtime overhead,
  allocator and garbage-collection timing, the measurement channel
  itself. In any garbage-collected runtime, three numbers with
  distinct meanings work better than one total:
</p>

<ul>
  <li>
    <strong>churn:</strong> total memory allocated during the run,
    counting objects created and then immediately thrown away. This is
    what makes work for the garbage collector, and the number that
    matters most while the code under test is mostly stateless.
  </li>
  <li>
    <strong>retained:</strong> how much the live heap grew from before
    the run to after it, measured after forcing a garbage collection
    so only genuinely-kept memory counts. This approximates what the
    run held onto; for us, mostly the analyzer’s cache.
  </li>
  <li>
    <strong>live heap:</strong> the total memory in use by the whole
    process. A useful check on overall footprint, but it includes
    runtime and benchmark state, not just the code under test.
  </li>
</ul>

<p>
  Every managed runtime exposes the raw material for these. We read
  them through the Dart VM’s service protocol; the JVM, V8, and Go all
  have equivalent channels.
</p>

<h2>Sampling until the number stops moving</h2>

<p>
  A single timing is meaningless, and the usual reflex, running the
  benchmark some round number of times and averaging, is only half a
  fix: the right sample count depends on variance you cannot know in
  advance, and an average alone says nothing about how trustworthy it
  is.
</p>

<p>
  So our harness samples adaptively, in the spirit of benchmarking
  tools like
  <a href="https://github.com/sharkdp/hyperfine">hyperfine</a> and
  <a href="https://github.com/criterion-rs/criterion.rs">Criterion</a
  >. After a few warmup runs to let the just-in-time compiler finish
  optimizing the hot code, it keeps sampling until the 95%
  <a href="https://en.wikipedia.org/wiki/Confidence_interval"
    >confidence interval</a
  >
  on the mean (a normal approximation) is within 1.5% of the mean,
  bounded by a run cap and a time budget so the expensive cold pass
  still finishes. The 1.5% is a stopping ceiling, not the precision
  you get; on a quiet machine the sampler settles well below it.
</p>

<p>
  Each measurement reports mean, median, standard deviation, min and
  max, the sample count, the confidence interval it reached, and
  whether it settled or hit a limit. Operations too fast for the
  clock, like the sub-microsecond warm pass, are timed in batches of
  many calls per clock read, or they vanish beneath the timer’s
  resolution. And the published number is the normalized score, a
  ratio of two sampled quantities, so both halves contribute
  uncertainty. The two combine <em>in quadrature</em>, as the square
  root of the sum of their squares, which is the standard statistical
  way to merge two independent sources of error.
</p>

<h2>Calibrating the noise you can’t sample away</h2>

<p>
  Separate invocations of the same benchmark on the same machine drift
  more than the in-process confidence interval suggests, due to
  runtime memory layout, thermal state, CPU scheduling, and whatever
  else the host is doing. A check that trusted only the in-process
  interval would flag a regression on any slightly warmer run.
</p>

<p>
  The fix is to measure that drift directly. The harness’s calibration
  mode launches the full benchmark repeatedly as separate
  subprocesses, compares each run to the baseline, and builds a
  per-metric noise estimate from the spread of the relative deltas. It
  runs at least 10 subprocesses, continuing until every metric’s
  estimate changes by less than 10% from the previous iteration,
  capped at 50 runs. Robust statistics matter here, because the
  occasional extreme run is exactly what a busy host produces:
</p>

<pre><code>noiseRel95   = <span class="nu">1.96</span> * <span class="nu">1.4826</span> * <span class="fn">medianAbsoluteDeviation</span>(relativeDeltas)

combined     = <span class="fn">sqrt</span>(baselineCI² + currentCI² + noiseRel95²)</code></pre>

<p>
  Unpacking the first line: the <code>1.96</code> is the standard 95%
  factor for a normal distribution, and the
  <a href="https://en.wikipedia.org/wiki/Median_absolute_deviation"
    >median absolute deviation</a
  >
  (MAD) is a measure of spread that, unlike the standard deviation, is
  barely affected by the occasional extreme run; the
  <code>1.4826</code> rescales the MAD so it lines up with a standard
  deviation on normally-distributed data. Like the per-run confidence
  interval, this is a model-based tolerance rather than measured
  coverage: it assumes roughly normal noise and deliberately deweights
  rare extreme runs, so treat the 95% as a design target, not a
  promise. The second line, the calibrated noise combined with both
  runs’ sampling confidence intervals in quadrature, is the
  uncertainty window that regression checks measure against.
</p>

<p>
  One rule keeps the model honest: a noise model describes only the
  class of machine it was calibrated on. A model built on a laptop
  says nothing about the variance of a hosted CI runner, whose shared
  tenancy and throttling are a noise profile of their own. Calibrate
  on the machine class that will run your regression checks, and
  recalibrate when that changes.
</p>

<h2>Gate on two thresholds, not one</h2>

<p>
  A baseline is only useful if something checks against it. The
  harness records a baseline file in the repository, holding the
  normalized scores, counters, and memory numbers, and compares every
  later run against it, failing loudly when a metric regresses. That
  comparison is the gate, and the design point worth stealing is that
  it separates statistical significance from practical significance. A
  change can be statistically real and still too small to care about;
  it can look large and still sit inside the noise. A run fails only
  when both tests trip:
</p>

<ul>
  <li>
    <strong>Time</strong> fails when it is slower than the baseline by
    at least 5% <em>and</em> falls outside the combined uncertainty
    window.
  </li>
  <li>
    <strong>Memory</strong> fails when it grows by at least 3%, clears
    a small absolute floor, and exceeds the calibrated noise when a
    model is available.
  </li>
  <li>
    <strong>Counters</strong> fail on any deterministic increase,
    because there is no noise to forgive.
  </li>
</ul>

<p>
  The practical thresholds are a product decision, not a statistical
  one: pick the smallest regression you would actually act on. The
  statistical window comes from the machinery above, and exists only
  to keep the gate from crying wolf. And trust the gate only on a
  machine class you have calibrated; anywhere else, treat the numbers
  as advisory.
</p>

<h2>Measuring the measuring tool</h2>

<p>
  One last trap: the benchmark measuring itself. A clock has finite
  resolution, and a timed quantity becomes unreliable as it shrinks
  toward that floor. So when normalized scores land at awkward
  magnitudes and you go looking for nicer numbers, keep measurement
  stability and display magnitude as separate decisions, and never buy
  readability by shrinking your yardstick into the timer’s resolution.
</p>

<p>
  We hit the trap after a big optimization landed. The normalized
  scores shrank so far, to around 0.099 on one corpus and 0.020 on the
  other, that they were awkward to read and compare at a glance. A
  normalized score is a dimensionless ratio, so its magnitude is
  arbitrary and free to rescale; the question was how. There are two
  levers: the
  <strong>reference workload size</strong>, which sets measurement
  stability, and a <strong>display multiplier</strong>, which sets the
  printed magnitude. The tempting shortcut is to use only the workload
  size, shrinking it until the ratio lands where you want.
</p>

<p>
  That fails because of timer resolution. The harness reads the clock
  in whole microseconds, so any single timing is rounded to the
  nearest microsecond (its
  <em>quantization</em>). To push the larger score up near 100 for
  readability by shrinking the workload alone, the reference would
  have to run in about 8 microseconds, which is only about 8 of those
  rounding steps wide. The reference would become the dominant source
  of noise, defeating its whole purpose as the stable yardstick.
</p>

<p>
  So we measured reliability against workload size directly, 400
  samples at each size, to find how small the workload can get before
  resolution and jitter start to dominate:
</p>

<table class="score-table">
  <thead>
    <tr>
      <th>Iterations</th>
      <th>Mean</th>
      <th>Per-sample rel. SD</th>
      <th>1 µs quant. floor</th>
      <th>CI95 (n=400)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="mono">100k</td>
      <td class="mono">202 µs</td>
      <td class="mono">2.67%</td>
      <td class="mono">0.495%</td>
      <td class="mono">0.26%</td>
    </tr>
    <tr>
      <td class="mono">400k</td>
      <td class="mono">806 µs</td>
      <td class="mono">1.49%</td>
      <td class="mono">0.124%</td>
      <td class="mono">0.15%</td>
    </tr>
    <tr>
      <td class="mono">1M</td>
      <td class="mono">2023 µs</td>
      <td class="mono">1.46%</td>
      <td class="mono">0.049%</td>
      <td class="mono">0.13%</td>
    </tr>
    <tr>
      <td class="mono">4M</td>
      <td class="mono">8125 µs</td>
      <td class="mono">1.30%</td>
      <td class="mono">0.012%</td>
      <td class="mono">0.13%</td>
    </tr>
  </tbody>
</table>

<p>
  Two things fall out. First, the binding noise is OS scheduling
  jitter, not timer resolution: the per-sample spread stays
  essentially flat as the workload shrinks from 4M down to 400k
  iterations, while the quantization floor stays two orders of
  magnitude below it. Only when a single sample drops under a couple
  hundred microseconds do resolution and jitter start to bite.
</p>

<p>
  Second, that makes
  <strong
    >400k iterations (about 0.8 ms) the smallest workload that stays
    reliable.</strong
  >
  At that size our larger score sits near 1.0, which makes the display
  multiplier a clean <strong>×100</strong>: the scores land as
  readable two-to-three-digit integers, with downward headroom as the
  code keeps getting faster. The rescale is purely cosmetic. A uniform
  factor leaves every relative delta, every confidence interval, and
  every regression decision exactly where it was.
</p>

<h2>What it buys</h2>

<p>
  The payoff is that performance changes get settled with numbers
  instead of guesswork. The counters catch algorithmic changes with
  zero noise. The reference-normalized, adaptively sampled time
  catches changes large enough to matter, and the noise model keeps
  the gate from firing on the ones that don’t. A baseline file in the
  repo means a change from a year ago and a change from today are
  measured on nearly the same footing, even on different hardware.
</p>

<p>
  For us, that is what made the ranking optimization work legible: a
  4% per-pair win and an 87% pruning win were both visible and both
  trustworthy, and the dead ends were provably dead because the
  counters said the work had not budged and the golden tests said the
  output had not either. None of it needed hardware we control, which
  was the point.
</p>

<div class="article-cta">
  <h3>See the engine behind the numbers.</h3>
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

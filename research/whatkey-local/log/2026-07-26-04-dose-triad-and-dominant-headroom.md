# 2026-07-26: Dose 4 guard-tested, triad trigger inert, dominant headroom mapped

**Goal.** Close three threads from entries -02/-03: guard-test cadenceBoost 4
(entry -02 chose 3 over 5 without measuring 4 on the guards), measure the
predominant-gated plain-triad cadence trigger (the bass-motion avenue), and
decompose the ensemble-mode residual to size a dominant-event mechanism.

**Setup.** Engine commit 0ce8809f plus working-copy changes. New
`HmmKeyDetector` option `cadenceTriadBoost` (default 0, byte-identical off):
fires when the previous event is a plain major triad a fifth above a
tonic-quality current chord AND the event two back was predominant-functioned in
the target key (ii-family on the second degree or IV-family on the fourth,
mode-matched). The trigram gate supplies the directionality the plain V-I bigram
lacks (I to IV is the same bigram; ii-V-I is not). The rootless harness gained a
miss decomposition (key error via the annotated arm, announcing-dominant flag,
used-key relation buckets) and a simulated secondary-dominant admission arm.
Same fixture pins as entries -01/-03.

```
dart run tool/whatkey/harness.dart \
  --fixtures build/whatkey-fixtures/isophonics-nc-v1 \
  --split-file research/whatkey/data/splits/isophonics-nc-v1.json \
  --split development --detector hmm --cadence-boost 4 \
  --out build/whatkey-local/iso-dev-stable-cb4

dart run tool/whatkey/harness.dart \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --detector hmm --decay-half-life-seconds 1 \
  --cadence-boost 3 --cadence-triad-boost 2 \
  --out build/whatkey-local/wir-dev-hl1-cb3-ctb2

dart run tool/chord-context/rootless_corpus.dart \
  --fixtures build/chord-context/fixtures/dcml-distant-listening-v1-span \
  --labels build/chord-context/labels/dcml-distant-listening-v1-span.labels.json \
  --split-file research/chord-context/data/splits/dcml-distant-listening-v1.json \
  --split development --behavior stable \
  --out build/whatkey-local/rootless-dev-stable-diag
```

**What happened.**

Dose 4 on the guards (paired vs base):

- WiR dev stable exact: +0.0113, CI95 [+0.0010, +0.0218], p = 0.015, a
  significant win where cb 3 only trends (+0.0060, p = 0.058).
- WiR dev hl1: exact +0.0096 (p = 0.16), MIREX +0.0109, CI95 [+0.0014, +0.0213],
  p = 0.054.
- pop-jazz suite: clean at 4; no secondary-dominants regression (that appears
  only at 5), and the descending ii-V-I chain improves further (hl1 exact 0.50
  at cb 3, 0.75 at cb 4).
- Isophonics dev stable guard: coverage -0.0106, CI95 [-0.0176, -0.0042], p =
  0.0003 (10 wins / 42 losses), spurious p90 1 to 2, exact a wash (+0.0043, p =
  0.51). A real, significant coverage cost of about one point, five times cb 3's
  -0.002.

So the dose ladder reads: 3 = strongest dose whose Iso guard cost is negligible;
4 = stronger local-ruler dose whose entire cost is about one point of pop
coverage (abstention, not error) plus one extra p90 spurious switch; 5 =
wrong-key regressions appear. The pre-declared overlap run for 4 was not
executed because the dev guard failed first (nothing to confirm). Product
framing for the eventual decision: 3 if the Iso guard stays as frozen, 4 if a
coverage-only trade on pop is judged acceptable.

Triad cadence trigger, WiR dev hl1 (the corpus where plain-triad V-I cadences
live):

| Config               | Coverage                 | Exact                    | Mods        |
| -------------------- | ------------------------ | ------------------------ | ----------- |
| base                 | 0.6803                   | 0.5457                   | 184/399     |
| ctb 1 / 2 / 3        | 0.6802 / 0.6802 / 0.6792 | 0.5466 / 0.5469 / 0.5465 | 184/399 all |
| cb 3                 | 0.7014                   | 0.5529                   | 195/399     |
| cb 3 + ctb 1 / 2 / 3 | 0.7013 / 0.7012 / 0.7001 | 0.5538 / 0.5541 / 0.5537 | 195/399 all |

Inert: at best +0.0012 exact, zero new matched modulations, fading at
strength 3. The trigram fires too rarely to matter. Avenue closed as measured;
the option stays in code at default 0, matching the relative-tilt precedent.

Ensemble residual decomposition (DCML dev, stable, 957 engine inferred-key
misses of 13,197):

- Key error (annotated-key arm names it correctly): 525 (55%).
- Used key exactly right at the miss: 289 (30%); these are naming or tiebreak
  misses that no key detector can touch.
- Announcing dominants (expected dominant-family chord whose annotated local key
  is its own resolution target): 182 (19%).
- Used-key relation over all misses: exact 289, other 443, subdominant 81,
  relative 55, parallel 48, dominant 41.

Simulated secondary-dominant admission (dominant7 hypotheses admitted when the
key they tonicize is diatonic in the used key): unique-correct falls 81.9% to
72.4%, ambiguous rises 11.1% to 21.2%, miss falls only 7.0% to 6.4%. A blanket
admission trades 9.5 points of unique answers for 0.6 points of recovered
misses; without a tiebreak that resolves the new ambiguity it is strictly worse.
Measured-negative at the filter level.

**Plain-English reading.** Strength 4 really is better at following local keys,
and its only cost is that the detector goes quiet about one percent more often
on pop songs; whether that trade ships is a product call, and the frozen guard
currently says no. The trigram idea (ii-V-I with a plain V triad) was a nice
theory that the corpus declined: it almost never fires where it would change
anything. And the ensemble residual now has a map: over half is the key being
momentarily wrong (the existing WhatKey lead), a fifth is the dominant that
announces a key change (unfixable by any causal key signal at that moment;
fixable in hindsight, which is exactly what the chord-context retro-resolution
relabel already does with 100% measured precision), and a third would not be
fixed even by a perfect key detector. Simply letting secondary dominants through
the ensemble filter makes things worse, not better.

**Decisions.**

- The shippable-dose recommendation stays 3 under the frozen guard; 4 is
  recorded as the alternative if the product accepts a coverage-only Iso cost.
  No protocol amendment proposed here; that is a deliberate open question for
  the initiative.
- `cadenceTriadBoost` closed as inert; default 0, retained in code.
- A dominant-aware ensemble filter is dead as a blanket admission. The live
  paths to the remaining ensemble headroom, in measured-size order: (1) local
  key exactness (55% of misses; the cadence boost's claimed-event gains are
  diluted by the harness's sticky-key arrangement, so a claim-freshness or
  abstention-aware key handoff to the ensemble filter is worth a look), (2)
  hindsight relabeling of announcing dominants in the history list (19%,
  mechanism already validated in chord-context log 2026-07-20-15), (3) tiebreak
  quality for the exact-key misses (30%, ensemble-mode territory).

**Next.**

- Mine the surviving relative-confusion residual (8.3% of stable claims at cb 3)
  for structure before designing any further mechanism.
- Probe the sticky-key dilution: measure ensemble accuracy with the filter keyed
  off the detector's fresh claim (abstention-aware) instead of the last-claim
  fallback.
- The adoption question from entry -03 stands, now with the cb 4 data on the
  table; holdout stays untouched per the decision to explore all avenues first.

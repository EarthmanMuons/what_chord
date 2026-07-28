# 2026-07-28: The tonality-gated tier correction, scoped and declined

**Goal.** Log -09 left a narrow path open: pair the frequency-justified m(maj7)
tier promotion with a tonality-gated protection for the harmonic-minor tonic,
the one context that killed the blanket version. Scope it: what would it take
mechanically, and what mass could it move?

**Finding 1: the protection already exists.** The engine has
preferHarmonicMinorTonicOverSplitThirdInversion, a pair-specific tie rule
written for exactly the broken golden (root-position m(maj7,b13) as
harmonic-minor tonic versus the Aadd#9 split-third inversion; the doc comment
uses the golden's pitch classes as its example). The tier bump broke the golden
anyway because tie rules only engage within the near-tie window (0.25), and the
+0.3 price pushed the pair out of it: the rule never saw the matchup and raw
cost decided. So strengthening the rule is not a rule edit; it means widening
the global window or promoting a hard rule, both heavy levers pointing away from
where the rule reduction work has been heading. The buildable version is a
context-gated price (m(maj7) marked when it names the harmonic-minor tonic of a
minor-key context, uncommon otherwise): _priceTemplate already receives the
AnalysisContext and the cache is context-keyed, so it is mechanically small,
though it crosses the standing design line that prices are context-free and
rules are context-aware.

**Finding 2: the golden case and the flagship absorption case are the same
configuration.** Dm with a held C# melody in D minor is m(maj7) as
harmonic-minor tonic. Any tonality gate that protects C#m(maj7,b13) in C# minor
also keeps Dm(maj7) cheap in exactly the keyed playing where melody absorption
concentrates. The gate's reachable mass is therefore only the non-tonic share of
m(maj7) absorption.

**Finding 3: the census split.** Reproducing the added-tone attribution on the
A0 dev roster (analyst chord tones a strict subset of the app's, exact-tier
failures, boundary tolerance as in error_census; note the error_census
appSuperset bucket is the wrong filter here, since same-root absorption like Dm
named Dm(maj7) classifies as rootHit): added-tone total 328.2s, minorMajor7
38.8s (11.8%), matching log -06's shape. The split:

- harmonic-minor tonic in the local minor key: 26.3s (67.9%), dominated by
  exactly the flagship shape (Dm(maj7) against i in D minor).
- non-tonic or non-minor context: 12.4s (32.1%), e.g. Bm(maj7) against v in E
  minor, Fm(maj7,9) against ii in Eb major: leading-tone and neighbor colors
  absorbed on non-tonic minor chords.

**Finding 4: the flip arithmetic caps the reachable third at roughly zero.** Log
-06's arithmetic applies to the non-tonic cases identically: these absorbers
fully explain the voicing, so Bm(maj7) at the promoted 0.4 still beats honest Bm
paying the 2.0 unexplained price, and would even at the swept utc 1.0. The gated
promotion could only move near-tie band composition and rare marginal
competitions, not these head-to-head absorptions. The gate protects the 68% that
was never supposed to flip and the arithmetic keeps the remaining 32% from
flipping anyway.

**Verdict: declined.** A context-crossing price mechanism with a ruler yield
bounded near zero does not clear the adoption bar. Recorded so the narrow path
from log -09 is closed by measurement rather than left standing.

**Plain-English reading.** The rescue idea was to make the rare chord name
expensive everywhere except the one classical situation where it is the right
answer. It turns out the engine already has a bodyguard for that situation; the
price hike just shoved the fight out of the room the bodyguard stands in. Worse,
the protected situation and the bad habit we wanted to fix are the same
situation, so the exception would shelter most of the problem, and the math says
the unsheltered remainder would not change its behavior at any honest price.
Clever idea, measured, empty; closing it.

**Next.** The decision from log -08 stands: design the shell lever experiment or
close the initiative with the shell side scoped-but-unbuilt.

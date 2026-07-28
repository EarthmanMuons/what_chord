# 2026-07-28: Shell lever designed; the blast-radius census gates it to bare shells

**Goal.** Design the shell-lever experiment (the omission side of the
initiative, blockers mapped in log -04), with a blast-radius check BEFORE any
engine or vocabulary work. Context recorded per the review discussion: power
chords have contentious history here. They were in the engine originally, caused
too many ranking problems and edge cases, were removed for simplicity (justified
as a guitar concern rather than a piano one), and were reintroduced under the
pricing model only with strict requirements. The full-explanation gate at the
pricing site IS that peace treaty; relaxing it is exactly the historically
dangerous move, so the radius gets measured first.

**The check costs nothing.** A shell candidate can only ever enumerate for a
voicing containing a fifth dyad plus exactly one seventh, with every remaining
tone nameable as a power color. That family is closed and countable over the
existing pool snapshot with POP909 exposure weights: no engine change, no
tooling beyond a walk.

**Census results (pool 1,501 canonical cases, pop dwell mass):**

- Naive family (any nameable color allowed): 894 cases, 43.0% of pooled mass.
  Driver: interval 3 read as sharp-nine lets every minor-seventh voicing respell
  as a shell (Dm7 as a D5 stack). This is the historical degenerate case in one
  number, and it is excluded by design, not by price.
- Colors 9 and 11 allowed: 32 cases, 13.4% of mass, 21 of them reviewed oracle
  entries. The incumbents are canonical, top-exposure names (Amadd11 at 3.0%
  mass, Am11, C6/9, Abadd11). A no-third honest label has no business
  outcompeting those; this stratum is out.
- Bare shells only: 6 case families (R-5-b7 and R-5-maj7, three bass variants
  each), 2.13% of pooled mass, ALL SIX already reviewed, mostly
  context-dependent verdicts. Ruler side, shell time was already measured at
  roughly 1.8% of dev playing time (log -01). Today the sole surfaced name for
  the b7 shell is the folk reading (Am/D for D-A-C at 0.95); the D-rooted
  readings (D7 at 1.7) rank but do not surface.

**Verdict: GO, gated to bare shells.** The check the review asked for comes back
green precisely because the scope shrinks to six case families with existing
review notes. And the gate dissolves blocker 1: a bare-only shell is a closed
template (required root, fifth, seventh; no extras tolerated), so the
contentious unexplained-tone rejection stays intact for every other voicing.
Nothing outside the six families can change, by construction.

**Staged plan:**

1. Research probe, no vocabulary work: ChordAnalyzer gains a research-only
   shellSeventhCost parameter (default null = shipped behavior, mirroring the
   unexplainedToneCost mechanism). When set, a power candidate whose voicing is
   exactly the bare shell prices its seventh at the dial value instead of
   rejecting. Identity surfaces as the power root for measurement purposes;
   display forms come later or never.
2. Pre-declared measurements: price sweep (0.7 / 0.9 / 1.1 / 1.3) reading (a)
   win versus band entry on the six pool families (incumbent geometry: Am/D
   0.95, band width 0.25, so alternative-surfacing needs cost <= 1.20 and
   winning needs < 0.95); (b) dev-ruler conversion of the ~1.8% shell time; (c)
   the three standing shell rows re-read per price; (d) a full pool diff proving
   zero changes outside the six families; (e) package goldens green (no golden
   asserts a bare-shell incumbent; checked).
3. Declared success shape: the shell surfacing as an honest ALTERNATIVE
   alongside the folk reading, not necessarily evicting it. The idiom split
   (jazz hears D7-without-third, folk hears Am/D) says both readings deserve the
   band; whether the shell should ever win outright is left to the sweep to
   inform, not assumed.
4. Only if the probe finds a workable price window: display vocabulary (the
   chord-symbols guide's anti-omission stance argues for 5-based forms, so new
   power-only extensions addFlat7/addMaj7 and formatter work), then the adoption
   bar per protocol with review-on-flip on the six reviewed entries and POP909
   held-pool corroboration.

**Plain-English reading.** Before building anything we measured who could
possibly be affected if power chords learned to carry a seventh. The answer
splits three ways: let the shell borrow any color and nearly half of all playing
time is in the blast zone, because every ordinary minor seventh chord can be
misspelled as a power stack, which is the old disaster in miniature. Allow just
the gentle colors and it still collides with beloved names like Amadd11. But the
plain two-note-plus-seventh shell touches only six chord shapes, about two
percent of playing time, every one already discussed in our review notes. So the
experiment proceeds, but only for those six, and the engine's strict wall
against leftover notes stays up everywhere else.

**Next.** Build the probe parameter and run the pre-declared sweep.

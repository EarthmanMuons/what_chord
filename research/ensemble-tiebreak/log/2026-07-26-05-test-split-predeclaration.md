# 2026-07-26: Test-split pre-declaration

**Goal.** Declare, before execution, the one-shot result set that confirms the
entry -02 change on held-out data.

**Design.** One declared spend of the weimar-comping-v1 test split (83 solos, 54
tunes, tune-disjoint from development by the frozen split):

1. Baseline arms: the pre-admission engine (the commit preceding "Open ensemble
   implied-root admission to out-of-key chords"), reconstructed by restoring the
   three changed analysis files from git, run with the current harness at the
   stable and reactive behaviors.
2. Current arms: the shipped engine (key-open admission, out-of-key idiom gate,
   semitone-pair rule), same behaviors.
3. Paired per-solo statistics on the inferred arm (the protocol's primary),
   annotated arm alongside, via the same seeded-bootstrap and Wilcoxon method as
   entry -02.

DCML's test split is NOT spent: this initiative's protocol uses DCML as a
dev-side continuity ruler only, and its test split was already spent by the
ensemble-mode initiative's shipping result.

**Pre-declared expectations.** The improvement transfers at roughly its dev
magnitude (inferred exact up by several points; dev was +9.2 at stable), because
the mechanism is structural (readings that previously could not exist) rather
than tuned; the behavior arms stay within a fraction of a point of each other,
as in entry -04; and the annotated arm moves with the inferred arm. Reported
either way, including any miss.

**Spend accounting.** This is the initiative's single test-split result set; no
further weimar-comping-v1 test runs after it.

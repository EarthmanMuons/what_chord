# 2026-07-26: The residual was admission, not tiebreak

**Goal.** Build the degree-aware tiebreak rules against the three jazz miss
families from entry -01.

**Setup.** Engine at the shipped defaults. A pre-design check reframed the whole
plan: for every quality family, the count of dev events whose expected root is
NOT diatonic in the annotated key matches that family's annotated-arm miss count
almost exactly (dominant7: 1,244 non-diatonic against 1,251 tritone misses;
halfDiminished7: 176 against 182; major7: 532 against 537 summed; minor7: 512
against 504). The ensemble implied-root admission gate only hypothesizes
diatonic roots, so secondary and substitute dominants, and every chord under a
mislabeled or momentarily wrong key, never generate their true reading; the
engine names the in-key twin. No tiebreak can fix a reading that does not exist.

**What happened.** Two engine changes, developed against the failure each step
exposed:

1. **Key-open admission.** The ensemble pass now hypothesizes every absent pitch
   class as an implied root (`chord_analyzer.dart`). The first run broke the
   off-idiom package test in an instructive way: a complete sounding C7 was
   hard-promoted to its own tritone-sub ghost (an F sharp 7 flat-9 sharp-11
   reading of the same tones), because the idiom rule held that dominant ghosts
   are always promotable.
2. **The out-of-key idiom gate and the semitone-pair rule.** Promotion of an
   out-of-key implied root now requires all-natural colors (a real sub-five
   voicing reads with natural nine and thirteen; the spurious tritone ghost of a
   sounding dominant is an altered stack), keeping diatonic-ghost behavior
   byte-compatible. And the one pure re-rooting pair, a rootless half-diminished
   seventh against the major seventh a semitone below (identical tones), is
   decided by whichever root the key contains
   (`preferInKeyMemberOfSemitonePair`, a narrowly gated hard rule). Admission
   alone regressed DCML to 90.2% because the old diatonic gate had been silently
   protecting in-key half-diminished readings by never generating their
   major-seventh twins; the pair rule is that protection made principled.

Results (engine top-1 exact, stable behavior, dev splits):

| Ruler, arm       | Baseline | Admission only | Admission + pair rule |
| ---------------- | -------- | -------------- | --------------------- |
| Weimar inferred  | 83.7%    | 92.1%          | 92.9%                 |
| Weimar annotated | 83.4%    | 92.1%          | 92.9%                 |
| DCML inferred    | 92.8%    | 90.2%          | 96.5%                 |
| DCML annotated   | 95.9%    | 90.2%          | 97.3%                 |

Paired per-piece statistics (combined change against baseline, same harness,
old-engine baselines regenerated with per-piece counts and verified to reproduce
the recorded aggregates):

- Weimar dev inferred: +0.0786 per solo, CI95 [+0.0664, +0.0915], 179 wins / 3
  losses / 151 ties, Wilcoxon p = 3.5e-30. Annotated: +0.0826, CI95 [+0.0692,
  +0.0964], p = 2.1e-29.
- DCML dev inferred: +0.0335 per piece, CI95 [+0.0262, +0.0417], 178/1/572, p =
  1.3e-30. Annotated: +0.0130, CI95 [+0.0081, +0.0187], p = 3.0e-13.

Guards: comping suite 18/18 exactly; package suite 534 green (the old
admission-documenting test replaced by a substitute-dominant admission test; the
off-idiom displacement test now guards the tritone-ghost case); solo invariance
holds (golden suite unchanged, `tool/benchmark.sh --check` PASS). Remaining DCML
annotated-arm shapes are exactly the pre-initiative half-diminished pair cells
(264 and 49), the cells where both or neither root is in key.

Two side effects worth recording:

- The whatkey-local announcing-dominant residual (19% of ensemble misses, judged
  structurally unreachable by any causal key signal in its log 2026-07-26-04)
  collapses from 180 to 3 events on DCML: a dominant that announces a key change
  no longer needs the key belief to have switched, because its true root is
  admissible under the old key.
- The DCML inferred arm (96.5%) now sits above the pre-initiative annotated-key
  oracle (95.9%): naming robustness to key error bought more than perfect keys
  used to.

**Plain-English reading.** The mode was not confused between candidate names; it
was forbidden from considering the right name whenever the chord stepped outside
the current key, which jazz does constantly and classical does at every
tonicization. Letting every absent note audition as the missing root, with two
narrow guards (an out-of-key ghost must look like a natural comping voicing, and
the one truly identical-sounding pair is settled by the key), fixes five chords
in six of the jazz mode's mistakes and most of the classical ones too, while
every existing acceptance test still passes.

**Decisions.** Adoption bar (PROTOCOL.md): bar 1 met overwhelmingly on the
primary arm; bar 2 met exactly; bar 3 met (targeted shapes reduced to the
irreducible cells, no new shapes appeared); bar 4 met. Adopted; the remaining
ø7/major7 cells (both-or-neither in key) stay on the record as the residual
floor for a future round with better local key context.

**Next.** Test-split confirmation (one shot, to be pre-declared), docs and
changelog, and a re-run of the whatkey-local key-detection guard since committed
event identities can now change under ensemble playing.

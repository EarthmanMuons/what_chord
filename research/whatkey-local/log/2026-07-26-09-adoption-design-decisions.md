# 2026-07-26: Design decisions for the relabel and internal-key adoptions

**Goal.** Record the design questions settled in the initiative discussion
(2026-07-26) so the implementation inherits them; no measurements in this entry.

**Decisions.**

1. **One-event history relabel: unconditional on every axis.** Applies in both
   playing modes (solo effect measured inert as retroKey, chord-context log
   2026-07-20-15) and in both key modes. Under a manually selected key, live
   naming keeps following the manual key exactly as today, but history entries
   are still relabeled from the internal detector's later claims: the history
   list is a record of what was heard, not a restatement of the key choice, and
   the internal belief is maintained regardless of mode. Precision framing for
   the record: unlike retroResAll (100% flip precision), the hindsight-key
   relabel is net-positive rather than per-flip perfect (entry -08: 161 events
   fixed, 4 of the 129 fallback events broken, at reactive). Record-only;
   detectors never reprocess relabeled events; one event deep.
2. **Internal ensemble naming key: pinned reactive, ensemble path only.** The
   display key follows the user's key behavior preset (the preference is "how
   calm should the indicator feel"); the ensemble hypothesis filter consults a
   second detector instance hardwired to the reactive timescale (measured best:
   93.5% vs 92.8% under stable). Separate instances even when the user's preset
   is reactive, so the naming path never depends on display state. Manual key
   mode overrides the internal key for live naming as today.
3. **Identity from the internal key, spelling from the display context.** The
   internal key decides the accuracy-bearing choice (which ghost root and
   quality); the chosen chord is spelled under the display tonality context so
   the visible key signature, degree numbering, and note spellings stay
   self-consistent. This removes the naming/display contradiction concern in
   ensemble; whether the engine/presentation split supports this directly is
   validated at implementation time (a small refactor if not).

**Next.** Implement per these decisions, then design the minor-evidence
asymmetry (entry -07) before any holdout use.

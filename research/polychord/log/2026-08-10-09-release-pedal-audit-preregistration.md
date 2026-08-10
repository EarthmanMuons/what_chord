# 2026-08-10: Preregister the release and pedal audit

**Goal.** Turn the onset census's next-step recommendation into a bounded,
reproducible audit before reading any release-history outcomes.

**Setup.** Log 2026-08-10-08 records a fixed negative onset ablation and the
already observed fact that all 59 pitch-class-disjoint candidate instances, in
12 POP909 sample songs, included at least one sustained note. The detailed
source report has SHA-256
`60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`. No POP909
annotation file or held song was opened for this design step.

The audit contract is `release-pedal-audit.md`, implemented by
`tool/polychord/release_pedal_audit.py` and covered by
`tool/polychord/release_pedal_audit_test.py`. Synthetic tests exercise
pedal-held releases, pedal-sustained reattack and its prior release, carried-in
unknown history, per-candidate raw evidence, pitch-class-disjoint selection, and
exact-candidate run grouping.

After this preregistration is committed with clean declared inputs, the exact
measurement command will be:

```sh
./.venv/bin/python tool/polychord/release_pedal_audit.py \
  --out build/polychord/pop909-sample-disjoint-release-pedal-audit-v1.json
```

**What happened.** The selection is frozen to every source-report candidate
whose `sharedPitchClasses` array is empty. The tool requires exactly the 59
previously reported instances and the exact 12 song IDs, then reconstructs only
those sample songs and reproduces every source frame, candidate, and onset
record before attaching release history.

The new evidence remains threshold-free. It preserves note-on, state-changing
note-off, release velocity, current-state origin, pedal-transition origin,
restrike-from-sustain, note and state ages, and whether an attack predates the
current pedal-down transition. Unknown carried-in facts stay unknown. No field
labels a candidate as a polychord or assigns support, penalty, confidence, or
eligibility.

Repeated frames are handled explicitly. The report retains every frame-level
instance, including zero-dwell transitions, while grouping an exact candidate
allocation only across consecutive normalized event indices. A shared display
symbol is not enough to join runs. Runs are inspection units, not claimed
independent musical events.

**Plain-English reading.** We already know which 59 machine proposals warrant a
closer look. This step fixes what "closer look" means before seeing the answer.
It will show exactly which keys were still held, which notes survived only
because of the pedal, when those notes were released or re-pressed, and whether
several report rows are merely successive views of the same transient state. It
will not decide whether any proposal is musically correct.

**Decisions.** Use the complete disjoint subset instead of hand-selecting vivid
examples. Keep the report local because it contains detailed corpus event
sequences. Treat both frame instances and exact-candidate runs as denominators,
and do not infer corpus prevalence or accuracy from either. Commit this design
before the first run, preserve the result unchanged, and use it only to choose
the raw fields for a reusable release/pedal evidence contract.

**Next.** Run the audit once from the clean preregistration commit, validate its
pins and summaries, and record the result in a new dated entry. Then freeze the
reusable threshold-free release/pedal evidence contract before attempting any
categorical interpretation. Leave motion and the 808-song reserve untouched.

# 2026-07-28: Shell probe built and swept; the flat-seven shell finds its window

**Goal.** Stage 1-2 of the log -11 plan: build the research-only
shellSeventhCost probe and run the pre-declared sweep.

**Mechanism.** ChordAnalyzer gains shellSeventhCost (default null = shipped
rejection), mirroring the unexplainedToneCost pattern; when set, the bare shell
prices its seventh at the dial instead of rejecting. Plumbed through
oracle_batch/pool_diff (per-request shellSeventhCost, --shell-seventh-cost) and
replay_batch/asap_wir_extract (-shell<value> set suffix). Package suite 536
green at the default; the app never sets the parameter.

**Pool sweep (0.7 / 0.9 / 1.1 / 1.3), both sevenths enabled.** Containment held
at every price: zero changes outside the six bare-shell case families, matching
the by-construction argument. Within the family the two sevenths diverged
sharply:

- Flat-seven shell: on root-position D-A-C, D5 joins Am/D in the surfaced band
  at 0.7 through 1.1 and drops out at 1.3. Am/D keeps the top even when D5 is
  cheaper: the triad-completeness rule already protects the complete reading.
  Bass variants (fifth or seventh in the bass) never surface, which is right;
  the shell is a root-position idiom.
- Major-seven shell: at 1.1 and below it FLIPS the top of Db-Ab-C to the power
  reading and evicts both incumbents from the band, including Dbmaj7, the honest
  missing-third name that already surfaces today. The asymmetry has a clean
  explanation: the major-seventh shell is redundant (its honest label exists via
  the missing-third allowance) while the flat-seven shell has none (D7 sits at
  1.7, out of band).

**Ruler run at 1.1, both sevenths:** nine dev pieces moved, net a wash (exact
-0.001, root +0.001), and every top flip was the major-seven shell stealing
leaning-tone moments (D-C#-A type appoggiaturas renamed from Aadd11/D to a power
reading). The flat-seven shell produced zero top flips.

**Verdict: the probe is restricted to the flat-seven shell only,** the
major-seven form excluded by two independent instruments. Confirmation runs at
b7-only 1.1:

- Pool: zero top flips; exactly ONE surfaced-set change in 1,501 cases (D-A-C
  gains D5 beside Am/D; exposure 1.14%) plus one below-top reorder (0-2-9_b9,
  not a contract).
- Ruler: zero pieces moved of 23; top identical to baseline across all 36
  fixtures; the shell surfaces as an alternative on 62.3s of 6,435s displayed
  (0.97%, matching the ~1.8%-scale shell-time estimate's root-position share).

**Recommended price: 1.1.** Above Am/D's 0.95, so the shell can never beat a
complete triad on cost anywhere, only band; below the 1.20 band ceiling. The
eviction-freedom argument is arithmetic, not empirical.

**Review-on-flip note.** The one changed pool entry, 0-2-9_b2, is a reviewed
case (context-dependent verdict). Its change is an added alternative, not a top
flip, which is the outcome its review note argues for; the re-verdict at
adoption time should be a formality.

**Plain-English reading.** We gave the engine a dial that lets a bare
fifth-plus-seventh be priced instead of forbidden, and tried it both ways. The
classic jazz shell (D-A-C) behaves perfectly: the folk name keeps the top spot
everywhere, and the honest "D5 with a seventh" reading appears beside it as an
alternative, exactly the outcome we declared as success. The other seventh
(D-A-C#) misbehaved in both test rigs, stealing the top from better names, and
it turns out nobody needs it: that shape already has an honest name today. So
the lever narrows to the one chord shape that lacked one, at a price
mathematically incapable of demoting anyone.

**Next.** Stage 4 decision: display vocabulary for the surfaced shell (the probe
surfaces it as bare "D5", which under-tells the story; the chord-symbols guide's
5-based forms suggest D5add(b7) or similar), then the adoption bar: goldens with
the price set, review-on-flip formality on 0-2-9_b2, POP909 held-pool
corroboration, and the changelog.

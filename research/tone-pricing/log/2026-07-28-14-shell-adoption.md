# 2026-07-28: The shell ships: D7(omit3) surfaces beside the folk reading

**Goal.** The adoption package approved in review: display vocabulary, the
shipped price, the guide addition, and the full guard suite.

**What shipped.**

- Engine: defaultShellMissingThirdCost = 1.1 under the current profile; the bare
  flat-seven shell read as dominant7 pays it instead of the full missing-third
  surcharge. The frozen whatKeyPaper2026 profile keeps the full surcharge,
  preserving byte-identical fixture reproduction. The research override
  parameter remains for future sweeps. Other missing-third readings (Dm7 for
  D-A-C at 1.7, the maj7 shell) are untouched.
- Display: ChordDisplayConventions.showsOmittedThird gates the marker to exactly
  the bare shell (dominant7, no extensions, present intervals
  root+fifth+flat-seven). Symbol D7(omit3); long form appends "omitted third";
  spoken form "omit three". No other symbol can change, by construction.
- Guide: the chord-symbols article's Omissions section now separates
  omit-as-formatting (still avoided; no5 stays noise per its original reasoning)
  from omit-as-identity (the bare shell, where the marker IS the information),
  records the Brandt/Roemer citation, the omit-over-no rationale (the "No."
  collision with "number", instruction-vocabulary register, one-pass
  readability), and the standard's own colored-shell boundary. Per the review
  discussion: the original stance formed against omit-as-formatting and never
  ruled on omit-as-identity, so this is an addition, not a reversal.
- Changelog entry under Unreleased/Added.

**Guards, all green.**

- Package suite 540 (536 plus two shell goldens, Am/D top with the D7(omit3)
  alternative and the C-rooted transposition Gm/C with C7(omit3), plus long form
  and spoken form cases: "D dominant seventh, omitted third" and "D seven omit
  three").
- Root flutter test 247, flutter analyze clean, comping suite 18/18,
  tool/benchmark.sh --check PASS.
- WhatKey closed-loop behavioral probe (pop-jazz-v2, when-in-rome): all pass;
  top-1 identity unchanged, so committed event streams are untouched and key
  detection sees nothing new.
- Tonality stress: Am/D keeps the top for D-A-C in every checked key including G
  major, where D7 is the dominant, so no tonality-gated rule promotes the shell.
- Shipped-default pool diff: zero top flips; exactly ONE surfaced-set change in
  1,501 cases (D-A-C gains D7(omit3), exposure 1.14%); two below-top reorders
  (not a contract).
- Review-on-flip: 0-2-9_b2 re-verdicted in oracle_reviewed.json; its original
  note had anticipated exactly this vocabulary ("without D5(add-flat-7) or
  D7(no3) vocabulary..."), so the flip is the outcome the review argued for. The
  stale vocabulary claim in 0-2-9_b0 was amended; its behavior is unchanged.
- POP909 held-pool corroboration, engine-free per the freeze note: the b7 shell
  family carries 1.53% of pooled dwell on the 808 held songs vs 1.40% on the
  sample (root-position surfacing case 1.16% vs 1.04%), so the exposure claim
  replicates off-sample. No engine evaluation was run on the held pool: the
  price was tuned on the oracle pool and the ASAP ruler only, and the pool keeps
  its evaluation virginity.
- Dense census: unaffected by construction (the shell is a 3-pitch-class
  voicing; the census guards 7-plus).

**Adoption bar scoping, recorded explicitly.** The bar's paired
exact-tier-improvement clause governs levers that claim ruler gains. This change
pre-declared alternative-surfacing as its success shape (log -11, confirmed in
review) and measures exactly that: zero top-1 movement anywhere, the alternative
surfacing on ~1% of displayed time. Attribution is exact: the change moves
precisely the bucket it claims and no other.

**Plain-English reading.** The app now tells the whole truth about the most
common chord it couldn't name honestly. Play the two-handed jazz shell, root,
fifth, and flat seventh, and the display still leads with the safe name it
always showed, but right beside it appears D7(omit3), the name a jazz player
would actually use, spelled the way the profession's own style guide spells it.
Nothing else anywhere changed: not one top pick in the test pool, not one second
of the classical replay, not the frozen paper numbers. The symbol guide now
explains why this one omission earns a marker when all others stay noise.

**Next.** The initiative's two sides are now resolved: superset measured to
declination, shell measured to adoption. Remaining housekeeping: regenerate the
web demo bundle before release (not auto-run per convention), and the whatsnew
entry at release time. Initiative closure entry after the change settles.

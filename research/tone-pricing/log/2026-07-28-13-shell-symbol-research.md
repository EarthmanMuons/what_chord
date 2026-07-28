# 2026-07-28: The shell symbol: external research lands on D7(omit 3)

**Goal.** Per the review discussion: is D5add(b7) actually recognized, or what
would the most conventional representation be? External research before
committing display vocabulary.

**Findings.** D5add(b7) is a WhatChord invention: compositionally parseable,
consistent with our shipped power-color forms, but absent from charts and
literature. The conventional family is the omission marker, and the professional
copyist standard rules on it directly. Brandt and Roemer's Standardized Chord
Symbol Notation (1976), the uniform-system reference for the profession, has a
dedicated Omitted Notes section (pp. 41-42) whose worked examples include
exactly our chord: D7(OMIT 3) and Db7(OMIT 3), alongside triad (OMIT 3) and
(OMIT 5) configurations. It also rules on spelling: "The expression OMIT is
preferable to NO." The no3 form is the recognized informal variant that notation
software supports.

**The convergences are the striking part.** The standard independently endorses
both restrictions our measurements derived:

- "A 9TH CHORD that omits the 3rd is better shown as a COMPOUND CHORD": once
  colors join the shell, prefer the compound/slash reading. That is the census
  verdict on the +9/+11 strata (colored shells keep their Amadd11-family
  incumbent names) stated as a 1976 copyist rule.
- Their omit examples cover triads and small (dominant) sevenths only; no
  ma7(omit 3) appears. That matches the two-instrument exclusion of the
  major-seventh shell in log -12.

**Decision: the display symbol is D7(omit3)** (app-style compaction of
Brandt/Roemer's D7(OMIT 3)), and the identity should be dominant-based to match:
the symbol rides the ENGINE'S EXISTING dominant7-missing-third candidate rather
than the power quality wearing a dominant symbol. The chord-symbols article
needs an addition, not a reversal: its anti-omission stance formed against
omit-as-formatting (no5 on a complete identity, noise per its own words "without
changing which chord is named") and never ruled on omit-as-identity, where the
marker IS the information. Per the review discussion, that distinction is the
article's own logic extended.

**Mechanism swapped and re-confirmed.** shellSeventhCost now reprices the
missing-third charge on the dominant7 template for exactly the bare {root,
fifth, flat-seven} mask (the power-gate relaxation is reverted; the historical
peace treaty stands fully intact). Package suite 536 green at the default. Both
instruments reproduce the power probe's results at 1.1:

- Pool: zero top flips; one surfaced-set change in 1,501 (D-A-C gains D7 beside
  Am/D, exposure 1.14%); two below-top reorders. The dominant slash rules do not
  promote the shell.
- Ruler: zero of 23 dev pieces moved; zero top flips across all 36 fixtures; the
  shell bands on 62.3s of 6,435s displayed (0.97%), identical to the power
  variant.

The alternative-only property holds on the same three grounds: cost arithmetic
(1.1 above the 0.95 complete-triad reading), no rule promotes it, and measured
zero across both instruments.

**Plain-English reading.** We asked whether our invented spelling would be
understood and went looking at what the profession actually writes. The copyist
bible not only contains our exact chord with its blessed spelling, D7(omit 3),
it also states as rules the two limits we had found by measurement: no omit
symbols once extra colors are present, and no such symbol for the major-seventh
version. So the app will show the conventional symbol, the engine names it as
the dominant seventh it functions as, and re-running both test rigs on the
reworked mechanism gave the same clean result: the honest name appears beside
the old one and never on top.

**Next.** Adoption package: the omit3 display marker in the formatter (shown
only when no third sounds), the chord-symbols article addition, the shipped
default price (1.1), goldens for the shell cases, review-on-flip formality on
0-2-9_b2, POP909 held-pool corroboration, changelog.

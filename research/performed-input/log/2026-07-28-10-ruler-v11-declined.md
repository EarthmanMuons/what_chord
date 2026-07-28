# 2026-07-28: Ruler v1.1 candidate measured and declined

**Goal.** Resolve the pre-holdout gate item from log -07: would redefining the
members tier to compare the app candidate's presentIntervalsMask (sounding chord
tones) instead of its canonical quality intervals improve the ruler? Development
split only; the test side stays untouched.

**What happened.** Scratchpad probe (method recorded here), mean per piece:
exact 0.5948 to 0.5959, root unchanged, members 0.5252 to 0.4458. The intended
gain, crediting enharmonic augmented-sixth namings, amounts to 4 seconds of
exact-tier time; the side effect costs 274 seconds of members credit against 9
gained, because incomplete voicings (shells, partial arrivals, ordinary
performance practice) stop matching the analyst's canonical set when the app
side switches from the named chord to the sounding tones.

**Verdict: declined.** The members tier compares names (claimed canonical set
against analyst canonical set); voicing completeness is already the error
census's content axis, and v1.1 would conflate the two while mostly re-measuring
completeness. An aug6-only variant would move exact by about a tenth of a point,
not worth a versioned ruler bump. Ruler v1 stands as frozen.

**Pre-holdout checklist state** (from the review discussion): v1.1 resolved
(this entry). Remaining before any test-split spend: the 12-1 rescue decision
(its sonata sits on the test side, so a piecewise-calibration rescue must land
before the spend to be counted) and the pre-declaration of the confirmed result
set (identity arms, stability baseline, gated-policy numbers, with the
extension-exclusion line stated).

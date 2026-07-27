# 2026-07-26: Resolution-aware relabel shipped

**Goal.** Implement the mechanism validated in entry -07 in the app.

**Setup.** App-side change only, riding the existing one-event relabel in
`InternalKeyCoordinator` (whatkey-local logs 2026-07-26-09/-10). Simulation
reference: entry -07 (90% flip precision on Weimar dev, zero fires on DCML).

**What happened.** `_relabelPrevious` now serves both correction rules:

- The key rule as before: when the internal claim disagrees with the tonality
  the entry was ranked under, re-rank under the claim.
- The resolution rule: when the (re-ranked) top reading of the previous entry is
  an implied-root dominant carrying the flat-nine stack that does not resolve
  into the newest committed root (down a fifth, or a half step for the
  substitute), and its minor-third-axis twin does resolve down a fifth, that
  twin is promoted to lead the record. Implemented as a candidate promotion
  within the fresh re-analysis (take 24), so the promoted reading is a real
  engine candidate with its cost and colors, not a synthesized identity. Tritone
  twins are never touched (both resolve into the same target). A churn guard
  skips the write when neither rule changes anything.

Tests (suite 239 green, package 534, comping gate 18/18): an end-to-end case
where the record holds the E7 flat-nine reading of the B-D-F-A flat stack and
the arrival of C major promotes G7 (the member resolving down a fifth), plus a
negative case proving natural-color dominants are never resolution-relabeled;
the existing relabel, record-only, and naming-sync tests all hold unchanged.

**Plain-English reading.** When a pianist plays a rootless flat-nine voicing
over a bassist, four different chords fit the same keys perfectly, and the app
has to guess until the next chord lands. Now, one chord later, the recent-chords
list quietly corrects the guess to the dominant that actually resolved, nine
times right for every once wrong in simulation, and it never touches classical
playing or natural-colored chords.

**Decisions.** Shipped per the entry -07 validation and the initiative
discussion. The measured ceilings stand as the record: about +0.9 points of
history-record accuracy on jazz at 90% flip precision.

**Next.** This closes the last scoped mechanism of the initiative; the residual
floor per entry -03 stands for a future round with better local key context.

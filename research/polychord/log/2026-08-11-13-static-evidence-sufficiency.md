# 2026-08-11: Reassess static evidence sufficiency

**Goal.** Determine whether the 73 failed version-1 development displays support
a principled broader integrated-harmony veto, or instead show that static
register evidence is insufficient for automatic polychord selection.

**Setup.** The analysis began from clean commit
`6d58bd7f1f8c4e5f0f56c9f2ebe8203d229b883d`. No held POP909 song was opened and
no selector, suite, corpus adapter, or result artifact was changed. The relevant
pins were:

- frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- v1 output contract:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`;
- v1 selector specification:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`;
- valid development manifest:
  `3c098224a2ad77979005b3ae575b855a0523f2703559d1b80ebd43be07250178`;
- POP909 development summary:
  `46855886e83fa217d4ea53d0103da9e699e42b724cb042276b1a91f478af49ae`;
- review index:
  `64352b871bd4859ab96e58a0d7247c7cffe33355943c8d2a88bcf66c5ceb68c7`;
- completed dispositions:
  `08ca572a11d3d3fb64acaa27ef5f6f1be32a9558b1aaef41fdd86431b884f7f0`;
- prior onset-exposure report:
  `60b6702283b6b3eb1a0f5b4dd2a0932f0d43720c1dea24746c43999eb39d0ce9`; and
- prior motion-exposure report:
  `3489da54e0c2b71ba0a9f1c17acb6678115eae07afacf280c8afef8b81a2a3b6`.

The root-location count used the full immutable POP909 piece reports:

```sh
jq -s '
  [.[]
   | .analysis.profiles["polychord-register-policy/1"].stableEpisodes[]
   | {selectedSymbol: .selected.symbol,
      upperRoot: .selected.upper.rootPc,
      lowerRoot: .selected.lower.rootPc,
      primarySymbol: .primary.symbol,
      primaryRoot: .primary.identity.rootPc}]
  | unique_by([.selectedSymbol, .primarySymbol])
  | group_by(
      if .primaryRoot == .upperRoot then "upper"
      elif .primaryRoot == .lowerRoot then "lower"
      else "third"
      end)
  | map({location:
      (if .[0].primaryRoot == .[0].upperRoot then "upper"
       elif .[0].primaryRoot == .[0].lowerRoot then "lower"
       else "third"
       end), pairs: length})
' build/polychord/register-selector-development-exposure-v1/pieces/pop909/*.json
```

The exact collision was checked from the frozen suite and the three `G|Dm`
episodes in POP909 piece 127. Existing onset and motion summaries were read only
after the static analysis; neither report was rerun or reinterpreted with a
post-result threshold.

**What happened.** The 73 displays contain 33 distinct selected-symbol versus
primary-symbol pairs. In 19, the ordinary primary reading is rooted on the
proposed upper layer; ten are rooted on the lower layer; four use a third root.
The v1 mask is therefore too lower-root-centered, but merely testing every root
does not solve the selection problem.

The decisive counterexample is transposition-invariant:

| Case                             | Product reading                  | Upper/lower qualities | Root relation | Shared pitch classes | Gap |
| -------------------------------- | -------------------------------- | --------------------- | ------------- | -------------------: | --: |
| Ives positive                    | C above Gm, with `C9/G` retained | major/minor           | +5 semitones  |                    1 |   2 |
| synthetic positive               | C above Gm, with `C9/G` retained | major/minor           | +5 semitones  |                    1 |  10 |
| POP909 piece 127, three episodes | G above Dm versus `G9/D`         | major/minor           | +5 semitones  |                    1 |   9 |

A root-general ninth veto would remove the three development errors and both
frozen positives. A gap threshold that preserves only the 10-semitone synthetic
case would discard the source-attested Ives case; a threshold that preserves
Ives also preserves the development errors. Similar conflicts occur in other
suite positives that intentionally retain integrated single-chord alternatives.

The already-frozen temporal reports sharpen the boundary but do not validate a
new selector. The onset census found zero positive instances among all 3,645
POP909 structural candidate instances. The motion census found zero positive
hypotheses among 8,932 interpretations on 1,733 candidate-to-candidate windows.
Because the v1 displays are subsets of those exposed structural candidates, none
can acquire positive support under either unchanged rule. This is a known
development diagnostic, not an unseen version-2 result. The prior release/pedal
audit and the fact that every v1 display occurred with pedal down do not supply
a principled pedal veto.

**Plain-English reading.** The app can see two complete chords in different
registers, but the same visible pattern can be a genuine composed polychord in
one passage and a normal ninth chord spread between the hands in another. More
rules about chord names or register distance cannot recover the missing musical
context. Automatic recognition needs evidence that the two groups behave like
separate units, or it should remain silent.

**Decisions.** Preserve v1 as a failed register-only automatic-selection
hypothesis. Keep its candidate generator and layer vocabulary; neither caused
the semantic failure. Do not design version 2 as a wider integrated-chord
blacklist, consult the primary analyzer as truth, add a fitted gap threshold, or
reject pedal use categorically.

For the next automatic selector, static register becomes proposal evidence only.
A displayed result must also have positively observed support from a separately
preregistered evidence source independent of static register. Neutral,
incomplete, or unavailable support means abstention for automatic raw-MIDI
inference. This changes input eligibility, not the definition of polychord, and
therefore requires a versioned output amendment and suite rather than edits to
the frozen v0/v1 records. Explicit manual upper/lower input remains a separate
future condition because the user, rather than the detector, supplies the
grouping.

The detailed prerequisite and evaluation sequence is fixed in
`automatic-selection-v2-plan.md`. It is a design boundary, not the exact
version-2 selector preregistration.

**Next.** Define the versioned automatic timestamped-input output amendment and
its reason semantics. Then build a new suite condition with source-attested,
event-complete positive controls for every licensing cue before freezing an
exact selector. Previously exposed corpora remain development data; keep the
808-song POP909 reserve untouched.

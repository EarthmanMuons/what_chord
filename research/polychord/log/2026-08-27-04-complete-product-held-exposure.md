# 2026-08-27: Complete product held exposure

**Goal.** Execute and verify the frozen v3 post-abort reserve completion,
inspect all potentially visible transitions, and make the final product release
decision.

**Setup.** The tree was clean at prospective v3 commit
`02e3f3223e7ace03946645216c3762eddf33faf7`. Every artifact matched log
2026-08-27-03, the retained v2 song 002 report still matched
`a09a183a7b11dba36c35ded81e696e45007811c06c7031407ffafed2985cf4d0`, and the v3
output directory was absent. The registered commands ran unchanged:

```sh
./.venv/bin/python tool/polychord/held_exposure.py \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory build/polychord/product-held-exposure-v3

./.venv/bin/python tool/polychord/held_exposure_verify.py \
  --result-directory build/polychord/product-held-exposure-v3 \
  --require-pass
```

The manifest records Python 3.12.13, Dart 3.13.1, Mido 1.3.3, clean candidate
commit `02e3f3223`, POP909 commit `d83e6edb`, 808 held songs, zero sample songs,
and no supplied labels.

**Results.** The harness processed 2,389,037 relevant raw messages into
2,303,088 app-equivalent source frames. It filtered 29,722 repeated note-ons,
29,722 unmatched note-offs, and 26,505 repeated pedal messages. Across those
frames it generated 35,301 structural candidate instances on 24,524 frames. Only
two frames were selected and authorized.

Both authorized frames were the same `A#|F` candidate in song 310. Each entered
the hidden pending state, then cleared 69 ms later when an upper note released.
Both were 131 ms short of the frozen 200 ms presentation deadline. Therefore:

- stable display episodes: 0;
- displayed time: 0 ms;
- review items: 0; and
- out-of-scope stable displays: 0.

The verifier independently reconstructed all 808 piece reports, aggregate
counts, displayed duration, empty review coverage, adjudication template, and
809 immutable output hashes. It returned:

```json
{ "displayedMs": 0, "pass": true, "songCount": 808, "stableEpisodeCount": 0 }
```

The retained build result contains 811 files and occupies approximately 1.1 GB.
Repository-retained hashes are:

| Artifact             | SHA-256                                                            |
| -------------------- | ------------------------------------------------------------------ |
| Summary              | `dcb31c8c27901cd7c5cbc23489329e03663083d47b986f630c6c2ffa2848d040` |
| Empty review         | `141e6806e933b29126d131fe25a2ea9e4ffb78e03d126f736fda0a1dd8b5800a` |
| Manifest             | `e33e5c6eff9f5bff69681eaad0416f59593bb24493d5c0cd92ad766d76357981` |
| Song 310 diagnostics | `96f2546b47b368fc219f252472ef7b15c1f3af0c130519680a63d28022483d29` |
| Compact result       | `c59e736e207f6549bac624ceb7517bce13c4e47dec106c6add0fc41123058987` |

The complete compact result is `results/product-held-exposure-v3-summary.json`.
The build manifest preserves the complete per-file and per-source inventory.

**Plain-English reading.** Across all 808 songs, the feature never showed a
polychord annotation. Twice it briefly found a plausible internal candidate, but
the voicing changed after 69 ms, so the stability rule correctly prevented the
candidate from reaching users. The reserve cannot tell us whether real
polychords were missed because it has no verified positive labels.

The v2 technical abort remains a methodological blemish: song 002's negative
result was known before v3 replayed the full pool. It did not reveal a musical
failure or motivate a policy change, so v3 remains strong product-safety
evidence, but it is not represented as a perfectly pristine held estimate.

**Decisions.** The false-display safety gate passes. Together with the passing
musical suites, unchanged-primary comparisons, performance benchmark, and
maintainer acceptance on iPhone and Android, this completes the polychord
product cycle. Approve the current conservative feature for release. Preserve
external annotation and publication-grade validation as optional future work,
not a release blocker.

**Next.** Commit this append-only result and completion status. No additional
polychord implementation or measurement work is required for this release.

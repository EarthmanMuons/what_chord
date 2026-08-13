# 2026-08-13: Define the product completion track

**Goal.** Remove publication-grade source admission as a prerequisite for
finishing the feature while preserving the stronger research claim boundary, the
failed register-only result, and an auditable comparison against prior-art
baselines.

**Setup.** Work began from clean repository commit
`879ff5567da451c83c3919f374b418d732781cc3`. No selector, suite prediction,
baseline output, development-corpus result, or held POP909 item was generated.
The decision used these pre-change records:

- protocol: `697513817e2f640d9be940bcefdfe4439745e08eaf68d041da6359d5344e3e0b`;
- automatic-selection plan:
  `d5cf888e07266ca422208508969798225288160d120b2eae6c4eee5735ba56ec`;
- automatic-suite plan:
  `0b5592a1eae629cf5616390abb4c325e603b4691766a040e670c96b0cbcecd00`;
- preserved automatic-output contract:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`;
- bounded source-search log:
  `faba2f89356a2d18a5556261a17589b62ad202aa335bc8a624de4f5d84e9a52c`; and
- corrected timing-guard log:
  `2d3a5c430fe4497261076c903b99aa85a0c42eeb418f140893dcf3c724ae9931`.

The exact read-only inspection commands were:

```sh
git status --short
rg -n \
  'paused at the source|source-evidence prerequisite|next eligible step|source coverage remains|source-attested automatic' \
  research/polychord --glob '*.md'
sed -n '1,280p' research/polychord/prior-art-search.md
rg -n \
  'musicpy|mingus|ChordRecGen|baseline' \
  research/polychord tool/polychord --glob '*.md' --glob '*.py'
sed -n '300,390p' research/polychord/automatic-suite-v2-plan.md
sed -n '1,240p' research/polychord/register-selector-v1.md
shasum -a 256 \
  research/polychord/PROTOCOL.md \
  research/polychord/automatic-selection-v2-plan.md \
  research/polychord/automatic-suite-v2-plan.md \
  research/polychord/automatic-output-contract-v2.md \
  research/polychord/log/2026-08-12-02-bounded-automatic-source-search.md \
  research/polychord/log/2026-08-12-07-correct-timing-guard-interpretation.md
```

**What happened.** The source-admission rule was doing two jobs that do not need
to be coupled. It correctly protects a claim that a cue branch has
source-attested automatic positives and externally defensible controls. It is
not necessary for an explicitly author-adjudicated product policy whose claims,
suite, and corpus evidence are labeled accordingly.

The new `product-completion-plan.md` creates a separate delivery route. It keeps
the symmetric complete-common layer vocabulary, candidate-specific onset
binding, conservative static guards, automatic abstention, and delayed display.
It chooses the already measured 50-millisecond within-layer and 80-millisecond
between-layer onset profile as the first product hypothesis. Motion,
release/pedal interpretation, and independent validation remain outside that
first selector.

The plan also fixes the order of the remaining work: a new output and selector
identity, an author-adjudicated automatic product suite, Python/Dart
cross-checking, frozen adapters for register-only WhatChord, musicpy, mingus,
and conditionally ChordRecGen, development exposure, product integration, and a
single final false-display safety run on the untouched 808-song POP909 pool.

**Plain-English reading.** We can finish a conservative product without finding
an independently validated performance dataset first. We must call the result
what it is: behavior that matches a documented product policy and survives our
safety checks, not a universal or independently measured account of how humans
identify polychords.

**Decisions.** Keep the frozen `polychord-output/2` source-validation route as
the prerequisite for later independent-validation or publication claims. Do not
weaken it retrospectively. Use a planned `polychord-output/3` contract and a new
selector identity for product work.

Retain symmetric `complete-common` layers; the upper chord is not triad-only.
Use candidate-bound onset support as the only licensing family in the first
product hypothesis, with the 50/80-millisecond profile and the existing
200-millisecond appearance baseline. These are product parameters, not
scientific constants. Keep motion and release/pedal evidence diagnostic.

Treat the new suite as an author-adjudicated conformance ruler. Compare all
systems on identical eligible observations and retain raw baseline output. Use
development corpora for false-display exposure, not accuracy. Preserve the held
POP909 pool until every other product artifact and guard is frozen; any
out-of-scope held display blocks release and cannot be tuned away on the same
pool.

External annotators, prospective performance acquisition, and publication-grade
source coverage are not product-completion gates.

Final SHA-256 pins:

- product-completion plan:
  `1ed73d03051cf65cfc0c7217af61f5d544d481d9f9fc87eac3be9afc3ef73b7f`;
- protocol: `fff283957f9819f372e4b5b30148073172e4c8f83b250d846ee9eff75444d13c`;
- preserved automatic-selection plan:
  `51cf88cc036c128166c5de97109fbaf70c89302d6211489d8461de9679e2879e`; and
- preserved automatic-suite plan:
  `8af467f555d4b27add2c78909d05ea5a01cc3183d7ee3c5d13ccbb5a1686f707`.

**Next.** Commit the plan before specifying or implementing policy. Then freeze
the exact `polychord-output/3` behavior, selector reason precedence, automatic
product suite, scorer, and baseline adapter contract before producing any new
prediction or corpus result.

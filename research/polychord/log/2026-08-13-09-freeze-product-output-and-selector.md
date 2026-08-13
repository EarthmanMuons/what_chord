# 2026-08-13: Freeze the product output and selector

**Goal.** Freeze the first exact author-adjudicated automatic product contract
and onset-licensed selector before implementing policy, constructing its scorer,
reading a prediction, running a prior-art baseline, or opening new corpus
output.

**Setup.** Work began from clean repository commit
`08ae0e8e934de5a4649ce38c64c8929327a8bd50`. The product-completion decision was
already committed. No Dart or Python file, suite data, baseline dependency,
development corpus, or held POP909 item was changed or evaluated.

The decision began from these pins:

- product-completion plan:
  `1ed73d03051cf65cfc0c7217af61f5d544d481d9f9fc87eac3be9afc3ef73b7f`;
- framework v0:
  `3694429bca2c4e4782d9a9c2b32fec00558d7b2ba8d3dd59890a1b7c5cf13615`;
- output/evaluation contract v1:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`;
- register-candidate schema:
  `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538`;
- register-selector v1 specification:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`;
- preserved automatic-output contract v2:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`;
- onset-evidence schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- timing sensitivity preregistration:
  `957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522`;
- timing sensitivity result:
  `18a723cd2f47853dbe688ba38eb1cb1e2266bcf2ee0508e7767867dfeebef6fe`;
- corrected timing-guard decision:
  `2d3a5c430fe4497261076c903b99aa85a0c42eeb418f140893dcf3c724ae9931`;
- unchanged Dart register generator:
  `8554bb1eb18baa63c8707085039cd8f5480e1d5556c9998b0d93f0c37e4741db`; and
- unchanged Dart register selector:
  `b362196dfe29ee95e19f7fe5888d94459662436dd5573ec94319da59d7c0a0ca`.

The read-only review and final validation commands were:

```sh
git status --short
git log -5 --oneline --decorate
rg -n \
  'polychord-output/3|product selector|automatic product suite|baseline adapter' \
  research/polychord packages/whatchord tool/polychord \
  --glob '*.md' --glob '*.dart' --glob '*.py'
sed -n '1,360p' research/polychord/automatic-output-contract-v2.md
sed -n '1,300p' research/polychord/register-selector-v1.md
sed -n '1,280p' research/polychord/onset-support-ablation.md
sed -n '1,280p' \
  packages/whatchord/lib/src/polychord/services/polychord_register_selector.dart
sed -n '1,220p' \
  packages/whatchord/lib/src/polychord/models/polychord_onset_cue_record.dart
sed -n '1,180p' \
  packages/whatchord/lib/src/polychord/services/polychord_onset_cue_record_builder.dart
sed -n '1,220p' \
  packages/whatchord/lib/src/polychord/services/polychord_stable_display_gate.dart
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/product-completion-plan.md \
  research/polychord/product-output-contract-v3.md \
  research/polychord/onset-register-selector-v1.md \
  research/polychord/log/2026-08-13-09-freeze-product-output-and-selector.md
git diff --check
```

**What happened.** `product-output-contract-v3.md` now fixes the complete event,
decision, authorization, display, presentation, and feature-isolation boundary
for automatic product work. It retains the existing symmetric five-quality layer
vocabulary, exact candidate and sounding-instance binding, primary-result
isolation, upper-first notation, explicit screen-reader wording,
single-chord-history behavior, and 200-millisecond presentation baseline.

`onset-register-selector-v1.md` names
`coherent-separated-onsets-50-80ms/product-1` as the sole licensing cue. The cue
requires complete onset history, at most 50 milliseconds within either layer,
and at least 80 milliseconds between nonoverlapping layer onset intervals. Both
layer orders are equivalent. Motion and release/pedal state remain diagnostics.

The selector first removes identities with multiple exact assignments, then
integrated-tertian candidates, then candidates without positive bound onset
support. It applies widest-gap resolution only among the remaining positive
candidates. It emits one deterministic abstention reason from the first stage
that prevents selection, while retaining all per-candidate predicates.

The display reducer uses the exact tracker epoch, candidate, assignment, and
note-on identifiers as its authorization key. It clears immediately on loss or
change and requires a fresh 200-millisecond interval for a different key. Timer
events can mature an unchanged key but cannot create evidence.

**Plain-English reading.** We have now specified the entire first product rule
without looking at how it scores. A chord-over-chord structure must pass the old
static safety filters and must also have two compact groups of attacks separated
by at least 80 milliseconds. Missing history, simultaneous attacks, ordinary
integrated harmony, unresolved assignments, and tied candidates all cause the
feature to stay silent.

**Decisions.** Use `polychord-output/3`, `polychord-onset-register-policy/1`,
`coherent-separated-onsets-50-80ms/product-1`, and
`polychord-continuous-authorization-200ms/1` as the exact first product
identities.

Keep the v1 static assignment and integrated-tertian safety rules. Do not use
different onset histories to resolve multiple assignments of one identity in
this version. Resolve multiple supported identities only by a unique widest
register gap. Keep the primary result entirely outside raw musical selection;
primary availability gates authorization afterward.

Clear an old visible annotation as soon as its exact authorization key is no
longer selected and valid. Do not carry it while a different key matures. Keep
history, key inference, Explore, and sharing single-chord/input-only.

Treat this as author-adjudicated product policy. It does not satisfy the
source-admission rule preserved for independent-validation or publication
claims.

Final SHA-256 pins:

- product output contract:
  `071aa1bd5bb6798505603f27e72a48365c6f6c3c04cca87274072fde4573e024`; and
- onset-register selector:
  `22ad4b91afeb1da7ebd3b03265a16279171c14a988141268cb7f2e952e30d58d`.

**Next.** Freeze the author-adjudicated automatic product suite schema and
complete case inventory, exact scorer and acceptance rule, and prior-art
baseline adapter contract before implementing this selector or reading any
prediction.

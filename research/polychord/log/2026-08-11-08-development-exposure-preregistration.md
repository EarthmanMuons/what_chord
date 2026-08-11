# 2026-08-11: Preregister development-corpus exposure

**Goal.** Fix the corpus evidence roles, raw MIDI semantics, primary-analysis
condition, stable-display timing, complete reporting, fire dispositions, and
stopping rules before generating or reading any development-corpus selector
result.

**Setup.** Work began from clean repository commit `3c7bca30`, after the first
and only frozen-suite run passed the internal exact gates for
`polychord-register-policy/1`. No selector was run on a development corpus in
this step. No ASAP test performance, When in Rome test fixture, or held POP909
song was passed through a polychord generator, selector, or scorer. No raw ASAP
test MIDI or held POP909 song was opened. The 808-song POP909 reserve remains
untouched.

The audit used these read-only checks:

```sh
git status --short
git log -8 --oneline --decorate
git -C build/whatkey-corpora/asap-dataset rev-parse HEAD
git -C build/whatkey-corpora/asap-dataset status --short
git -C build/whatkey-corpora/POP909-Dataset rev-parse HEAD
git -C build/whatkey-corpora/POP909-Dataset status --short
shasum -a 256 \
  research/whatkey/data/splits/when-in-rome-v1.json \
  research/performed-input/data/splits/asap-wir-nc-v2.json \
  research/performed-input/data/pop909-held-pool.json
```

One schema-shape inspection used a wildcard over committed When in Rome
fixtures:

```sh
jq '{id,title,event:(.events[0] // null)}' \
  research/whatkey/data/fixtures/when-in-rome-v1/*.json | head -100
```

Its first printed fixture, `Bach WTC I Prelude 01`, is on that source's test
side. The command exposed its already committed first-event voicing,
single-chord candidates, and reference label before the split membership was
checked. It did not run or reveal a polychord proposal or selector result. When
in Rome is now a proposal-only companion and cannot support the stable-display
adoption item, but future records must not describe its test fixtures as wholly
unseen. The implementation is restricted to its 59 development entries.

The local ASAP checkout matches `afc815c75c42e83a79c03feb6da8a35e77d4c6b8`; the
POP909 checkout matches `d83e6edba6872a704f5d3b8b32f5cb540088dae6`. Both were
clean. The split and roster hashes were:

- When in Rome split:
  `4f55b18f88130fd62718c358b62a2c81302bbb11eede3c67d133f23161795684`;
- ASAP x When in Rome split:
  `240cab19043f8d4c1877a3d24c67a5a6ba7ddfc0058a29f4791209d0eeed440f`; and
- POP909 roster:
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`.

## Evidence audit

The 59 When in Rome development fixtures contain committed chord-identity
events. Each event preserves an onset snapshot and the committed identity's
duration, but not the note-event stream or same-identity revoicing inside that
duration. Treating the snapshot as if it persisted for `durationMs` would
manufacture exact-assignment evidence. These fixtures can support a
committed-event proposal companion only.

The 23 ASAP x When in Rome development entries resolve to original performance
MIDI in the pinned local ASAP checkout. Those files preserve the note, release,
sustain, order, and end-time evidence needed for exact frame and timer replay.
Their detailed derived output must remain local because of the source license.

The 101-song POP909 sample likewise resolves to original MIDI. The already
preregistered `BRIDGE` plus `PIANO` accompaniment projection preserves the
initiative's exposed input condition while the adapter makes the `held` roster
unselectable. It can support exact event and stable-display replay without
spending the 808-song reserve.

The app audit also found two timing and input details that the measurement must
model explicitly:

- the primary identity card already has its own timer-driven stability path,
  while the secondary annotation's frozen gate is a separate exact-assignment
  reducer; and
- a secondary timer can mature between MIDI events, so a replay that calls the
  gate only at source frames would undercount displays.

The raw adapter therefore mirrors the current channel-blind `MidiNoteState`
transition rules, including controller 123 and global sustain, and the secondary
replay inserts explicit timer deadlines. A deadline tied with a MIDI event is
processed first so an exact 200-millisecond selection is conservatively retained
as a possible zero-duration display.

## Measurement fixed

`development-exposure-v1.md` preregisters three separately reported conditions:

1. exact event and stable-display exposure on the 23 raw ASAP development
   performances;
2. exact event and stable-display exposure on the frozen 101-song POP909
   accompaniment sample; and
3. committed-event proposal and duration-attributed diagnostics on the 59 When
   in Rome development fixtures, with no stable-display inference.

All four selector profiles run through the pure-Dart implementation. The main
primary analysis uses the app's label-blind default C-major solo context and
current analysis profile. Every selected frame also receives an availability
audit over all supported tonalities and solo/ensemble modes; labels cannot
change or create a polychord decision.

The contract reports frame and duration exposure together, retains every
decision and display transition, creates a musician-readable event packet, and
requires an individual disposition for every full-selector stable fire. The
frozen categories distinguish in-scope polychords from ordinary integrated
harmony, slash or bass structures, same-root or duplicated harmony, pedal or
release artifacts, transient or serialization artifacts, other out-of-scope
cases, and unresolved cases. Only the in-scope category is compatible with the
development-display adoption item. No sampling may support that gate.

The documentation boundary was checked with:

```sh
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/development-exposure-v1.md \
  research/polychord/log/2026-08-11-08-development-exposure-preregistration.md
git diff --check
shasum -a 256 \
  research/polychord/development-exposure-v1.md \
  research/polychord/PROTOCOL.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/register-selector-v1.md \
  research/polychord/data/internal-suite/suite-v0.json
```

Formatting and whitespace checks passed. Final SHA-256 pins are:

- development-exposure contract:
  `22aa005535d28f388155ea3bf1bd258c3daf0992331d43dc6cd5d8a864bf6390`;
- protocol: `c48d18df2ccf4352f76f8a0fd859fb729cab530d68b61b123105412d254234e4`;
- clarified output contract:
  `56befc025222647f2e7111cbe5b1962a2b3102b00fd5dce3a07bfcc1db002bc4`;
- unchanged selector preregistration:
  `7ed2b174c4ed97db6dd386a98393d239c27716a71db7162b20fdae23a33d07ff`; and
- unchanged frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`.

**Plain-English reading.** Two of the development sources can honestly answer
whether an annotation would stay on screen; one cannot. The new contract keeps
the useful sparse source without pretending it contains timing evidence it does
not. It also makes the display replay behave like a timer-driven product, keeps
musical labels out of the rule, and ensures every possible user-visible
annotation is reviewed from note names and a complete event timeline rather than
raw MIDI numbers alone.

**Decision.** Adopt `polychord-development-exposure/1` as the pre-result
contract. Amend the protocol and output contract so stable-display safety
applies to the two frame-capable development sources, while When in Rome remains
an explicitly proposal-only companion. This narrows an overbroad measurement
claim; it does not alter the frozen selector, internal suite result, or adoption
threshold.

Do not generate a development result from this worktree. First implement the
pure-Dart stable reducer and complete corpus harness, prove them on synthetic
inputs only, and commit that implementation as a separate premeasurement
boundary.

**Next.** Implement the preregistered harness without opening permitted corpus
outcomes. Run all required synthetic, Dart, Python, and provenance controls;
then record the exact official command and implementation hashes. Only the
following clean-commit step may write the first official output to:

```text
build/polychord/register-selector-development-exposure-v1
```

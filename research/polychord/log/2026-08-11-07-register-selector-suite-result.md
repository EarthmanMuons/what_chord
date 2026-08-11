# 2026-08-11: Score the frozen suite with register selector v1

**Goal.** Generate the first and only version-1 prediction set for the frozen
author-adjudicated adoption suite, compare the independent Python and pure Dart
decisions on every exact suite frame, score the full selector and all three
preregistered ablations, and retain every case result.

**Setup.** The evaluation harness was committed as `f750a0e2`. The repository
was clean, the designated output directory did not exist, and the following pins
matched the pre-result record before execution:

- evaluation harness:
  `ad53dea92d26d5d4e4ee6ba56aba63e9f2bd45c26cf115991ae155ec6c16f9cc`;
- frozen suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`; and
- exact scorer:
  `0942adf1bc07c041a443be21d54da845c8adc17d296392bfee6adba868d177d9`.

No selector result from any development corpus, prior-art baseline result, or
held POP909 item had been read. The exact command was:

```sh
./.venv/bin/python tool/polychord/internal_suite_evaluation.py \
  research/polychord/data/internal-suite/suite-v0.json \
  --out-directory build/polychord/register-selector-suite-v1
```

It completed without correction or rerun:

```text
160 decisions across 17 suite cases; 0 mismatches; results -> build/polychord/register-selector-suite-v1
```

The manifest records repository commit
`f750a0e2a7385535bbb86f7c964e2452a3416a81`, a clean worktree, Python 3.12.13,
Dart 3.12.2, every suite and replay dependency, and `heldPop909Read: false`. The
40 evaluated frames comprise one exact frame for each of the 16 non-window cases
plus all 24 frames of the Petrushka replay window. All four selector profiles
agreed field-for-field between Python and Dart on every frame. Each Petrushka
frame had zero candidates under every profile; the case-level adjacent-register
prediction remained the preregistered `missing-register-evidence` abstention and
was excluded from scoring.

## Exact gate result

| Selector profile                | Exact positives | Correct guards | Suite exact gate |
| ------------------------------- | --------------: | -------------: | ---------------- |
| Full v1                         |             6/6 |            9/9 | pass             |
| Without integrated-tertian veto |             6/6 |            5/9 | fail             |
| Without assignment veto         |             6/6 |            9/9 | pass             |
| Without widest-gap resolution   |             5/6 |            9/9 | fail             |

The full selector also received 12/12 layer-identity credit, 6/6 correct
orientations, and 41/41 correctly assigned notes. Every applicable epistemic
stratum passed separately: literature-attested cases had 3/3 exact positives and
2/2 correct guards, synthetic cases had 3/3 and 4/4, and theory-derived
boundaries had 3/3 correct abstentions. The two coverage exclusions were the
already-frozen Augurs overlapping-register snapshot and Petrushka unfolding
window.

## Complete case record

`exact` means both ordered identity and exact MIDI-note assignment matched the
frozen expectation. `Abstain` cells passed a boundary or negative guard unless
marked `fail`. Enharmonic names use the source-facing suite spelling here; the
machine artifacts retain neutral pitch-class spellings.

| Case                                 | Gate role           | Full v1                 | No integrated veto             | No assignment veto      | No gap resolution       |
| ------------------------------------ | ------------------- | ----------------------- | ------------------------------ | ----------------------- | ----------------------- |
| Maiden Voyage Am7 over D             | boundary            | abstain: no structural  | abstain: no structural         | abstain: no structural  | abstain: no structural  |
| Herrmann Gm over Abm                 | literature positive | Gm over Abm: exact      | Gm over Abm: exact             | Gm over Abm: exact      | Gm over Abm: exact      |
| Ives C over Gm                       | literature positive | C over Gm: exact        | C over Gm: exact               | C over Gm: exact        | C over Gm: exact        |
| Elektra overlapping cover            | boundary            | abstain: no structural  | abstain: no structural         | abstain: no structural  | abstain: no structural  |
| Augurs overlapping registers         | positive coverage   | excluded: no structural | excluded: no structural        | excluded: no structural | excluded: no structural |
| Petrushka unfolding window           | positive coverage   | excluded: no snapshot   | excluded: no snapshot          | excluded: no snapshot   | excluded: no snapshot   |
| Shrovetide integrated Gm7            | literature boundary | abstain: policy         | Gm over Bb: unexpected, fail   | abstain: policy         | abstain: policy         |
| Three Movements G over Ab7           | literature positive | G over Ab7: exact       | G over Ab7: exact              | G over Ab7: exact       | abstain: multiple, fail |
| Generated Cmaj9 assignment ambiguity | negative guard      | abstain: policy         | abstain: assignment            | abstain: integrated     | abstain: assignment     |
| Generated Cmaj7 accompaniment        | negative guard      | abstain: policy         | Em over C: unexpected, fail    | abstain: policy         | abstain: policy         |
| Generated D over Cmaj7               | boundary            | abstain: policy         | D over Cmaj7: unexpected, fail | abstain: policy         | abstain: policy         |
| Generated D over C7 shell            | boundary            | abstain: no structural  | abstain: no structural         | abstain: no structural  | abstain: no structural  |
| Generated D-sharp 7 over E           | synthetic positive  | D-sharp 7 over E: exact | D-sharp 7 over E: exact        | D-sharp 7 over E: exact | D-sharp 7 over E: exact |
| Generated integrated D6              | negative guard      | abstain: policy         | Bm over D: unexpected, fail    | abstain: policy         | abstain: policy         |
| Generated layered C over Gm          | synthetic positive  | C over Gm: exact        | C over Gm: exact               | C over Gm: exact        | C over Gm: exact        |
| Generated same-root C registers      | negative guard      | abstain: no structural  | abstain: no structural         | abstain: no structural  | abstain: no structural  |
| Generated separated F-sharp over C   | synthetic positive  | F-sharp over C: exact   | F-sharp over C: exact          | F-sharp over C: exact   | F-sharp over C: exact   |

The integrated-tertian component is directly load-bearing in this ruler. Its
removal creates four unexpected annotations spanning all three guard strata: the
source-backed Shrovetide endpoint, doubled Cmaj7 accompaniment, a complete Cmaj7
with conventional extensions, and integrated D6.

Widest-gap resolution is also directly load-bearing. The Three Movements case
contains two surviving structural identities; the unique 13-semitone boundary
selects the expected `G|Ab7`, while the no-gap ablation abstains.

The assignment-veto ablation matches the full suite result. This does not show
that the veto is useless: the frozen Cmaj9 ambiguity also satisfies the
independently fixed rooted-ninth veto, so either component abstains there. It
does mean the author-adjudicated suite supplies no isolated product-policy case
in which assignment ambiguity alone changes the final gate. The complete traces
retain the distinction, and version 1 remains unchanged as preregistered.

## Artifact verification and pins

The generated directory is local under `build/` and is not committed. It
contains 233,887 bytes of complete decision diagnostics, four 17-case prediction
artifacts, four scores containing 15 evaluated cases plus the same two coverage
exclusions, and the provenance manifest. Read-only verification checked every
manifest output hash, all 68 predictions, and all 68 scored-or-excluded case
records without invoking the selector or scorer again.

The inspection and verification commands were:

```sh
shasum -a 256 build/polychord/register-selector-suite-v1/*.json
jq '{schema,source,method,summary,outputs}' \
  build/polychord/register-selector-suite-v1/manifest.json
./.venv/bin/python -c \
  'import hashlib,json,pathlib; d=pathlib.Path("build/polychord/register-selector-suite-v1"); m=json.loads((d/"manifest.json").read_text()); assert all(hashlib.sha256(pathlib.Path(v["path"]).read_bytes()).hexdigest()==v["sha256"] for v in m["outputs"].values()); scores={p.stem.removeprefix("score-"):json.loads(p.read_text())["summary"] for p in d.glob("score-*.json")}; assert len(scores)==4; assert sum(len(json.loads(p.read_text())["predictions"]) for p in d.glob("predictions-*.json"))==68; assert all(len(json.loads(p.read_text())["results"])+len(json.loads(p.read_text())["coverageExclusions"])==17 for p in d.glob("score-*.json")); print("valid: 9 output hashes, 68 predictions, 68 accounted score cases")'
```

Final SHA-256 pins:

- manifest: `8267d84b2f2fc83c532d19504eaa54924c87c6685d9ee5df7ff8ac37e4cbefd6`;
- complete diagnostics:
  `92c50e445e5c90ab2b767fd03aab8c4db419824768245c3e75cb00f5c9db5f5a`;
- full predictions:
  `f8b0d616fb7848bac3f2cb2c279612289eae6d9b06d0e2120ad40f811a757de5`;
- full score:
  `e9949fe1f4f82072cc831a8b288e8bc9f48cd2ec1a6ca7debb0e87efef7916b5`;
- no-integrated-veto predictions:
  `1aab4a430472b305252e47f3178eb54986d4655b79e0a92fc9de51ec206db441`;
- no-integrated-veto score:
  `4f675464b63d0ae015db245566dadbda1568c60221c8935dce4a792860a20b7c`;
- no-assignment-veto predictions:
  `905775e9cbf58ec4d897a3476a168a1328574b27155ce7437163813df3b2d9b3`;
- no-assignment-veto score:
  `1abd6ed5edec743117c7f17a97ca43b38e650a304901471b99774d860bae198d`;
- no-gap-resolution predictions:
  `c1c1835977541065cc92353b5285c4912893dc6f92c8143fe014ac4e2dedbc9e`;
- no-gap-resolution score:
  `250e46cec50845dc4ff4fc106370c7971d43a0a511b3b08f54aa600ad8156536`; and
- protocol: `8c30771b1ec2f907d6e3783ec653f895e2106480e3c2959c3cfe14e1ffa24bcd`.

**Plain-English reading.** On the exact musical policy cases we froze before
seeing any output, the complete rule did everything asked of it. It selected the
right layered reading and exact note division in all six recoverable positives,
and stayed silent on all nine ordinary-chord and scope guards. The comparisons
also show why two parts of the rule are present: without the integrated-chord
filter it produces four known-bad annotations, and without the register-gap
choice it cannot resolve the source-backed case that offers two decompositions.

This is an encouraging internal conformance result, not a scientific accuracy
estimate. The suite is author-adjudicated, two important constructions remain
outside this input condition, and the complete adoption bar still requires
development-corpus dispositions, primary regressions, prior-art baselines,
performance, and device accessibility checks.

**Decision.** Preserve the complete result and all ablations unchanged. Mark
adoption-bar items 2 through 4 satisfied for `polychord-register-policy/1` only.
Do not treat the passing no-assignment ablation as a post-result alternative and
do not alter version 1. Keep the held reserve untouched.

**Next.** Before reading a development selector result, fix the exact corpus
adapters, frame units, primary-result availability, 200-millisecond
stable-display replay, fire-disposition schema, and stopping rules for each
declared development corpus. Distinguish true frame replay from the
committed-event fixtures that omit within-event revoicing; do not label the
latter as live-frame or stable-display evidence without an explicit limitation.

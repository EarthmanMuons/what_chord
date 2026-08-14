# 2026-08-13: Preregister the product suite and baselines

**Goal.** Correct unreachable branches in the frozen product specification and
preregister the complete automatic case inventory, exact scoring behavior, and
prior-art adapters before implementing the new selector or reading any product
or baseline prediction.

**Setup.** Work began from repository commit
`f7d4eef16a856fadf3d0cbe753d0506d6873ce3f`. That commit froze the first product
output and selector. No implementation of `polychord-onset-register-policy/1`,
product fixture, suite prediction, prior-art suite output, development-corpus
output, or held item existed or was read.

The pre-correction digests were:

- product-completion plan:
  `47a6851f59493224e879b192bfbf4090e7caeb8fd26b34fafafd6e0e34311c2b`;
- product output contract:
  `071aa1bd5bb6798505603f27e72a48365c6f6c3c04cca87274072fde4573e024`; and
- onset-register selector:
  `22ad4b91afeb1da7ebd3b03265a16279171c14a988141268cb7f2e952e30d58d`.

The inherited evidence remained pinned and unchanged:

- internal suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`; and
- frame-replay manifest:
  `d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`.

The read-only structural and source inspections included:

```sh
git status --short
git diff -- research/polychord/product-output-contract-v3.md
jq -r \
  '.cases[] | [.id, .epistemicStatus, .productExpectation.class, \
  (.construction.notation.symbol // "-"), .observation.kind, \
  (.observation.fixtureId // "-")] | @tsv' \
  research/polychord/data/internal-suite/suite-v0.json
jq -r '.fixtures[] | [.id, .file, .sha256] | @tsv' \
  research/polychord/data/frame-replay/manifest.json
python3 -c 'import itertools,sys; sys.path.insert(0,"tool/polychord"); \
import register_candidates as r; ambiguous=[]; \
[ambiguous.append((pcs,m)) for n in range(1,13) \
for pcs in itertools.combinations(range(12),n) \
if len((m:=r.chord_matches(tuple(60+p for p in pcs))))>1]; \
print(len(ambiguous)); print(ambiguous[:20])'
python3 -c 'import sys; sys.path.insert(0,"tool/polychord"); \
import register_candidates as c, register_selector as s; \
cases={"disjoint":[42,46,49,60,64,67], \
"upper7":[28,40,44,47,51,55,58,61], \
"multiple-identities":[44,48,51,54,67,71,74], \
"assignment-ambiguity":[48,52,55,67,71,74,79], \
"compact":[48,52,55,64,67,71], \
"rooted-ninth":[48,52,55,67,71,74], \
"seventh-extension":[47,48,52,55,62,66,69], \
"shared":[43,46,50,60,64,67], \
"changed-assignment":[43,46,50,60,64,67,72]}; \
[(print(name),[print(x.symbol,x.gap_semitones, \
s.integrated_tertian_tests(notes,x)) \
for x in c.generate_register_candidates(notes)]) \
for name,notes in cases.items()]'
curl -sS -L --max-time 30 \
  -o /tmp/whatchord-musicpy-7.15.tar.gz \
  https://files.pythonhosted.org/packages/33/0d/bf46de4e00961fc8371af9cf90315f9cf55f51cae417a5f0f0c3dae5413b/musicpy-7.15.tar.gz
curl -sS -L --max-time 30 \
  -o /tmp/whatchord-mingus-6558cac.tar.gz \
  https://github.com/bspaans/python-mingus/archive/6558cacffeaab4f084a3eedda12b0e86fd24c430.tar.gz
curl -sS -L --max-time 30 \
  -o /tmp/whatchord-chordrecgen-3790a4d.tar.gz \
  https://github.com/derrickward/ChordRecGen/archive/3790a4df5f1c3bbef4ff0a27c43ddacc020a6639.tar.gz
shasum -a 256 \
  /tmp/whatchord-musicpy-7.15.tar.gz \
  /tmp/whatchord-mingus-6558cac.tar.gz \
  /tmp/whatchord-chordrecgen-3790a4d.tar.gz
tar -xOf /tmp/whatchord-musicpy-7.15.tar.gz \
  musicpy-7.15/musicpy/algorithms.py
tar -xOf /tmp/whatchord-mingus-6558cac.tar.gz \
  python-mingus-6558cacffeaab4f084a3eedda12b0e86fd24c430/mingus/core/chords.py
tar -xOf /tmp/whatchord-chordrecgen-3790a4d.tar.gz \
  ChordRecGen-3790a4df5f1c3bbef4ff0a27c43ddacc020a6639/IOS/ChordRecognizeGenerate/ChordRecognizeGenerate/ChordRecognizer.swift
```

The exhaustive chord-match check printed `0` and `[]`: none of the 4,095
nonempty pitch-class subsets has more than one identity under the fixed five
layer qualities. This is a structural check, not a product prediction.

The authored-sonority check produced exactly the candidate sets required by the
inventory. In particular, the lower-seventh case produced two distinct
identities, the assignment guard produced two `G|C` assignments, each positive
control had no integrated predicate, and the compact, rooted-ninth, and
seventh-extension guards activated only their declared predicate.

The inspected source archive digests were:

- musicpy 7.15 PyPI sdist:
  `b6e10025648632a666ce99b0647655158a87dc554ebd9edbb9547d87fbf2a3e1`;
- python-mingus commit archive:
  `b0723787b69943940ca7ad1c7dffa3cb27eb83755a2a1bc25f8a8f90cd935462`; and
- ChordRecGen commit archive:
  `6f5bb36fda9156e1dff518387dcf8e95e788f342ec1963cb715573d3541994eb`.

No prior-art detector or new onset selector was executed on a suite observation
during this work.

**What happened.** The case-inventory audit found two unreachable contract
branches before implementation.

First, an unchanged exact sounding-instance binding cannot lose onset support.
The onset record is a deterministic function of the current note-on identities
and fixed thresholds, and this product profile has no evidence expiry. Support
can change only when the assignment, sounding instance, or raw candidate
changes. `layer-separation-support-lost` was therefore removed from the display
reason vocabulary; raw selector abstention and invalidated bindings cover the
reachable transitions.

Second, two different adjacent-register splits cannot both have positive
50/80-ms onset support. For split points `i < j`, any note between them is in
the upper layer at `i` and in the lower layer at `j`. Positive support at `i`
requires its onset to be separated from the notes below `i` by at least 80 ms;
positive support at `j` requires those same onsets to fit together inside a
lower-layer span of at most 50 ms. Both cannot be true. The exhaustive
five-quality check also established that a fixed split has at most one chord
identity. The positive-survivor count is therefore at most one.

That proof removes the product selector's inherited widest-gap tie-break and the
unreachable `multiple-unresolved-identities` reason. Candidate-specific onset
evidence now does all identity resolution after the assignment and
integrated-tertian vetoes. Any implementation state with two positive survivors
is a contract defect, not a musical result.

The selector's dependency table also now pins the final active
product-completion plan rather than the plan digest captured before the prior
freeze commit updated that same file. The earlier log continues to preserve its
actual starting pin; the corrected selector points to the normative plan it now
implements.

`product-suite-v1.md` preregisters a separate automatic conformance suite. It
pins the 17-case construction ruler without copying or inventing timing for it,
keeps static-only cases as coverage and baseline references, and freezes 20
automatic cases in three strata:

- 3 inherited replay cases;
- 12 authored musical-policy cases; and
- 5 authored contract-mechanics cases.

The inventory covers both onset orders, shared and disjoint layers, triads and
seventh chords in both roles, assignment ambiguity, candidate-bound resolution
of multiple structural identities, every integrated predicate, simultaneous and
incomplete history, exact and just-outside 50/80-ms boundaries, sustain,
release, reattack, primary availability, reset, binding and authorization-key
changes, and every reachable display diagnostic.

The product fixtures will use a separate manifest so the new work does not
invalidate the frozen replay-manifest digest used by the earlier internal suite.
The exact scorer requires literal expected cue, raw decision, authorization, and
display data and cannot import the implementation being scored. Coverage
exclusions never count as passes.

`prior-art-baseline-contract-v1.md` freezes the common registered-MIDI input,
raw result retention, exact source pins and invocations, loss of octave
information in mingus, structured lower/upper order in musicpy, conservative
orientation recovery for ChordRecGen, supported-quality normalization, failure
handling, capability exclusions, named-snapshot metrics, and adapted-stream
reporting. Hash-locked transitive dependencies, adapters, smoke controls, and
runtime identities must still be implemented and committed before any suite
target is run.

**Plain-English reading.** The earlier selector carried two pieces of machinery
that can never activate under its own rules. Removing them now makes the first
implementation smaller and prevents us from fabricating tests for impossible
states. The new ruler also stops static musical examples from masquerading as
timed performances: only real or explicitly authored event histories test the
automatic feature. Comparisons with other libraries will use identical note
states and retain what those libraries actually say, including failures and
unsupported answers.

**Decisions.** Keep the identities `polychord-output/3` and
`polychord-onset-register-policy/1`. These are pre-implementation reachability
corrections with no changed result for any admissible input, and no result has
been read. The old and new digests remain in append-only dated entries. If the
same correction were made after a product result, or if an admissible output
changed, a new version would be required.

Use `polychord-product-suite/1` as an author-adjudicated automatic conformance
ruler and `polychord-prior-art-baselines/1` as its descriptive comparison
contract. Preserve `polychord-internal-suite/2` unchanged as the construction
and static register ruler.

Do not implement the selector next. First implement and freeze the product
fixtures, machine suite, validator, exact scorer, source verification,
hash-locked baseline environments, adapters, result schemas, and smoke controls.
That maintains the preregistered boundary.

Final digests for this decision are:

- protocol: `ee737c233396e36f7b04a7fdf30a122de062df67260328f1815bb34d44c52996`;
- product-completion plan:
  `d8c8de418fc5fda1cfd2ad5648632057a84be9c806431f1e4141a767fba16eb3`;
- corrected product output contract:
  `77c2f6a9085aec3a53c733372ae3e3d3e8f20127e6af0f0e74af2f6337301b89`;
- corrected onset-register selector:
  `f909263d052ad88c5f001fe9694ff4a558a3888df0ef541c2eaa83438a9fbc58`;
- product-suite specification:
  `e378f565d4afb9bfd5a753cd7aaccd9ccdff64ac6bfb76d75006e53d5cdfb361`; and
- prior-art baseline contract:
  `4d5766117891254bbf64e54ce4689f380610f53d4b90bad35f4bb1f6cde3e75d`.

**Next.** Implement the machine-readable product fixtures and suite, strict
validator, scorer with deliberate-failure controls, and pinned baseline adapter
substrate. Freeze those artifacts before implementing or executing the new
selector.

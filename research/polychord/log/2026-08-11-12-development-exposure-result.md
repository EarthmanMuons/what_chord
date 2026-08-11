# 2026-08-11: Evaluate development display exposure

**Goal.** Run the frozen register-only selector over its declared development
sources, verify the result before inspection, disposition every full-policy
display, and decide adoption-bar item 5 without opening the held reserve.

**Setup.** The repository was clean at runtime-provenance commit `dc6f5644`. The
two earlier invalid attempts remain preserved as recorded in logs 2026-08-11-10
and -11. ASAP was clean at commit `afc815c75c42e83a79c03feb6da8a35e77d4c6b8`;
POP909 was clean at commit `d83e6edba6872a704f5d3b8b32f5cb540088dae6`. The
designated output directory was absent. The exact command was:

```sh
./.venv/bin/python tool/polychord/development_exposure.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory \
    build/polychord/register-selector-development-exposure-v1
```

The result used Python 3.12.13, Dart 3.12.2, and Mido 1.3.3. The complete
disposition was validated with:

```sh
./.venv/bin/python tool/polychord/validate_development_dispositions.py \
  --review-index \
    build/polychord/register-selector-development-exposure-v1/review-index.json \
  --dispositions \
    build/polychord/register-selector-development-exposure-v1/dispositions.json
```

## Integrity audit

The manifest and accounting audit completed before selector summaries were read.
It established:

- exact command, working directory, repository commit
  `dc6f56442a65c5322d7a059048c3228f8b14e460`, and `repositoryDirty: false`;
- nonempty Python, Dart, and Mido runtime versions;
- 189 declared non-manifest outputs and exactly 189 present, with no missing,
  unexpected, or hash-mismatched output;
- 13 matching contract, implementation, split, and roster pins;
- 183 matching source hashes and aggregate source digests;
- 183 matching summary piece-index hashes, covering exactly 23 ASAP, 101 POP909,
  and 59 When in Rome pieces;
- unique source and review identifiers and consistent 73-item manifest,
  review-index, and blank-template counts;
- no source-label projection violation;
- 16,444 When in Rome source-note occurrences projected to 15,819 distinct
  analyzer pitches, with the preregistered 625 repeated occurrences in 597
  events explicitly counted; and
- no ASAP test MIDI or POP909 held song opened, no corpus label supplied to
  analysis, and no stable-display claim made from When in Rome.

The initial 190-file artifact inventory, before the separately authored
disposition file, has SHA-256
`37b480254e67b3f9785b189a566aa14039369c9cf423ee8c89975fe43962d4ba`. After
disposition, the complete 191-file inventory has SHA-256
`22eb44a6c396e66eca371622969578f0e26c7d67b4c48c879ca481cb3adf038a`. Key artifact
hashes are:

- manifest: `3c098224a2ad77979005b3ae575b855a0523f2703559d1b80ebd43be07250178`;
- ASAP summary:
  `8c197126de163871a26b9b0d464c487711de223dfccc3365af83f393bcaa10c9`;
- POP909 summary:
  `46855886e83fa217d4ea53d0103da9e699e42b724cb042276b1a91f478af49ae`;
- When in Rome summary:
  `b886be41fad8bf7cadbea603865b7e3ed5e8205cd01a2b91f8fff6ec6a09e927`;
- review index:
  `64352b871bd4859ab96e58a0d7247c7cffe33355943c8d2a88bcf66c5ceb68c7`; and
- completed dispositions:
  `08ca572a11d3d3fb64acaa27ef5f6f1be32a9558b1aaef41fdd86431b884f7f0`.

## Results

The frame-capable sources contain 31,093,273 milliseconds of sounding-note
state: 6,607,780 in ASAP and 24,485,493 in POP909. There were no primary-context
availability warnings. Results by frozen profile are:

| Corpus       | Profile                 | Raw selections | Stable episodes/proposals | Displayed/attributed ms |
| ------------ | ----------------------- | -------------- | ------------------------- | ----------------------- |
| ASAP         | full                    | 37 frames      | 0 episodes                | 0                       |
| ASAP         | without assignment veto | 37 frames      | 0 episodes                | 0                       |
| ASAP         | without gap resolution  | 37 frames      | 0 episodes                | 0                       |
| ASAP         | without integrated veto | 120 frames     | 4 episodes                | 279                     |
| POP909       | full                    | 456 frames     | 73 episodes               | 18,201                  |
| POP909       | without assignment veto | 459 frames     | 73 episodes               | 18,201                  |
| POP909       | without gap resolution  | 440 frames     | 68 episodes               | 18,160                  |
| POP909       | without integrated veto | 2,032 frames   | 294 episodes              | 102,470                 |
| When in Rome | full                    | n/a            | 0 proposals               | 0                       |
| When in Rome | without assignment veto | n/a            | 0 proposals               | 0                       |
| When in Rome | without gap resolution  | n/a            | 0 proposals               | 0                       |
| When in Rome | without integrated veto | n/a            | 4 proposals               | 2,750                   |

The full selector's 73 episodes occur in 23 of the 101 POP909 sample songs. Its
18,201 displayed milliseconds are 0.0743% of POP909 sounding time and 0.0585% of
combined frame-capable sounding time. All appearances matured at exactly the
frozen 200-millisecond threshold. Episode duration was minimum 0, median 179,
p90 563, and maximum 1,027 milliseconds. Three episodes had zero duration. The
remaining clears were 43 exact-assignment invalidations and 30 losses of
displayable primary output. The gate suppressed 45 unstable raw selections.

All 73 appearances occurred while the pedal was down; 72 included one or more
pedal-sustained pitches. Pedal use alone was not treated as an error because it
is normal accompaniment performance. The musical disposition instead asked
whether the complete sounding set preferred a constructional polychord or an
ordinary integrated reading.

## Complete disposition

Every full-selector episode was reviewed from its exact assignment, primary
reading, timing, and pressed-versus-sustained state. The reviewer field
transparently identifies `OpenAI Codex (author-directed review)`; this remains
the contract's product-safety author adjudication, not independent annotation or
ground truth. The local in-app browser was unavailable, so review used the same
immutable structured evidence that generates the HTML packet rather than
claiming visual interaction with the rendered page.

The validated disposition is:

| Disposition                           | Count |
| ------------------------------------- | ----: |
| `in-scope-polychord`                  |     0 |
| `ordinary-integrated-harmony`         |    70 |
| `transient-or-serialization-artifact` |     3 |
| all other frozen categories           |     0 |

The 70 ordinary cases all have a coherent single-chord reading from the parallel
primary path. Repeated examples include `F#m|C#m` versus `F#m9/C#`, `Fm7|Eb`
versus `Fm11/Eb`, `Gm7|F` versus `Gm11/F`, `Dm|Am` versus `Dm9/A`, and `B|Gmaj7`
versus `Gmaj7b13`. The proposed layers redistribute chord tones and extensions
across register; the secondary notation is not preferable. The three remaining
cases are identical `Em7|Dm` versus `G13/D` appearances in song 685. Each
matured and cleared at the same timestamp when the primary became unavailable,
giving zero display dwell and making the tied event boundary a serialization
artifact.

## Ablation reading

The integrated-tertian veto is the dominant existing guard: removing it adds 221
POP909 stable episodes, four ASAP episodes, and all four When in Rome event
proposals. It is nevertheless too narrow, because all 73 episodes that survive
the full policy are still ordinary integrated harmonies. Exact-assignment
ambiguity has no stable-display effect in this exposure, although it removes
three POP909 raw-selection frames and 214 raw-selection milliseconds. Removing
widest-gap resolution reduces rather than increases the stable count by five,
showing a small interaction between deterministic assignment choice and the
stability gate.

**Plain-English reading.** The detector is quiet, but not safely quiet. It shows
only 18 seconds of secondary annotations across more than eight and a half hours
of sounding development input, yet every one of those displays is wrong for the
declared product semantics. Most are ordinary extended or altered chords split
into two register groups, and three exist for no measurable duration. A low fire
rate cannot compensate for a zero-of-73 useful-display rate.

**Decision.** Adoption-bar item 5 fails. Do not proceed to the 808-song held
POP909 reserve, product integration, performance/device qualification, or a
claim that `polychord-register-policy/1` is safe. Preserve this result
unchanged; it cannot tune v1 in place.

The failure is informative rather than a failure of the constructional premise.
The internal adoption suite still establishes that the generator and selector
can represent all six frozen positives and abstain on all nine frozen guards.
Development exposure shows that the current integrated-harmony exclusion does
not cover ordinary extensions, suspensions, alterations, and inversions broadly
enough for product use.

**Next.** Perform a label-free error analysis of the 33 distinct
polychord-versus-primary reading pairs already exposed here. Before changing a
lever, preregister a version-2 hypothesis that recognizes a broader integrated
single-chord explanation without another primary-analyzer call and state how it
will be evaluated without spending the held reserve. Keep the valid v1 result as
the fixed comparison.

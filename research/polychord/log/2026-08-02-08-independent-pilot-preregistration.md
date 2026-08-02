# 2026-08-02: Independent pilot preregistration

**Goal.** Freeze how the six-case annotation pilot is handed to an independent
annotator and how pre-adjudication disagreement is reported, before any
independent response is observed.

**Setup.** Base repository commit `aba3d818`. The ruler, guide, packet
generator, validator, agreement code, and this entry land as one method change.
No completed independent annotation response existed or was inspected while
these rules were written. No corpus fixture or held-out split was read.

Working directory: `/Users/abs/src/whatchord`. The reproducibility commands are:

```sh
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json --review-packet-out research/polychord/pilot-review-template-v0.json
python3 tool/polychord/pilot_ruler.py research/polychord/pilot-ruler-v0.json --validate-review research/polychord/pilot-review-template-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
git diff --check
shasum -a 256 research/polychord/pilot-ruler-v0.json research/polychord/pilot-annotation.md research/polychord/pilot-review-template-v0.json tool/polychord/pilot_ruler.py tool/polychord/pilot_agreement.py
```

Pinned SHA-256 digests:

- ruler: `f5fa532757cba27ef21760920647d612a7cba0f91b921993a4f0c9e7ca35f5c3`;
- annotation guide:
  `f311f428603fa3a7a65b7834f34c02b298c33c53dce1193d9241e65399c9c4d8`;
- blinded template:
  `8eb672bf73ba7dea9eb781bd3c1886b0542030104c24915399e78a92986c70fa`;
- packet generator and validator:
  `9596f77125e651c8254bdfbfad59b2a6ee0cb79c73ccb144fa296a9374d9bad4`;
- agreement reporter:
  `183db56152811b8e08f8d13c75311cb8e92d3ac22050dc5c9bd88b9fbd8dc804`.

**What happened.** The generated packet contains six neutral, deterministically
shuffled review IDs. It omits the initial case IDs, labels, layer assignments,
alternatives, eligibility judgments, rationales, and synthetic generation prose.
It retains only raw synthetic MIDI/onset evidence or pinned public score
locations. The template pins the ruler and guide digests; validation rejects
added mapping fields, changed evidence, incomplete note accounting, and an
optimized-Python run that would disable assertions.

The response schema permits `abstain`, requires a reason for every eligibility
judgment, and requires each synthetic MIDI note to appear in exactly one layer
or `unassignedMidiNotes`. Completed reviews use a pseudonymous annotator ID and
remain separate, immutable raw data.

The agreement reporter was implemented and tested before data collection. It
reports raw exact confusion tables for construction tag, observation unit, and
each input condition; order-invariant exact layer pitch-class agreement;
maximum-matched layer Jaccard; shared-pitch-class agreement; and exact synthetic
note partitions. Unnormalized identity-text agreement is diagnostic only.
Alternatives receive qualitative disposition. Abstentions count as tag
disagreements. Adjudicated values are excluded.

**Plain-English reading.** The second reviewer will not see our answers, and we
have fixed how their answer will be compared with ours before receiving it. The
reviewer must still know which score page to inspect, so this is label-blinded,
not work-blinded or double-blind. Six examples can find ambiguous instructions;
they cannot establish a general reliability statistic.

**Decisions.** Do not report kappa, confidence intervals, hypothesis tests, or a
general reliability claim from this pilot. Any construction-tag or observation-
unit disagreement or abstention requires a documented rubric review and a new
pilot version before the full ruler freezes. A layer or synthetic partition
mismatch blocks freezing the decomposition representation. An eligibility
disagreement blocks using that input condition as an accuracy-eligibility rule
until revised and independently retested.

**Next.** Give only `pilot-annotation.md` and `pilot-review-template-v0.json` to
a genuinely independent music-theory annotator. When a completed packet returns,
validate it, preserve it under `reviews/`, generate the pre-adjudication report
before discussion, and record the response and report digests in a new dated
measurement entry.

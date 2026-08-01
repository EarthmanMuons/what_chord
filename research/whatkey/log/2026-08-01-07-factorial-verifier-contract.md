# 2026-08-01: Correct the factorial confidence-setting verifier

**Goal.** Resolve a provenance-check failure encountered after running the eight
predeclared R4 development cells, without calculating or adopting the factorial
endpoint.

**What happened.** All eight harness commands completed on clean commit
`d3ee062f45496df9be3ad74d5d686e87a71058a6`. The first scoring command then
stopped before writing `development-factorial.json` because the verifier
required the serialized detector configuration to contain
`confidenceWeighted=false`. A functional-zero cell instead records
`functionalBlend=0.0` and `evidence: disabled`. This is the harness's faithful
representation: with a zero blend the functional evidence object is not
instantiated, so its confidence-weighting field is inert and absent. Every
harness report separately preserves the exact invocation, including the
predeclared `--confidence-weighting off` option.

The verifier now continues to check all consequential active settings in the
serialized detector configuration, but checks the confidence-weighting option in
the tokenized recorded command. A synthetic regression test covers both the
valid disabled-evidence case and rejection of a command that says
`--confidence-weighting on`.

**Plain-English reading.** The experiment ran the setting we declared. The
checker looked for that setting in an object which correctly did not exist when
its blend was zero. The recorded command is the right place to verify an option
that was supplied but had no active component to configure.

**Decisions.** Preserve all eight cell artifacts unchanged. Do not rerun the
detectors: this correction changes only how their provenance is verified. Do not
calculate the R4 effects until the corrected verifier and this entry are
reviewed and committed. The harness summaries were necessarily visible while
diagnosing the failure, so R4 remains explicitly post-hoc/explanatory rather
than blinded or confirmatory.

**Next.** Run Python formatting, lint, compilation, and the synthetic test
suite. Commit the correction as a pre-endpoint checkpoint, then rerun only the
factorial scorer against the immutable eight cell artifacts.

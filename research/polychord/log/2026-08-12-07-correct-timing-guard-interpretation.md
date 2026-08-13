# 2026-08-12: Correct the timing guard interpretation

**Goal.** Reconcile the completed timing result with its preregistered stopping
rule after the active plans incorrectly stated that no cue-positive boundary
guard existed, while preserving the frozen requirement for ordinary integrated
controls.

**Setup.** This is an interpretation correction, not a new measurement. Work
began from clean commit `379568299cc014e26fefac5befb7d87923fb0975`. The frozen
inputs are:

- timing preregistration SHA-256:
  `957b309db295192cba95a5f4ed20904deaea45e206246f7ce3958efa2cd37522`;
- timing result-log SHA-256:
  `18a723cd2f47853dbe688ba38eb1cb1e2266bcf2ee0508e7767867dfeebef6fe`;
- frozen automatic-output contract SHA-256:
  `f4165d6016a94d6a7e33295b03104cecab3e29bf937cba40d90947adfecc4dee`; and
- local timing report SHA-256:
  `69dae7ed22fd7fed12e195bbb05a71ade6ba4d03085a4e4e83de95b7be3be8ca`.

The report remains ignored at
`build/polychord/automatic-timing-sensitivity-v1.json`. No source file, corpus
item, selector result, or held-reserve item was opened for this correction.

The exact read-only check was:

```sh
jq -e '
  (.lisztSourceCase.fixedConstructionLabel == "boundary") and
  (.lisztSourceCase.profiles[
    "coherent-separated-onsets-50-50ms/sensitivity-1"
  ].summary.positiveCandidateInstances == 10) and
  (.lisztSourceCase.profiles[
    "coherent-separated-onsets-50-50ms/sensitivity-1"
  ].episodes | length == 2) and
  (.lisztSourceCase.profiles[
    "coherent-separated-onsets-50-80ms/sensitivity-1"
  ].summary.positiveCandidateInstances == 10) and
  (.lisztSourceCase.profiles[
    "coherent-separated-onsets-50-80ms/sensitivity-1"
  ].episodes | length == 2) and
  (.lisztSourceCase.profiles[
    "coherent-separated-onsets-50-100ms/sensitivity-1"
  ].summary.positiveCandidateInstances == 0) and
  (.assertions | to_entries | all(.value == true))
' build/polychord/automatic-timing-sensitivity-v1.json
```

It returned `true`.

**What happened.** The preregistration's stopping rule says that when a
lower-gap profile makes the Liszt boundary positive, the case must be treated as
a source-backed cue-positive guard for that profile. The successful report
records exactly that outcome: the fixed `boundary` case has ten positive
serialization frames grouped into two episodes at both 50 and 80 milliseconds,
and zero positive instances at 100, 200, or 300 milliseconds.

The first post-result synthesis correctly retained Liszt's boundary label and
correctly selected no timing row, but it then said that no matched cue-positive
guard existed. That statement failed to credit the preregistered boundary-guard
result. It also collapsed that result with the stronger frozen output-contract
requirement for cue-positive ordinary integrated controls. The measurement and
all numerical results remain unchanged.

**Plain-English reading.** The Liszt example already supplies the safety example
we wanted for either lower onset setting: it shows that the timing cue can fire
on music that should not be named as a static polychord. What is still missing
is a genuine polychord with exact note-event history that receives the same cue,
plus the matched cue-positive ordinary integrated controls required by the
frozen output contract. Having a boundary alone is not a reason to choose the
setting.

**Decisions.** Treat Liszt as the source-backed onset boundary guard for
`coherent-separated-onsets-50-50ms/sensitivity-1` and
`coherent-separated-onsets-50-80ms/sensitivity-1`. Select neither profile and do
not change the fixed construction label, report, preregistration, or result log.
The onset branch still cannot license because neither profile has an
event-complete source-attested automatic-decision positive or cue-positive
ordinary integrated controls. The already admitted Shrovetide transition remains
the motion branch's source-backed boundary; motion likewise lacks a
source-attested automatic-decision positive and cue-positive ordinary integrated
controls.

Update only the living protocol and plans. Preserve the original result log so
the interpretation error and its correction remain auditable.

**Next.** Search specifically for an event-complete source-attested positive and
matched cue-positive ordinary integrated controls under an already
boundary-guarded cue profile. Do not spend effort finding another onset boundary
unless a new onset profile is prospectively introduced, and do not read the held
POP909 reserve.

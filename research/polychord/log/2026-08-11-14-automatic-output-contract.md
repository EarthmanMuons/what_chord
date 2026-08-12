# 2026-08-11: Define the automatic output contract

**Goal.** Convert the post-v1 evidence boundary into an exact output and history
contract before choosing a temporal selector or changing the frozen suite.

**Setup.** Work began from clean commit
`e1b8858c02762056d201cfc4cd9b58923c970500`. No corpus result, held POP909 song,
selector output, or new suite label was read. The design used these committed
inputs:

- v2 prerequisite plan:
  `901f0c661c030a49e5a85c7edf742e7db7d6d9bc176b35bd58ff786fa3d49994`;
- frozen v1 output contract:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`;
- frame replay schema:
  `93cbfe0cb77cb570d4c444438b8cde8df82c04e68e0667c134ba21cde10e85b8`;
- onset evidence schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- onset support rule:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`;
- frame-transition evidence schema:
  `7db90bb1a40fc0a34be5a1ab84da0724ae2da1db0dd8529b81e2d31970eccc78`; and
- motion support rule:
  `50886b62cf5e361148af3b05fd015f0e75a54eb5f4a36fac4ac690f07d57e083`.

This was a contract-design step, not a measurement. The existing zero-positive
POP909 onset and motion results were already disclosed by log 2026-08-11-13 and
were not used to tune a new threshold.

**What happened.** `automatic-output-contract-v2.md` defines
`polychord-output/2` for the `automaticTimestampedMidi` input condition. It
requires every licensing cue to bind one exact candidate and every assigned
note's current sounding instance. Candidate support is positive only when at
least one preregistered licensing cue is complete, positively interpreted, and
fully bound. Neutral and unavailable evidence both require automatic abstention,
but receive different diagnostic reasons.

The decision shape records a tracker epoch, exact observation, complete
candidate list, candidate-bound cue and aggregate records, zero or one selected
candidate, authorization key, selector identity, one abstention reason, and all
true abstention predicates. Unknown carried-in instance identifiers remain
explicit rather than being presented as a complete binding. Atomic cue results
combine only by the declared OR aggregation; an AND rule must be a separately
versioned composite cue.

The contract makes evidence lifetime causal rather than threshold-based. Support
can remain current while the same target sounding instances persist, including
through a note-off held by sustain, but it is revalidated after every normalized
event. Reattack, changed assignment, tracker reset, or loss of all positive cue
support invalidates authorization. No arbitrary wall-clock expiry was inferred
from the development result.

The stable gate now keys continuous authorization on the exact candidate plus
its sounding-instance binding. It can mature between MIDI events, restarts when
the binding changes, and clears immediately when support is lost. Changing from
one positive cue to another does not restart the gate when authorization stays
continuous.

**Plain-English reading.** Timing or motion evidence must explain this exact
pair of chordal units made from these exact sounding note attacks. Evidence for
an earlier chord, a different split, or the same MIDI pitches played again does
not carry over. Once that evidence is present, the candidate still waits the
same 200 milliseconds before display and disappears as soon as its evidence or
notes stop being valid.

**Decisions.** Freeze the new input condition, exact candidate and
sounding-instance binding, three-state support aggregation, two new abstention
reasons, decision shape, causal reset behavior, authorization key, and
support-aware stability semantics as `polychord-output/2`. Keep release/pedal as
raw evidence rather than a licensing cue. Keep static registered MIDI eligible
for reproducing v1 but ineligible for v2 automatic display. Treat explicit
manual upper/lower input as a separate future condition.

Do not yet choose an onset or motion licensing branch, endpoint rule, structural
selector, suite, scorer, implementation, or corpus evaluation. Each licensing
branch first needs evidence-complete source-attested positives and matched
ordinary-integrated controls.

**Next.** Create a versioned suite plan for `automaticTimestampedMidi`. Preserve
all v0 construction and candidate records, classify their temporal coverage, and
identify the source passages required before any exact selector can be
preregistered.

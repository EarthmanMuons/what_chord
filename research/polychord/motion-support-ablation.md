# Conservative polychord motion-support ablation

Status: active research contract for `rigid-layers-oblique-or-contrary/1`,
emitted as `polychord-motion-support/1`. This is a named interpretation of
`polychord-frame-transition-evidence/1`. It supplies one-sided evidence for an
explicit endpoint candidate and layer-correspondence hypothesis; it does not
reject or rank candidates, choose a correspondence, infer monophonic voices, or
authorize displaying a polychord.

The canonical implementation is `tool/polychord/motion_support.py`. Its
categorical policies are constants, not command-line options.

## Claim boundary

The ablation asks one narrow question:

> Under one explicit correspondence between source and target candidate layers,
> does each layer undergo an exact parallel translation in MIDI pitch while the
> two layer translations move obliquely or in contrary directions?

A positive result means only that this strict motion pattern supports treating
the endpoint register groups as two constructional layers. It does not establish
perceptually independent streams, compositional intent, two keys, a ground-truth
polychord, or individual note-to-voice identity. A neutral result is not
negative evidence.

The caller selects the two exact endpoint frames. This ablation defines no
lookback, adjacency, maximum elapsed time, intervening-candidate, dwell, or
stable-display rule. Any measurement must preregister its endpoint enumeration
separately. The complete transition window remains in the output so zero-dwell
events and any intervening silence or revoicing cannot be hidden.

## Perceptual and computational rationale

Moreira's polychord discussion, following Bregman and Huron, describes chordal
notes moving in exact parallel as coalescing into one textural stream. Separate
chordal groups are favored when each group moves together internally while the
groups have oblique or contrary motion relative to one another. His Petrushka
example is especially close to this task: two moving triadic groups form two
textural streams, rather than six inferred monophonic voices
([Moreira 2025, paragraphs 6.2-6.3](https://mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html)).
Huron's broader account treats parallel motion as an auditory-grouping cue
([2016](https://doi.org/10.7551/mitpress/9780262034852.001.0001)).

This first ablation therefore operates on complete chordal sets. It does not
solve symbolic voice separation. That adjacent task commonly uses pitch and
temporal proximity, crossing constraints, annotated voice labels, or learned
note affinity, as documented in `prior-art-search.md`. Those methods answer a
larger question than this product experiment requires.

Exact set translation is intentionally stricter than the perceptual literature.
It gives the term **parallel motion** one deterministic, threshold-free meaning
for this ablation: every MIDI note in a layer is shifted by the same signed
number of semitones, with no entry, exit, doubling change, internal revoicing,
or quality change. This is a relation between two sets. It does not assert that
each source note was heard as the same continuing monophonic voice as its
translated target note.

## Fixed layer transformation

For each relation named by a layer-correspondence hypothesis, let `S` be the
strictly increasing source MIDI-note list and `T` the strictly increasing target
list. The raw MIDI-set relation is an `exactMidiSetTranslation` only when:

1. `S` and `T` have the same cardinality;
2. there is one signed integer `d` such that
   `T == [source_note + d for source_note in S]`.

When those conditions hold, `translationSemitones` is `d`. Otherwise it is
`null`. A finite nonempty pitch set has at most one exact translation to another
set, so the rule does not choose among note pairings or optimize a distance.

The relation qualifies for motion support only when the raw set translation is
exact **and** the target chord quality equals the source quality and the target
root pitch class equals `(sourceRootPc + d) mod 12`. The output keeps these as
separate `exactMidiSetTranslation` and `chordIdentityFollowsTranslation`
diagnostics. `bothLayersExactTranslations` is true only when both diagnostics
are true for both mapped layers. The identity check is redundant for valid
output from the fixed generator but protects the interpretation from malformed
or later-incompatible evidence.

Entry, exit, changed doubling, inversion change, and internal revoicing all make
the relation non-rigid. They remain neutral. A later, more permissive profile
would need an explicit voice-assignment or set-matching model and separate
provenance.

## Fixed between-layer classification

When both relations in a hypothesis are exact translations, their signed lower
and upper source-layer deltas receive exactly one class:

- `static`: both deltas are zero;
- `common-translation`: both deltas are the same nonzero value;
- `oblique`: exactly one delta is zero;
- `contrary`: one delta is negative and the other positive; or
- `unequal-similar-direction`: both are nonzero with the same sign but unequal
  values.

Only `oblique` and `contrary` emit `motionSupport: positive`. `static`,
`common-translation`, and `unequal-similar-direction` are neutral. Common
translation moves the complete sonority as one rigid set and therefore does not
differentiate its proposed layers. The same-direction unequal case may be
musically meaningful, but the reviewed polychord-specific source does not make
it as clear a segregation cue as oblique or contrary motion, so schema 1 does
not grant it support.

If either layer is not an exact translation, `betweenLayerMotionClass` is `null`
and support is neutral. There is no interval magnitude threshold,
motion-duration threshold, score, weight, or confidence.

## Correspondence and retained instances

Both endpoint correspondence hypotheses from the transition contract are
interpreted independently and remain unranked:

- `register-role-preserving`; and
- `register-role-exchanging`.

Exact retained sounding instances are stronger facts than modeled set
translation. Their relation to each hypothesis is summarized as:

- `consistent` when at least one is retained, all retained instances follow the
  hypothesis, and none falls outside it;
- `contradictory` when any retained instance falls outside the hypothesis; or
- `none` when the endpoints share no sounding instance.

A contradictory hypothesis is always neutral, even if its pitch sets otherwise
form supporting translations. Consistent retained evidence is not required for
positive support: exact rigid translation may supply the modeled correspondence
when every note is rearticulated. `none` is reported rather than silently
treated as continuity.

The ablation never emits a selected hypothesis. If unusual evidence allowed more
than one positive hypothesis, both would remain visible for later policy to
resolve.

## Score-derived construct check

After the frozen POP909 exposure measurement returned zero positive windows, the
specific scholarly example that motivated this ablation was transcribed as
`stravinsky-shrovetide-oblique-motion`. This is a transparent post-result
construct check, not a preregistered accuracy case or an independent holdout.

Moreira's Example 17 reproduces the triadic counterpoint in Stravinsky's “The
Shrovetide Fair,” mm. 41–53, and describes parallel motion within each
three-note register group together with oblique or contrary motion between the
groups. The first two depicted attacks supply these endpoints:

| Endpoint | Lower layer | Upper layer         |
| -------- | ----------- | ------------------- |
| Source   | C4 E4 G4    | Bb4 D5 G5 (G minor) |
| Target   | Bb3 D4 F4   | Bb4 D5 G5 (G minor) |

The lower C-major set translates by -2 semitones to B-flat major while the upper
G-minor set is rearticulated at delta zero. Both endpoints produce one complete
adjacent-register candidate. The register-role-preserving hypothesis therefore
receives `oblique` positive support; the exchanging hypothesis is non-rigid and
neutral.

The official
[MTO example image](https://www.mtosmt.org/issues/mto.25.31.4/moreira_ex17.png)
has SHA-256 `9278955cb63cab32c2675aeee9e257cc4c1e0e4d34ca11229781ba7106d7565f`.
The fixture normalizes one notated quarter-note interval to 500 milliseconds and
serializes simultaneous releases before attacks. Its velocity and
within-timestamp order are representational choices, not performance
measurements; all zero-dwell intermediate frames remain explicit.

This check establishes that the strict rule can recognize one source-attested
layer-motion construct. It does not establish a user-facing polychord label.
Moreira places both streams in one G-Dorian space, and the two endpoint pitch
collections also admit compact C9 and Gm7 readings. Motion support remains
one-sided evidence to be combined with a separately frozen product policy.

## Output

The command preserves the source fixture identity and hash, complete selected
window, endpoint candidates, and complete transition evidence for each candidate
pair. It adds:

- `ablationId` and the four exact categorical `parameters`;
- one interpretation for each correspondence hypothesis;
- per-relation cardinality, exact-translation, signed-delta, and
  chord-identity-consistency facts;
- `retainedInstanceEvidence`;
- `bothLayersExactTranslations`;
- `betweenLayerMotionClass`;
- `motionSupport`: `positive` or `neutral`; and
- ordered `reasonCodes` explaining the result.

The implementation contains no negative evidence, distance optimizer,
note-to-voice link, crossing rule, entry or exit cost, confidence, ranking,
abstention, endpoint selection, display rule, onset weighting, pedal weighting,
or channel/source inference.

## Synthetic controls

`two-register-contrary-motion` changes `C|Gm` to `D|Fm`. The complete lower
G-minor MIDI set translates down two semitones to F minor while the complete
upper C-major set translates up two semitones to D major. The source notes are
released and target notes attacked at the same timestamp, with exact event order
and zero-dwell intermediate frames retained. The register-role-preserving
hypothesis has no retained-instance evidence, two exact translations, a
`contrary` classification, and positive support. The exchanging hypothesis is
non-rigid and neutral.

`two-register-inner-motion` remains a complementary neutral control. Under the
register-role-preserving hypothesis, lower G minor changes to G major and upper
C major changes to C minor through one departed and one arrived pitch in each
layer, so neither relation is an exact translation. Under the exchanging
hypothesis, the endpoint sets happen to form exact translations of plus and
minus 17 semitones, but all four retained sounding instances contradict that
correspondence. Both hypotheses therefore remain neutral. The apparent inner
links are not promoted to observed voice identities.

Unit controls additionally freeze oblique positive support and neutral outcomes
for static layers, whole-sonority common translation, unequal same-direction
translation, cardinality change, corrupted identity, and contradiction by a
retained instance. These are model invariants, not accuracy labels or human
perception results.

## Reproduction

```sh
python3 tool/polychord/motion_support.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-contrary-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 17

python3 tool/polychord/motion_support.py \
  --fixture \
  research/polychord/data/frame-replay/stravinsky-shrovetide-oblique-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 17
```

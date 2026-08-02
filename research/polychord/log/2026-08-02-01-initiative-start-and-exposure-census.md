# 2026-08-02: Initiative start and polychord exposure census

**Later scope correction.** This initial census operationalized an upper-
structure boundary shape, not the general polychord definition: the layers used
asymmetric vocabularies, incomplete lower shells were admitted, and shared-tone
layers were excluded. Logs -03 and -04 identify parts of that mismatch; log -06
replaces the design with symmetric named profiles. The measurements below remain
valid for the original profile and are retained as boundary evidence.

**Goal.** Scope polychord naming (two independent chords sounded together, like
an upper triad over a lower chord) by measuring, on the octave-preserving
corpora we already hold, how often observed voicings look polychord-shaped and
what a candidate generator would touch. This is the phase-0 question from the
feasibility review: understand how often this would fire before designing any
lever.

**Context.** The engine's article lists polychords as not currently handled (the
best single-chord description of the combined note set wins), and the Petrushka
pitch set {C,E,G,Bb,Db,F#} is a golden resolving to C7(b9,#11) at cost near 1.0
with zero unexplained tones: the canonical polychord already has a complete
single-symbol explanation, so any polychord reading competes inside the 0.25
near-tie window or not at all. The one shipped register rule,
`VoicingEvidence.supportsUpperStructureSlash`, detects chord-over-bass-note,
never chord-over-chord. History events retain full `ObservedVoicing`, and the
analyzer cache is already keyed on `voicing.signature`, so voicing-sensitive
candidate work is architecturally open.

**Setup.** New `tool/polychord/split_census.py` with two detectors, run over
whatkey-fixture event streams (committed events, 3+ sounding notes, 200 ms
stability):

- Registral: split the distinct sounding notes at each register gap of at least
  G semitones (G swept over 3, 5, 7); fire when the upper stack is exactly a
  plain major or minor triad, the lower stack matches a small closed template
  list (major/minor triads, dominant7, major7, minor7, power, seventh shells),
  and the stacks share no pitch class. Widest qualifying gap wins.
- Pitch-class-only: same shapes, register ignored; fire when the distinct pitch
  classes partition exactly into upper triad plus lower template with the bass
  in the lower part. This measures the exposure of a register-blind generator;
  partitions per fired event measure its ambiguity.

Smoke checks before the runs: the Petrushka voicing [48,52,55,66,70,73] fires as
F#|C at every G; a two-handed C major (C2 G2 + C4 E4 G4) is blocked by the
shared-pitch-class rule at every G; a jazz shell-plus-triad D-over-C7
[36,52,58,62,66,69] fires only at G=3 (the right-hand sits a fourth above the
shell), which calibrates G=3 as the liberal end of the sweep.

Commands:

```
python3 tool/polychord/split_census.py \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --out build/polychord/wir-dev.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-shipped \
  --split-file research/performed-input/data/splits/asap-wir-nc-v2.json \
  --split development --out build/polychord/asap-dev.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/pop909-cur \
  --out build/polychord/pop909.json
```

Fixture provenance: `asap-wir-shipped` engine commit 9dc97571, profile current,
clean; `pop909-cur` engine commit 9dd07bed, profile current, clean;
`when-in-rome-v1` is the committed fixture set. Development splits only; no test
split was read.

**Registral exposure is near zero everywhere.** Fired share of event mass (fired
events in parentheses):

| corpus        | events | G=7         | G=5         | G=3         |
| ------------- | ------ | ----------- | ----------- | ----------- |
| WiR dev       | 3,694  | 0.0000 (0)  | 0.0000 (0)  | 0.0007 (1)  |
| ASAP dev      | 6,301  | 0.0004 (4)  | 0.0004 (5)  | 0.0004 (5)  |
| POP909 sample | 28,722 | 0.0005 (10) | 0.0007 (17) | 0.0008 (23) |

Real playing almost never sounds like two registrally separated complete
disjoint sonorities. And every fired example is a boundary case the engine
already names, not a bitonal sonority: the m11 identity (D|Em read today as
Em7(9,11), cost 0.65), stacked-fifth sus textures (Fm|G:power read as
G7sus4(b9), cost 0.55; B|A:power read as Amaj7sus4(9), cost 0.75), and a
shell-plus-triad Bm|A read as Amaj7(9) at cost 0.35. Fired events sit in the
expensive tail (mean top-1 cost 0.57 to 0.95 against corpus baselines 0.17 to
0.33; on POP909 at G=7, 53% of fired mass carries 2+ extensions against 12%
baseline) but nothing is unexplained. Zero genuinely bitonal instances in
32,000+ scored events across three idioms.

**A register-blind generator over-fires by two orders of magnitude.** The
pitch-class-only detector fires on 0.70% of WiR dev, 2.1% of ASAP dev, and 12.5%
of POP909 event mass (2,379 events), with up to three distinct partitions per
event (POP909: 1,779 single, 457 double, 143 triple). Ordinary pop piano (maj9,
m11, add-tone pads under pedal) partitions into triad-plus-template constantly.
The same lesson shows in mingus, the first library found in this survey that
names polychords: its overlap-permissive, unranked slice enumeration returns
Bm|CM as the top reading for a plain Cmaj13(#11) voicing (details in the
external-landscape entry; log -05 later adds musicpy and ChordRecGen). Register
separation is the only gating evidence the current input carries, and it is the
difference between these two numbers; this touches the standing
voicing-is-evidence constraint and is flagged in PROTOCOL.md as a decision any
lever must record explicitly.

**What the census settles for the initiative.**

- Under this initial upper-structure profile, fire rate with registral gating is
  roughly 0.05% of committed-event mass.
  (Corrected by the review in log -04: committed events snapshot the onset
  voicing and ignore same-identity revoicing, so frame-level and display-level
  exposure must be measured separately before this becomes a safety claim, and
  the adoption guard must instrument the adopted generator rather than this
  census detector.)
- No corpus we hold provides positive polychord ground truth; the fired sets are
  boundary cases where the single symbol is conventionally right. The ruler must
  be hand-authored goldens (positives from literature and jazz practice,
  boundary cases like m11 and upper-structure voicings where the single symbol
  must win, negative guards like wide same-chord voicings).
- The value case is deliberate probing (a musician playing a sonority to see
  what it is called), not corpus accuracy; adoption criteria should be golden
  agreement plus zero corpus regression, not corpus-metric gains.

**Plain-English reading.** We asked how often real playing, classical or pop,
looks like an upper triad over a complete chord or lower shell. The answer is
almost never: about one event in two thousand, and even those are familiar jazz
shapes with ordinary names, not Stravinsky-style clashes. But if we ignored the
keyboard layout and only asked whether the notes could be split into those
shapes, an eighth of pop playing would qualify, usually several ways at once.
This supports register as important evidence for that narrow screen; it does not
establish general polychord exposure or safety. The test cases that define
success still have to be written by hand because no corpus surveyed so far
provides labels for the real thing.

**Next.** External-landscape entry (mingus autopsy, corpus survey, golden
candidates from literature and jazz pedagogy), then a draft golden suite for
review.

# 2026-08-02: External review: corrections and open decisions

**Goal.** Record the external review of the initiative drafts, apply the factual
corrections, and set up the decisions the review requires before the ruler
freezes. The review agreed with the direction (golden-first, conservative
secondary labeling, negative guards, rejection of register-blind decomposition)
but found seven problems with conclusions presented as settled. All initiative
work remains unpublished, and the corrections are part of the same
foundation-setting logical change; factual errors were corrected in place, and
this entry records what the review found and what changed.

**The findings.**

1. Blocker: inheriting the chord-context protocol "wholesale" is incompatible
   with the feature. That protocol scores a single root/quality/bass identity,
   requires empty-context output to remain identical, and freezes the snapshot
   path and operation counters; none of that can govern composite candidates,
   and `ChordIdentity`, `ChordCandidate`, and `ChordSymbol` each represent
   exactly one chord.
2. Blocker: the census detectors require a disjoint partition, which
   mathematically excludes four flagship positives that share a pitch class
   between layers (Ives shares G, Copland E, Holst B, Milhaud B); the draft
   claimed only two. The detector does include fifth-only lower layers, but a
   contemplated lower-third rule would exclude Elektra; bass-only layers such as
   Rumble and Zarathustra are not modeled. The census therefore measures a
   narrower concept than the declared positive set, and its low exposure cannot
   by itself establish that the eventual feature is safe.
3. High: "independent chords" is not observable from the current input.
   `ObservedVoicing` carries sorted MIDI numbers only; onset grouping, channel,
   motion, and timbre are discarded, and the perception literature ties layer
   independence to those cues jointly (Moreira, MTO 31.4, to be integrated in
   the deep-diligence entry). Register can license a conservative keyboard
   decomposition; it is not established as the universal gate for recognizing
   independent layers. The initiative must decide whether it names a notational
   decomposition, perceptual layers, or compositional intent.
4. High: committed chord events are the wrong unit for generator exposure. They
   snapshot the voicing at identity onset, attribute the whole duration to it,
   and ignore same-identity revoicing; a live generator sees every note-on/off,
   roll, and pedal accumulation. Frame-level generator exposure and
   stable-display exposure are required before any safety claim.
5. Medium: the drafted guard was vacuous. The frozen census detector does not
   depend on engine candidate generation, so an engine change could not alter
   its result; the guard must instrument the actual adopted generator, and
   single-chord pool diffs cannot catch wrong secondary decompositions when
   primary identities are unchanged.
6. Medium: the evidence trail stored only the top eight fires per gap while the
   logs claimed every fire was a recognizable boundary case, omitted the
   per-piece results the inherited statistics require, and lacked argv, manifest
   pins, and content hashes. Claims of "no prior art / no corpus" were stated
   absolutely rather than scoped to the searches actually run.
7. Medium: golden-list defects. Petrushka's layer orientation was stated
   inconsistently; Rumble was tagged positive despite the draft's own
   categorical bass-only rule; Zarathustra exposes the same unresolved boundary;
   the README cited a "phased plan recorded in log -01" that log -01 does not
   contain; several voicings are unverified against scores.

**Corrections applied.**

- PROTOCOL.md rewritten as a self-contained initiative protocol: split and label
  isolation, reproducibility, statistics, output-contract requirements, census
  scope, and engine guards are stated directly rather than inherited. An
  explicit polychord output contract, scoring model, and performance budget are
  required in a dated entry before any lever; the guard section requires
  instrumenting the adopted generator at frame level with complete fire
  dispositions; an "open decisions" section lists the decisions below.
- golden-candidates.md corrected: shared-tone audit fixed to four cases and
  flagged per case; Petrushka orientation made layering-neutral pending score
  verification; Rumble moved to boundary beside Zarathustra (bass-only-layer
  boundary); the categorical "never a polychord" bass rule reframed as a
  declared open question; score verification before ruler admission stated in
  the preamble.
- README corrected: the phased plan is now stated as proposed and pending the
  open decisions rather than attributed to log -01; the register claim is scoped
  to "the only gating evidence the current input carries"; absolute no-prior-art
  claims are scoped to the surveyed sources.
- Logs -01 and -02 softened in place (drafts): "load-bearing gate" reframed, the
  committed-event caveat attached to the fire-rate conclusion, the safety
  sentence in the plain-English reading qualified, and "no external corpus"
  scoped to surveyed sources with the deep sweep noted as pending.
- `split_census.py` upgraded to schema 2 for the evidence trail: every fire is
  recorded (piece, event index, timestamp, voicing, split reading, current top-1
  with cost), plus per-piece fired tallies, piece mass totals, argv and working
  directory, Python and script pins, an aggregate selected-fixture hash, fixture
  manifest pins when available (engine commit, profile, content hash), the
  manifest-file sha256, and the split-file sha256. All six configurations (three
  corpora, both tiers) were rerun with the log -01/-03 commands; every headline
  number reproduced identically. Log -06 later replaces the asymmetric tiers
  with schema-3 named profiles and extends the evidence trail to the
  pitch-class-only comparator; its explicitly disjoint upper-structure profiles
  reproduce these numbers.

**Complete fire dispositions.** The disjoint wide upper-structure tier at G=3 is
the superset of all registral fires across the six configurations measured here:
32 fires. In schema-3 terminology it is the
`upper-structure-common --disallow-shared-pitch-classes` profile. Dispositions
below; timestamps were recorded in the schema-2 reports under `build/polychord/`
and are reproduced in the schema-3 profile reports.

| corpus   | piece  | event | voicing (MIDI)       | split               | current top-1 (cost)           | disposition    |
| -------- | ------ | ----- | -------------------- | ------------------- | ------------------------------ | -------------- |
| WiR dev  | WoO 70 | 45    | 55 62 65 68 72       | Fm\|G:power         | G dominant7sus4 [flat9] (0.55) | sus texture    |
| ASAP dev | 31-1   | 248   | 37 39 65 69 72       | F\|D#:seventhShell  | C# major7Sharp5 [nine] (1.01)  | no lower third |
| ASAP dev | 7-2    | 476   | 33 45 55 61 64 80    | C#m\|A:seventhShell | C# minor [#11,b13] (2.05)      | pedal wash     |
| ASAP dev | 9-1    | 266   | 40 45 54 75 83 87    | B\|A:power          | E major7sus4 [nine] (0.75)     | sus texture    |
| ASAP dev | 9-1    | 268   | 40 45 54 75 83 87    | B\|A:power          | E major7sus4 [nine] (0.75)     | sus texture    |
| ASAP dev | 9-1    | 270   | 40 45 54 75 83 87    | B\|A:power          | E major7sus4 [nine] (0.75)     | sus texture    |
| POP909   | 010    | 371   | 46 53 58 61 68 72 75 | G#\|A#:minorTriad   | A# minor7 [9,11] (0.65)        | m11 identity   |
| POP909   | 361    | 87    | 43 57 62 66 71       | Bm\|A:seventhShell  | G major7 [nine] (0.35)         | maj9 voicing   |
| POP909   | 361    | 233   | 40 47 57 62 66       | D\|E:power          | B minor7 [eleven] (0.60)       | sus/quartal    |
| POP909   | 361    | 309   | 45 59 64 68 73       | C#m\|B:seventhShell | A major7 [nine] (0.35)         | maj9 voicing   |
| POP909   | 388    | 65    | 47 57 61 64 68       | C#m\|B:seventhShell | A major7 [nine] (0.65)         | maj9 voicing   |
| POP909   | 388    | 88    | 47 54 57 61 76       | A\|B:power          | F# minor7 [eleven] (0.60)      | sus/quartal    |
| POP909   | 388    | 162   | 47 57 61 64 68       | C#m\|B:seventhShell | A major7 [nine] (0.65)         | maj9 voicing   |
| POP909   | 388    | 185   | 47 54 57 61 76       | A\|B:power          | F# minor7 [eleven] (0.60)      | sus/quartal    |
| POP909   | 388    | 263   | 47 54 57 61 64       | A\|B:power          | F# minor7 [eleven] (0.60)      | sus/quartal    |
| POP909   | 487    | 266   | 41 48 62 67 70 91    | Gm\|F:power         | G minor7 [eleven] (0.60)       | sus/quartal    |
| POP909   | 514    | 211   | 39 56 61 78 82       | F#\|G#:power        | D# minor7 [eleven] (0.45)      | sus/quartal    |
| POP909   | 577    | 74    | 37 56 59 63 66 75    | B\|C#:power         | G# minor7 [eleven] (0.60)      | sus/quartal    |
| POP909   | 577    | 109   | 42 49 59 63 68       | G#m\|F#:power       | G# minor7 [eleven] (0.60)      | sus/quartal    |
| POP909   | 703    | 25    | 52 59 64 67 74 78 81 | D\|E:minorTriad     | E minor7 [9,11] (0.65)         | m11 identity   |
| POP909   | 721    | 25    | 38 45 52 56 59 61    | C#m7\|D:power       | B minor7 [9,11,13] (1.10)      | sus/quartal    |
| POP909   | 721    | 46    | 38 45 52 56 59 61    | C#m7\|D:power       | B minor7 [9,11,13] (1.10)      | sus/quartal    |
| POP909   | 721    | 73    | 40 45 57 62 66 71    | Bm\|A:power         | B minor7 [eleven] (0.60)       | sus/quartal    |
| POP909   | 721    | 113   | 38 45 52 56 59 61    | C#m7\|D:power       | B minor7 [9,11,13] (1.10)      | sus/quartal    |
| POP909   | 721    | 173   | 40 45 57 62 66 71    | Bm\|A:power         | B minor7 [eleven] (0.60)       | sus/quartal    |
| POP909   | 721    | 273   | 38 45 61 64 68 80    | C#m\|D:power        | A major7 [eleven] (1.10)       | sus/quartal    |
| POP909   | 730    | 4     | 43 50 57 65 69 72    | F\|G:power          | D minor7 [eleven] (0.60)       | sus/quartal    |
| POP909   | 730    | 154   | 38 43 50 57 65 69 72 | F\|G:power          | D minor7 [eleven] (0.45)       | sus/quartal    |
| POP909   | 757    | 66    | 43 50 57 60 64       | Am\|G:power         | C major6 [add9] (0.55)         | 6/9 voicing    |
| POP909   | 757    | 353   | 40 47 55 62 69 78    | D\|E:minorTriad     | E minor7 [9,11] (0.65)         | m11 identity   |
| POP909   | 766    | 92    | 43 57 62 66 71       | Bm\|A:seventhShell  | G major7 [nine] (0.35)         | maj9 voicing   |
| POP909   | 766    | 242   | 43 57 62 66 71       | Bm\|A:seventhShell  | G major7 [nine] (0.35)         | maj9 voicing   |

Reading: 29 of 32 fires have no third in the lower stack (a power dyad or bare
shell), and all three complete-triad lowers are the m11 identity. One fire is a
pedal-wash artifact (movement 7-2, the performed-input melody-absorption
flagship; the only fire whose current reading costs above 2). Zero fires are
bitonal. The "every fire is a recognizable boundary case" claim now has its
receipts, at committed-event granularity only.

**Open decisions before the ruler freezes** (now in PROTOCOL.md; each decision
must be dated, but closely coupled decisions may share one entry when that is
the clearest logical record):

1. Product semantics: notational decomposition versus perceptually independent
   layers versus compositional intent; primary versus secondary display; whether
   shared-tone, incomplete, and bass-only layers are in scope.
2. Evidence contract: register-only licensing on the current input, or a richer
   input carrying onset grouping, channel, or temporal history.
3. Golden verification and an implementation-shaped census: score-verified
   voicings, frame-level input, and overlapping pitch-class projections if
   shared tones stay in scope (a true overlapping note cover only if one sounded
   note may serve both layers).

**Plain-English reading.** An outside review checked our early conclusions and
found the right level of trouble: the test protocol we borrowed assumes one
chord at a time and cannot referee a two-chord feature as-is; our detector
quietly cannot see four of the most famous examples we ourselves listed as
targets; our safety number counts settled chords rather than every moment of
playing; and our promised safety check could never have failed. All of that is
now either fixed in the documents or written down as a decision still to be
made. The complete list of the 32 places the initial upper-structure detector
fired now sits in a table anyone can re-check, and none of them is a real
polychord.

**Next.** The terminology-aware deep sweep of academic and software prior art
(three parallel surveys in flight) lands as log -05; then the three dated
decisions (combined where they form one logical record), then golden encoding.

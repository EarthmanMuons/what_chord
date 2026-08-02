# 2026-08-02: External landscape: mingus, corpora, golden candidates

**Goal.** Before designing anything: learn from the first library found that
names polychords, establish whether anyone in the field has usable data, and
collect golden candidates from literature and pedagogy since log -01 found no
positive instances among the strict detector's fires and no corpus-provided
polychord labels.

**mingus was the first polychord namer found in this survey, and its failure
modes are instructive.** (python-mingus, `mingus/core/chords.py`, verified
against source and live execution.) The later terminology sweep in log -05 also
found ChordRecGen and musicpy; this entry records the mingus autopsy rather than
an exhaustive software claim. `determine()` dispatches on note count: 3 notes
never try polychords, 4-7 notes always append polychord readings after
conventional names, 8-14 notes get polychords only, 15+ silently return nothing.
`determine_polychords` enumerates contiguous slices of the given note-name list
(never subsets): upper half from the last 3..7 notes, lower half independently
from the first 3..7, each named by the full determiner for its size with
inversions disabled. Consequences, all verified by running it:

- Halves may overlap or leave gaps, so every root-position seventh chord is also
  a "polychord" (C E G B returns Em|CM beside C major seventh), 8-note inputs
  return 42 unranked names including self-referential ones (G13|G13, CM|CM13),
  and gap splits silently drop the middle notes.
- One missing vocabulary entry flips the headline: the 6-note table has no
  maj13(#11), so a plain Cmaj13(#11) voicing returns nine polychord names and
  zero conventional ones, with Bm|CM first.
- Register is smuggled in through list order plus a root-position spelling
  requirement, so reordering identical pitch content changes or eliminates every
  polychord reading.
- No ranking, no dedup, no scoring; the docs admit "the first item is probably
  the most likely interpretation".

Lessons that transfer directly: require a genuine partition covering every input
note; score polychord readings against the single-symbol competitor inside one
cost model instead of appending them; dedupe at the (upper root, lower root)
level; and make register an explicit, tested license rather than an ordering
accident. music21, tonal.js, and pychord name single chords only; mingus is the
outlier among the libraries inspected at this stage. Log -05 later adds the
direct musicpy and ChordRecGen comparisons.

**No surveyed source provides polychord ground truth.** ChoCo's "polychord"
notation family is a false lead: its `polychord_converter.py` collapses
comma-separated note lists into a single Harte chord, and Harte syntax has no
two-stack operator. The polytonality literature sampled here (Milhaud's
taxonomy, MTO on Herrmann, Integral on West Side Story) is analytic prose, not
data. This survey was breadth-first over dataset names and obvious keywords; a
terminology-aware deep sweep of academic and software prior art, with its search
scope recorded, follows in a later entry. Within what was surveyed, any external
census stays shape-defined with manual validation, exactly like log -01.

**But two octave-exact substrates are worth holding for a wider census.** Survey
of voicing-level datasets beyond our current set:

- Doug McKenzie collection (bushgrafts.com): 308 jazz-standard MIDI files played
  by a professional jazz pianist, direct MIDI capture, zero transcription error.
  No formal license; internal analysis only. The cleanest jazz-voicing ground
  truth anywhere; the right seed set for validating any polychord-shape detector
  on real two-hand jazz playing.
- PiJAMA: 2,777 transcribed solo jazz piano performances (~220 h, CC BY-NC 4.0),
  no chord labels, documented octave-error modes. Scale-out corpus after
  McKenzie validation.
- GiantMIDI-Piano (CC BY 4.0) is the only corpus containing Stravinsky, Milhaud,
  and Ives at all (verified in its composer list), but transcription octave
  errors directly confound registral measurement; exploratory only.
- YCAC (Yale): octave-specific vertical slices as CSV, cheap classical-side
  substrate, needs near-simultaneous slice merging; algorithmic key labels only.
  MAESTRO/ATEPP/PIAST/Aria-MIDI add little for this question over what ASAP and
  POP909 already give us.

**Golden candidates collected.** 32 sourced cases now sit in
`research/polychord/golden-candidates.md`: 13 positive (Petrushka both
transpositions, Augurs, Elektra, Ives Psalm 67, Copland, Holst, Milhaud, Liszt
Malediction, Bernstein Rumble, Perry Mason theme, two Lippincott jazz
polychords), 11 boundary (the five USTs over a dominant shell, Maiden Voyage,
F/G, the D/C slash-versus-polychord pair, Zarathustra, Bartok), and 8 negative
guards (Psalms chord, So What, Kenny Barron Cm11, Tyner comping, drop-2, pop
same-chord layers, spread voicings). Two traps stand out: Ives equals C9 and
Copland equals Amaj9 as pitch-class sets, so the polychord reading is licensed
by layout alone, which is the whole design question in two cases.

**A detector refinement fell out of cross-reading the goldens against log -01.**
The So What chord (E A D G B) fires the drafted registral detector as G|A:power,
and most of the census's live fires are the same shape family: a triad over a
power dyad or bare shell (F|G:power, Bm|A:seventhShell), which is sus/quartal
territory with standard single names. The other repeated fire is the m11
identity (D|Em:minorTriad, named Em7(9,11) today), a boundary case whose single
symbol must keep winning on price. Requiring a third in the lower stack
(complete triad or seventh) removes the sus/quartal family while keeping
Petrushka, Augurs, and the jazz positives; it also excludes the Elektra chord as
sourced (C# major over a bare E-B fifth), so the ruler must decide whether
fifth-only lower layers are in scope, alongside the shared-tone question (Holst
and Milhaud share a pitch class between layers, which the strict disjointness
gate excludes).

**Plain-English reading.** The first program we inspected names polychords by
brute force with no judge, and it ends up calling ordinary jazz chords
polychords while missing the layout evidence that makes a real one. No labeled
dataset of the real thing surfaced in this survey. The best raw material for
checking our detector against real hands is a set of 308 direct-recorded jazz
piano files; the famous examples themselves now sit in a reviewed candidate
list. Comparing that list against our census suggests a lower-third requirement
as a strong false-positive control, but that rule would exclude Elektra and
therefore remains a declared scope decision rather than a settled design rule.

**Next.** The external review and terminology sweep in logs -04 and -05 precede
golden encoding; their scope decisions and source-verification requirements
govern the next step.

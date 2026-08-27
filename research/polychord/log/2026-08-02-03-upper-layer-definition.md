# 2026-08-02: The upper layer is a chord, not just a triad

**Later correction.** This entry correctly found that an upper-triad restriction
cannot define polychords, but retained an asymmetric upper/lower detector and
mistook its widened tier for general exposure. Log 2026-08-02-06 replaces that
design with symmetric named profiles and preserves these results as an
upper-structure boundary sensitivity analysis.

**Goal.** Review of log -01 raised a precision question about what the census
measures: the detectors required the upper stack to be a plain major or minor
triad. Is "upper triad over an independent lower chord" actually the definition
of a polychord?

**The literature says no.** The general constructional definition (the Puget
Sound OER and Persichetti's usage) combines two or more conventional chordal
units, with no triad restriction on either layer. Our own candidate list
contains the counterexample: the Augurs chord is Eb7 over Fb major, a seventh
chord on top. "The upper structure is usually a triad" is the jazz notation
convention and the UST pedagogy, not the phenomenon. So the initiative's working
definition of record is two or more conventional chordal units combined in one
sonority; which templates and grouping evidence each layer requires is a
detector and ruler choice, to be declared wherever it is used, never conflated
with the definition. Logs -04 and -05 further limit the product claim: the word
"independent" cannot mean perceptually segregated streams on pitch-and-register
input alone.

**Setup.** The schema-1 script gained `--upper-sevenths`, which widened the
upper templates from plain major/minor triads to also admit plain dominant,
major, and minor sevenths. The default remained the strict triad tier, and a
re-run of the When in Rome narrow census reproduced log -01 exactly. Smoke
check: an Augurs voicing (E1 E2 G#2 B2 under Eb3 G3 Bb3 Db4) fires only under
`--upper-sevenths`, as D#7|E:majorTriad at G=3 (the layer gap is 4 semitones),
confirming the strict tier was blind to upper-seventh polychords.

Commands: the three log -01 invocations with `--upper-sevenths` added and
`-wide` output names.

**Widening the upper layer barely moves the corpus numbers.** Fired share of
event mass (fired events in parentheses):

| corpus        | tier   | G=7         | G=5         | G=3         | pc-only       |
| ------------- | ------ | ----------- | ----------- | ----------- | ------------- |
| WiR dev       | triads | 0.0000 (0)  | 0.0000 (0)  | 0.0007 (1)  | 0.0070 (22)   |
| WiR dev       | +7ths  | 0.0000 (0)  | 0.0000 (0)  | 0.0007 (1)  | 0.0070 (22)   |
| ASAP dev      | triads | 0.0004 (4)  | 0.0004 (5)  | 0.0004 (5)  | 0.0214 (158)  |
| ASAP dev      | +7ths  | 0.0004 (4)  | 0.0004 (5)  | 0.0004 (5)  | 0.0246 (180)  |
| POP909 sample | triads | 0.0005 (10) | 0.0007 (17) | 0.0008 (23) | 0.1251 (2379) |
| POP909 sample | +7ths  | 0.0007 (13) | 0.0009 (20) | 0.0010 (26) | 0.1279 (2430) |

When in Rome is unchanged, ASAP changes only on the pc-only side, and the POP909
registral additions are all the same boundary family as before: an m7 upper over
a power-dyad lower (C#m7|D:power, a maj13/sus texture), no bitonality. Pc-only
ambiguity grows as expected (POP909 now has 157 events with five partitions).
Every log -01 conclusion stands: registral exposure stays under 0.1% of event
mass, the fires are conventionally-named boundary shapes, and the register-blind
generator over-fires by two orders of magnitude.

**Decision at the time (superseded by log -06).** The strict upper-triad tier
was retained as the census baseline because it was the jazz-shaped form and the
tighter false-positive gate, with the widened tier reported beside it. That was
still the wrong primary design: a false-positive gate is not a constructional
definition, and neither tier treated the layers symmetrically. The durable
conclusion is narrower: positives like Augurs require upper-seventh admission,
and every detector or ruler must declare its exact layer templates.

**Plain-English reading.** We had quietly defined a polychord as a triad sitting
on top of another chord. The textbook counterexample is the Rite of Spring
chord, where the thing on top is a seventh chord. Widening only the upper layer
changed these particular corpus numbers by a rounding error, but it did not yet
give us a neutral split design. Log -06 completes that correction.

**Next.** Revisit the asymmetric split design before encoding the ruler (log
-06).

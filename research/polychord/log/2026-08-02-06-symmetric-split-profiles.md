# 2026-08-02: Replace the upper-triad assumption with symmetric split profiles

**Goal.** Revisit the design of the exposure census before the initiative's
foundation is published. The original detector assumed a major/minor triad in
the upper register but allowed a much broader lower vocabulary, then added an
`--upper-sevenths` widening flag. That sequence was useful for finding the
Augurs counterexample, but did it leave an initial jazz convention embedded as
the operational definition of a polychord?

**Decision before measurement.** Yes. The old detector is an upper-structure
boundary screen, not a neutral polychord split. Its asymmetry has no basis in
the constructional definition, and its lower shells and power dyads are the
source of 29 of its 32 registral fires. The literature distinguishes the
narrower major/minor two-triad case as a bichord or polytriad and separately
admits superimpositions involving common seventh chords. The general definition
does not privilege the upper layer.

Report schema 3 therefore replaces the Boolean widening with required, named
profiles:

- `complete-common` is the primary constructional profile: the same closed set
  of complete major/minor triads and dominant, major, and minor sevenths on both
  sides.
- `bichord-triads` is a symmetric major/minor-triad ablation.
- `upper-structure-triads` and `upper-structure-common` preserve the original
  asymmetric vocabularies as boundary sensitivity profiles. They are not
  definitions or primary results.

Every profile requires different layer roots. This is the minimum operational
meaning of different harmonic areas: two register groups both spelling C major
are one rooted harmony, not `C|C`. The primary run allows the pitch-class
projections of the register groups to overlap only when separate sounded notes
support the shared pitch class. The register-blind comparator applies the same
note-instance requirement. The script reports every qualifying register boundary
rather than choosing the widest one without evidence. Reports embed the exact
upper and lower templates, profile description, overlap policy, and candidate
policy.

This remains deliberately narrower than the initiative's constructional
definition. Augmented and diminished families, incomplete units, bass-only
units, extended units beyond sevenths, a single sounded note serving two layers,
and sonorities with more than two layers are not in the primary profile. A ruler
decision must justify any of them before a new named profile measures them.

**Setup.** The corpus fixtures, development splits, and gap sweep are unchanged
from logs -01 and -03. Shared pitch classes are allowed in the two
constructional profiles. A disjoint `complete-common` ablation isolates the
effect of that choice. The two upper-structure reproductions explicitly disallow
shared pitch classes, matching the old detector. Schema-3 reports retain every
registral and pitch-class fire and candidate, ambiguity counts, per-piece
tallies, argv, script and fixture hashes, and manifest and split pins.

Commands for the primary profile:

```sh
python3 tool/polychord/split_census.py \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --profile complete-common \
  --out build/polychord/wir-dev-complete-common.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-shipped \
  --split-file research/performed-input/data/splits/asap-wir-nc-v2.json \
  --split development --profile complete-common \
  --out build/polychord/asap-dev-complete-common.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/pop909-cur \
  --profile complete-common \
  --out build/polychord/pop909-complete-common.json
```

Commands for the bichord ablation:

```sh
python3 tool/polychord/split_census.py \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --profile bichord-triads \
  --out build/polychord/wir-dev-bichord-triads.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-shipped \
  --split-file research/performed-input/data/splits/asap-wir-nc-v2.json \
  --split development --profile bichord-triads \
  --out build/polychord/asap-dev-bichord-triads.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/pop909-cur \
  --profile bichord-triads \
  --out build/polychord/pop909-bichord-triads.json
```

Commands for the disjoint primary ablation:

```sh
python3 tool/polychord/split_census.py \
  --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
  --split-file research/whatkey/data/splits/when-in-rome-v1.json \
  --split development --profile complete-common \
  --disallow-shared-pitch-classes \
  --out build/polychord/wir-dev-complete-common-disjoint.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/asap-wir-shipped \
  --split-file research/performed-input/data/splits/asap-wir-nc-v2.json \
  --split development --profile complete-common \
  --disallow-shared-pitch-classes \
  --out build/polychord/asap-dev-complete-common-disjoint.json
python3 tool/polychord/split_census.py \
  --fixtures build/whatkey-fixtures/pop909-cur \
  --profile complete-common --disallow-shared-pitch-classes \
  --out build/polychord/pop909-complete-common-disjoint.json
```

Commands reproducing the two historical upper-structure profiles:

```sh
for polychord_profile in upper-structure-triads upper-structure-common; do
  python3 tool/polychord/split_census.py \
    --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
    --split-file research/whatkey/data/splits/when-in-rome-v1.json \
    --split development --profile "$polychord_profile" \
    --disallow-shared-pitch-classes \
    --out "build/polychord/wir-dev-${polychord_profile}-disjoint.json"
  python3 tool/polychord/split_census.py \
    --fixtures build/whatkey-fixtures/asap-wir-shipped \
    --split-file research/performed-input/data/splits/asap-wir-nc-v2.json \
    --split development --profile "$polychord_profile" \
    --disallow-shared-pitch-classes \
    --out "build/polychord/asap-dev-${polychord_profile}-disjoint.json"
  python3 tool/polychord/split_census.py \
    --fixtures build/whatkey-fixtures/pop909-cur \
    --profile "$polychord_profile" --disallow-shared-pitch-classes \
    --out "build/polychord/pop909-${polychord_profile}-disjoint.json"
done
```

Synthetic regression command:

```sh
python3 tool/polychord/split_census_test.py
```

**Results.** Fired share of committed-event mass, with fired events in
parentheses:

| corpus        | profile         | G=7          | G=5          | G=3          | pc-only        |
| ------------- | --------------- | ------------ | ------------ | ------------ | -------------- |
| WiR dev       | complete-common | 0.0000 (0)   | 0.0004 (3)   | 0.0005 (4)   | 0.0020 (11)    |
| WiR dev       | bichord-triads  | 0.0000 (0)   | 0.0004 (3)   | 0.0005 (4)   | 0.0020 (11)    |
| ASAP dev      | complete-common | 0.0003 (2)   | 0.0008 (7)   | 0.0016 (12)  | 0.0177 (143)   |
| ASAP dev      | bichord-triads  | 0.0000 (0)   | 0.0001 (2)   | 0.0005 (5)   | 0.0117 (97)    |
| POP909 sample | complete-common | 0.0040 (115) | 0.0074 (212) | 0.0122 (372) | 0.1280 (2,634) |
| POP909 sample | bichord-triads  | 0.0027 (78)  | 0.0047 (130) | 0.0073 (207) | 0.0853 (2,327) |

At G=3, `complete-common` produced 4 candidates across 4 WiR fires, 15
candidates across 12 ASAP fires, and 492 candidates across 372 POP909 fires.
Every WiR candidate, every ASAP candidate, and 489 of 492 POP909 candidates
share at least one pitch class between separately sounded layer notes. The
disjoint ablation consequently falls to zero registral fires on WiR, zero on
ASAP, and three on POP909 (0.0003 mass share); the three POP909 events are the
same `D|Em` / `G#|A#m` minor-eleventh family already dispositioned in log -04.

The inspected shared-tone fires show why they must remain exposure rather than
positive labels: `Bm|D` is currently and conventionally D6, `Gm|Eb` is Ebmaj7,
`Em|G` is Em7, `C|Am7` is Am7/C6-family material, and many POP909 covers are
relative-triad or triad-with-seventh decompositions. Admitting canonical
shared-tone positives therefore also admits ordinary integrated chords by the
hundreds. That is a ruler and ranking problem, not a reason to erase shared-tone
positives from the task.

The two explicit upper-structure reproductions match logs -01 and -03 exactly:
their G=3 event counts remain 1/5/23 for the triad-upper profile and 1/5/26 for
the common-upper profile across WiR/ASAP/POP909. The redesign changes the
interpretation, not those historical measurements.

**Plain-English reading.** The original census answered, "How often is there a
triad or seventh above a jazz-like lower foundation?" It did not answer the
broader question we meant to ask. The corrected primary test gives both layers
the same chord vocabulary and can see famous examples whose layers repeat a note
in different registers. That makes the pop exposure rise from about one event in
a thousand to about one in eighty. Nearly all of the new events are ordinary
chords split into overlapping subchords, which is exactly the ambiguity the
eventual method must solve. The lower old number was real, but it was real for a
much narrower and differently shaped question.

**Decisions.** Use `complete-common` as the primary constructional exposure
profile and `bichord-triads` as its named ablation. Retain the upper-structure
profiles only for boundary comparison. Do not call any census profile the full
definition of a polychord. Do not make an adoption or safety claim from these
committed-event results. The golden ruler must explicitly distinguish
shared-tone polychords from integrated sixth, seventh, and extended chords
before an implementation-shaped frame census is meaningful.

**Next.** Score-verify and encode a pilot ruler centered on this exact
ambiguity: canonical shared-tone positives beside relative-triad,
duplicated-register, upper-structure, and ordinary extended-chord negatives. Use
it to decide the constructional conflict/integration rule before freezing the
full ruler.

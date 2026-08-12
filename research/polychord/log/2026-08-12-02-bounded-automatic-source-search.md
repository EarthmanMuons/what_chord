# 2026-08-12: Close the bounded automatic source search

**Goal.** Complete the bounded search required by log 2026-08-12-01 and decide
whether either frozen temporal cue has enough source evidence to become a
licensing branch under `polychord-output/2`.

**Setup.** Tracked files began at clean commit
`5c0984f473dd4e3d278e540e8df9706dc167f08b`. No selector was defined or run, no
corpus candidate result was generated, and no held POP909 song was opened. The
admission rule, cue interpretations, and display threshold remained unchanged.

The fixed inputs were:

- automatic-suite plan:
  `909d066a4d2ff454fbe696a905ea10044daac7a995048efde1ceff1a168ffb25`;
- v2 selection plan:
  `6600e2ed925d21ff47eeba2cb45967ce5cc9d4eea85860a9b1c505b90cd4e7d8`;
- v2 output contract:
  `83bf6a5f182b3b7204d21863964ddf5a9a2da35014f2ef9d24e3c657b94d81c2`;
- protocol: `0cc39731a385abe7b0534811e9cc403e8278fc09e9e84a79e15453464b4961fe`;
- frozen internal suite:
  `327291bbd83c50040989a4ac07bc7d157b0f810bd2e00487a8e544d2339c5403`;
- onset rule:
  `8385ddbed316d3a770980527c396c29e5339ed010c203b133434f32c311cc3aa`; and
- motion rule:
  `50886b62cf5e361148af3b05fd015f0e75a54eb5f4a36fac4ac690f07d57e083`.

The search was bounded to sources that could plausibly close the exact gap:

1. the frozen construction and boundary inventory;
2. all 34 examples in Moreira's official 2025 MTO supplement, because the
   article explicitly analyzes polychordal construction, onset, and motion;
3. open symbolic datasets containing the named Ives, Stravinsky, Schuman,
   Herrmann, Milhaud, or Liszt leads;
4. public perception datasets returned by `polychord`, `polytonality`,
   `bichord`, `clash of keys`, and symbolic-MIDI searches;
5. targeted title searches for an open score plus a human-authored timestamped
   note representation or performance of the strongest leads; and
6. specialist classical MIDI archives for a score-derived representation missed
   by general dataset and web searches.

The source inventory was captured with:

```sh
mkdir -p tmp/pdfs

curl -L --max-time 30 \
  -o tmp/pdfs/moreira-article.html \
  https://mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-examples.pdf \
  https://www.mtosmt.org/issues/mto.25.31.4/moreira_examples.pdf
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-example3.html \
  'https://mtosmt.org/issues/mto.25.31.4/moreira_examples.php?id=2&nonav=true'
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-ex03.png \
  https://mtosmt.org/issues/mto.25.31.4/moreira_ex03.png
curl -L --max-time 30 \
  -o tmp/pdfs/moreira-audio-ex02.mp3 \
  https://mtosmt.org/issues/mto.25.31.4/moreira_audio_ex02.mp3

git clone --depth 1 \
  https://github.com/bytedance/GiantMIDI-Piano.git \
  tmp/GiantMIDI-Piano
git -C tmp/GiantMIDI-Piano rev-parse HEAD
rg -n \
  '^Ives\t|^Stravinsky\t|^Schuman\t|^Milhaud\t|Malediction|Psalm 67|Petrushka|Petrouchka|Three-Score Set' \
  tmp/GiantMIDI-Piano/resources/full_music_pieces_youtube_similarity_pianosoloprob_split.csv

curl -L --max-time 30 \
  -o tmp/pdfs/osf-project.json \
  https://api.osf.io/v2/nodes/sj3da/
curl -L --max-time 30 \
  -o tmp/pdfs/osf-storage.json \
  https://api.osf.io/v2/nodes/sj3da/files/osfstorage/
curl -L --max-time 30 \
  -o tmp/pdfs/osf-stimuli.json \
  https://api.osf.io/v2/files/693bec27ca934a71c2025846/

curl -L --max-time 30 \
  -o tmp/pdfs/liszt-kunstderfuge.html \
  https://www.kunstderfuge.com/liszt.htm
curl -L --max-time 30 \
  -o tmp/pdfs/liszt-malediction.mid \
  'https://kunstderfuge.com/-/mid.files/26/liszt_piano_concerto_e-major_malediction_S-121_(c)laviano.mid'
curl -L --max-time 30 \
  -o tmp/pdfs/liszt-malediction-score.pdf \
  https://www.archive.org/download/Cantorion_sheet_music_collection_3/47ce8305b3f09c974c692a4276e63aac.pdf
curl -L --max-time 30 \
  -o tmp/pdfs/bis-2100-booklet.pdf \
  https://eclassical.textalk.se/shop/17115/art83/4947683-7499e4-BIS-2100__booklet.pdf

shasum -a 256 \
  tmp/pdfs/moreira-article.html \
  tmp/pdfs/moreira-examples.pdf \
  tmp/pdfs/moreira-example3.html \
  tmp/pdfs/moreira-ex03.png \
  tmp/pdfs/moreira-audio-ex02.mp3 \
  tmp/GiantMIDI-Piano/resources/full_music_pieces_youtube_similarity_pianosoloprob_split.csv \
  tmp/pdfs/osf-project.json \
  tmp/pdfs/osf-storage.json \
  tmp/pdfs/osf-stimuli.json \
  tmp/pdfs/liszt-kunstderfuge.html \
  tmp/pdfs/liszt-malediction.mid \
  tmp/pdfs/liszt-malediction-score.pdf \
  tmp/pdfs/bis-2100-booklet.pdf
```

The source pins are:

- Moreira article HTML:
  `b89ca02d9bd38a18cda1019c2932fa751ed8e889d36919129d97eeeb78ffb45b`;
- Moreira examples PDF:
  `09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`;
- Moreira Example 3 page:
  `3a9fdd595b5788985600799d76c19179d7f1fd3b64c7e7921e3a205a8e0ab019`;
- Moreira Example 3 image:
  `7e9697252e1842a89f90b9bb2e747b4e5c2d59efb5b73457faeedf556500f28a`;
- Moreira Example 3 audio:
  `0761f6c947cc17fe61db9e664addb548b07b08cf5f909b62b561d0e2a7cd8d19`;
- GiantMIDI-Piano repository commit: `930d535a3882f301f7dd8b4c1389072e04989037`;
- GiantMIDI-Piano indexed-piece table:
  `af1b60605560c77dce0d685db957d5c7c1648143c3ddb8e9f905211721d2d6be`;
- OSF project record:
  `885a6416a2509fd8d7f6c47ddf9b65d2ad87271ccf80fcb00f4fc986ba92bdd4`;
- OSF root-file listing:
  `9ae1bc5db651f2bf3f33c99e8c4cf3d355e0946e7b61b69f89c06506046f3a03`;
- OSF stimulus-file listing:
  `e710882565a360348408d65c14cb92685f18af164001f715a28154bb3e9ddd89`;
- Kunst der Fuge Liszt listing:
  `f6fdb5136a69ed4be2accebb70004017bf3a40a435edc99432503c546f321287`;
- Antonio Laviano's 2008 _Malediction_ MIDI sequence:
  `e9d569df697371879f6ee88c7b956bfea4251a397b6bde2d0065cb8ea01f1f05`;
- 1915 Breitkopf & Hartel complete-score scan:
  `1dacb7483b16e45bd753fbb678720df40d6860fa81556df0d284f1764629ef2b`; and
- BIS-2100 booklet:
  `a8e395708473d3aabf707b9d29fa62291cd7d391ce94b9ced8a6f0af3d65eec2`.

The Moreira supplement and source images were rendered and visually inspected.
The Ives opening was rechecked against the already pinned Johnson reduction and
published-score preview. The public-domain Liszt score was rendered and checked
against the BIS commentary and hand sequence. The sequence carries Laviano's
2008 authorship and NoteWorthy Composer metadata; its embedded notice prohibits
republication, so it was inspected locally, pinned by digest, and not added to
the repository. Search-result pages and failed access responses did not enter
the evidence record.

## Admission results

| Source lead                            | Construction | Positive cue        | Exact note events   | 200 ms gate      | Matched cue-positive guard | Disposition                                                                                                              |
| -------------------------------------- | ------------ | ------------------- | ------------------- | ---------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Herrmann, “The Scar,” Moreira Ex. 3    | Yes          | Onset premise       | No                  | Unresolved       | No                         | Strongest new lead; retain as scholarly cue evidence, not a licensing positive                                           |
| Ives, _Psalm 67_ opening               | Yes          | No                  | No                  | Not needed       | N/A                        | Simultaneous-onset construction control; first frame has no motion predecessor                                           |
| Schuman, _Three-Score Set_ II, mm. 1-4 | Yes          | Motion premise      | No                  | Unresolved       | Existing guards only       | Contrary-motion construct without source-fixed per-note timing                                                           |
| Stravinsky, “Shrovetide Fair”          | Boundary     | Motion              | Normalized only     | Not source-fixed | Yes                        | Existing construct and guard, not a product positive                                                                     |
| Liszt, _Malediction_, printed p. 2     | Boundary     | Onset neutral       | Hand sequence       | 96 or 97 ms      | N/A                        | Alternating score construction; pedal-derived <code>F&#124;B</code> never reaches the frozen onset or display thresholds |
| GiantMIDI-Piano relevant entries       | Unaligned    | Measurable          | Machine-transcribed | Measurable       | No                         | Not human-authored event ground truth; no pinned analytical measure and voicing for the available Milhaud MIDI           |
| OSF _Detection of clash of keys_       | Study labels | Not candidate-bound | Audio only          | Measurable       | No                         | Perception resource; eight MP3 stimuli and no symbolic or note-event stimuli                                             |

### Strongest onset lead: “The Scar”

Moreira's peer-reviewed analysis describes Example 3 as two registrally distinct
and autonomous tritone-related minor triads separated through contrasting
timbres and rhythms. Section 4 further identifies the slower, separate attacks
as favoring perception of the two layers, and section 6 names onset asynchrony
as one source of the two textural streams.

The official notation labels the successive constructions, including E-flat
minor below A minor and D minor below A-flat minor, and shows the two complete
triads attacked at different score positions. The article-hosted 63.2-second
audio is a source-linked film excerpt and corroborates the performance context.
This is better support for the _musical premise_ of onset grouping than the
previous “The Pass” lead.

It still does not meet `polychord-output/2`. The audio is a mixed recording, not
an authoritative event stream. It cannot bind the exact onset event identifier
and release state of every candidate note or prove that each within-layer onset
span is at most 50 milliseconds. Extracting six per-note timestamps from the mix
would add an estimator and uncertainty model that were not preregistered. The
notation also has no numeric tempo from which to derive the physical
200-millisecond onset separation without selecting a favorable realization.
Finally, the search found no ordinary integrated source guard that satisfies the
same exact onset rule and must abstain. The lead fails admission items 1 through
3 as a complete package even though its construction and onset rationale are
strong.

### Ives correction

The paid MuseScore download is unnecessary. Johnson's open analytical reduction
and the published-score preview already establish what matters: the opening
G-minor lower unit and C-major upper unit attack together. The opening is a
source-attested construction and an eligible static register candidate, but its
onset evidence is neutral under the frozen rule. Because it is the first
sonority, it has no direct candidate predecessor for motion. Its long notated
duration cannot create a cue that is absent at the attack.

This makes Ives useful for preserving the distinction between construction and
automatic observability, not for filling either licensing-positive cell. No paid
file was purchased or used.

### Liszt correction and source-fixed probe

The specialist Kunst der Fuge archive lists Antonio Laviano's hand-sequenced
2008 MIDI of Liszt's _Malediction_. Unlike GiantMIDI-Piano, this is a
human-authored score realization rather than a model transcription. It fixes one
documented event timing and carries named piano and string tracks, but it
remains a sequencer's realization rather than captured performance ground truth.

The source trail corrects the existing golden-candidate wording. Printed page 2
of the 1915 score shows the relevant B-major and F-major chords alternating in
the `ff martellato` passage. Michael Emmans Dean's 2015 BIS-2100 commentary also
describes rapid alternation that blurs together, then contrasts it with the
simultaneous tritone-related triads in _Petrushka_. Calling the Liszt source a
sustained `F major plus B major` vertical was therefore too strong.

The sequence was replayed with Mido 1.3.3 through the existing
`development_exposure.read_midi_messages` and
`development_exposure.normalize_midi_messages` functions. Those functions merge
the SMF in deterministic time order and reproduce WhatChord's channel-blind,
global-pedal, distinct-note input semantics. Every resulting frame was passed to
the unchanged `generate_register_candidates` function. The analysis code pins
were:

- `tool/polychord/development_exposure.py`:
  `21d3de85923d488f35a93bfd5c8aa1317ca087eea7c7ba889aca7b5ec338e6ab`; and
- `tool/polychord/register_candidates.py`:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`.

The input contained 35,774 relevant messages and normalized to 30,388 observable
events. The normalization reported 5,386 messages with no observable change,
2,674 repeated note-ons, 2,674 unmatched note-offs, and 58 repeated pedal
messages. Those counts matter: both piano tracks use channel 0, while the live
input semantics intentionally collapse source and channel to one distinct-note
set. A separate per-track/channel reference-count replay corroborated the same
two positive-duration targets, so the result is not an artifact of the duplicate
message handling.

Only two positive-duration frames generated either orientation of the expected
tritone-related target. At 24,404 milliseconds and again at 24,792 milliseconds,
pedal carry retained the lower B-major assignment `75 78 83` while the upper
F-major assignment `84 89 93 96` attacked, producing upper-first `F|B`. Each
exact assignment persisted only until the next changed frame, for 97 and 96
milliseconds respectively. The lower and upper onset cohorts were 96 and 97
milliseconds apart. Thus:

- the frozen onset rule is neutral because its required between-layer gap is at
  least 200 milliseconds;
- motion is unavailable because each direct predecessor lacks a complete source
  register candidate, and no causal lookback rule is frozen; and
- the exact target authorization cannot satisfy the 200-millisecond display
  gate.

The exact read-only probe was:

```sh
./.venv/bin/python - <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, "tool/polychord")
import development_exposure
from register_candidates import generate_register_candidates

messages, end_ms, _ = development_exposure.read_midi_messages(
    Path("tmp/pdfs/liszt-malediction.mid")
)
normalized = development_exposure.normalize_midi_messages(messages, end_ms)
onsets = {}
rows = []

for index, (event, frame) in enumerate(
    zip(normalized["events"], normalized["frames"])
):
    if event["type"] == "noteOn":
        onsets[event["midiNote"]] = event["timestampMs"]
    next_ms = (
        normalized["frames"][index + 1]["timestampMs"]
        if index + 1 < len(normalized["frames"])
        else end_ms
    )
    duration_ms = next_ms - frame["timestampMs"]
    if duration_ms <= 0:
        continue
    for candidate in generate_register_candidates(frame["soundingMidiNotes"]):
        if candidate.symbol not in {"F|B", "B|F"}:
            continue
        onset_gap_ms = min(onsets[note] for note in candidate.upper.midi_notes) - max(
            onsets[note] for note in candidate.lower.midi_notes
        )
        rows.append(
            (
                frame["timestampMs"],
                duration_ms,
                onset_gap_ms,
                candidate.symbol,
                candidate.lower.midi_notes,
                candidate.upper.midi_notes,
            )
        )

print("normalizedEvents", len(normalized["events"]))
for row in rows:
    print(row)
PY
```

It printed:

```text
normalizedEvents 30388
(24404, 97, 96, 'F|B', (75, 78, 83), (84, 89, 93, 96))
(24792, 96, 97, 'F|B', (75, 78, 83), (84, 89, 93, 96))
```

An independent per-track/channel reference-count replay produced the same two
rows. That corroboration was necessary because the research input intentionally
models WhatChord's channel-blind state rather than retaining orchestral track
identity.

The sequence therefore supplies exact negative evidence for this realization,
not a licensing positive. The candidate backlog now treats Liszt as a temporal
and perceptual boundary: performance and pedal may blur rapidly alternating
chords, but the printed source does not attest the static snapshot previously
implied.

### Open symbolic and perception sources

GiantMIDI-Piano describes its 10,855 files as high-resolution piano
transcriptions of live recordings and explicitly disclaims their accuracy. Its
indexed table contains no Ives _Psalm 67_, no William Schuman _Three-Score Set_,
and no eligible Petrushka MIDI. It does contain a machine transcription of
Milhaud's complete _Saudades do Brasil_, but the existing “Copacabana” candidate
still lacks a verified measure and exact score voicing. Searching the
transcription for a favorable split would reverse the required provenance order
and turn model output into ground truth.

The public OSF project _Detection of clash of keys_ is a perception study rather
than a polychord event corpus. Its stimulus directory contains eight MP3 files,
crossing jazz or classical style, saxophone or trumpet, and fitting or clashing
conditions. There is no MIDI, MusicXML, note-event table, polychord assignment,
or registration fixing candidate-level labels. It cannot satisfy the automatic
input contract.

**Plain-English reading.** The open research strongly supports the idea that
separate attacks and separate motion can make chordal layers musically
meaningful. It does not supply the complete evidence needed to show that
WhatChord can recognize those layers safely from live MIDI. A score tells us
what was written; mixed audio tells us what was heard; machine transcription
guesses what notes occurred; and a hand sequence fixes one realization rather
than proving score simultaneity or a performance distribution. The Liszt
sequence supplies exact events, but its only relevant candidate is subthreshold.
No available source supplies a qualifying candidate and cue plus the closely
matched guard required to license that branch.

## Decision

Admit no onset or motion licensing branch. Stop automatic selector work under
`polychord-output/2` before encoding `polychord-automatic-suite/1`, implementing
a selector, running development data, or reading the held POP909 reserve.

Preserve `polychord-output/2` and the suite plan as closed research contracts so
the evidence standard and null result remain reproducible. Keep onset, motion,
release, and pedal trackers as useful diagnostic infrastructure. Do not weaken
the 50/200-millisecond onset rule, the motion endpoint rule, the source-attested
guard requirement, or the display gate after seeing this search.

This is a scoped stopping result, not a universal claim that no suitable source
exists. Reopening requires a new dated decision that identifies either:

- an authoritative timestamped note-level source satisfying the unchanged
  admission rule; or
- a deliberately different input or output claim under a new contract version,
  with its own validation burden.

Do not make a paid or machine-transcribed download a prerequisite merely to keep
the current route alive.

**Next.** Return to a product path whose evidence is actually observable. The
cleanest candidate is a separately contracted explicit-layer input, where a
musician supplies the upper and lower units rather than the app inferring them.
That work may reuse the frozen notation, presentation, candidate, accessibility,
and temporal-diagnostic infrastructure, but it must start with its own input
semantics and must not be described as automatic detection.

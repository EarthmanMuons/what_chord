# 2026-08-02: Musician-facing pilot redesign

**Goal.** Remove programming and MIDI literacy from the independent-review task,
make the musical evidence directly inspectable, and standardize the amount of
orientation a qualified reviewer receives without changing the scored response
schema or exposing the initial answers.

**Setup.** Base repository commit `3c8e5a1b`. No independent response existed,
was inspected, or was migrated. This is a direct measurement-instrument revision
and therefore receives a new dated entry even though it corrects the same pilot
stage recorded in logs -09 and -10. The prior instrument remains historical and
is superseded before data collection.

The two source PDFs were downloaded from the exact Archive.org records already
pinned in the blinded packet:

- `ptrouchkascn00stra.pdf`, SHA-256
  `8c753ed9ddc37e61d7fb1a261fd350cbe7b529d9bc957e9c2efcfab953532d64`;
- `lesacreduprintem00stra_3.pdf`, SHA-256
  `6871f14d62c39eeaa7a1482c644947870bbb30b297f0ed2b89321dad85f35495`.

`pdftoppm version 26.07.0` rendered deterministic, unannotated crops. The
Petrushka crop uses PDF page 66 at 250 DPI and rectangle
`x=38, y=306, width=900, height=500`. The Augurs crop uses PDF page 18 at 200
DPI and rectangle `x=70, y=35, width=1580, height=700`. Both final PNGs were
inspected visually at original resolution for the intended rehearsal location,
legibility, absence of harmonic labels or highlighting, and sufficient musical
context.

Reproducibility and validation commands:

```sh
python3 tool/polychord/prepare_review_score_excerpts.py \
  --petrushka-pdf tmp/pdfs/ptrouchkascn00stra.pdf \
  --augurs-pdf tmp/pdfs/lesacreduprintem00stra_3.pdf
python3 tool/polychord/pilot_ruler.py \
  research/polychord/pilot-ruler-v0.json \
  --review-packet-out research/polychord/pilot-review-template-v0.json
python3 tool/polychord/pilot_ruler.py \
  research/polychord/pilot-ruler-v0.json \
  --validate-review research/polychord/pilot-review-template-v0.json
mise python:format
mise python:lint
npx prettier --check \
  research/polychord/pilot-annotation.md \
  research/polychord/pilot-response-schema.md \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/reviews/README.md \
  research/polychord/review-instrument \
  tool/polychord/review_instrument_test.mjs
npx stylelint research/polychord/review-instrument/styles.css
mise css:lint:fix
node --check research/polychord/review-instrument/app.mjs
node --check research/polychord/review-instrument/model.mjs
node --check research/polychord/review-instrument/presentation.mjs
node --test tool/polychord/review_instrument_test.mjs
python3 -m unittest discover -s tool/polychord -p '*_test.py'
git diff --check
```

A temporary localhost server returned HTTP 200 and the expected content type for
the instrument, controller, presentation module, manifest, both PNGs, packet,
and guide. Five Node tests and 24 Python tests passed. The packet generator
reported `unchanged`, confirming that its case evidence, order, response fields,
and blinding remain derived from the same ruler; only the pinned reviewer-guide
digest changed.

The available in-app browser-control integration could not initialize because
its packaged bootstrap imported `node:process`, which the provided control
runtime prohibited. The failure occurred before a browser was selected and is
not a repository, localhost, or nono permission failure. Consequently, the
interactive, responsive, download, browser-storage, keyboard, and assistive-
technology checklist remains explicitly incomplete.

Pinned SHA-256 digests:

- reviewer guide:
  `6bd6c592bebd72f36aa29ce1258cd4c710e3716cc6409e6b96a9b5c8f60a6806`;
- technical response schema:
  `a5d74b24a72d531454119c4f731f32cf6cb612447852f6d21e67435501079217`;
- neutral review packet:
  `5c9c389f46c65664a2db92cef797980764369c0db53656f222497e68cfea79fe`;
- evidence-presentation manifest:
  `a77bcab355ddeafde6804353235834c2e820164256c7a5fce0c7cfcd44cdeb6b`;
- Petrushka excerpt:
  `5b7f59dbfb9757253305c6743a4d24c99109b86c76517d545d54d7c678e8e184`;
- Augurs excerpt:
  `d552b39f1f9d19c6904674f5d8bb756c376784ebec561f3af9be257d4893405e`;
- instrument HTML:
  `12a4eba567f397365eca1d7fe5206aea9ab48eb052d12b3a030343fa4a1b24a6`;
- instrument CSS:
  `e208e92f8a3b2e1354b797a0a3326620607c09487c642e471bac3e9e14ca75fe`;
- browser controller:
  `20643d42531e726f6576bb64fcc1ab346a932fd49446fd99d175cd75d051c16e`;
- pure response model:
  `4f5c68f7e7966805382ace7b299cf61db7e2f46e90758e96034eed136cc01fe4`;
- presentation model:
  `493902dcb407564777ab80463b11d9d533fe6f934e66682b6e83307eb102ea60`;
- score-excerpt generator:
  `a31530a3d0bfc724fd4ed40422c4a07c41252fd3427749608cb93c86289eaf8c`;
- score-excerpt generator test:
  `d736a24ce6d763f5caa2b81b08150d720b11b16102f49120d0e10a8dcd44c31d`;
- cross-language instrument test:
  `324df1619cc6902054febbc4f0370efcd3e4a5e32d54258fe270d1a02f8ec59d`.

**What happened.** `pilot-annotation.md` is now a musician-facing handbook. Raw
field names, JSON examples, validation commands, agreement measures, and
blocking rules moved to `pilot-response-schema.md`; their substance was not
removed. The handbook states the construct in constructional rather than
perceptual terms, explains all four construction choices and three input
conditions in ordinary musical language, identifies the necessary reviewer
skills, and makes clear that programming, MIDI, JSON, MIR, and WhatChord
knowledge are not qualifications.

Instrument version `polychord-pilot-review-instrument/2` begins with a standard
10-to-15-minute orientation. Three worked examples cover an expected polychord,
an integrated-chord guard, and a single-chord-preferred boundary. Their exact
octave-specific note collections are tested not to occur in the scored packet.
Three task-boundary questions give fixed feedback and gate the scored cases.
Their answers are not retained or exported; local state stores only that the
orientation was completed.

Generated cases now show written scientific-pitch names, a neutral keyboard,
and a plain attack timeline. Black-key notes display both common enharmonic
names because the blinded MIDI evidence carries no spelling. Note assignment
uses those names, and score pitch membership uses named pitch classes rather
than integers. Raw MIDI and onset JSON remain available under collapsed
technical provenance. Score cases embed the verified unannotated crops and link
to the complete source; the application verifies the manifest and both image
digests before showing any scored case.

The response schema remains `polychord-pilot-review/1`. The export retains the
same evidence, neutral order, construction values, layer representation,
recoverability fields, confidence, and notes. The new interface wording is an
explicit mapping onto those stored values, not a data migration or answer
normalization.

**Plain-English reading.** A qualified theory musician can now learn and perform
the review as a musical task. They see scores, note names, keyboards, and timing
rather than being asked to decode MIDI numbers or edit a research file. The
computer still keeps the exact raw evidence needed for reproducibility, but it
does not make that implementation detail the reviewer's job. The six scored
answers are still blinded and structurally comparable with the initial ruler.

**Decisions.** Supersede instrument version 1 with version 2 before collecting
responses; do not rewrite log -10 or imply that version 1 collected data. Treat
`pilot-annotation.md` as the reviewer handbook and
`pilot-response-schema.md` as its technical companion. Require formal theory or
equivalent advanced experience, but no software or MIR knowledge. Use the same
orientation and feedback for every reviewer, and exclude the cognitive-
walkthrough participant from the independent panel.

Keep synthesized audio out of this pilot. A synthesized performance would add
timbre, articulation, duration, balance, and potentially layer-segregation cues
that are not present in the current symbolic evidence. Any later audio condition
must be separately designed, rendered, pinned, and reviewed as a new evidence
condition.

The presentation redesign does not make the pilot distribution-ready. It also
does not freeze an accuracy ruler or authorize an engine lever.

**Next.** Conduct one no-data cognitive walkthrough with a qualified musician
who will not join the pilot panel. Fix and version any wording or evidence-view
failure it exposes. Complete the recorded real-browser, responsive, keyboard,
and assistive-technology pass when the browser-control surface is available.
Separately freeze and test the multi-reviewer comparison report required by the
protocol. Only then distribute the pinned instrument independently to two,
preferably three, qualified reviewers.
